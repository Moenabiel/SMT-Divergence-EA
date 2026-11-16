//+------------------------------------------------------------------+
//|                                          SMT_Divergence_EA.mq5   |
//|                        SMT Divergence Trading System v1.0         |
//|                   XAUUSD / XAGUSD Institutional Smart Money EA    |
//+------------------------------------------------------------------+
#property copyright "SMT Divergence EA"
#property link      ""
#property version   "1.00"
#property strict

#include "Include/Types.mqh"
#include "Include/LoggingManager.mqh"
#include "Include/SymbolManager.mqh"
#include "Include/SessionManager.mqh"
#include "Include/LiquidityEngine.mqh"
#include "Include/CorrelationEngine.mqh"
#include "Include/SMTDetectionEngine.mqh"
#include "Include/DisplacementEngine.mqh"
#include "Include/MarketStructureEngine.mqh"
#include "Include/FVGEngine.mqh"
#include "Include/OrderBlockEngine.mqh"
#include "Include/PremiumDiscountEngine.mqh"
#include "Include/MarketRegimeEngine.mqh"
#include "Include/ScoringEngine.mqh"
#include "Include/RiskManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/StatisticsManager.mqh"
#include "Include/VisualizationManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input string   InpSymbol1        = "XAUUSD";
input string   InpSymbol2        = "XAGUSD";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;
input bool     InpDebugMode      = false;

input group "=== Session Settings (UTC) ==="
input int      InpAsianSH        = 0;
input int      InpAsianSM        = 0;
input int      InpAsianEH        = 8;
input int      InpAsianEM        = 0;
input int      InpLondonSH       = 8;
input int      InpLondonSM       = 0;
input int      InpLondonEH       = 12;
input int      InpLondonEM       = 0;
input int      InpNYSH           = 13;
input int      InpNYSM           = 0;
input int      InpNYEH           = 17;
input int      InpNYEM           = 0;
input int      InpORMinutes      = 30;

input group "=== SMT Settings ==="
input int      InpSweepConfirm   = 1;
input double   InpSweepBuffer    = 10;
input bool     InpTier3Enabled   = false;
input bool     InpCascadeEnabled = true;

input group "=== Correlation Settings ==="
input int      InpCorrLookback   = 50;
input double   InpCorrMinimum    = 0.60;

input group "=== Displacement Settings ==="
input double   InpDispMinATR     = 1.5;
input double   InpDispBodyRatio  = 0.70;
input int      InpDispConsecutive = 1;

input group "=== Structure Settings ==="
input int      InpStructLookback = 50;

input group "=== FVG Settings ==="
input double   InpFVGMinPips     = 2;
input double   InpFVGMaxPips     = 200;

input group "=== Order Block Settings ==="
input int      InpOBLookback     = 50;
input double   InpOBMinImpulse   = 1.5;

input group "=== Scoring Settings ==="
input double   InpScoreThreshold = 70;

input group "=== Risk Settings ==="
input ENUM_RISK_MODE InpRiskMode  = RISK_DYNAMIC;
input double   InpRiskPercent    = 0.50;
input double   InpFixedLot       = 0.01;
input double   InpDynRiskLow     = 0.25;
input double   InpDynRiskMid     = 0.50;
input double   InpDynRiskHigh    = 0.75;
input double   InpDailyDD        = 3.0;
input double   InpWeeklyDD       = 6.0;
input double   InpSessionDD      = 2.0;
input int      InpMaxTradesDay   = 5;
input int      InpMaxTradesSess  = 3;
input int      InpMaxConsecLoss  = 4;

input group "=== Trade Management ==="
input bool     InpBEEnabled      = true;
input double   InpBETrigger      = 1.0;
input double   InpBEOffset       = 5;
input bool     InpPartialEnabled = true;
input double   InpPartialPct     = 50;
input ENUM_TRAIL_MODE InpTrailMode = TRAIL_ATR;
input double   InpTrailATRMult   = 1.5;

input group "=== Visualization ==="
input bool     InpShowDaily      = true;
input bool     InpShowSessions   = true;
input bool     InpShowLiquidity  = true;
input bool     InpShowFVG        = true;
input bool     InpShowOB         = true;
input bool     InpShowPD         = true;
input bool     InpShowStats      = true;

//+------------------------------------------------------------------+
//| Global Engine Instances                                           |
//+------------------------------------------------------------------+
CLoggingManager      g_log_mgr;
CSymbolManager       g_symbol_mgr;
CSessionManager      g_session_mgr;
CLiquidityEngine     g_liquidity_mgr;
CCorrelationEngine   g_correlation_mgr;
CSMTDetectionEngine  g_smt_mgr;
CDisplacementEngine  g_displacement_mgr;
CMarketStructureEngine g_structure_mgr;
CFVGEngine           g_fvg_mgr;
COrderBlockEngine    g_ob_mgr;
CPremiumDiscountEngine g_pd_mgr;
CMarketRegimeEngine  g_regime_mgr;
CScoringEngine       g_scoring_mgr;
CRiskManager         g_risk_mgr;
CTradeManager        g_trade_mgr;
CStatisticsManager   g_stats_mgr;
CVisualizationManager g_vis_mgr;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  SMT Divergence EA v1.0 - Initializing");
   Print("========================================");

   g_log_mgr.SetDebugMode(InpDebugMode);

   if(!g_symbol_mgr.Init(InpSymbol1, InpSymbol2, InpTimeframe))
   {
      Print("FATAL: SymbolManager init failed");
      return INIT_FAILED;
   }

   if(!g_session_mgr.Init(&g_symbol_mgr,
                           InpAsianSH, InpAsianSM, InpAsianEH, InpAsianEM,
                           InpLondonSH, InpLondonSM, InpLondonEH, InpLondonEM,
                           InpNYSH, InpNYSM, InpNYEH, InpNYEM,
                           InpORMinutes))
   {
      Print("FATAL: SessionManager init failed");
      return INIT_FAILED;
   }

   if(!g_liquidity_mgr.Init(&g_symbol_mgr, &g_session_mgr, &g_log_mgr,
                             InpSweepBuffer, InpSweepBuffer))
   {
      Print("FATAL: LiquidityEngine init failed");
      return INIT_FAILED;
   }

   if(!g_correlation_mgr.Init(&g_symbol_mgr, &g_log_mgr, InpCorrLookback, InpCorrMinimum))
   {
      Print("FATAL: CorrelationEngine init failed");
      return INIT_FAILED;
   }

   if(!g_smt_mgr.Init(&g_symbol_mgr, &g_session_mgr, &g_liquidity_mgr, &g_log_mgr,
                       InpSweepConfirm, InpSweepBuffer, InpTier3Enabled))
   {
      Print("FATAL: SMTDetectionEngine init failed");
      return INIT_FAILED;
   }

   if(!g_displacement_mgr.Init(&g_symbol_mgr, &g_log_mgr,
                                InpDispMinATR, InpDispBodyRatio, InpDispConsecutive))
   {
      Print("FATAL: DisplacementEngine init failed");
      return INIT_FAILED;
   }

   if(!g_structure_mgr.Init(&g_symbol_mgr, &g_log_mgr, InpStructLookback))
   {
      Print("FATAL: MarketStructureEngine init failed");
      return INIT_FAILED;
   }

   if(!g_fvg_mgr.Init(&g_symbol_mgr, &g_log_mgr, InpFVGMinPips, InpFVGMaxPips))
   {
      Print("FATAL: FVGEngine init failed");
      return INIT_FAILED;
   }

   if(!g_ob_mgr.Init(&g_symbol_mgr, &g_log_mgr, InpOBLookback, InpOBMinImpulse))
   {
      Print("FATAL: OrderBlockEngine init failed");
      return INIT_FAILED;
   }

   if(!g_pd_mgr.Init(&g_symbol_mgr, &g_session_mgr))
   {
      Print("FATAL: PremiumDiscountEngine init failed");
      return INIT_FAILED;
   }

   if(!g_regime_mgr.Init(&g_symbol_mgr, &g_log_mgr))
   {
      Print("FATAL: MarketRegimeEngine init failed");
      return INIT_FAILED;
   }

   g_scoring_mgr.SetThreshold(InpScoreThreshold);

   if(!g_risk_mgr.Init(&g_log_mgr, InpRiskPercent, InpFixedLot, InpRiskMode,
                        InpDailyDD, InpWeeklyDD, InpSessionDD,
                        InpMaxTradesDay, InpMaxTradesSess, InpMaxConsecLoss,
                        InpDynRiskLow, InpDynRiskMid, InpDynRiskHigh))
   {
      Print("FATAL: RiskManager init failed");
      return INIT_FAILED;
   }

   if(!g_trade_mgr.Init(&g_symbol_mgr, &g_log_mgr,
                         InpBEEnabled, InpBETrigger, InpBEOffset,
                         InpPartialEnabled, InpPartialPct,
                         InpTrailMode, InpTrailATRMult))
   {
      Print("FATAL: TradeManager init failed");
      return INIT_FAILED;
   }

   if(!g_stats_mgr.Init(&g_log_mgr))
   {
      Print("FATAL: StatisticsManager init failed");
      return INIT_FAILED;
   }

   if(!g_vis_mgr.Init(&g_symbol_mgr, &g_session_mgr, &g_liquidity_mgr,
                       &g_fvg_mgr, &g_ob_mgr, &g_stats_mgr))
   {
      Print("FATAL: VisualizationManager init failed");
      return INIT_FAILED;
   }

   Print("========================================");
   Print("  All engines initialized successfully");
   Print("  Symbols: ", InpSymbol1, " + ", InpSymbol2);
   Print("  Timeframe: ", EnumToString(InpTimeframe));
   Print("  Threshold: ", InpScoreThreshold);
   Print("  Risk: ", InpRiskPercent, "%");
   Print("========================================");

   EventSetTimer(60);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("SMT Divergence EA: Deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   g_symbol_mgr.Refresh();
   g_session_mgr.Update();
   g_liquidity_mgr.Update();
   g_correlation_mgr.Update();

   g_risk_mgr.UpdateDailyEquity();
   g_trade_mgr.ManageOpenTrades();

   if(!g_correlation_mgr.IsCorrelated())
   {
      g_vis_mgr.DrawAll();
      return;
   }

   if(!g_session_mgr.IsTradingAllowed())
   {
      g_vis_mgr.DrawAll();
      return;
   }

   if(!g_risk_mgr.CanTrade())
   {
      g_vis_mgr.DrawAll();
      return;
   }

   SMTResult smt = g_smt_mgr.Detect();

   if(smt.direction == SMT_INVALID)
   {
      g_vis_mgr.DrawAll();
      return;
   }

   string stronger = smt.stronger_symbol;
   string weaker   = smt.weaker_symbol;

   double disp_score = g_displacement_mgr.GetDisplacementScore(stronger, 0);

   bool is_bull_disp = false;
   double disp_str = 0;
   g_displacement_mgr.DetectDisplacement(stronger, 0, is_bull_disp, disp_str);

   StructureResult structure = g_structure_mgr.DetectStructure(stronger, 0);

   g_fvg_mgr.DetectFVGs(stronger, 50);
   g_ob_mgr.DetectOrderBlocks(stronger);

   ENUM_SESSION_TYPE curr_session = g_session_mgr.GetCurrentSession();
   double session_score = 10.0;
   if(curr_session == SESSION_NONE) session_score = 0;

   double cascade_score = 0;
   if(InpCascadeEnabled)
   {
      SMTResult t1 = g_smt_mgr.DetectTier1();
      SMTResult t2 = g_smt_mgr.DetectTier2();
      if(t1.direction != SMT_INVALID && t2.direction != SMT_INVALID)
      {
         if(t1.direction == t2.direction)
            cascade_score = 20.0;
         else
            cascade_score = 10.0;
      }
   }

   g_regime_mgr.Classify(stronger);
   double regime_score = g_regime_mgr.GetRegimeScore(smt.direction);

   ENUM_TRADE_SIGNAL signal = SIGNAL_NONE;
   if(smt.direction == SMT_BULLISH) signal = SIGNAL_LONG;
   else if(smt.direction == SMT_BEARISH) signal = SIGNAL_SHORT;

   double liquidity_score = g_liquidity_mgr.GetLiquidityScore();
   double correlation_score = g_correlation_mgr.GetCorrelationScore();
   double fvg_score = g_fvg_mgr.GetFVGScore();
   double ob_score = g_ob_mgr.GetOBScore();

   ScoreBreakdown score = g_scoring_mgr.CalculateScore(
      smt, liquidity_score, disp_score, structure,
      g_pd_mgr.GetPDScore(signal, g_symbol_mgr.GetClose(stronger, 0)),
      fvg_score, ob_score, session_score, correlation_score,
      regime_score, cascade_score);

   g_log_mgr.LogScore(score, stronger);

   if(!score.passes)
   {
      g_vis_mgr.DrawAll();
      g_vis_mgr.DrawSMTMarker(stronger, smt, smt.signal_time,
                               g_symbol_mgr.GetClose(stronger, 0));
      return;
   }

   double close_price = g_symbol_mgr.GetClose(stronger, 0);
   double point = SymbolInfoDouble(stronger, SYMBOL_POINT);

   double sl_distance = 0;

   if(signal == SIGNAL_LONG)
   {
      LiquidityLevel below = g_liquidity_mgr.GetNearestLevel(stronger, false, 0);
      sl_distance = close_price - below.price;
      if(sl_distance < 20 * point) sl_distance = g_symbol_mgr.GetATR(stronger, 14, 0) * 1.5;
   }
   else
   {
      LiquidityLevel above = g_liquidity_mgr.GetNearestLevel(stronger, true, 0);
      sl_distance = above.price - close_price;
      if(sl_distance < 20 * point) sl_distance = g_symbol_mgr.GetATR(stronger, 14, 0) * 1.5;
   }

   double tp1_dist = sl_distance * 2.0;
   double tp2_dist = sl_distance * 3.0;
   double tp3_dist = sl_distance * 5.0;

   double entry = close_price;
   double sl = 0, tp1 = 0, tp2 = 0, tp3 = 0;

   if(signal == SIGNAL_LONG)
   {
      sl  = entry - sl_distance;
      tp1 = entry + tp1_dist;
      tp2 = entry + tp2_dist;
      tp3 = entry + tp3_dist;
   }
   else
   {
      sl  = entry + sl_distance;
      tp1 = entry - tp1_dist;
      tp2 = entry - tp2_dist;
      tp3 = entry - tp3_dist;
   }

   double lot = g_risk_mgr.CalculateLotSize(stronger, sl_distance, score.total);
   if(lot < SymbolInfoDouble(stronger, SYMBOL_VOLUME_MIN))
   {
      g_vis_mgr.DrawAll();
      return;
   }

   TradeSetup setup;
   setup.signal     = signal;
   setup.entry      = entry;
   setup.sl         = sl;
   setup.tp1        = tp1;
   setup.tp2        = tp2;
   setup.tp3        = tp3;
   setup.confidence = score.total;
   setup.lot_size   = lot;
   setup.smt        = smt;
   setup.structure  = structure;
   setup.symbol     = stronger;
   setup.log        = StringFormat("Score=%.1f Tier=%d Liq=%.0f Disp=%.0f Struct=%.0f",
                                   score.total, smt.tier, liquidity_score, disp_score,
                                   (structure.shift != STRUCT_NONE) ? 20.0 : 0);

   if(g_trade_mgr.OpenTrade(setup, lot))
   {
      g_risk_mgr.RecordTrade(false);
      g_stats_mgr.RecordSetup(setup, false, entry, 0);
   }

   g_vis_mgr.DrawAll();
   g_vis_mgr.DrawSMTMarker(stronger, smt, smt.signal_time, close_price);
   g_vis_mgr.DrawTradeEntry(stronger, signal, TimeCurrent(), entry);
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_session_mgr.Update();
   g_vis_mgr.DrawAll();
}
//+------------------------------------------------------------------+
