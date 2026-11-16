#ifndef SCORING_ENGINE_MQH
#define SCORING_ENGINE_MQH

#include "Types.mqh"

class CScoringEngine
{
private:
   double m_threshold;

   double m_w_smt_t1;
   double m_w_smt_t2;
   double m_w_smt_t3;
   double m_w_cascade;
   double m_w_liquidity;
   double m_w_displacement;
   double m_w_structure;
   double m_w_pd;
   double m_w_fvg;
   double m_w_ob;
   double m_w_session;
   double m_w_correlation;
   double m_w_regime;

public:
   CScoringEngine()
   {
      m_threshold    = 70;
      m_w_smt_t1     = 40;
      m_w_smt_t2     = 25;
      m_w_smt_t3     = 10;
      m_w_cascade    = 20;
      m_w_liquidity  = 15;
      m_w_displacement = 15;
      m_w_structure  = 20;
      m_w_pd         = 10;
      m_w_fvg        = 10;
      m_w_ob         = 10;
      m_w_session    = 10;
      m_w_correlation = 10;
      m_w_regime     = 10;
   }

   void SetThreshold(double threshold)  { m_threshold = threshold; }
   double GetThreshold()                { return m_threshold; }

   ScoreBreakdown CalculateScore(SMTResult &smt, double liquidity_score,
                                  double displacement_score, StructureResult &structure,
                                  double pd_score, double fvg_score, double ob_score,
                                  double session_score, double correlation_score,
                                  double regime_score, double cascade_score)
   {
      ScoreBreakdown sb;

      sb.smt_tier = smt.score;
      sb.cascade  = cascade_score;
      sb.liquidity = liquidity_score;
      sb.displacement = displacement_score;
      sb.structure = (structure.shift != STRUCT_NONE) ? 20.0 : 0;
      sb.premium_discount = pd_score;
      sb.fvg      = fvg_score;
      sb.order_block = ob_score;
      sb.session_alignment = session_score;
      sb.correlation = correlation_score;
      sb.regime   = regime_score;

      sb.total = sb.smt_tier + sb.cascade + sb.liquidity + sb.displacement +
                 sb.structure + sb.premium_discount + sb.fvg + sb.order_block +
                 sb.session_alignment + sb.correlation + sb.regime;

      sb.passes = (sb.total >= m_threshold && smt.direction != SMT_INVALID);

      return sb;
   }

   double GetDynamicRisk(double score, double low_risk, double mid_risk, double high_risk)
   {
      if(score >= 90)   return high_risk;
      if(score >= 80)   return mid_risk;
      if(score >= 70)   return low_risk;
      return 0;
   }
};

#endif
