#ifndef ORDER_BLOCK_ENGINE_MQH
#define ORDER_BLOCK_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class COrderBlockEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   OrderBlock m_blocks[];
   int        m_block_count;

   int    m_lookback;
   double m_min_impulse_atr;

   void AddBlock(double high, double low, bool bullish, datetime time, int bar)
   {
      m_block_count++;
      ArrayResize(m_blocks, m_block_count);
      m_blocks[m_block_count - 1].high      = high;
      m_blocks[m_block_count - 1].low       = low;
      m_blocks[m_block_count - 1].bullish   = bullish;
      m_blocks[m_block_count - 1].time      = time;
      m_blocks[m_block_count - 1].mitigated = false;
      m_blocks[m_block_count - 1].bar_index = bar;
   }

public:
   COrderBlockEngine()
   {
      m_symbol_mgr       = NULL;
      m_log_mgr          = NULL;
      m_block_count      = 0;
      m_lookback         = 50;
      m_min_impulse_atr  = 1.5;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             int lookback = 50, double min_impulse = 1.5)
   {
      m_symbol_mgr      = sym;
      m_log_mgr         = log;
      m_lookback        = lookback;
      m_min_impulse_atr = min_impulse;

      Print("OrderBlockEngine: Initialized. Lookback=", lookback, " MinImpulse=", min_impulse);
      return true;
   }

   void DetectOrderBlocks(string symbol)
   {
      m_block_count = 0;
      ArrayResize(m_blocks, 0);

      if(m_symbol_mgr == NULL) return;

      for(int i = 1; i < m_lookback - 1; i++)
      {
         double impulse = m_symbol_mgr.GetImpulseStrength(symbol, i - 1, 14);
         bool is_impulsive = (impulse >= m_min_impulse_atr);

         if(!is_impulsive) continue;

         bool impulse_bull = m_symbol_mgr.IsBullish(symbol, i - 1);

         int ob_bar = i;
         if(impulse_bull)
         {
            if(m_symbol_mgr.IsBearish(symbol, ob_bar))
            {
               AddBlock(m_symbol_mgr.GetHigh(symbol, ob_bar),
                        m_symbol_mgr.GetLow(symbol, ob_bar),
                        true, m_symbol_mgr.GetTime(symbol, ob_bar), ob_bar);
            }
         }
         else
         {
            if(m_symbol_mgr.IsBullish(symbol, ob_bar))
            {
               AddBlock(m_symbol_mgr.GetHigh(symbol, ob_bar),
                        m_symbol_mgr.GetLow(symbol, ob_bar),
                        false, m_symbol_mgr.GetTime(symbol, ob_bar), ob_bar);
            }
         }
      }

      UpdateMitigation(symbol);
   }

   void UpdateMitigation(string symbol)
   {
      double price = m_symbol_mgr.GetClose(symbol, 0);

      for(int i = 0; i < m_block_count; i++)
      {
         if(m_blocks[i].mitigated) continue;

         if(m_blocks[i].bullish)
         {
            if(price < m_blocks[i].low)
               m_blocks[i].mitigated = true;
         }
         else
         {
            if(price > m_blocks[i].high)
               m_blocks[i].mitigated = true;
         }
      }
   }

   OrderBlock GetNearestOB(string symbol, bool bullish_ob)
   {
      OrderBlock empty;
      empty.high = 0; empty.low = 0; empty.bullish = false;
      empty.time = 0; empty.mitigated = true; empty.bar_index = -1;

      double price = m_symbol_mgr.GetClose(symbol, 0);
      double nearest_dist = DBL_MAX;
      int nearest_idx = -1;

      for(int i = 0; i < m_block_count; i++)
      {
         if(m_blocks[i].mitigated) continue;
         if(m_blocks[i].bullish != bullish_ob) continue;

         double mid = (m_blocks[i].high + m_blocks[i].low) / 2.0;
         double dist = MathAbs(price - mid);

         if(dist < nearest_dist)
         {
            nearest_dist = dist;
            nearest_idx = i;
         }
      }

      if(nearest_idx >= 0) return m_blocks[nearest_idx];
      return empty;
   }

   bool IsPriceInOB(string symbol, double price)
   {
      for(int i = 0; i < m_block_count; i++)
      {
         if(m_blocks[i].mitigated) continue;

         if(price >= m_blocks[i].low && price <= m_blocks[i].high)
            return true;
      }
      return false;
   }

   double GetOBScore()
   {
      for(int i = 0; i < m_block_count; i++)
      {
         if(!m_blocks[i].mitigated)
            return 10.0;
      }
      return 0;
   }

   int GetBlockCount()   { return m_block_count; }
   OrderBlock GetBlock(int idx)
   {
      if(idx >= 0 && idx < m_block_count) return m_blocks[idx];
      OrderBlock empty;
      empty.high = 0;
      return empty;
   }
};

#endif
