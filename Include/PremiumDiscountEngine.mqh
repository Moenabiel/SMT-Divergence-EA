#ifndef PREMIUM_DISCOUNT_ENGINE_MQH
#define PREMIUM_DISCOUNT_ENGINE_MQH

#include "Types.mqh"
#include "SymbolManager.mqh"
#include "SessionManager.mqh"

class CPremiumDiscountEngine
{
private:
   CSymbolManager  *m_symbol_mgr;
   CSessionManager *m_session_mgr;

public:
   CPremiumDiscountEngine()
   {
      m_symbol_mgr  = NULL;
      m_session_mgr = NULL;
   }

   bool Init(CSymbolManager *sym, CSessionManager *sess)
   {
      m_symbol_mgr  = sym;
      m_session_mgr = sess;
      return true;
   }

   PremiumDiscount CalculateDailyPD()
   {
      PremiumDiscount pd;
      pd.range_type = SESSION_NONE;

      if(m_session_mgr == NULL) return pd;

      double high = m_session_mgr.GetPDH();
      double low  = m_session_mgr.GetPDL();

      if(high < POINT_EPSILON || low < POINT_EPSILON) return pd;

      pd.premium_start = high;
      pd.equilibrium   = (high + low) / 2.0;
      pd.discount_end  = low;

      return pd;
   }

   PremiumDiscount CalculateWeeklyPD()
   {
      PremiumDiscount pd;
      pd.range_type = SESSION_NONE;

      if(m_session_mgr == NULL) return pd;

      double high = m_session_mgr.GetWH();
      double low  = m_session_mgr.GetWL();

      if(high < POINT_EPSILON || low < POINT_EPSILON) return pd;

      pd.premium_start = high;
      pd.equilibrium   = (high + low) / 2.0;
      pd.discount_end  = low;

      return pd;
   }

   PremiumDiscount CalculateSessionPD(ENUM_SESSION_TYPE session)
   {
      PremiumDiscount pd;
      pd.range_type = session;

      if(m_session_mgr == NULL) return pd;

      double high, low;
      m_session_mgr.GetSessionLevels(session, high, low);

      if(high < POINT_EPSILON || low > DBL_MAX / 2) return pd;

      pd.premium_start = high;
      pd.equilibrium   = (high + low) / 2.0;
      pd.discount_end  = low;

      return pd;
   }

   bool IsInDiscount(double price, PremiumDiscount &pd)
   {
      if(pd.discount_end < POINT_EPSILON) return false;
      return price < pd.equilibrium;
   }

   bool IsInPremium(double price, PremiumDiscount &pd)
   {
      if(pd.premium_start < POINT_EPSILON) return false;
      return price > pd.equilibrium;
   }

   bool IsAtEquilibrium(double price, PremiumDiscount &pd, double tolerance_pips = 5)
   {
      if(pd.equilibrium < POINT_EPSILON) return false;
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      return MathAbs(price - pd.equilibrium) < tolerance_pips * point;
   }

   double GetPDScore(ENUM_TRADE_SIGNAL signal, double price)
   {
      PremiumDiscount daily_pd = CalculateDailyPD();
      PremiumDiscount weekly_pd = CalculateWeeklyPD();

      if(daily_pd.equilibrium < POINT_EPSILON && weekly_pd.equilibrium < POINT_EPSILON)
         return 0;

      bool in_discount = IsInDiscount(price, daily_pd) || IsInDiscount(price, weekly_pd);
      bool in_premium  = IsInPremium(price, daily_pd) || IsInPremium(price, weekly_pd);

      if(signal == SIGNAL_LONG && in_discount)
         return 10.0;

      if(signal == SIGNAL_SHORT && in_premium)
         return 10.0;

      return 0;
   }
};

#endif
