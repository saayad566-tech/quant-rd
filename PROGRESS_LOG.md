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
