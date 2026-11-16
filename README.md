# SMT Divergence EA

MetaTrader 5 Expert Advisor — an institutional Smart Money Concepts trading system
for **XAUUSD / XAGUSD** (default M15), built as a set of composable engines rather
than one monolithic script.

## Engine architecture

| Engine | Role |
|---|---|
| `SMTDetectionEngine` | SMT (smart-money divergence) detection between correlated symbols |
| `CorrelationEngine` | Symbol-pair correlation tracking |
| `LiquidityEngine` | Liquidity sweep/pool logic |
| `DisplacementEngine` | Displacement leg detection |
| `MarketStructureEngine` | BOS/CHoCH structure tracking |
| `FVGEngine` | Fair-value-gap identification |
| `OrderBlockEngine` | Order-block mapping |
| `PremiumDiscountEngine` | Premium/discount zone pricing |
| `MarketRegimeEngine` | Regime classification |
| `ScoringEngine` | Confluence scoring for entries |
| `RiskManager` / `TradeManager` | Sizing, exposure and trade lifecycle |
| `StatisticsManager` / `VisualizationManager` / `LoggingManager` | Reporting, on-chart visualization, logs |

Session windows (Asian/London/NY) are configurable in UTC via input groups.

## Status

**Research** — strategy research software. No live-performance claims are made;
validate independently before any real-money use.

## Stack

- MQL5 (MetaTrader 5)
- Modular `.mqh` engine includes under `Include/`
