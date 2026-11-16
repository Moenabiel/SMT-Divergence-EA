#ifndef FVG_ENGINE_MQH
#define FVG_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CFVGEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   FVGZone m_zones[];
   int     m_zone_count;

   double m_min_gap_pips;
   double m_max_gap_pips;
   double m_fill_threshold;

   void AddZone(double top, double bottom, bool bullish, datetime time, int bar)
   {
      m_zone_count++;
      ArrayResize(m_zones, m_zone_count);
      m_zones[m_zone_count - 1].top      = top;
      m_zones[m_zone_count - 1].bottom   = bottom;
      m_zones[m_zone_count - 1].bullish  = bullish;
      m_zones[m_zone_count - 1].time     = time;
      m_zones[m_zone_count - 1].filled   = false;
      m_zones[m_zone_count - 1].bar_index = bar;
   }

   void UpdateFillStatus(string symbol)
   {
      double price = m_symbol_mgr.GetClose(symbol, 0);

      for(int i = 0; i < m_zone_count; i++)
      {
         if(m_zones[i].filled) continue;

         if(m_zones[i].bullish)
         {
            if(price <= m_zones[i].bottom)
               m_zones[i].filled = true;
         }
         else
         {
            if(price >= m_zones[i].top)
               m_zones[i].filled = true;
         }
      }
   }

public:
   CFVGEngine()
   {
      m_symbol_mgr    = NULL;
      m_log_mgr       = NULL;
      m_zone_count    = 0;
      m_min_gap_pips  = 2;
      m_max_gap_pips  = 200;
      m_fill_threshold = 50;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             double min_gap = 2, double max_gap = 200, double fill_pct = 50)
   {
      m_symbol_mgr    = sym;
      m_log_mgr       = log;
      m_min_gap_pips  = min_gap;
      m_max_gap_pips  = max_gap;
      m_fill_threshold = fill_pct;

      Print("FVGEngine: Initialized. MinGap=", min_gap, " MaxGap=", max_gap);
      return true;
   }

   void DetectFVGs(string symbol, int lookback = 50)
   {
      m_zone_count = 0;
      ArrayResize(m_zones, 0);

      if(m_symbol_mgr == NULL) return;

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double min_gap = m_min_gap_pips * point;
      double max_gap = m_max_gap_pips * point;

      for(int i = 2; i < lookback; i++)
      {
         double high_prev = m_symbol_mgr.GetHigh(symbol, i);
         double low_next  = m_symbol_mgr.GetLow(symbol, i - 2);

         if(m_symbol_mgr.IsBullish(symbol, i - 1))
         {
            double gap = low_next - high_prev;
            if(gap > min_gap && gap < max_gap)
            {
               datetime time = m_symbol_mgr.GetTime(symbol, i - 1);
               AddZone(low_next, high_prev, true, time, i - 1);
            }
         }

         double high_next = m_symbol_mgr.GetHigh(symbol, i - 2);
         double low_prev  = m_symbol_mgr.GetLow(symbol, i);

         if(m_symbol_mgr.IsBearish(symbol, i - 1))
         {
            double gap = low_prev - high_next;
            if(gap > min_gap && gap < max_gap)
            {
               datetime time = m_symbol_mgr.GetTime(symbol, i - 1);
               AddZone(low_prev, high_next, false, time, i - 1);
            }
         }
      }

      UpdateFillStatus(symbol);
   }

   FVGZone GetNearestFVG(string symbol, bool bullish_fvg, double current_price)
   {
      FVGZone empty;
      empty.top = 0; empty.bottom = 0; empty.bullish = false;
      empty.time = 0; empty.filled = true; empty.bar_index = -1;

      double nearest_dist = DBL_MAX;
      int nearest_idx = -1;

      for(int i = 0; i < m_zone_count; i++)
      {
         if(m_zones[i].filled) continue;
         if(m_zones[i].bullish != bullish_fvg) continue;

         double mid = (m_zones[i].top + m_zones[i].bottom) / 2.0;
         double dist = MathAbs(current_price - mid);

         if(dist < nearest_dist)
         {
            nearest_dist = dist;
            nearest_idx = i;
         }
      }

      if(nearest_idx >= 0) return m_zones[nearest_idx];
      return empty;
   }

   bool IsPriceInFVG(string symbol, double price)
   {
      for(int i = 0; i < m_zone_count; i++)
      {
         if(m_zones[i].filled) continue;

         if(price >= m_zones[i].bottom && price <= m_zones[i].top)
            return true;
      }
      return false;
   }

   double GetFVGScore()
   {
      for(int i = 0; i < m_zone_count; i++)
      {
         if(!m_zones[i].filled)
            return 10.0;
      }
      return 0;
   }

   int GetZoneCount()    { return m_zone_count; }
   FVGZone GetZone(int idx)
   {
      if(idx >= 0 && idx < m_zone_count) return m_zones[idx];
      FVGZone empty;
      empty.top = 0;
      return empty;
   }
};

#endif
