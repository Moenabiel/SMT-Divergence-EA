#ifndef SMT_DETECTION_ENGINE_MQH
#define SMT_DETECTION_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "SessionManager.mqh"
#include "LiquidityEngine.mqh"
#include "LoggingManager.mqh"

class CSMTDetectionEngine
{
private:
   CSymbolManager   *m_symbol_mgr;
   CSessionManager  *m_session_mgr;
   CLiquidityEngine *m_liquidity_mgr;
   CLoggingManager  *m_log_mgr;

   int    m_sweep_confirm_bars;
   double m_sweep_buffer_pips;
   bool   m_tier3_enabled;

   SMTResult m_last_result;

   int GetDigits(string symbol)
   {
      return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   }

   bool DidSweepAbove(string symbol, double level, double buffer, int shift)
   {
      double high = m_symbol_mgr.GetHigh(symbol, shift);
      double close = m_symbol_mgr.GetClose(symbol, shift);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(level < POINT_EPSILON) return false;

      return (high > level + buffer * point && close < level + buffer * point * 0.5);
   }

   bool DidSweepBelow(string symbol, double level, double buffer, int shift)
   {
      double low = m_symbol_mgr.GetLow(symbol, shift);
      double close = m_symbol_mgr.GetClose(symbol, shift);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(level < POINT_EPSILON) return false;

      return (low < level - buffer * point && close > level - buffer * point * 0.5);
   }

   bool DidRefuseSweepAbove(string symbol, double level, double buffer, int lookback)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      for(int i = 0; i < lookback; i++)
      {
         double high = m_symbol_mgr.GetHigh(symbol, i);
         if(high > level + buffer * point)
            return false;
      }
      return true;
   }

   bool DidRefuseSweepBelow(string symbol, double level, double buffer, int lookback)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      for(int i = 0; i < lookback; i++)
      {
         double low = m_symbol_mgr.GetLow(symbol, i);
         if(low < level - buffer * point)
            return false;
      }
      return true;
   }

   SMTResult DetectBullishSMT(double level, string level_name, ENUM_SMT_TIER tier, double tier_score)
   {
      SMTResult result;
      result.direction   = SMT_INVALID;
      result.tier        = SMT_TIER_NONE;
      result.score       = 0;
      result.stronger_symbol = "";
      result.weaker_symbol   = "";
      result.signal_time     = TimeCurrent();

      string sym1 = m_symbol_mgr.GetSymbol1();
      string sym2 = m_symbol_mgr.GetSymbol2();

      bool sym1_swept  = DidSweepBelow(sym1, level, m_sweep_buffer_pips, 0);
      bool sym2_swept  = DidSweepBelow(sym2, level, m_sweep_buffer_pips, 0);

      bool sym1_refuse = DidRefuseSweepBelow(sym1, level, m_sweep_buffer_pips, m_sweep_confirm_bars + 1);
      bool sym2_refuse = DidRefuseSweepBelow(sym2, level, m_sweep_buffer_pips, m_sweep_confirm_bars + 1);

      if(sym1_swept && !sym2_swept && sym2_refuse)
      {
         result.direction       = SMT_BULLISH;
         result.tier            = tier;
         result.score           = tier_score;
         result.stronger_symbol = sym2;
         result.weaker_symbol   = sym1;
         result.reason          = sym1 + " swept " + level_name + " (" + DoubleToString(level, GetDigits(sym1)) + "), " + sym2 + " refused";
         return result;
      }

      if(sym2_swept && !sym1_swept && sym1_refuse)
      {
         result.direction       = SMT_BULLISH;
         result.tier            = tier;
         result.score           = tier_score;
         result.stronger_symbol = sym1;
         result.weaker_symbol   = sym2;
         result.reason          = sym2 + " swept " + level_name + " (" + DoubleToString(level, GetDigits(sym2)) + "), " + sym1 + " refused";
         return result;
      }

      if(sym1_swept && sym2_swept)
      {
         result.reason = "Both swept " + level_name + " - invalid";
         return result;
      }

      if(!sym1_swept && !sym2_swept)
      {
         result.reason = "Neither swept " + level_name + " - no signal";
         return result;
      }

      result.reason = "No valid SMT at " + level_name;
      return result;
   }

   SMTResult DetectBearishSMT(double level, string level_name, ENUM_SMT_TIER tier, double tier_score)
   {
      SMTResult result;
      result.direction   = SMT_INVALID;
      result.tier        = SMT_TIER_NONE;
      result.score       = 0;
      result.stronger_symbol = "";
      result.weaker_symbol   = "";
      result.signal_time     = TimeCurrent();

      string sym1 = m_symbol_mgr.GetSymbol1();
      string sym2 = m_symbol_mgr.GetSymbol2();

      bool sym1_swept  = DidSweepAbove(sym1, level, m_sweep_buffer_pips, 0);
      bool sym2_swept  = DidSweepAbove(sym2, level, m_sweep_buffer_pips, 0);

      bool sym1_refuse = DidRefuseSweepAbove(sym1, level, m_sweep_buffer_pips, m_sweep_confirm_bars + 1);
      bool sym2_refuse = DidRefuseSweepAbove(sym2, level, m_sweep_buffer_pips, m_sweep_confirm_bars + 1);

      if(sym1_swept && !sym2_swept && sym2_refuse)
      {
         result.direction       = SMT_BEARISH;
         result.tier            = tier;
         result.score           = tier_score;
         result.stronger_symbol = sym2;
         result.weaker_symbol   = sym1;
         result.reason          = sym1 + " swept " + level_name + " (" + DoubleToString(level, GetDigits(sym1)) + "), " + sym2 + " refused";
         return result;
      }

      if(sym2_swept && !sym1_swept && sym1_refuse)
      {
         result.direction       = SMT_BEARISH;
         result.tier            = tier;
         result.score           = tier_score;
         result.stronger_symbol = sym1;
         result.weaker_symbol   = sym2;
         result.reason          = sym2 + " swept " + level_name + " (" + DoubleToString(level, GetDigits(sym2)) + "), " + sym1 + " refused";
         return result;
      }

      if(sym1_swept && sym2_swept)
      {
         result.reason = "Both swept " + level_name + " - invalid";
         return result;
      }

      if(!sym1_swept && !sym2_swept)
      {
         result.reason = "Neither swept " + level_name + " - no signal";
         return result;
      }

      result.reason = "No valid SMT at " + level_name;
      return result;
   }

public:
   CSMTDetectionEngine()
   {
      m_symbol_mgr        = NULL;
      m_session_mgr       = NULL;
      m_liquidity_mgr     = NULL;
      m_log_mgr           = NULL;
      m_sweep_confirm_bars = 1;
      m_sweep_buffer_pips  = 10;
      m_tier3_enabled      = false;

      m_last_result.direction = SMT_INVALID;
      m_last_result.tier      = SMT_TIER_NONE;
      m_last_result.score     = 0;
   }

   bool Init(CSymbolManager *sym, CSessionManager *sess, CLiquidityEngine *liq,
             CLoggingManager *log,
             int confirm_bars = 1, double buffer_pips = 10, bool tier3 = false)
   {
      m_symbol_mgr         = sym;
      m_session_mgr        = sess;
      m_liquidity_mgr      = liq;
      m_log_mgr            = log;
      m_sweep_confirm_bars = confirm_bars;
      m_sweep_buffer_pips  = buffer_pips;
      m_tier3_enabled      = tier3;

      Print("SMTDetectionEngine: Initialized. Confirm bars=", confirm_bars,
            " Buffer=", buffer_pips, " Tier3=", tier3 ? "ON" : "OFF");
      return true;
   }

   SMTResult DetectTier1()
   {
      SMTResult best;
      best.direction = SMT_INVALID;
      best.tier      = SMT_TIER_NONE;
      best.score     = 0;

      double pdh = m_session_mgr.GetPDH();
      double pdl = m_session_mgr.GetPDL();
      double wh  = m_session_mgr.GetWH();
      double wl  = m_session_mgr.GetWL();

      SMTResult r1 = DetectBearishSMT(pdh, "PDH", SMT_TIER_1, 40);
      if(r1.direction != SMT_INVALID && r1.score > best.score)
         best = r1;

      SMTResult r2 = DetectBullishSMT(pdl, "PDL", SMT_TIER_1, 40);
      if(r2.direction != SMT_INVALID && r2.score > best.score)
         best = r2;

      SMTResult r3 = DetectBearishSMT(wh, "WH", SMT_TIER_1, 40);
      if(r3.direction != SMT_INVALID && r3.score > best.score)
         best = r3;

      SMTResult r4 = DetectBullishSMT(wl, "WL", SMT_TIER_1, 40);
      if(r4.direction != SMT_INVALID && r4.score > best.score)
         best = r4;

      if(m_log_mgr != NULL && best.direction != SMT_INVALID)
         m_log_mgr.LogSMT(best);

      return best;
   }

   SMTResult DetectTier2()
   {
      SMTResult best;
      best.direction = SMT_INVALID;
      best.tier      = SMT_TIER_NONE;
      best.score     = 0;

      SessionRange ranges[4];
      string names[4];
      ranges[0] = m_session_mgr.GetAsianRange();
      names[0]  = "Asian";
      ranges[1] = m_session_mgr.GetLondonRange();
      names[1]  = "London";
      ranges[2] = m_session_mgr.GetNYRange();
      names[2]  = "NY";
      ranges[3] = m_session_mgr.GetORRange();
      names[3]  = "NY OR";

      for(int i = 0; i < 4; i++)
      {
         if(ranges[i].high < POINT_EPSILON || ranges[i].low > DBL_MAX / 2)
            continue;

         SMTResult rb = DetectBullishSMT(ranges[i].low, names[i] + " Low", SMT_TIER_2, 25);
         if(rb.direction != SMT_INVALID && rb.score > best.score)
            best = rb;

         SMTResult rs = DetectBearishSMT(ranges[i].high, names[i] + " High", SMT_TIER_2, 25);
         if(rs.direction != SMT_INVALID && rs.score > best.score)
            best = rs;
      }

      if(m_log_mgr != NULL && best.direction != SMT_INVALID)
         m_log_mgr.LogSMT(best);

      return best;
   }

   SMTResult Detect()
   {
      SMTResult tier1 = DetectTier1();
      if(tier1.direction != SMT_INVALID)
      {
         m_last_result = tier1;
         return tier1;
      }

      SMTResult tier2 = DetectTier2();
      if(tier2.direction != SMT_INVALID)
      {
         m_last_result = tier2;
         return tier2;
      }

      m_last_result.direction = SMT_INVALID;
      m_last_result.tier      = SMT_TIER_NONE;
      m_last_result.score     = 0;
      m_last_result.reason    = "No valid SMT detected across all tiers";

      return m_last_result;
   }

   SMTResult GetLastResult()
   {
      return m_last_result;
   }

   string GetStrongerSymbol()
   {
      return m_last_result.stronger_symbol;
   }

   string GetWeakerSymbol()
   {
      return m_last_result.weaker_symbol;
   }

   ENUM_SMT_DIRECTION GetDirection()
   {
      return m_last_result.direction;
   }

   ENUM_SMT_TIER GetTier()
   {
      return m_last_result.tier;
   }
};

#endif
