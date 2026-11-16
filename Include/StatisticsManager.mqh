#ifndef STATISTICS_MANAGER_MQH
#define STATISTICS_MANAGER_MQH

#include "Types.mqh"
#include "LoggingManager.mqh"

class CStatisticsManager
{
private:
   TradeStats m_stats;
   CLoggingManager *m_log_mgr;

   struct TradeRecord
   {
      ulong    ticket;
      string   symbol;
      double   entry;
      double   exit_price;
      double   profit;
      double   rr;
      ENUM_SMT_TIER tier;
      ENUM_MARKET_REGIME regime;
      ENUM_SESSION_TYPE session;
      datetime open_time;
      datetime close_time;
      bool     is_win;
   };

   TradeRecord m_history[];
   int m_history_count;

public:
   CStatisticsManager()
   {
      m_log_mgr = NULL;
      m_history_count = 0;
      ArrayResize(m_history, 0);
      ResetStats();
   }

   void ResetStats()
   {
      m_stats.total_trades     = 0;
      m_stats.wins             = 0;
      m_stats.losses           = 0;
      m_stats.total_profit     = 0;
      m_stats.total_loss       = 0;
      m_stats.max_drawdown     = 0;
      m_stats.profit_factor    = 0;
      m_stats.win_rate         = 0;
      m_stats.avg_rr           = 0;
      m_stats.today_trades     = 0;
      m_stats.today_losses     = 0;
      m_stats.session_trades   = 0;
      m_stats.session_losses   = 0;
      m_stats.consecutive_losses = 0;
   }

   bool Init(CLoggingManager *log)
   {
      m_log_mgr = log;
      return true;
   }

   void RecordSetup(TradeSetup &setup, bool is_win, double exit_price, double profit)
   {
      m_stats.total_trades++;

      if(is_win)
      {
         m_stats.wins++;
         m_stats.total_profit += profit;
      }
      else
      {
         m_stats.losses++;
         m_stats.total_loss += MathAbs(profit);
      }

      double risk = MathAbs(setup.entry - setup.sl);
      double reward = MathAbs(exit_price - setup.entry);

      if(risk > POINT_EPSILON)
      {
         double rr = reward / risk;
         m_stats.avg_rr = (m_stats.avg_rr * (m_stats.total_trades - 1) + rr) / m_stats.total_trades;
      }

      if(m_stats.total_trades > 0)
         m_stats.win_rate = (double)m_stats.wins / m_stats.total_trades * 100.0;

      if(m_stats.total_loss > POINT_EPSILON)
         m_stats.profit_factor = m_stats.total_profit / m_stats.total_loss;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      static double peak_equity = 0;
      if(equity > peak_equity) peak_equity = equity;
      double dd = (peak_equity - equity) / peak_equity * 100;
      if(dd > m_stats.max_drawdown) m_stats.max_drawdown = dd;

      TradeRecord rec;
      rec.ticket     = 0;
      rec.symbol     = setup.symbol;
      rec.entry      = setup.entry;
      rec.exit_price = exit_price;
      rec.profit     = profit;
      rec.rr         = (risk > POINT_EPSILON) ? reward / risk : 0;
      rec.tier       = setup.smt.tier;
      rec.regime     = REGIME_RANGING;
      rec.session    = SESSION_NONE;
      rec.open_time  = TimeCurrent();
      rec.close_time = TimeCurrent();
      rec.is_win     = is_win;

      m_history_count++;
      ArrayResize(m_history, m_history_count);
      m_history[m_history_count - 1] = rec;

      if(m_log_mgr != NULL)
      {
         string result = is_win ? "WIN" : "LOSS";
         m_log_mgr.Log(StringFormat("STATS: %s %s Profit=%.2f WR=%.1f%% PF=%.2f AvgRR=%.2f DD=%.2f%%",
                        setup.symbol, result, profit, m_stats.win_rate,
                        m_stats.profit_factor, m_stats.avg_rr, m_stats.max_drawdown), LOG_TRADE);
      }
   }

   TradeStats GetStats()     { return m_stats; }
   int GetHistoryCount()     { return m_history_count; }

   double GetWinRate()       { return m_stats.win_rate; }
   double GetProfitFactor()  { return m_stats.profit_factor; }
   double GetAvgRR()         { return m_stats.avg_rr; }
   double GetMaxDrawdown()   { return m_stats.max_drawdown; }
   int GetTotalTrades()      { return m_stats.total_trades; }
   int GetWins()             { return m_stats.wins; }
   int GetLosses()           { return m_stats.losses; }
};

#endif
