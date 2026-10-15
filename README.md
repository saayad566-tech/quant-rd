# Quant RD

**Quantitative strategy research & backtesting — offline-first, on your device.**

Quant RD is a cross-platform research workstation for building trading strategies,
backtesting them honestly (fees, slippage, no look-ahead bias) and analysing the
results. It ships as a native **Android app** and a native **Windows desktop app**
from a single Flutter codebase, and runs fully offline. Network data fetching is
optional and uses *your own* API keys, stored only in the device secure store.

> **Not financial advice.** Backtests are simulations on historical data. Past
> performance does not predict future results. Always paper-trade before risking
> real capital.

---

## Features

- **Market data**
  - Import OHLCV **CSV** files (comma / semicolon / tab / pipe, header or
    headerless, multiple date formats, epoch timestamps).
  - Fetch history from **Alpha Vantage, Twelve Data, Polygon.io, Finnhub** or a
    custom JSON endpoint using your own key.
  - Bundled **synthetic sample data** so the app is usable offline instantly.
  - Local, versioned SQLite storage — every dataset is cached for offline use.
- **Strategy Lab**
  - Six built-in strategies (Buy & Hold, SMA/EMA crossover, RSI mean-reversion,
    MACD trend, Bollinger breakout).
  - A full **rule builder**: entry/exit conditions over 15 indicators with
    `>`, `<`, `crosses above`, `crosses below` and constant/indicator operands.
  - Stop-loss, take-profit, position sizing and long/short modes.
- **Backtester** — event-driven, executes signals on the **next bar's open**,
  charges fees and slippage on both sides, supports intra-bar stop-loss /
  take-profit. No look-ahead bias.
- **Analytics** — total return, CAGR, volatility, Sharpe, Sortino, max drawdown,
  Calmar, win rate, profit factor, expectancy, exposure and more; equity curve,
  drawdown chart, full trade log, and a buy-&-hold comparison.
- **Premium UI** — dark glassmorphism with a light theme, animated transitions,
  responsive layout (permanent sidebar on desktop, drawer on mobile).
- **Multi-tab sidebar** — dedicated **Navigate**, **API Keys** and **Configs**
  sections so the main workspace layout is never compromised.
- **Projects (workspaces)** — keep separate research projects fully isolated;
  datasets, strategies and results never leak between projects.
- **Activity log** — a plain-English, timestamped record of every import, fetch,
  backtest and error, exportable at any time.
- **Export** — trades, metrics, equity curves and datasets to CSV, saved to disk
  and copied to the clipboard in one tap.
- **Resilient by design** — global error handling turns failures into calm,
  self-explanatory messages and keeps the rest of the app running.
- **Runtime asset packs** — large datasets live in a *separate* repository,
  chunked and downloaded on demand, verified by SHA-256.

---

## Quick start (developers)

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # 38 tests
flutter run              # desktop / mobile
```

## Building

See **[BUILD.md](BUILD.md)** for the exact commands to produce the Android
`.apk` / `.aab`, the Windows `.exe`, and the web build — plus signing and CI.

CI builds all targets automatically on every push (`.github/workflows/build.yml`)
and publishes signed artifacts on version tags.

---

## Architecture

Clean layering — the domain never imports the UI or the platform:

```
lib/
  core/            constants, result type, formatters, theme tokens, ids
  data/
    models/        Candle, Dataset, StrategySpec, BacktestConfig, Trade, results
    parsers/       robust OHLCV CSV parser
    storage/       AppDatabase (SQLite on IO / in-memory on web) + repositories
    remote/        provider clients, chunked asset-pack downloader
    sample/        deterministic synthetic sample data
  domain/
    indicators/    SMA, EMA, RSI, MACD, Bollinger, ATR, Stochastic, ROC
    engine/        strategy evaluation, event-driven backtester, metrics
    providers/     Riverpod providers (the app's state graph)
  presentation/
    shell/         app shell, multi-tab sidebar, screens
    widgets/       glass components, charts
```

**Key design guarantees**

- Indicator values at bar `i` use only bars `0..i`; signals execute at `i+1`.
- Fees and slippage are charged on entry **and** exit.
- The domain layer is pure Dart and unit-tested independently of Flutter.
- Errors are typed values with user-facing messages — no swallowed exceptions.

## Performance

Built for a smooth 60/120 Hz experience:

- The glass surfaces use a **cheap translucent fill by default**; a true backdrop
  blur is opt-in and reserved for a few hero cards, because a blur re-samples the
  backdrop every frame and is the classic cause of scroll jank.
- Charts are wrapped in `RepaintBoundary` and **downsample to ≤600 points**, so a
  50,000-bar equity curve paints as fast as a 600-bar one.
- Lists are virtualised (`ListView.builder`); database reads are indexed and
  paginated; heavy work stays off the UI thread.

## Testing

53 tests across indicators, strategy evaluation, the backtester, metrics, the
CSV parser, the storage layer, **workspace isolation**, export, the activity log,
error reporting, and a full UI navigation walk (which also guards against layout
overflow).

```bash
flutter test
```

## Licence

MIT — see [LICENSE](LICENSE).
