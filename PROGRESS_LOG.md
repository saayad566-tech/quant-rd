# PROGRESS_LOG — Quant RD

## 2026-10-15 — Session 1 (recovery + full build)

**Context recovery:** the sandbox was empty; no prior artifacts existed. The
product definition was re-established with the user and the app was rebuilt from
scratch.

**Completed**
- Installed Flutter 3.47.7 SDK; scaffolded the project (android, windows, web).
- Pinned 13 dependencies via `pub add` (versions resolved live, not from memory).
- Verified the exact API surface of Riverpod 3.4.3, fl_chart 1.2.0,
  flutter_secure_storage 11.2.0, file_picker 13.1.0, csv 8.0.0 before writing code.
- Built the full domain engine: indicators, strategy evaluation, event-driven
  backtester, metrics.
- Built the data layer: SQLite/in-memory database + repositories, secure store,
  five market-data provider clients, chunked asset-pack downloader, CSV parser,
  synthetic sample data.
- Built the UI: app shell, multi-tab sidebar (Navigate / API Keys / Configs),
  five screens, glass component library, charts.
- Wrote and passed 38 tests.
- Produced a **release web build** (`flutter build web --release` → success).

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (38)**
- `flutter build web --release` → `✓ Built build/web`

**Blocked / not done here**
- Local Android `.apk`: Gradle cannot reach the Gradle Plugin Portal host through
  the sandbox's egress proxy (HTTP 403). Code is verified; CI builds the APK.
- Local Windows `.exe`: requires a Windows toolchain (or Wine), absent here. CI builds it.

**Fixes made during the session (evidence-driven)**
- Rewrote the backtest loop when the pending-exit logic was ambiguous.
- Corrected the warm-up calculation (it over-skipped bars for indicator-free rules).
- Fixed a `MetricTile` layout overflow caught by the widget test.
- Updated the CSV parser to `csv` 8.x's `Csv` codec after the API changed.
- Made timezone-less CSV timestamps UTC for deterministic tests.

## 2026-10-15 — Session 2 (deep audit + protocol hardening + shipping)

**Audit** — re-read the whole codebase and catalogued gaps against the protocol
set: no project isolation, no user-visible logging, no global error handling, a
blur-on-every-card rendering cost, and no data export.

**Implemented**
- **Multi-project isolation** — first-class *Workspaces*. New `workspaces` table;
  `workspace_id` on datasets/strategies/backtests; v1→v2 SQLite migration that
  moves existing rows into a default project; workspace-scoped queries in every
  repository; a project switcher in the sidebar and full project management
  (create / rename / clear / delete) in Configs. Built-in strategies are global
  templates; user strategies are workspace-scoped.
- **Plain-English activity log** — `ActivityLog` records imports, fetches,
  backtests, deletes and errors as readable lines; persisted across sessions and
  viewable/exportable in a new Activity Log screen.
- **Self-healing error reporting** — `ErrorReporter` installs global handlers
  (`FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder`),
  converts any failure into a calm sentence, and replaces the red error screen
  with a fallback that keeps the app running.
- **60/120 Hz performance pass** — `GlassCard` backdrop blur is now opt-in
  (reserved for hero surfaces) instead of applied to every card, which removes a
  per-frame backdrop re-sample in scrolling lists; blur layers are wrapped in
  `RepaintBoundary`; charts are wrapped in `RepaintBoundary` and downsample to
  ≤600 points.
- **Export** — trades, metrics, equity curve and datasets to CSV, saved to disk
  (IO platforms) and copied to the clipboard everywhere.
- Fixed a real bug found by the widget test earlier (MetricTile overflow) and
  cleaned remaining template TODOs.

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (53)** — up from 38; new suites cover
  workspace isolation, export, the activity log and error reporting.

**Shipped (CI)**
- Pushed the full source to a private GitHub repo and ran GitHub Actions.
- `verify`, `android`, `windows`, `web` jobs all **succeeded**.
- Downloaded the real artifacts: 3 release APKs, the Play Store `.aab`, the
  Windows release (contains `quant_rd.exe`), and the web build.

**Lessons recorded**
- Binary files must be committed as base64; a text-only upload silently drops
  launcher icons and `app_icon.ico`, which breaks the Android and Windows builds.
- GitHub's free artifact storage quota can be exhausted; publishing to GitHub
  **Releases** is a reliable alternative that does not use artifact storage.
- `secrets` cannot be used in a step-level `if:`; use a shell check instead.

## 2026-10-15 — Session 3 (autonomous data + strategy management)

**Directive received** (uploaded brief): stop relying on passive stubs; make data
ingestion self-sufficient at zero cost, wire up strategy install/management, add
proactive status reporting, and verify with strict type-safety + tests.

**Implemented**
- **Keyless auto-fetch (zero cost).** Added two free public sources needing no key:
  **Yahoo Finance** (`/v8/finance/chart`) and **Binance** (`/api/v3/klines`).
  `ApiProvider` now carries `requiresKey`, and `MarketDataClient` gained
  `_fetchYahoo` / `_fetchBinance` plus a User-Agent header (Yahoo requires one)
  and a header-capable retry helper.
- **Smart fallback chain** (`SmartDataService`): local cache → free keyless
  sources → any provider the user holds a key for. Everything fetched is written
  to the workspace so the next run is an instant, fully-offline cache hit.
- **Plain-English data status.** Every resolution reports what happened
  ("Using local cache: 1,200 candles…", "Fetched 500 candles from Yahoo Finance
  (free, no key needed) and cached them locally"), surfaced in the UI and the
  activity log.
- **JSON ingestion.** New `JsonCandleParser` accepting arrays of objects, arrays
  of arrays, wrapped payloads (`data`/`values`/`candles`/`result`/…), and raw
  **Yahoo** / **Binance** responses. The import button now takes CSV **or** JSON
  and auto-detects. Introduced a shared `CandleParseReport` (CSV kept as an alias).
- **Strategy install/import + management.** "Install / Import" reads a strategy
  from pasted JSON or a file (tolerant of missing fields), "Export" writes one
  out, and each strategy has an **Active/Disabled** toggle backed by a new
  `enabled` column (DB v3 migration).
- **API-keys screen** now leads with the free keyless sources and only lists the
  providers that actually need a key.

**Verified**
- `flutter analyze` → **No issues found!** (the Dart equivalent of the brief's
  `tsc --noEmit` requirement).
- `flutter test` → **All tests passed! (83)**, up from 53. New suites cover
  **slippage**, **smart data fallback** (cache hit → free source → keyed
  provider → helpful error, plus workspace isolation), the **JSON parser**
  (objects/arrays/wrappers/Yahoo/Binance), and strategy import/export.
- **Live endpoint check:** `query1.finance.yahoo.com` returned real data for
  `AAPL` (equity), `BTC-USD` (crypto) and `EURUSD=X` (FX) with no key. The real
  AAPL payload is committed as a test fixture and parsed in the suite.

**Environment limits found (honest)**
- `api.binance.com`, `data-api.binance.vision`, `api.binance.us` and
  `api.coingecko.com` are all blocked by this sandbox's egress proxy, so the
  Binance path could not be exercised live here. It is covered by a unit test
  built on the documented payload shape, and Yahoo also serves crypto
  (`BTC-USD`), so crypto fetching still works without Binance.

## 2026-10-15 — Session 4 (autonomous R&D core, validation gate, swarm)

**Directive received** (uploaded brief): wire the house end-to-end, build a
multi-device swarm, a local model hub, sequential multi-AI R&D, offline voice,
a mandatory backtesting gate, rolling buffer caps, and "death to mocks".

**Built and verified**
- **Rolling buffer caps** — `RollingBuffer` / `RollingCandleBuffer` with a hard
  5,000-bar cap; a 100,000-item feed holds exactly 5,000.
- **Mandatory validation gate** — `ValidationPolicy`, `ValidationOutcome`,
  `StrategyValidation`; strategies persist their validation record (DB v4) and
  cannot be enabled on an assertion — the UI prompts to run the gate first.
- **Research pipeline** — Data Analyst → Strategy Builder → Backtester →
  Validator, with a bounded work queue (batch yields) and a bounded leaderboard
  (only the top K retained, equity curves released immediately).
- **Local model hub** — manifest fetch, streamed download with progress,
  SHA-256 verification, on-device index, list and remove.
- **Device swarm** — a real LAN sync layer: HTTP node advertising datasets,
  client probe/list/pull, peer registry hard-capped at 15. Verified by a real
  loopback server/client test.
- **UI** — three new screens (Research, Local Models, Device Swarm) wired into
  the sidebar; validation status surfaced in the Strategy Lab.

**Deliberately not built** (documented in `SCOPE.md`, because the brief forbids
fake claims): on-device LLM inference, LLM-driven agents, cross-device compute
pooling/scheduling, and offline Whisper STT — each needs a native runtime or
real multi-device hardware that this build does not have.

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (110)**, up from 83. New suites: rolling
  buffer, research pipeline, validation gate, and the LAN swarm loopback.
- Placeholder scan across `lib/` + `test/`: **0 hits**.

## 2026-10-15 — Session 5 (book-framework knowledge engine)

**Directive received**: build a "100-book domain knowledge engine" into Strategy
Lab — every strategy citing its book framework, supply-chain "picks and shovels"
intelligence, an education panel, a mandatory compliance banner, and strict
regional isolation (India vs US).

**Copyright position, stated plainly.** The app does **not** download or
distribute in-copyright books. What it does instead:
- encodes the **frameworks** (publicly documented rules, formulas and screening
  criteria) with plain-prose attribution to each source book;
- downloads **public-domain titles in full from Project Gutenberg**, which hosts
  them for anyone to copy and reuse;
- lets the user index **their own copy** of any book locally, which is never
  uploaded.

**Built and verified**
- `BookFramework` / `BookRef` / `FrameworkCriterion` models and a catalogue of
  80+ benchmark titles plus 11 detailed frameworks (Magic Formula, CAN SLIM,
  Minervini Trend Template + VCP, Graham defensive, Lynch PEG, Piotroski F-Score,
  Weinstein stage analysis, momentum factor, Turtle trend, low-volatility/quality,
  Wilder RSI/ATR), each with cited sources.
- `FrameworkScreener`: computes the technical criteria from **real candles** —
  moving-average stack, 200-day slope, distance from the 52-week high/low,
  cross-sectional relative-strength percentile, volume dry-up, and a genuine VCP
  contraction detector. Criteria needing fundamentals are reported as **N/A and
  never counted as passes**.
- `MarketRegion` with a single `filter()` funnel: India accepts NSE/BSE listings
  and rejects US tickers, the US the reverse, crypto is neutral. Zero
  cross-market leakage, unit-tested.
- `SupplyChainTheme` map for AI infrastructure, EV, energy/grid, semiconductors,
  defence and water — front-line names versus upstream choke-points.
- `BookLibrary`: real Project Gutenberg fetcher (verified live: HTTP 200, full
  text), own-copy indexing, and passage search across stored books.
- New **Book Intelligence** screen (Frameworks · Screener · Supply chain ·
  Book library) plus a non-dismissible compliance banner in Strategy Lab, a
  framework citation on each tagged strategy (DB v5 `framework_id`), and a
  market-region selector in Configs.

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (131)**, up from 110. New suite covers
  catalogue integrity, regional isolation, the screener on real candles, the
  supply-chain map, and framework tagging.

## 2026-10-15 — Session 6 (quant mechanics + strategy plugin engine)

**Directive received**: ingest 2,000+ trading books, extract their formulas, and
"train the Strategy Engine" to execute them.

**Copyright position, stated plainly.** I did not and will not ingest 2,000+
in-copyright books — I do not have that corpus and acquiring it would be piracy.
I also cannot "train" a model here. What I built is the thing that actually makes
a trading engine correct: **explicit, deterministic, tested mathematics**. A model
that had absorbed a book's idea approximately would be worse at this than a
formula that is exactly right and can be audited.

**Built and verified**
- **Quant mechanics library** (`lib/domain/quant/quant_mechanics.dart`): N-bar
  fractal pivots; least-squares trendlines with R-squared and touch counts;
  volume-confirmed breakouts; support/resistance clustering; Fibonacci
  retracements and extensions; VWAP and anchored VWAP; volume profile with point
  of control and the 70% value area, plus high/low-volume nodes; OBV; an
  order-flow delta **proxy** (labelled as one, because OHLCV bars carry no bid/ask
  volume); Wilder ATR; ATR, Keltner, Bollinger and envelope channels; double
  tops/bottoms; head and shoulders; gap taxonomy; a four-state regime classifier;
  fractional differentiation; an ADF statistic; and triple-barrier labelling.
- **Risk and statistics** (`quant_risk.dart`): the directive's **Section 5
  step-up trailing stop implemented exactly** — a -10% floor, break-even at +10%,
  +5% at +15%, +10% at +20%, a 10% gap to +50%, then 5-point steps — plus Kelly
  sizing, expected value, max drawdown, Sharpe, fixed-fractional position sizing,
  Engle-Granger cointegration, a Kalman filter and rolling z-scores.
- **Options** (`quant_options.dart`): Black-Scholes pricing and the full Greeks
  (verified against put-call parity and the standard reference value), implied
  volatility by bisection that **refuses** a price outside the no-arbitrage
  bounds, and dealer gamma exposure with a gamma wall and flip level.
- **Strategy plugin engine** (`lib/domain/strategy_engine/`): `BaseStrategy`,
  `Signal` with mandatory provenance, and a `StrategyFactory` registry. Twelve
  concrete book-derived strategies (Minervini trend template, Weinstein Stage 2,
  Turtle breakout, Wilder RSI, CAN SLIM's technical subset, 12-1 momentum,
  value-area breakout, Wyckoff spring, VCP breakout, regression trendline
  breakout, double-bottom reversal, gap-and-go).
- **Framework ingestion pipeline** (`framework_ingestion.dart`): a declarative
  schema (indicators, operators, thresholds, risk rules) parsed into live
  strategies. Provenance is mandatory — a framework with no cited source is
  rejected. Malformed documents report their failure instead of being dropped.
- **Signal tracker** (`lib/domain/tracking/signal_tracker.dart`): follows every
  signal through the bars with the trailing stop and produces win rate, profit
  factor, expectancy, Sharpe, max drawdown, average gain/loss and hold time.
- **Quant Engine screen**: mechanics, the strategy engine with provenance, and an
  interactive trailing-stop ladder — wired into the sidebar and registered at
  startup.

**Honesty markers carried through the code**: fundamental criteria (EPS growth,
ROIC, institutional ownership) are reported as needing data and never assumed to
pass; relative-strength percentiles are cross-sectional and the single-symbol path
says it uses absolute momentum; the delta proxy is labelled a proxy; replay fills
at the stop level and the gap optimism is stated.

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (187)**, up from 131. The new suites assert
  the exact trailing-stop ladder, Black-Scholes against put-call parity and the
  reference value, fractional differentiation, the VWAP hand calculation, the
  triple barrier, cointegration on a constructed pair, and the ingestion
  pipeline's accept/reject paths.
- Three real bugs were caught by these tests and fixed: a floating-point boundary
  error that skipped the +15% stop step, an inconsistent fill in the stop replay,
  and a test fixture whose swing low sat too close to the end of the series.

## 2026-10-15 — Session 7 (closing the four gaps)

**Directive received**: close four gaps — (1) scale the corpus pipeline from
legitimate text, (2) integrate a fundamental data feed, (3) surface the options
and GEX maths in a dashboard, (4) upgrade the supply-chain map to a three-tier
dependency graph. The directive itself restates the anti-piracy guardrail, which
matches the position I have held throughout.

**Built and verified**
- **Public-domain corpus extraction** (`corpus_parser.dart`): maps sentences onto
  the executable schema — indicators, comparators, thresholds, periods (with weeks
  converted to trading days). Anything ambiguous is **rejected with a stated
  reason**, never guessed. Provenance is mandatory, and the extraction report is
  serialisable. Wired into the Book Intelligence screen as an ingest panel.
- **SEC EDGAR fundamentals** (`edgar_client.dart` + IO/web): keyless, with the
  descriptive User-Agent the SEC requires, configurable in Configs. A pure parser
  (testable offline) separates annual 10-K entries from quarterly 10-Q entries
  under the same tag, and turns any unreadable figure into a reported gap.
- **Fundamental scorer** (`fundamental_scorer.dart`): ROE, ROA, return on capital,
  net margin, debt/equity, current ratio, EPS and revenue growth, 3-year EPS CAGR,
  positive-earnings years, and — with a real price — market cap, earnings yield,
  P/B and PEG. Every metric carries its formula. The framework screener now takes
  an optional fundamentals map, so criteria that were passive placeholders become
  genuinely **evaluated** (and genuinely fail when the numbers say so).
- **Options & GEX dashboard** (`options_screen.dart`): a net-gamma-by-strike
  heatmap, gamma wall and flip level, and the volatility smile. The chain comes
  from a clearly-labelled simulated feed or your own pasted chain.
- **Three-tier supply-chain graph** (`supply_chain_graph.dart`): 45+ nodes across
  tier 1/2/3 with dependency edges, choke-point scoring, transitive traversal, and
  a systemic risk-propagation model with a critical path.

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (236)**, up from 187. New suites cover
  graph construction/traversal/propagation, EDGAR parsing and scoring against a
  realistic company-facts fixture, corpus extraction accept/reject paths, and the
  options screen's GEX dashboard.
- Bugs the tests caught and I fixed: the propagation model attenuated on the wrong
  node's substitutability; the corpus parser read "oversold" as the operator
  "over" and could not find a second moving average; the EDGAR fixture had 27-day
  "quarters"; and the options test needed the app theme and a scroll to reach the
  smile.
