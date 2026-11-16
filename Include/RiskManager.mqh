#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include "Types.mqh"
#include "LoggingManager.mqh"

class CRiskManager
{
private:
   ENUM_RISK_MODE m_risk_mode;
   double m_fixed_lot;
   double m_risk_percent;
   double m_dynamic_risk_low;
   double m_dynamic_risk_mid;
   double m_dynamic_risk_high;

   double m_daily_dd_limit;
   double m_weekly_dd_limit;
   double m_session_dd_limit;
   int    m_max_trades_day;
   int    m_max_trades_session;
   int    m_max_consecutive_loss;

   double m_starting_equity;
   double m_daily_start_equity;
   double m_weekly_start_equity;
   double m_session_start_equity;

   int    m_today_trades;
   int    m_today_losses;
   int    m_session_trades;
   int    m_session_losses;
   int    m_consecutive_losses;

   bool   m_trading_paused;

   CLoggingManager *m_log_mgr;

   double GetEquity()
   {
      return AccountInfoDouble(ACCOUNT_EQUITY);
   }

   datetime GetDayStart()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
   }

   datetime GetWeekStart()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int day = dt.day_of_week;
      int offset = (day == 0) ? 6 : day - 1;
      dt.day -= offset;
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
   }

public:
   CRiskManager()
   {
      m_risk_mode         = RISK_DYNAMIC;
      m_fixed_lot         = 0.01;
      m_risk_percent      = 0.50;
      m_dynamic_risk_low  = 0.25;
      m_dynamic_risk_mid  = 0.50;
      m_dynamic_risk_high = 0.75;

      m_daily_dd_limit    = 3.0;
      m_weekly_dd_limit   = 6.0;
      m_session_dd_limit  = 2.0;
      m_max_trades_day    = 5;
      m_max_trades_session = 3;
      m_max_consecutive_loss = 4;

      m_starting_equity    = 0;
      m_daily_start_equity = 0;
      m_weekly_start_equity = 0;
      m_session_start_equity = 0;

      m_today_trades    = 0;
      m_today_losses    = 0;
      m_session_trades  = 0;
      m_session_losses  = 0;
      m_consecutive_losses = 0;
      m_trading_paused  = false;
      m_log_mgr         = NULL;
   }

   bool Init(CLoggingManager *log,
             double risk_pct = 0.50, double fixed_lot = 0.01,
             ENUM_RISK_MODE mode = RISK_DYNAMIC,
             double dd_daily = 3.0, double dd_weekly = 6.0, double dd_session = 2.0,
             int max_day = 5, int max_session = 3, int max_consec = 4,
             double dyn_low = 0.25, double dyn_mid = 0.50, double dyn_high = 0.75)
   {
      m_log_mgr            = log;
      m_risk_percent       = risk_pct;
      m_fixed_lot          = fixed_lot;
      m_risk_mode          = mode;
      m_daily_dd_limit     = dd_daily;
      m_weekly_dd_limit    = dd_weekly;
      m_session_dd_limit   = dd_session;
      m_max_trades_day     = max_day;
      m_max_trades_session = max_session;
      m_max_consecutive_loss = max_consec;
      m_dynamic_risk_low   = dyn_low;
      m_dynamic_risk_mid   = dyn_mid;
      m_dynamic_risk_high  = dyn_high;

      m_starting_equity    = GetEquity();
      m_daily_start_equity = m_starting_equity;
      m_weekly_start_equity = m_starting_equity;
      m_session_start_equity = m_starting_equity;

      Print("RiskManager: Initialized. Risk=", risk_pct, "% Mode=",
            (mode == RISK_FIXED ? "Fixed" : "Dynamic"), " DD_Daily=", dd_daily, "%");
      return true;
   }

   void ResetSession()
   {
      m_session_trades  = 0;
      m_session_losses  = 0;
      m_session_start_equity = GetEquity();
   }

   bool CanTrade()
   {
      if(m_trading_paused)
      {
         if(m_log_mgr) m_log_mgr.LogRisk("PAUSED", "Trading is paused");
         return false;
      }

      double equity = GetEquity();

      if(m_today_trades >= m_max_trades_day)
      {
         if(m_log_mgr) m_log_mgr.LogRisk("DAILY_LIMIT",
            StringFormat("Max daily trades reached (%d)", m_max_trades_day));
         return false;
      }

      if(m_session_trades >= m_max_trades_session)
      {
         if(m_log_mgr) m_log_mgr.LogRisk("SESSION_LIMIT",
            StringFormat("Max session trades reached (%d)", m_max_trades_session));
         return false;
      }

      if(m_consecutive_losses >= m_max_consecutive_loss)
      {
         if(m_log_mgr) m_log_mgr.LogRisk("CONSEC_LOSS",
            StringFormat("Consecutive loss limit reached (%d)", m_max_consecutive_loss));
         return false;
      }

      if(m_daily_start_equity > 0)
      {
         double daily_dd = (m_daily_start_equity - equity) / m_daily_start_equity * 100;
         if(daily_dd >= m_daily_dd_limit)
         {
            if(m_log_mgr) m_log_mgr.LogRisk("DAILY_DD",
               StringFormat("Daily drawdown limit breached: %.2f%% >= %.2f%%", daily_dd, m_daily_dd_limit));
            m_trading_paused = true;
            return false;
         }
      }

      if(m_weekly_start_equity > 0)
      {
         double weekly_dd = (m_weekly_start_equity - equity) / m_weekly_start_equity * 100;
         if(weekly_dd >= m_weekly_dd_limit)
         {
            if(m_log_mgr) m_log_mgr.LogRisk("WEEKLY_DD",
               StringFormat("Weekly drawdown limit breached: %.2f%% >= %.2f%%", weekly_dd, m_weekly_dd_limit));
            m_trading_paused = true;
            return false;
         }
      }

      if(m_session_start_equity > 0)
      {
         double session_dd = (m_session_start_equity - equity) / m_session_start_equity * 100;
         if(session_dd >= m_session_dd_limit)
         {
            if(m_log_mgr) m_log_mgr.LogRisk("SESSION_DD",
               StringFormat("Session drawdown limit breached: %.2f%% >= %.2f%%", session_dd, m_session_dd_limit));
            return false;
         }
      }

      return true;
   }

   double CalculateLotSize(string symbol, double sl_distance, double confidence = 70)
   {
      if(m_risk_mode == RISK_FIXED)
         return m_fixed_lot;

      double risk_pct = m_risk_percent;
      if(confidence >= 90)       risk_pct = m_dynamic_risk_high;
      else if(confidence >= 80)  risk_pct = m_dynamic_risk_mid;
      else if(confidence >= 70)  risk_pct = m_dynamic_risk_low;

      double equity = GetEquity();
      double risk_amount = equity * risk_pct / 100.0;

      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tick_value < POINT_EPSILON || tick_size < POINT_EPSILON)
         return m_fixed_lot;

      double sl_ticks = sl_distance / tick_size;
      double risk_per_lot = sl_ticks * tick_value;

      if(risk_per_lot < POINT_EPSILON)
         return m_fixed_lot;

      double lots = risk_amount / risk_per_lot;

      double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(lot_step > 0)
         lots = MathFloor(lots / lot_step) * lot_step;

      lots = MathMax(lots, min_lot);
      lots = MathMin(lots, max_lot);

      return NormalizeDouble(lots, 2);
   }

   void RecordTrade(bool is_win)
   {
      m_today_trades++;
      m_session_trades++;

      if(!is_win)
      {
         m_today_losses++;
         m_session_losses++;
         m_consecutive_losses++;
      }
      else
      {
         m_consecutive_losses = 0;
      }

      if(m_consecutive_losses >= m_max_consecutive_loss)
      {
         m_trading_paused = true;
         if(m_log_mgr) m_log_mgr.LogRisk("CONSEC_LOSS_SHUTDOWN",
            StringFormat("Shutdown: %d consecutive losses", m_consecutive_losses));
      }
   }

   void UpdateDailyEquity()
   {
      datetime now = TimeCurrent();
      datetime day_start = GetDayStart();

      static datetime last_day = 0;
      if(day_start != last_day)
      {
         m_daily_start_equity = GetEquity();
         m_today_trades = 0;
         m_today_losses = 0;
         m_trading_paused = false;
         last_day = day_start;
      }

      datetime week_start = GetWeekStart();
      static datetime last_week = 0;
      if(week_start != last_week)
      {
         m_weekly_start_equity = GetEquity();
         last_week = week_start;
      }
   }

   double GetDailyPnL()
   {
      if(m_daily_start_equity <= 0) return 0;
      return GetEquity() - m_daily_start_equity;
   }

   double GetWeeklyPnL()
   {
      if(m_weekly_start_equity <= 0) return 0;
      return GetEquity() - m_weekly_start_equity;
   }

   double GetSessionPnL()
   {
      if(m_session_start_equity <= 0) return 0;
      return GetEquity() - m_session_start_equity;
   }

   int GetTodayTrades()     { return m_today_trades; }
   int GetSessionTrades()   { return m_session_trades; }
   int GetConsecutiveLosses() { return m_consecutive_losses; }
   bool IsPaused()          { return m_trading_paused; }

   void ResumeTrading()  { m_trading_paused = false; }
};

#endif
