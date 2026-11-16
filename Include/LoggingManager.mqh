#ifndef LOGGING_MANAGER_MQH
#define LOGGING_MANAGER_MQH

#include "Types.mqh"

class CLoggingManager
{
private:
   bool m_debug_mode;
   string m_prefix;

public:
   CLoggingManager()
   {
      m_debug_mode = false;
      m_prefix = "SMT_EA";
   }

   void SetDebugMode(bool enabled)
   {
      m_debug_mode = enabled;
   }

   void SetPrefix(string prefix)
   {
      m_prefix = prefix;
   }

   void Log(string message, ENUM_LOG_LEVEL level)
   {
      string tag;
      switch(level)
      {
         case LOG_INFO:    tag = "INFO";    break;
         case LOG_WARNING: tag = "WARNING"; break;
         case LOG_DEBUG:   tag = "DEBUG";   break;
         case LOG_TRADE:   tag = "TRADE";   break;
         default:          tag = "UNKNOWN"; break;
      }

      if(level == LOG_DEBUG && !m_debug_mode)
         return;

      PrintFormat("[%s][%s] %s", m_prefix, tag, message);
   }

   void LogLiquidity(string symbol, string event, double price, string level_name)
   {
      string msg = StringFormat("%s: Liquidity %s at %.5f (%s)", symbol, event, price, level_name);
      Log(msg, LOG_INFO);
   }

   void LogSMT(SMTResult &result)
   {
      if(result.direction == SMT_INVALID)
      {
         Log(StringFormat("SMT INVALID: %s", result.reason), LOG_DEBUG);
         return;
      }

      string tier_str;
      switch(result.tier)
      {
         case SMT_TIER_1: tier_str = "TIER_1"; break;
         case SMT_TIER_2: tier_str = "TIER_2"; break;
         case SMT_TIER_3: tier_str = "TIER_3"; break;
         default: tier_str = "NONE"; break;
      }

      string dir_str = (result.direction == SMT_BULLISH) ? "BULLISH" : "BEARISH";
      string msg = StringFormat("SMT %s [%s]: Stronger=%s, Weaker=%s, Score=%.1f, %s",
                                dir_str, tier_str, result.stronger_symbol, result.weaker_symbol,
                                result.score, result.reason);
      Log(msg, LOG_TRADE);
   }

   void LogCorrelation(double value, double threshold, bool passes)
   {
      string status = passes ? "PASS" : "FAIL";
      string msg = StringFormat("Correlation: %.4f (threshold=%.4f) [%s]", value, threshold, status);
      Log(msg, LOG_DEBUG);
   }

   void LogStructure(string symbol, StructureResult &result)
   {
      if(result.shift == STRUCT_NONE)
         return;

      string shift_str;
      switch(result.shift)
      {
         case STRUCT_MSS_BULL:  shift_str = "MSS_BULL";  break;
         case STRUCT_MSS_BEAR:  shift_str = "MSS_BEAR";  break;
         case STRUCT_CHOCH_BULL: shift_str = "CHOCH_BULL"; break;
         case STRUCT_CHOCH_BEAR: shift_str = "CHOCH_BEAR"; break;
         default: shift_str = "NONE"; break;
      }

      string msg = StringFormat("%s: Structure %s at %.5f", symbol, shift_str, result.level);
      Log(msg, LOG_INFO);
   }

   void LogScore(ScoreBreakdown &breakdown, string symbol)
   {
      string msg = StringFormat("%s: SCORE=%.1f [SMT=%.0f Cascade=%.0f Liq=%.0f Disp=%.0f Struct=%.0f PD=%.0f FVG=%.0f OB=%.0f Session=%.0f Corr=%.0f Regime=%.0f] %s",
                                symbol, breakdown.total,
                                breakdown.smt_tier, breakdown.cascade, breakdown.liquidity,
                                breakdown.displacement, breakdown.structure, breakdown.premium_discount,
                                breakdown.fvg, breakdown.order_block, breakdown.session_alignment,
                                breakdown.correlation, breakdown.regime,
                                breakdown.passes ? "PASSED" : "REJECTED");
      Log(msg, LOG_TRADE);
   }

   void LogTrade(string action, string symbol, double entry, double sl, double tp, double lot, string reason)
   {
      string msg = StringFormat("TRADE %s: %s @ %.5f | SL=%.5f | TP=%.5f | Lot=%.2f | %s",
                                action, symbol, entry, sl, tp, lot, reason);
      Log(msg, LOG_TRADE);
   }

   void LogRisk(string event, string details)
   {
      string msg = StringFormat("RISK %s: %s", event, details);
      Log(msg, LOG_WARNING);
   }
};

#endif
