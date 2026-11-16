#ifndef TRADE_MANAGER_MQH
#define TRADE_MANAGER_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CTradeManager
{
private:
   CSymbolManager  *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   bool   m_break_even_enabled;
   double m_break_even_trigger_rr;
   double m_break_even_offset_pips;

   bool   m_partial_close_enabled;
   double m_partial_close_pct;

   ENUM_TRAIL_MODE m_trail_mode;
   double m_atr_trail_multiple;

   struct SOpenTrade
   {
      ulong    ticket;
      string   symbol;
      double   entry;
      double   sl;
      double   tp1;
      double   tp2;
      double   tp3;
      double   lot;
      ENUM_TRADE_SIGNAL direction;
      bool     partial_closed;
      bool     breakeven_hit;
   };

   SOpenTrade m_open_trades[];
   int m_open_count;

   bool ModifyPosition(ulong ticket, double sl, double tp)
   {
      if(!PositionSelectByTicket(ticket)) return false;

      MqlTradeRequest request = {};
      MqlTradeResult  result  = {};

      string sym = PositionGetString(POSITION_SYMBOL);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      request.action   = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.sl       = NormalizeDouble(sl, digits);
      request.tp       = NormalizeDouble(tp, digits);

      return OrderSend(request, result);
   }

   bool ClosePartial(ulong ticket, double volume)
   {
      if(!PositionSelectByTicket(ticket)) return false;

      MqlTradeRequest request = {};
      MqlTradeResult  result  = {};

      string sym = PositionGetString(POSITION_SYMBOL);
      double min_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double close_vol = MathMax(volume, min_lot);

      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = sym;
      request.volume    = close_vol;
      request.type      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price     = (request.type == ORDER_TYPE_BUY) ?
                           SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
      request.deviation = 20;
      request.position  = ticket;

      return OrderSend(request, result);
   }

   double GetRRRatio(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return 0;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      long   type  = PositionGetInteger(POSITION_TYPE);

      double risk = 0, reward = 0;

      if(type == POSITION_TYPE_BUY)
      {
         risk   = entry - sl;
         reward = tp - entry;
      }
      else
      {
         risk   = sl - entry;
         reward = entry - tp;
      }

      if(risk < POINT_EPSILON) return 0;
      return reward / risk;
   }

public:
   CTradeManager()
   {
      m_symbol_mgr  = NULL;
      m_log_mgr     = NULL;

      m_break_even_enabled     = true;
      m_break_even_trigger_rr  = 1.0;
      m_break_even_offset_pips = 5;

      m_partial_close_enabled  = true;
      m_partial_close_pct      = 50;

      m_trail_mode          = TRAIL_ATR;
      m_atr_trail_multiple  = 1.5;

      m_open_count = 0;
      ArrayResize(m_open_trades, 0);
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             bool be_enabled = true, double be_trigger = 1.0, double be_offset = 5,
             bool partial = true, double partial_pct = 50,
             ENUM_TRAIL_MODE trail = TRAIL_ATR, double trail_mult = 1.5)
   {
      m_symbol_mgr             = sym;
      m_log_mgr                = log;
      m_break_even_enabled     = be_enabled;
      m_break_even_trigger_rr  = be_trigger;
      m_break_even_offset_pips = be_offset;
      m_partial_close_enabled  = partial;
      m_partial_close_pct      = partial_pct;
      m_trail_mode             = trail;
      m_atr_trail_multiple     = trail_mult;

      Print("TradeManager: Initialized. BE=", be_enabled, " Trail=", EnumToString((ENUM_TRAIL_MODE)trail));
      return true;
   }

   bool OpenTrade(TradeSetup &setup, double lot_size)
   {
      MqlTradeRequest request = {};
      MqlTradeResult  result  = {};

      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = setup.symbol;
      request.volume    = lot_size;
      request.deviation = 20;
      request.magic     = 123456;

      if(setup.signal == SIGNAL_LONG)
      {
         request.type  = ORDER_TYPE_BUY;
         request.price = SymbolInfoDouble(setup.symbol, SYMBOL_ASK);
      }
      else if(setup.signal == SIGNAL_SHORT)
      {
         request.type  = ORDER_TYPE_SELL;
         request.price = SymbolInfoDouble(setup.symbol, SYMBOL_BID);
      }
      else
      {
         return false;
      }

      int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
      request.sl = NormalizeDouble(setup.sl, digits);
      request.tp = NormalizeDouble(setup.tp1, digits);

      request.comment = StringFormat("SMT_%.0f_%s", setup.confidence,
                         (setup.signal == SIGNAL_LONG) ? "BUY" : "SELL");

      if(!OrderSend(request, result))
      {
         if(m_log_mgr != NULL)
            m_log_mgr.LogTrade("REJECTED", setup.symbol, setup.entry, setup.sl, setup.tp1,
                               lot_size, "OrderSend failed: " + IntegerToString(result.retcode));
         return false;
      }

      if(result.retcode != TRADE_RETCODE_DONE)
      {
         if(m_log_mgr != NULL)
            m_log_mgr.LogTrade("REJECTED", setup.symbol, setup.entry, setup.sl, setup.tp1,
                               lot_size, "Trade failed: " + IntegerToString(result.retcode));
         return false;
      }

      SOpenTrade ot;
      ot.ticket         = result.order;
      ot.symbol         = setup.symbol;
      ot.entry          = setup.entry;
      ot.sl             = setup.sl;
      ot.tp1            = setup.tp1;
      ot.tp2            = setup.tp2;
      ot.tp3            = setup.tp3;
      ot.lot            = lot_size;
      ot.direction      = setup.signal;
      ot.partial_closed = false;
      ot.breakeven_hit  = false;

      m_open_count++;
      ArrayResize(m_open_trades, m_open_count);
      m_open_trades[m_open_count - 1] = ot;

      if(m_log_mgr != NULL)
         m_log_mgr.LogTrade("OPENED", setup.symbol, setup.entry, setup.sl, setup.tp1,
                            lot_size, setup.log);

      return true;
   }

   void ManageOpenTrades()
   {
      for(int i = m_open_count - 1; i >= 0; i--)
      {
         if(!PositionSelectByTicket(m_open_trades[i].ticket))
         {
            ArrayRemove(m_open_trades, i, 1);
            m_open_count--;
            continue;
         }

         ulong ticket = m_open_trades[i].ticket;

         if(m_break_even_enabled && !m_open_trades[i].breakeven_hit)
            CheckBreakEven(m_open_trades[i]);

         if(m_partial_close_enabled && !m_open_trades[i].partial_closed)
            CheckPartialClose(m_open_trades[i]);

         ApplyTrailing(m_open_trades[i]);
      }
   }

   void CheckBreakEven(SOpenTrade &trade)
   {
      double rr = GetRRRatio(trade.ticket);
      if(rr < m_break_even_trigger_rr) return;

      if(!PositionSelectByTicket(trade.ticket)) return;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double point = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
      double be_offset = m_break_even_offset_pips * point;

      double new_sl = 0;

      if(trade.direction == SIGNAL_LONG)
         new_sl = entry + be_offset;
      else
         new_sl = entry - be_offset;

      if(trade.direction == SIGNAL_LONG && new_sl > sl)
      {
         ModifyPosition(trade.ticket, new_sl, PositionGetDouble(POSITION_TP));
         trade.breakeven_hit = true;
         if(m_log_mgr != NULL)
            m_log_mgr.Log(StringFormat("BE applied: %s ticket=%d SL=%.5f",
                               trade.symbol, (int)trade.ticket, new_sl), LOG_TRADE);
      }
      else if(trade.direction == SIGNAL_SHORT && new_sl < sl)
      {
         ModifyPosition(trade.ticket, new_sl, PositionGetDouble(POSITION_TP));
         trade.breakeven_hit = true;
         if(m_log_mgr != NULL)
            m_log_mgr.Log(StringFormat("BE applied: %s ticket=%d SL=%.5f",
                               trade.symbol, (int)trade.ticket, new_sl), LOG_TRADE);
      }
   }

   void CheckPartialClose(SOpenTrade &trade)
   {
      double rr = GetRRRatio(trade.ticket);
      if(rr < 1.5) return;

      double close_vol = trade.lot * m_partial_close_pct / 100.0;
      if(ClosePartial(trade.ticket, close_vol))
      {
         trade.partial_closed = true;
         if(m_log_mgr != NULL)
            m_log_mgr.Log(StringFormat("Partial close: %s ticket=%d vol=%.2f",
                               trade.symbol, (int)trade.ticket, close_vol), LOG_TRADE);
      }
   }

   void ApplyTrailing(SOpenTrade &trade)
   {
      if(!PositionSelectByTicket(trade.ticket)) return;

      double current_sl = PositionGetDouble(POSITION_SL);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);

      double trail_dist = m_symbol_mgr.GetATR(trade.symbol, 14, 0) * m_atr_trail_multiple;
      if(trail_dist < POINT_EPSILON) return;

      double new_sl = 0;

      if(trade.direction == SIGNAL_LONG)
      {
         new_sl = price - trail_dist;
         if(new_sl > current_sl)
            ModifyPosition(trade.ticket, new_sl, PositionGetDouble(POSITION_TP));
      }
      else
      {
         new_sl = price + trail_dist;
         if(new_sl < current_sl)
            ModifyPosition(trade.ticket, new_sl, PositionGetDouble(POSITION_TP));
      }
   }

   int GetOpenCount()  { return m_open_count; }

   void CloseAll()
   {
      for(int i = 0; i < m_open_count; i++)
      {
         if(PositionSelectByTicket(m_open_trades[i].ticket))
         {
            MqlTradeRequest request = {};
            MqlTradeResult  result  = {};

            request.action   = TRADE_ACTION_DEAL;
            request.symbol   = PositionGetString(POSITION_SYMBOL);
            request.volume   = PositionGetDouble(POSITION_VOLUME);
            request.type     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price    = (request.type == ORDER_TYPE_BUY) ?
                                SymbolInfoDouble(request.symbol, SYMBOL_ASK) :
                                SymbolInfoDouble(request.symbol, SYMBOL_BID);
            request.deviation = 20;
            request.position  = m_open_trades[i].ticket;

            OrderSend(request, result);
         }
      }

      m_open_count = 0;
      ArrayResize(m_open_trades, 0);
   }
};

#endif
