#ifndef MARKET_REGIME_ENGINE_MQH
#define MARKET_REGIME_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CMarketRegimeEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   ENUM_MARKET_REGIME m_current_regime;
   int    m_adx_period;
   int    m_atr_period;
   int    m_trend_lookback;
   double m_trending_threshold;
   double m_high_vol_multiplier;
   double m_low_vol_multiplier;

   int GetADXHandle(string symbol)
   {
      return iADX(symbol, (ENUM_TIMEFRAMES)m_symbol_mgr.GetTimeframe(), m_adx_period);
   }

   double GetADX(string symbol, int shift)
   {
      int handle = GetADXHandle(symbol);
      if(handle == INVALID_HANDLE) return 0;

      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, shift, 1, buf) < 1)
      {
         IndicatorRelease(handle);
         return 0;
      }
      double val = buf[0];
      IndicatorRelease(handle);
      return val;
   }

   double GetATRAverage(string symbol, int period, int lookback)
   {
      double total = 0;
      for(int i = 0; i < lookback; i++)
      {
         total += m_symbol_mgr.GetATR(symbol, period, i);
      }
      return total / lookback;
   }

   bool IsTrendingUp(string symbol)
   {
      int lookback = MathMin(m_trend_lookback, MAX_BARS - 10);
      int highs_count = 0;
      int lows_count = 0;

      for(int i = 0; i < lookback - 1; i++)
      {
         if(m_symbol_mgr.GetHigh(symbol, i) > m_symbol_mgr.GetHigh(symbol, i + 1))
            highs_count++;
         if(m_symbol_mgr.GetLow(symbol, i) > m_symbol_mgr.GetLow(symbol, i + 1))
            lows_count++;
      }

      return (highs_count > lookback * 0.6 && lows_count > lookback * 0.6);
   }

   bool IsTrendingDown(string symbol)
   {
      int lookback = MathMin(m_trend_lookback, MAX_BARS - 10);
      int highs_count = 0;
      int lows_count = 0;

      for(int i = 0; i < lookback - 1; i++)
      {
         if(m_symbol_mgr.GetHigh(symbol, i) < m_symbol_mgr.GetHigh(symbol, i + 1))
            highs_count++;
         if(m_symbol_mgr.GetLow(symbol, i) < m_symbol_mgr.GetLow(symbol, i + 1))
            lows_count++;
      }

      return (highs_count > lookback * 0.6 && lows_count > lookback * 0.6);
   }

public:
   CMarketRegimeEngine()
   {
      m_symbol_mgr        = NULL;
      m_log_mgr           = NULL;
      m_current_regime    = REGIME_RANGING;
      m_adx_period        = 14;
      m_atr_period        = 14;
      m_trend_lookback    = 20;
      m_trending_threshold = 25;
      m_high_vol_multiplier = 1.5;
      m_low_vol_multiplier  = 0.5;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             int adx_period = 14, int trend_lookback = 20)
   {
      m_symbol_mgr     = sym;
      m_log_mgr        = log;
      m_adx_period     = adx_period;
      m_trend_lookback = trend_lookback;

      Print("MarketRegimeEngine: Initialized. ADX period=", adx_period);
      return true;
   }

   ENUM_MARKET_REGIME Classify(string symbol)
   {
      if(m_symbol_mgr == NULL) return REGIME_RANGING;

      double adx = GetADX(symbol, 0);
      double atr = m_symbol_mgr.GetATR(symbol, m_atr_period, 0);
      double atr_avg = GetATRAverage(symbol, m_atr_period, 20);

      bool trending = (adx >= m_trending_threshold);
      bool high_vol = (atr > atr_avg * m_high_vol_multiplier);
      bool low_vol  = (atr < atr_avg * m_low_vol_multiplier);

      if(high_vol)
      {
         m_current_regime = REGIME_HIGH_VOL;
      }
      else if(low_vol)
      {
         m_current_regime = REGIME_LOW_VOL;
      }
      else if(trending)
      {
         if(IsTrendingUp(symbol) || IsTrendingDown(symbol))
            m_current_regime = REGIME_TRENDING;
         else
            m_current_regime = REGIME_EXPANSION;
      }
      else
      {
         m_current_regime = REGIME_RANGING;
      }

      if(m_log_mgr != NULL)
      {
         m_log_mgr.Log(StringFormat("%s: Regime=%s ADX=%.1f ATR=%.5f ATR_Avg=%.5f",
                        symbol, GetRegimeName(m_current_regime), adx, atr, atr_avg), LOG_DEBUG);
      }

      return m_current_regime;
   }

   ENUM_MARKET_REGIME GetRegime()  { return m_current_regime; }

   double GetRegimeScore(ENUM_SMT_DIRECTION smt_dir)
   {
      switch(m_current_regime)
      {
         case REGIME_TRENDING:
            if(smt_dir != SMT_INVALID) return 10.0;
            break;
         case REGIME_RANGING:
            if(smt_dir != SMT_INVALID) return 7.0;
            break;
         case REGIME_EXPANSION:
            if(smt_dir != SMT_INVALID) return 8.0;
            break;
         case REGIME_REVERSAL:
            if(smt_dir != SMT_INVALID) return 10.0;
            break;
         default:
            break;
      }
      return 5.0;
   }

   string GetRegimeName(ENUM_MARKET_REGIME regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING:   return "Trending";
         case REGIME_RANGING:    return "Ranging";
         case REGIME_EXPANSION:  return "Expansion";
         case REGIME_REVERSAL:   return "Reversal";
         case REGIME_HIGH_VOL:   return "High Vol";
         case REGIME_LOW_VOL:    return "Low Vol";
         default:                return "Unknown";
      }
   }
};

#endif
