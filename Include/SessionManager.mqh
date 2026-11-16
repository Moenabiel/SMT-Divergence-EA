#ifndef SESSION_MANAGER_MQH
#define SESSION_MANAGER_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"

class CSessionManager
{
private:
   int m_asian_start_h;
   int m_asian_start_m;
   int m_asian_end_h;
   int m_asian_end_m;

   int m_london_start_h;
   int m_london_start_m;
   int m_london_end_h;
   int m_london_end_m;

   int m_ny_start_h;
   int m_ny_start_m;
   int m_ny_end_h;
   int m_ny_end_m;

   int m_or_minutes;

   SessionRange m_asian_range;
   SessionRange m_london_range;
   SessionRange m_ny_range;
   SessionRange m_or_range;

   double m_pdh;
   double m_pdl;
   double m_pdo;
   double m_pdc;
   double m_wh;
   double m_wl;

   ENUM_SESSION_TYPE m_current_session;

   CSymbolManager *m_symbol_mgr;

   void ResetRange(SessionRange &range)
   {
      range.high = 0;
      range.low = DBL_MAX;
      range.active = false;
      range.swept_high = false;
      range.swept_low = false;
   }

   bool IsTimeInRange(int h, int m, int sh, int sm, int eh, int em)
   {
      int cur = h * 60 + m;
      int start = sh * 60 + sm;
      int end = eh * 60 + em;
      return (cur >= start && cur < end);
   }

   datetime GetSessionStart(datetime day, int h, int m)
   {
      MqlDateTime dt;
      TimeToStruct(day, dt);
      dt.hour = h;
      dt.min = m;
      dt.sec = 0;
      return StructToTime(dt);
   }

   void UpdateSessionRange(SessionRange &range, string symbol, CSymbolManager *mgr,
                           datetime session_start, datetime session_end, int shift)
   {
      datetime bar_time = mgr.GetTime(symbol, shift);
      if(bar_time >= session_start && bar_time < session_end)
      {
         double h = mgr.GetHigh(symbol, shift);
         double l = mgr.GetLow(symbol, shift);

         if(h > range.high)  range.high = h;
         if(l < range.low)   range.low = l;
         range.active = true;
      }
   }

public:
   CSessionManager()
   {
      m_asian_start_h = 0;  m_asian_start_m = 0;
      m_asian_end_h   = 8;  m_asian_end_m   = 0;

      m_london_start_h = 8;  m_london_start_m = 0;
      m_london_end_h   = 12; m_london_end_m   = 0;

      m_ny_start_h = 13;  m_ny_start_m = 0;
      m_ny_end_h   = 17;  m_ny_end_m   = 0;

      m_or_minutes = 30;

      m_current_session = SESSION_NONE;
      m_symbol_mgr = NULL;

      m_pdh = 0; m_pdl = 0; m_pdo = 0; m_pdc = 0;
      m_wh = 0; m_wl = 0;
   }

   bool Init(CSymbolManager *symbol_mgr,
             int asian_sh = 0, int asian_sm = 0, int asian_eh = 8, int asian_em = 0,
             int london_sh = 8, int london_sm = 0, int london_eh = 12, int london_em = 0,
             int ny_sh = 13, int ny_sm = 0, int ny_eh = 17, int ny_em = 0,
             int or_minutes = 30)
   {
      m_symbol_mgr = symbol_mgr;

      m_asian_start_h = asian_sh; m_asian_start_m = asian_sm;
      m_asian_end_h   = asian_eh; m_asian_end_m   = asian_em;

      m_london_start_h = london_sh; m_london_start_m = london_sm;
      m_london_end_h   = london_eh; m_london_end_m   = london_em;

      m_ny_start_h = ny_sh; m_ny_start_m = ny_sm;
      m_ny_end_h   = ny_eh; m_ny_end_m   = ny_em;

      m_or_minutes = or_minutes;

      ResetRange(m_asian_range);
      ResetRange(m_london_range);
      ResetRange(m_ny_range);
      ResetRange(m_or_range);

      if(!CalculateDailyWeeklyLevels())
      {
         Print("SessionManager: Failed to calculate daily/weekly levels");
         return false;
      }

      Print("SessionManager: Initialized. Asian=", asian_sh, ":", asian_sm, "-", asian_eh, ":",
            asian_em, " London=", london_sh, ":", london_sm, "-", london_eh, ":", london_em,
            " NY=", ny_sh, ":", ny_sm, "-", ny_eh, ":", ny_em);
      return true;
   }

   bool CalculateDailyWeeklyLevels()
   {
      if(m_symbol_mgr == NULL) return false;

      string sym = m_symbol_mgr.GetSymbol1();

      double d1_open[], d1_high[], d1_low[], d1_close[];
      ArraySetAsSeries(d1_open, true);
      ArraySetAsSeries(d1_high, true);
      ArraySetAsSeries(d1_low, true);
      ArraySetAsSeries(d1_close, true);

      if(CopyOpen(sym, PERIOD_D1, 0, 5, d1_open) < 5) return false;
      if(CopyHigh(sym, PERIOD_D1, 0, 5, d1_high) < 5) return false;
      if(CopyLow(sym, PERIOD_D1, 0, 5, d1_low) < 5) return false;
      if(CopyClose(sym, PERIOD_D1, 0, 5, d1_close) < 5) return false;

      m_pdh = d1_high[1];
      m_pdl = d1_low[1];
      m_pdo = d1_open[1];
      m_pdc = d1_close[1];

      double w1_high[], w1_low[];
      ArraySetAsSeries(w1_high, true);
      ArraySetAsSeries(w1_low, true);

      if(CopyHigh(sym, PERIOD_W1, 0, 2, w1_high) < 2) return false;
      if(CopyLow(sym, PERIOD_W1, 0, 2, w1_low) < 2) return false;

      m_wh = w1_high[1];
      m_wl = w1_low[1];

      return true;
   }

   void Update()
   {
      if(m_symbol_mgr == NULL) return;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      CalculateDailyWeeklyLevels();

      m_current_session = DetermineSession(dt);

      if(m_current_session != SESSION_NONE)
      {
         ResetRange(m_asian_range);
         ResetRange(m_london_range);
         ResetRange(m_ny_range);
         ResetRange(m_or_range);

         CalculateSessionRanges();
      }
   }

   ENUM_SESSION_TYPE DetermineSession(MqlDateTime &dt)
   {
      if(IsTimeInRange(dt.hour, dt.min, m_asian_start_h, m_asian_start_m, m_asian_end_h, m_asian_end_m))
         return SESSION_ASIAN;

      if(IsTimeInRange(dt.hour, dt.min, m_london_start_h, m_london_start_m, m_london_end_h, m_london_end_m))
         return SESSION_LONDON;

      if(IsTimeInRange(dt.hour, dt.min, m_ny_start_h, m_ny_start_m, m_ny_end_h, m_ny_end_m))
         return SESSION_NY;

      int or_end_m_total = m_ny_start_h * 60 + m_ny_start_m + m_or_minutes;
      int or_end_h = or_end_m_total / 60;
      int or_end_min = or_end_m_total % 60;

      if(IsTimeInRange(dt.hour, dt.min, m_ny_start_h, m_ny_start_m, or_end_h, or_end_min))
         return SESSION_OR_NY;

      int kz_lon_h = 7;
      int kz_lon_eh = 9;
      if(IsTimeInRange(dt.hour, dt.min, kz_lon_h, 0, kz_lon_eh, 0))
         return SESSION_KILLZONE_LONDON;

      int kz_ny_h = 12;
      int kz_ny_eh = 14;
      if(IsTimeInRange(dt.hour, dt.min, kz_ny_h, 0, kz_ny_eh, 0))
         return SESSION_KILLZONE_NY;

      return SESSION_NONE;
   }

   void CalculateSessionRanges()
   {
      string sym1 = m_symbol_mgr.GetSymbol1();
      string sym2 = m_symbol_mgr.GetSymbol2();

      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);

      datetime today_start = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);

      datetime asian_s = GetSessionStart(today_start, m_asian_start_h, m_asian_start_m);
      datetime asian_e = GetSessionStart(today_start, m_asian_end_h, m_asian_end_m);
      datetime london_s = GetSessionStart(today_start, m_london_start_h, m_london_start_m);
      datetime london_e = GetSessionStart(today_start, m_london_end_h, m_london_end_m);
      datetime ny_s = GetSessionStart(today_start, m_ny_start_h, m_ny_start_m);
      datetime ny_e = GetSessionStart(today_start, m_ny_end_h, m_ny_end_m);

      int or_end_min_total = m_ny_start_h * 60 + m_ny_start_m + m_or_minutes;
      datetime or_e = GetSessionStart(today_start, or_end_min_total / 60, or_end_min_total % 60);

      int lookback = 100;

      for(int i = 1; i < lookback; i++)
      {
         UpdateSessionRange(m_asian_range, sym1, m_symbol_mgr, asian_s, asian_e, i);
         UpdateSessionRange(m_asian_range, sym2, m_symbol_mgr, asian_s, asian_e, i);
         UpdateSessionRange(m_london_range, sym1, m_symbol_mgr, london_s, london_e, i);
         UpdateSessionRange(m_london_range, sym2, m_symbol_mgr, london_s, london_e, i);
         UpdateSessionRange(m_ny_range, sym1, m_symbol_mgr, ny_s, ny_e, i);
         UpdateSessionRange(m_ny_range, sym2, m_symbol_mgr, ny_s, ny_e, i);
         UpdateSessionRange(m_or_range, sym1, m_symbol_mgr, ny_s, or_e, i);
         UpdateSessionRange(m_or_range, sym2, m_symbol_mgr, ny_s, or_e, i);
      }
   }

   ENUM_SESSION_TYPE GetCurrentSession()   { return m_current_session; }
   double GetPDH()                          { return m_pdh; }
   double GetPDL()                          { return m_pdl; }
   double GetPDO()                          { return m_pdo; }
   double GetPDC()                          { return m_pdc; }
   double GetWH()                           { return m_wh; }
   double GetWL()                           { return m_wl; }

   SessionRange GetAsianRange()  { return m_asian_range; }
   SessionRange GetLondonRange() { return m_london_range; }
   SessionRange GetNYRange()     { return m_ny_range; }
   SessionRange GetORRange()     { return m_or_range; }

   bool IsKillZone()
   {
      return (m_current_session == SESSION_KILLZONE_LONDON ||
              m_current_session == SESSION_KILLZONE_NY);
   }

   bool IsTradingAllowed()
   {
      return (m_current_session != SESSION_NONE);
   }

   string GetSessionName(ENUM_SESSION_TYPE session)
   {
      switch(session)
      {
         case SESSION_ASIAN:            return "Asian";
         case SESSION_LONDON:           return "London";
         case SESSION_NY:               return "New York";
         case SESSION_KILLZONE_LONDON:  return "London KZ";
         case SESSION_KILLZONE_NY:      return "NY KZ";
         case SESSION_OR_NY:            return "NY OR";
         default:                       return "None";
      }
   }

   void GetSessionLevels(ENUM_SESSION_TYPE session, double &high, double &low)
   {
      switch(session)
      {
         case SESSION_ASIAN:
            high = m_asian_range.high;
            low  = m_asian_range.low;
            break;
         case SESSION_LONDON:
         case SESSION_KILLZONE_LONDON:
            high = m_london_range.high;
            low  = m_london_range.low;
            break;
         case SESSION_NY:
         case SESSION_KILLZONE_NY:
         case SESSION_OR_NY:
            high = m_ny_range.high;
            low  = m_ny_range.low;
            break;
         default:
            high = 0;
            low  = 0;
            break;
      }
   }
};

#endif
