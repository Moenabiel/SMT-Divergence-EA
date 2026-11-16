#ifndef TYPES_MQH
#define TYPES_MQH

enum ENUM_SMT_TIER
{
   SMT_TIER_NONE,
   SMT_TIER_1,
   SMT_TIER_2,
   SMT_TIER_3
};

enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_EXPANSION,
   REGIME_REVERSAL,
   REGIME_HIGH_VOL,
   REGIME_LOW_VOL
};

enum ENUM_LIQUIDITY_TYPE
{
   LIQ_DAILY_HIGH,
   LIQ_DAILY_LOW,
   LIQ_DAILY_OPEN,
   LIQ_DAILY_CLOSE,
   LIQ_WEEKLY_HIGH,
   LIQ_WEEKLY_LOW,
   LIQ_ASIAN_HIGH,
   LIQ_ASIAN_LOW,
   LIQ_LONDON_HIGH,
   LIQ_LONDON_LOW,
   LIQ_NY_HIGH,
   LIQ_NY_LOW,
   LIQ_OR_HIGH,
   LIQ_OR_LOW
};

enum ENUM_SMT_DIRECTION
{
   SMT_BULLISH,
   SMT_BEARISH,
   SMT_INVALID
};

enum ENUM_STRUCTURE_SHIFT
{
   STRUCT_NONE,
   STRUCT_MSS_BULL,
   STRUCT_MSS_BEAR,
   STRUCT_CHOCH_BULL,
   STRUCT_CHOCH_BEAR
};

enum ENUM_TRADE_SIGNAL
{
   SIGNAL_NONE,
   SIGNAL_LONG,
   SIGNAL_SHORT
};

enum ENUM_LOG_LEVEL
{
   LOG_INFO,
   LOG_WARNING,
   LOG_DEBUG,
   LOG_TRADE
};

enum ENUM_TRAIL_MODE
{
   TRAIL_ATR,
   TRAIL_STRUCTURE,
   TRAIL_FVG,
   TRAIL_DYNAMIC
};

enum ENUM_RISK_MODE
{
   RISK_FIXED,
   RISK_DYNAMIC
};

enum ENUM_SESSION_TYPE
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_KILLZONE_LONDON,
   SESSION_KILLZONE_NY,
   SESSION_OR_NY,
   SESSION_NONE
};

struct LiquidityLevel
{
   double         price;
   ENUM_LIQUIDITY_TYPE type;
   datetime       time;
   bool           swept;
   int            sweep_bar;
};

struct SMTResult
{
   ENUM_SMT_DIRECTION direction;
   ENUM_SMT_TIER      tier;
   double             score;
   string             reason;
   string             stronger_symbol;
   string             weaker_symbol;
   datetime           signal_time;
};

struct StructureResult
{
   ENUM_STRUCTURE_SHIFT shift;
   double               level;
   datetime             time;
   double               displacement_size;
};

struct FVGZone
{
   double   top;
   double   bottom;
   bool     bullish;
   datetime time;
   bool     filled;
   int      bar_index;
};

struct OrderBlock
{
   double   high;
   double   low;
   bool     bullish;
   datetime time;
   bool     mitigated;
   int      bar_index;
};

struct PremiumDiscount
{
   double            premium_start;
   double            equilibrium;
   double            discount_end;
   ENUM_SESSION_TYPE range_type;
};

struct TradeSetup
{
   ENUM_TRADE_SIGNAL signal;
   double            entry;
   double            sl;
   double            tp1;
   double            tp2;
   double            tp3;
   double            confidence;
   double            lot_size;
   SMTResult         smt;
   StructureResult   structure;
   string            log;
   string            symbol;
};

struct SymbolData
{
   string  symbol;
   double  high[];
   double  low[];
   double  close[];
   double  open[];
   long    volume[];
   datetime time[];
};

struct SessionRange
{
   double   high;
   double   low;
   datetime start;
   datetime end;
   string   name;
   bool     active;
   bool     swept_high;
   bool     swept_low;
};

struct TradeStats
{
   int    total_trades;
   int    wins;
   int    losses;
   double total_profit;
   double total_loss;
   double max_drawdown;
   double profit_factor;
   double win_rate;
   double avg_rr;
   int    today_trades;
   int    today_losses;
   int    session_trades;
   int    session_losses;
   int    consecutive_losses;
};

struct ScoreBreakdown
{
   double smt_tier;
   double cascade;
   double liquidity;
   double displacement;
   double structure;
   double premium_discount;
   double fvg;
   double order_block;
   double session_alignment;
   double correlation;
   double regime;
   double total;
   bool   passes;
};

#define MAX_BARS 500
#define POINT_EPSILON 0.00001

#endif
