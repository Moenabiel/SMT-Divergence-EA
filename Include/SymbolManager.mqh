#ifndef SYMBOL_MANAGER_MQH
#define SYMBOL_MANAGER_MQH

#include "Types.mqh"

class CSymbolManager
{
private:
   string m_symbol1;
   string m_symbol2;
   ENUM_TIMEFRAMES m_timeframe;
   int    m_bars_to_load;

   double m_high1[];
   double m_low1[];
   double m_close1[];
   double m_open1[];
   long   m_vol1[];
   datetime m_time1[];

   double m_high2[];
   double m_low2[];
   double m_close2[];
   double m_open2[];
   long   m_vol2[];
   datetime m_time2[];

   datetime m_last_bar_time1;
   datetime m_last_bar_time2;

   bool CopyData(string symbol,
                 double &high[], double &low[], double &close[], double &open[],
                 long &vol[], datetime &tm[], ENUM_TIMEFRAMES tf, int count)
   {
      ArrayResize(high, count);
      ArrayResize(low, count);
      ArrayResize(close, count);
      ArrayResize(open, count);
      ArrayResize(vol, count);
      ArrayResize(tm, count);

      if(CopyHigh(symbol, tf, 0, count, high) < count) return false;
      if(CopyLow(symbol, tf, 0, count, low) < count) return false;
      if(CopyClose(symbol, tf, 0, count, close) < count) return false;
      if(CopyOpen(symbol, tf, 0, count, open) < count) return false;
      if(CopyTickVolume(symbol, tf, 0, count, vol) < count) return false;
      if(CopyTime(symbol, tf, 0, count, tm) < count) return false;

      return true;
   }

   int DataSize(string symbol)
   {
      if(symbol == m_symbol1) return ArraySize(m_close1);
      return ArraySize(m_close2);
   }

public:
   CSymbolManager()
   {
      m_timeframe = PERIOD_M15;
      m_bars_to_load = MAX_BARS;
      m_last_bar_time1 = 0;
      m_last_bar_time2 = 0;
   }

   bool Init(string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe = PERIOD_M15, int bars = MAX_BARS)
   {
      m_symbol1 = symbol1;
      m_symbol2 = symbol2;
      m_timeframe = timeframe;
      m_bars_to_load = bars;

      SymbolSelect(m_symbol1, true);
      SymbolSelect(m_symbol2, true);

      if(!Refresh())
      {
         Print("SymbolManager: Failed to load initial data");
         return false;
      }

      Print("SymbolManager: Initialized ", m_symbol1, " + ", m_symbol2, " TF=", EnumToString(m_timeframe));
      return true;
   }

   bool Refresh()
   {
      if(!CopyData(m_symbol1, m_high1, m_low1, m_close1, m_open1, m_vol1, m_time1, m_timeframe, m_bars_to_load))
      {
         Print("SymbolManager: Failed to copy data for ", m_symbol1);
         return false;
      }

      if(!CopyData(m_symbol2, m_high2, m_low2, m_close2, m_open2, m_vol2, m_time2, m_timeframe, m_bars_to_load))
      {
         Print("SymbolManager: Failed to copy data for ", m_symbol2);
         return false;
      }

      return true;
   }

   string GetSymbol1()     { return m_symbol1; }
   string GetSymbol2()     { return m_symbol2; }
   ENUM_TIMEFRAMES GetTimeframe() { return m_timeframe; }

   double GetHigh(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_high1)) return 0;
         return m_high1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_high2)) return 0;
      return m_high2[shift];
   }

   double GetLow(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_low1)) return 0;
         return m_low1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_low2)) return 0;
      return m_low2[shift];
   }

   double GetClose(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_close1)) return 0;
         return m_close1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_close2)) return 0;
      return m_close2[shift];
   }

   double GetOpen(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_open1)) return 0;
         return m_open1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_open2)) return 0;
      return m_open2[shift];
   }

   long GetVolume(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_vol1)) return 0;
         return m_vol1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_vol2)) return 0;
      return m_vol2[shift];
   }

   datetime GetTime(string symbol, int shift)
   {
      if(symbol == m_symbol1)
      {
         if(shift < 0 || shift >= ArraySize(m_time1)) return 0;
         return m_time1[shift];
      }
      if(shift < 0 || shift >= ArraySize(m_time2)) return 0;
      return m_time2[shift];
   }

   double GetCloseAt(string symbol, int shift)
   {
      return GetClose(symbol, shift);
   }

   double GetBodySize(string symbol, int shift)
   {
      return MathAbs(GetClose(symbol, shift) - GetOpen(symbol, shift));
   }

   double GetCandleRange(string symbol, int shift)
   {
      return GetHigh(symbol, shift) - GetLow(symbol, shift);
   }

   double GetBodyRatio(string symbol, int shift)
   {
      double range = GetCandleRange(symbol, shift);
      if(range < POINT_EPSILON) return 0;
      return GetBodySize(symbol, shift) / range;
   }

   bool IsBullish(string symbol, int shift)
   {
      return GetClose(symbol, shift) > GetOpen(symbol, shift);
   }

   bool IsBearish(string symbol, int shift)
   {
      return GetClose(symbol, shift) < GetOpen(symbol, shift);
   }

   double GetATR(string symbol, int period = 14, int shift = 0)
   {
      int handle = iATR(symbol, m_timeframe, period);
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

   double GetImpulseStrength(string symbol, int shift, int atr_period = 14)
   {
      double atr = GetATR(symbol, atr_period, shift);
      if(atr < POINT_EPSILON) return 0;
      return GetBodySize(symbol, shift) / atr;
   }

   bool IsNewBar(string symbol)
   {
      datetime current = GetTime(symbol, 0);
      if(symbol == m_symbol1)
      {
         if(current != m_last_bar_time1)
         {
            m_last_bar_time1 = current;
            return true;
         }
      }
      else
      {
         if(current != m_last_bar_time2)
         {
            m_last_bar_time2 = current;
            return true;
         }
      }
      return false;
   }

   double GetDigits(string symbol)
   {
      return (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   }

   int GetSpread(string symbol)
   {
      return (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   }
};

#endif
