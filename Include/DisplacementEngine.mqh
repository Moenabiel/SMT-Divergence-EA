#ifndef DISPLACEMENT_ENGINE_MQH
#define DISPLACEMENT_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CDisplacementEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   double m_min_atr_multiple;
   double m_min_body_ratio;
   int    m_consecutive_candles;

public:
   CDisplacementEngine()
   {
      m_symbol_mgr         = NULL;
      m_log_mgr            = NULL;
      m_min_atr_multiple   = 1.5;
      m_min_body_ratio     = 0.70;
      m_consecutive_candles = 1;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             double min_atr = 1.5, double body_ratio = 0.70, int consecutive = 1)
   {
      m_symbol_mgr         = sym;
      m_log_mgr            = log;
      m_min_atr_multiple   = min_atr;
      m_min_body_ratio     = body_ratio;
      m_consecutive_candles = consecutive;

      Print("DisplacementEngine: Initialized. MinATR=", min_atr,
            " BodyRatio=", body_ratio, " Consecutive=", consecutive);
      return true;
   }

   bool DetectDisplacement(string symbol, int shift, bool &is_bullish, double &strength)
   {
      if(m_symbol_mgr == NULL) return false;

      int consecutive_count = 0;
      bool first_direction = false;
      double total_body = 0;
      double min_strength = DBL_MAX;

      for(int i = 0; i < m_consecutive_candles && (shift + i) < MAX_BARS; i++)
      {
         int idx = shift + i;
         double body = m_symbol_mgr.GetBodySize(symbol, idx);
         double ratio = m_symbol_mgr.GetBodyRatio(symbol, idx);
         double atr = m_symbol_mgr.GetATR(symbol, 14, idx);

         if(atr < POINT_EPSILON) continue;

         double imp = body / atr;
         bool is_bull = m_symbol_mgr.IsBullish(symbol, idx);

         if(i == 0)
            first_direction = is_bull;

         if(is_bull != first_direction) break;

         if(imp >= m_min_atr_multiple && ratio >= m_min_body_ratio)
         {
            consecutive_count++;
            total_body += body;
            if(imp < min_strength) min_strength = imp;
         }
         else
         {
            break;
         }
      }

      if(consecutive_count >= m_consecutive_candles)
      {
         is_bullish = first_direction;
         strength = min_strength;

         if(m_log_mgr != NULL)
         {
            string dir = is_bullish ? "BULLISH" : "BEARISH";
            m_log_mgr.Log(StringFormat("%s: Displacement %s detected. Strength=%.2f, Candles=%d",
                           symbol, dir, strength, consecutive_count), LOG_INFO);
         }
         return true;
      }

      return false;
   }

   bool HasDisplacement(string symbol, int shift = 0)
   {
      bool is_bull = false;
      double str = 0;
      return DetectDisplacement(symbol, shift, is_bull, str);
   }

   double GetDisplacementScore(string symbol, int shift = 0)
   {
      bool is_bull = false;
      double str = 0;
      if(DetectDisplacement(symbol, shift, is_bull, str))
         return 15.0;
      return 0;
   }
};

#endif
