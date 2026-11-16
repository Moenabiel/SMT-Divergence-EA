#ifndef MARKET_STRUCTURE_ENGINE_MQH
#define MARKET_STRUCTURE_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CMarketStructureEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   int m_lookback;
   double m_swing_ratio;

   void FindSwingPoints(string symbol, int lookback, double &swings_high[], double &swings_low[],
                        datetime &times_high[], datetime &times_low[], int &count_h, int &count_l)
   {
      count_h = 0;
      count_l = 0;
      ArrayResize(swings_high, lookback);
      ArrayResize(swings_low, lookback);
      ArrayResize(times_high, lookback);
      ArrayResize(times_low, lookback);

      for(int i = 2; i < lookback - 2; i++)
      {
         double h = m_symbol_mgr.GetHigh(symbol, i);
         double h1 = m_symbol_mgr.GetHigh(symbol, i - 1);
         double h2 = m_symbol_mgr.GetHigh(symbol, i - 2);
         double h3 = m_symbol_mgr.GetHigh(symbol, i + 1);
         double h4 = m_symbol_mgr.GetHigh(symbol, i + 2);

         if(h >= h1 && h >= h2 && h >= h3 && h >= h4)
         {
            if(count_h < lookback)
            {
               swings_high[count_h] = h;
               times_high[count_h] = m_symbol_mgr.GetTime(symbol, i);
               count_h++;
            }
         }

         double l = m_symbol_mgr.GetLow(symbol, i);
         double l1 = m_symbol_mgr.GetLow(symbol, i - 1);
         double l2 = m_symbol_mgr.GetLow(symbol, i - 2);
         double l3 = m_symbol_mgr.GetLow(symbol, i + 1);
         double l4 = m_symbol_mgr.GetLow(symbol, i + 2);

         if(l <= l1 && l <= l2 && l <= l3 && l <= l4)
         {
            if(count_l < lookback)
            {
               swings_low[count_l] = l;
               times_low[count_l] = m_symbol_mgr.GetTime(symbol, i);
               count_l++;
            }
         }
      }
   }

public:
   CMarketStructureEngine()
   {
      m_symbol_mgr  = NULL;
      m_log_mgr     = NULL;
      m_lookback    = 50;
      m_swing_ratio = 0.5;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log, int lookback = 50)
   {
      m_symbol_mgr = sym;
      m_log_mgr    = log;
      m_lookback   = lookback;

      Print("MarketStructureEngine: Initialized. Lookback=", lookback);
      return true;
   }

   StructureResult DetectStructure(string symbol, int timeframe_shift = 0)
   {
      StructureResult result;
      result.shift            = STRUCT_NONE;
      result.level            = 0;
      result.time             = 0;
      result.displacement_size = 0;

      if(m_symbol_mgr == NULL) return result;

      double swings_high[];
      double swings_low[];
      datetime times_high[];
      datetime times_low[];
      int count_h = 0, count_l = 0;

      FindSwingPoints(symbol, m_lookback, swings_high, swings_low,
                      times_high, times_low, count_h, count_l);

      if(count_h < 3 || count_l < 3) return result;

      double close = m_symbol_mgr.GetClose(symbol, timeframe_shift);
      double prev_close = m_symbol_mgr.GetClose(symbol, timeframe_shift + 1);

      for(int i = 0; i < count_h - 2; i++)
      {
         if(swings_high[i] > swings_high[i + 1])
         {
            if(close > swings_high[i] && prev_close <= swings_high[i])
            {
               result.shift = STRUCT_CHOCH_BULL;
               result.level = swings_high[i];
               result.time  = times_high[i];
               result.displacement_size = MathAbs(close - swings_high[i]);
               break;
            }
         }
      }

      for(int i = 0; i < count_l - 2; i++)
      {
         if(swings_low[i] < swings_low[i + 1])
         {
            if(close < swings_low[i] && prev_close >= swings_low[i])
            {
               result.shift = STRUCT_CHOCH_BEAR;
               result.level = swings_low[i];
               result.time  = times_low[i];
               result.displacement_size = MathAbs(swings_low[i] - close);
               break;
            }
         }
      }

      if(result.shift == STRUCT_NONE)
      {
         for(int i = 0; i < count_h - 3; i++)
         {
            bool higher_high = swings_high[i] > swings_high[i + 2];
            bool break_low = close > swings_high[i + 1];

            if(higher_high && break_low)
            {
               result.shift = STRUCT_MSS_BULL;
               result.level = swings_high[i + 1];
               result.time  = times_high[i + 1];
               result.displacement_size = MathAbs(close - swings_high[i + 1]);
               break;
            }
         }
      }

      if(result.shift == STRUCT_NONE)
      {
         for(int i = 0; i < count_l - 3; i++)
         {
            bool lower_low = swings_low[i] < swings_low[i + 2];
            bool break_high = close < swings_low[i + 1];

            if(lower_low && break_high)
            {
               result.shift = STRUCT_MSS_BEAR;
               result.level = swings_low[i + 1];
               result.time  = times_low[i + 1];
               result.displacement_size = MathAbs(swings_low[i + 1] - close);
               break;
            }
         }
      }

      if(m_log_mgr != NULL && result.shift != STRUCT_NONE)
         m_log_mgr.LogStructure(symbol, result);

      return result;
   }

   double GetStructureScore(StructureResult &result)
   {
      if(result.shift == STRUCT_NONE) return 0;
      return 20.0;
   }

   bool IsStructureConfirmed(StructureResult &result)
   {
      return (result.shift != STRUCT_NONE);
   }
};

#endif
