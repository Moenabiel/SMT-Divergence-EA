#ifndef CORRELATION_ENGINE_MQH
#define CORRELATION_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "LoggingManager.mqh"

class CCorrelationEngine
{
private:
   CSymbolManager *m_symbol_mgr;
   CLoggingManager *m_log_mgr;

   int    m_lookback;
   double m_minimum_correlation;
   double m_current_correlation;
   bool   m_is_correlated;

   double CalculatePearson(double &x[], double &y[], int count)
   {
      if(count < 2) return 0;

      double sum_x = 0, sum_y = 0;
      double sum_xy = 0, sum_x2 = 0, sum_y2 = 0;

      for(int i = 0; i < count; i++)
      {
         sum_x  += x[i];
         sum_y  += y[i];
         sum_xy += x[i] * y[i];
         sum_x2 += x[i] * x[i];
         sum_y2 += y[i] * y[i];
      }

      double denom = MathSqrt((count * sum_x2 - sum_x * sum_x) * (count * sum_y2 - sum_y * sum_y));
      if(denom < POINT_EPSILON) return 0;

      return (count * sum_xy - sum_x * sum_y) / denom;
   }

public:
   CCorrelationEngine()
   {
      m_symbol_mgr          = NULL;
      m_log_mgr             = NULL;
      m_lookback            = 50;
      m_minimum_correlation = 0.60;
      m_current_correlation = 0;
      m_is_correlated       = false;
   }

   bool Init(CSymbolManager *sym, CLoggingManager *log,
             int lookback = 50, double minimum = 0.60)
   {
      m_symbol_mgr          = sym;
      m_log_mgr             = log;
      m_lookback            = lookback;
      m_minimum_correlation = minimum;

      Print("CorrelationEngine: Initialized. Lookback=", lookback,
            " Minimum=", DoubleToString(minimum, 2));
      return true;
   }

   void Update()
   {
      if(m_symbol_mgr == NULL) return;

      string sym1 = m_symbol_mgr.GetSymbol1();
      string sym2 = m_symbol_mgr.GetSymbol2();

      int count = m_lookback;

      if(count < 10)
      {
         m_current_correlation = 0;
         m_is_correlated = false;
         return;
      }

      double close1[];
      double close2[];
      double ret1[];
      double ret2[];

      ArrayResize(close1, count);
      ArrayResize(close2, count);
      ArrayResize(ret1, count - 1);
      ArrayResize(ret2, count - 1);

      for(int i = 0; i < count; i++)
      {
         close1[i] = m_symbol_mgr.GetClose(sym1, i);
         close2[i] = m_symbol_mgr.GetClose(sym2, i);
      }

      for(int i = 0; i < count - 1; i++)
      {
         if(close1[i + 1] < POINT_EPSILON || close2[i + 1] < POINT_EPSILON)
         {
            ret1[i] = 0;
            ret2[i] = 0;
         }
         else
         {
            ret1[i] = (close1[i] - close1[i + 1]) / close1[i + 1];
            ret2[i] = (close2[i] - close2[i + 1]) / close2[i + 1];
         }
      }

      m_current_correlation = CalculatePearson(ret1, ret2, count - 1);
      m_is_correlated = (MathAbs(m_current_correlation) >= m_minimum_correlation);

      if(m_log_mgr != NULL)
      {
         m_log_mgr.LogCorrelation(m_current_correlation, m_minimum_correlation, m_is_correlated);
      }
   }

   double GetCorrelation()       { return m_current_correlation; }
   bool   IsCorrelated()         { return m_is_correlated; }
   double GetMinimum()           { return m_minimum_correlation; }

   void SetLookback(int lookback)           { m_lookback = lookback; }
   void SetMinimum(double minimum)          { m_minimum_correlation = minimum; }

   double GetCorrelationScore()
   {
      if(!m_is_correlated) return 0;

      double abs_corr = MathAbs(m_current_correlation);
      if(abs_corr >= 0.80) return 10.0;
      if(abs_corr >= 0.70) return 7.5;
      if(abs_corr >= 0.60) return 5.0;
      return 0;
   }
};

#endif
