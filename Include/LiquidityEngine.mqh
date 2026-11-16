#ifndef LIQUIDITY_ENGINE_MQH
#define LIQUIDITY_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "SessionManager.mqh"
#include "LoggingManager.mqh"

class CLiquidityEngine
{
private:
   CSymbolManager   *m_symbol_mgr;
   CSessionManager  *m_session_mgr;
   CLoggingManager  *m_log_mgr;

   LiquidityLevel m_levels[];
   int            m_level_count;

   double m_sweep_buffer_pips;
   int    m_sweep_confirm_bars;
   int    m_equal_level_lookback;
   double m_equal_level_tolerance_pips;

   void AddLevel(double price, ENUM_LIQUIDITY_TYPE type, datetime time)
   {
      if(price < POINT_EPSILON) return;

      double point = SymbolInfoDouble(m_symbol_mgr.GetSymbol1(), SYMBOL_POINT);
      double tolerance = m_equal_level_tolerance_pips * point;

      for(int i = 0; i < m_level_count; i++)
      {
         double diff = MathAbs(m_levels[i].price - price);
         if(diff < tolerance)
            return;
      }

      m_level_count++;
      ArrayResize(m_levels, m_level_count);
      m_levels[m_level_count - 1].price      = price;
      m_levels[m_level_count - 1].type       = type;
      m_levels[m_level_count - 1].time       = time;
      m_levels[m_level_count - 1].swept      = false;
      m_levels[m_level_count - 1].sweep_bar  = -1;
   }

public:
   CLiquidityEngine()
   {
      m_symbol_mgr  = NULL;
      m_session_mgr = NULL;
      m_log_mgr     = NULL;
      m_level_count = 0;

      m_sweep_buffer_pips       = 10;
      m_sweep_confirm_bars      = 1;
      m_equal_level_lookback    = 20;
      m_equal_level_tolerance_pips = 5;
   }

   bool Init(CSymbolManager *sym, CSessionManager *sess, CLoggingManager *log,
             double sweep_buffer = 10, double equal_tol = 5)
   {
      m_symbol_mgr  = sym;
      m_session_mgr = sess;
      m_log_mgr     = log;
      m_sweep_buffer_pips = sweep_buffer;
      m_equal_level_tolerance_pips = equal_tol;

      m_level_count = 0;
      ArrayResize(m_levels, 0);

      Print("LiquidityEngine: Initialized. Sweep buffer=", sweep_buffer, " pips");
      return true;
   }

   void Update()
   {
      if(m_symbol_mgr == NULL || m_session_mgr == NULL) return;

      m_level_count = 0;
      ArrayResize(m_levels, 0);

      AddLevel(m_session_mgr.GetPDH(), LIQ_DAILY_HIGH,  iTime(m_symbol_mgr.GetSymbol1(), PERIOD_D1, 1));
      AddLevel(m_session_mgr.GetPDL(), LIQ_DAILY_LOW,   iTime(m_symbol_mgr.GetSymbol1(), PERIOD_D1, 1));
      AddLevel(m_session_mgr.GetPDO(), LIQ_DAILY_OPEN,  iTime(m_symbol_mgr.GetSymbol1(), PERIOD_D1, 1));
      AddLevel(m_session_mgr.GetPDC(), LIQ_DAILY_CLOSE, iTime(m_symbol_mgr.GetSymbol1(), PERIOD_D1, 1));

      AddLevel(m_session_mgr.GetWH(), LIQ_WEEKLY_HIGH, iTime(m_symbol_mgr.GetSymbol1(), PERIOD_W1, 1));
      AddLevel(m_session_mgr.GetWL(), LIQ_WEEKLY_LOW,  iTime(m_symbol_mgr.GetSymbol1(), PERIOD_W1, 1));

      SessionRange ar = m_session_mgr.GetAsianRange();
      if(ar.high > POINT_EPSILON)  AddLevel(ar.high, LIQ_ASIAN_HIGH, ar.start);
      if(ar.low < DBL_MAX)        AddLevel(ar.low,  LIQ_ASIAN_LOW,  ar.start);

      SessionRange lr = m_session_mgr.GetLondonRange();
      if(lr.high > POINT_EPSILON)  AddLevel(lr.high, LIQ_LONDON_HIGH, lr.start);
      if(lr.low < DBL_MAX)        AddLevel(lr.low,  LIQ_LONDON_LOW,  lr.start);

      SessionRange nr = m_session_mgr.GetNYRange();
      if(nr.high > POINT_EPSILON)  AddLevel(nr.high, LIQ_NY_HIGH, nr.start);
      if(nr.low < DBL_MAX)        AddLevel(nr.low,  LIQ_NY_LOW,  nr.start);

      SessionRange or_range = m_session_mgr.GetORRange();
      if(or_range.high > POINT_EPSILON)  AddLevel(or_range.high, LIQ_OR_HIGH, or_range.start);
      if(or_range.low < DBL_MAX)        AddLevel(or_range.low,  LIQ_OR_LOW,  or_range.start);

      DetectEqualLevels(m_symbol_mgr.GetSymbol1());
      DetectEqualLevels(m_symbol_mgr.GetSymbol2());
   }

   void DetectEqualLevels(string symbol)
   {
      if(m_symbol_mgr == NULL) return;

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tolerance = m_equal_level_tolerance_pips * point;
      int lookback = MathMin(m_equal_level_lookback, MAX_BARS - 10);

      for(int i = 2; i < lookback; i++)
      {
         for(int j = i + 1; j < lookback; j++)
         {
            double h_i = m_symbol_mgr.GetHigh(symbol, i);
            double h_j = m_symbol_mgr.GetHigh(symbol, j);
            if(MathAbs(h_i - h_j) < tolerance && h_i > POINT_EPSILON)
               AddLevel(h_i, LIQ_DAILY_HIGH, m_symbol_mgr.GetTime(symbol, i));

            double l_i = m_symbol_mgr.GetLow(symbol, i);
            double l_j = m_symbol_mgr.GetLow(symbol, j);
            if(MathAbs(l_i - l_j) < tolerance && l_i > POINT_EPSILON)
               AddLevel(l_i, LIQ_DAILY_LOW, m_symbol_mgr.GetTime(symbol, i));
         }
      }
   }

   bool DetectSweep(string symbol, int shift)
   {
      if(m_symbol_mgr == NULL) return false;

      double high = m_symbol_mgr.GetHigh(symbol, shift);
      double low  = m_symbol_mgr.GetLow(symbol, shift);
      double close = m_symbol_mgr.GetClose(symbol, shift);

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double buffer = m_sweep_buffer_pips * point;

      bool swept = false;

      for(int i = 0; i < m_level_count; i++)
      {
         if(m_levels[i].swept) continue;

         if(high > m_levels[i].price + buffer && close < m_levels[i].price)
         {
            m_levels[i].swept     = true;
            m_levels[i].sweep_bar = shift;
            swept = true;

            if(m_log_mgr != NULL)
            {
               string name = GetLevelName(m_levels[i].type);
               m_log_mgr.LogLiquidity(symbol, "swept", m_levels[i].price, name);
            }
         }

         if(low < m_levels[i].price - buffer && close > m_levels[i].price)
         {
            m_levels[i].swept     = true;
            m_levels[i].sweep_bar = shift;
            swept = true;

            if(m_log_mgr != NULL)
            {
               string name = GetLevelName(m_levels[i].type);
               m_log_mgr.LogLiquidity(symbol, "swept", m_levels[i].price, name);
            }
         }
      }

      return swept;
   }

   LiquidityLevel GetNearestLevel(string symbol, bool above, int shift = 0)
   {
      LiquidityLevel empty;
      empty.price = 0;
      empty.type  = LIQ_DAILY_HIGH;
      empty.time  = 0;
      empty.swept = false;
      empty.sweep_bar = -1;

      double current_price = m_symbol_mgr.GetClose(symbol, shift);
      double nearest_dist = DBL_MAX;
      int    nearest_idx  = -1;

      for(int i = 0; i < m_level_count; i++)
      {
         if(m_levels[i].swept) continue;

         if(above && m_levels[i].price > current_price)
         {
            double dist = m_levels[i].price - current_price;
            if(dist < nearest_dist)
            {
               nearest_dist = dist;
               nearest_idx = i;
            }
         }
         else if(!above && m_levels[i].price < current_price)
         {
            double dist = current_price - m_levels[i].price;
            if(dist < nearest_dist)
            {
               nearest_dist = dist;
               nearest_idx = i;
            }
         }
      }

      if(nearest_idx >= 0) return m_levels[nearest_idx];
      return empty;
   }

   int GetLevelCount()  { return m_level_count; }

   LiquidityLevel GetLevel(int index)
   {
      if(index >= 0 && index < m_level_count)
         return m_levels[index];

      LiquidityLevel empty;
      empty.price = 0;
      return empty;
   }

   double GetLiquidityScore()
   {
      for(int i = 0; i < m_level_count; i++)
      {
         if(m_levels[i].swept)
            return 15.0;
      }
      return 0;
   }

   string GetLevelName(ENUM_LIQUIDITY_TYPE type)
   {
      switch(type)
      {
         case LIQ_DAILY_HIGH:  return "PDH";
         case LIQ_DAILY_LOW:   return "PDL";
         case LIQ_DAILY_OPEN:  return "PDO";
         case LIQ_DAILY_CLOSE: return "PDC";
         case LIQ_WEEKLY_HIGH: return "WH";
         case LIQ_WEEKLY_LOW:  return "WL";
         case LIQ_ASIAN_HIGH:  return "Asian High";
         case LIQ_ASIAN_LOW:   return "Asian Low";
         case LIQ_LONDON_HIGH: return "London High";
         case LIQ_LONDON_LOW:  return "London Low";
         case LIQ_NY_HIGH:     return "NY High";
         case LIQ_NY_LOW:      return "NY Low";
         case LIQ_OR_HIGH:     return "OR High";
         case LIQ_OR_LOW:      return "OR Low";
         default:              return "Unknown";
      }
   }
};

#endif
