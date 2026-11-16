#ifndef VISUALIZATION_MANAGER_MQH
#define VISUALIZATION_MANAGER_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "SessionManager.mqh"
#include "LiquidityEngine.mqh"
#include "FVGEngine.mqh"
#include "OrderBlockEngine.mqh"
#include "StatisticsManager.mqh"

class CVisualizationManager
{
private:
   CSymbolManager       *m_symbol_mgr;
   CSessionManager      *m_session_mgr;
   CLiquidityEngine     *m_liquidity_mgr;
   CFVGEngine           *m_fvg_mgr;
   COrderBlockEngine    *m_ob_mgr;
   CStatisticsManager   *m_stats_mgr;

   bool m_show_daily_levels;
   bool m_show_session_ranges;
   bool m_show_liquidity;
   bool m_show_fvg;
   bool m_show_order_blocks;
   bool m_show_pd_zones;
   bool m_show_stats_panel;

   string m_prefix;

   void CreateHLine(string name, double price, color clr, int width = 1, int style = STYLE_SOLID)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }

   void CreateRect(string name, datetime t1, double p1, datetime t2, double p2, color clr)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }

   void CreateText(string name, datetime time, double price, string text, color clr, int size = 8)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   }

   void CreateLabel(string name, int x, int y, string text, color clr, int size = 10)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }

   void RemoveByPrefix(string prefix)
   {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
      }
   }

public:
   CVisualizationManager()
   {
      m_symbol_mgr        = NULL;
      m_session_mgr       = NULL;
      m_liquidity_mgr     = NULL;
      m_fvg_mgr           = NULL;
      m_ob_mgr            = NULL;
      m_stats_mgr         = NULL;

      m_show_daily_levels   = true;
      m_show_session_ranges = true;
      m_show_liquidity      = true;
      m_show_fvg            = true;
      m_show_order_blocks   = true;
      m_show_pd_zones       = true;
      m_show_stats_panel    = true;

      m_prefix = "SMT_";
   }

   bool Init(CSymbolManager *sym, CSessionManager *sess, CLiquidityEngine *liq,
             CFVGEngine *fvg, COrderBlockEngine *ob, CStatisticsManager *stats)
   {
      m_symbol_mgr    = sym;
      m_session_mgr   = sess;
      m_liquidity_mgr = liq;
      m_fvg_mgr       = fvg;
      m_ob_mgr        = ob;
      m_stats_mgr     = stats;

      Print("VisualizationManager: Initialized");
      return true;
   }

   void DrawAll()
   {
      RemoveByPrefix(m_prefix);

      if(m_show_daily_levels)
         DrawDailyLevels();

      if(m_show_session_ranges && m_session_mgr != NULL)
         DrawSessionRanges();

      if(m_show_liquidity && m_liquidity_mgr != NULL)
         DrawLiquidityLevels();

      if(m_show_fvg && m_fvg_mgr != NULL)
         DrawFVGZones();

      if(m_show_order_blocks && m_ob_mgr != NULL)
         DrawOrderBlocks();

      if(m_show_pd_zones && m_session_mgr != NULL)
         DrawPremiumDiscount();

      if(m_show_stats_panel && m_stats_mgr != NULL)
         DrawStatsPanel();
   }

   void DrawDailyLevels()
   {
      if(m_session_mgr == NULL) return;

      datetime now = TimeCurrent();

      CreateHLine(m_prefix + "PDH", m_session_mgr.GetPDH(), clrDodgerBlue, 2, STYLE_DASH);
      CreateHLine(m_prefix + "PDL", m_session_mgr.GetPDL(), clrDodgerBlue, 2, STYLE_DASH);
      CreateHLine(m_prefix + "PDO", m_session_mgr.GetPDO(), clrGold, 1, STYLE_DOT);
      CreateHLine(m_prefix + "WH", m_session_mgr.GetWH(), clrMagenta, 2, STYLE_DASHDOT);
      CreateHLine(m_prefix + "WL", m_session_mgr.GetWL(), clrMagenta, 2, STYLE_DASHDOT);

      CreateText(m_prefix + "PDH_T", now, m_session_mgr.GetPDH(), " PDH", clrDodgerBlue, 8);
      CreateText(m_prefix + "PDL_T", now, m_session_mgr.GetPDL(), " PDL", clrDodgerBlue, 8);
      CreateText(m_prefix + "WH_T",  now, m_session_mgr.GetWH(), " WH", clrMagenta, 8);
      CreateText(m_prefix + "WL_T",  now, m_session_mgr.GetWL(), " WL", clrMagenta, 8);
   }

   void DrawSessionRanges()
   {
      datetime now = TimeCurrent();

      SessionRange ar = m_session_mgr.GetAsianRange();
      SessionRange lr = m_session_mgr.GetLondonRange();
      SessionRange nr = m_session_mgr.GetNYRange();
      SessionRange orr = m_session_mgr.GetORRange();

      DrawSessionBox("Asian", ar, clrDarkSlateGray, now);
      DrawSessionBox("London", lr, clrDarkGreen, now);
      DrawSessionBox("NY", nr, clrDarkBlue, now);
      DrawSessionBox("OR", orr, clrPurple, now);
   }

   void DrawSessionBox(string label, SessionRange &range, color clr, datetime now)
   {
      if(range.high < POINT_EPSILON) return;

      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      datetime start = now - 3600 * 4;
      datetime end   = now + 3600;

      string rect_name = m_prefix + "Session_" + label;
      CreateRect(rect_name, start, range.high, end, range.low, clr);

      string text_name = m_prefix + "Session_" + label + "_T";
      CreateText(text_name, now, range.high + 10 * point,
                 " " + label, clr, 7);
   }

   void DrawLiquidityLevels()
   {
      if(m_liquidity_mgr == NULL) return;

      datetime now = TimeCurrent();

      for(int i = 0; i < m_liquidity_mgr.GetLevelCount(); i++)
      {
         LiquidityLevel lvl = m_liquidity_mgr.GetLevel(i);
         if(lvl.price < POINT_EPSILON) continue;

         string name = m_prefix + "Liq_" + IntegerToString(i);
         color clr = lvl.swept ? clrRed : clrOrangeRed;
         int width = lvl.swept ? 1 : 2;

         CreateHLine(name, lvl.price, clr, width, STYLE_DOT);
      }
   }

   void DrawFVGZones()
   {
      if(m_fvg_mgr == NULL || m_symbol_mgr == NULL) return;

      datetime now = TimeCurrent();
      datetime start = now - 86400 * 2;
      datetime end   = now;

      for(int i = 0; i < m_fvg_mgr.GetZoneCount(); i++)
      {
         FVGZone zone = m_fvg_mgr.GetZone(i);

         color clr = zone.bullish ? clrGreen : clrRed;
         if(zone.filled)
            clr = clrGray;

         string name = m_prefix + "FVG_" + IntegerToString(i);
         CreateRect(name, start, zone.top, end, zone.bottom, clr);
      }
   }

   void DrawOrderBlocks()
   {
      if(m_ob_mgr == NULL || m_symbol_mgr == NULL) return;

      datetime now = TimeCurrent();
      datetime start = now - 86400 * 2;
      datetime end   = now;

      for(int i = 0; i < m_ob_mgr.GetBlockCount(); i++)
      {
         OrderBlock ob = m_ob_mgr.GetBlock(i);

         color clr = ob.bullish ? clrBlue : clrOrange;
         if(ob.mitigated)
            clr = clrGray;

         string name = m_prefix + "OB_" + IntegerToString(i);
         CreateRect(name, start, ob.high, end, ob.low, clr);
      }
   }

   void DrawPremiumDiscount()
   {
      if(m_session_mgr == NULL) return;

      double pdh = m_session_mgr.GetPDH();
      double pdl = m_session_mgr.GetPDL();

      if(pdh < POINT_EPSILON || pdl < POINT_EPSILON) return;

      double eq = (pdh + pdl) / 2.0;
      datetime now = TimeCurrent();
      datetime start = now - 86400;
      datetime end   = now + 3600;

      CreateRect(m_prefix + "PD_Premium", start, pdh, end, eq, clrRed);
      CreateRect(m_prefix + "PD_Discount", start, eq, end, pdl, clrGreen);
      CreateHLine(m_prefix + "PD_Eq", eq, clrYellow, 1, STYLE_DOT);
   }

   void DrawStatsPanel()
   {
      if(m_stats_mgr == NULL) return;

      TradeStats st = m_stats_mgr.GetStats();
      int x = 10, y = 30;

      CreateLabel(m_prefix + "Stats_0", x, y, "=== SMT EA Stats ===", clrWhite, 10);
      y += 18;
      CreateLabel(m_prefix + "Stats_1", x, y,
                  StringFormat("Trades: %d  W:%d  L:%d", st.total_trades, st.wins, st.losses), clrSilver, 9);
      y += 15;
      CreateLabel(m_prefix + "Stats_2", x, y,
                  StringFormat("WR: %.1f%%  PF: %.2f  AvgRR: %.2f", st.win_rate, st.profit_factor, st.avg_rr), clrSilver, 9);
      y += 15;
      CreateLabel(m_prefix + "Stats_3", x, y,
                  StringFormat("MaxDD: %.2f%%", st.max_drawdown), clrSilver, 9);
   }

   void DrawSMTMarker(string symbol, SMTResult &smt, datetime time, double price)
   {
      if(smt.direction == SMT_INVALID) return;

      string arrow = (smt.direction == SMT_BULLISH) ? "SMT_L_" : "SMT_S_";
      arrow += symbol + "_" + IntegerToString((int)time);

      int code = (smt.direction == SMT_BULLISH) ? 233 : 234;
      color clr = (smt.direction == SMT_BULLISH) ? clrLime : clrRed;

      ObjectCreate(0, arrow, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, arrow, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arrow, OBJPROP_WIDTH, 3);
   }

   void DrawTradeEntry(string symbol, ENUM_TRADE_SIGNAL signal, datetime time, double price)
   {
      string name = m_prefix + "Trade_" + IntegerToString((int)time);
      int code = (signal == SIGNAL_LONG) ? 233 : 234;
      color clr = (signal == SIGNAL_LONG) ? clrLime : clrRed;

      ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   }
};

#endif
