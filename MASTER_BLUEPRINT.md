# MASTER_BLUEPRINT — Quant RD

## 1. Tech-stack decision
**Flutter 3.47.7 (Dart 3.13)** — one codebase compiling to **native Android** and
**native Windows** binaries, with full control over a premium custom UI and a
mature local-storage / secure-storage ecosystem.

Alternatives rejected:
- *React Native / Expo* — weaker Windows desktop story.
- *Electron + Capacitor* — two build systems, webview UI, larger binaries.
- *Kotlin + Compose only* — would not produce a Windows build.
- *Tauri* — excellent for Windows, poor fit for Android without extra layers.

## 2. Folder tree
```
lib/
  main.dart, app.dart
  core/  constants.dart result.dart formatters.dart ids.dart
         theme/{design_tokens.dart, app_theme.dart}
  data/
    models/   candle, dataset, strategy_spec, backtest_config, trade,
              backtest_result, api_provider, app_settings, asset_pack
    parsers/  csv_candle_parser.dart
    storage/  app_database.dart, app_database_io.dart, app_database_web.dart,
              database_factory*.dart, repositories.dart, secret_store.dart
    remote/   market_data_client.dart, asset_pack_manager*.dart, asset_pack_factory*.dart
    sample/   sample_data.dart
  domain/
    indicators/ indicators.dart
    engine/     strategy_engine.dart, backtest_engine.dart, metrics.dart,
                builtin_strategies.dart
    providers/  core_providers.dart, feature_providers.dart, ui_providers.dart
  presentation/
    shell/    app_shell.dart, sidebar.dart, screens.dart, *_screen.dart
    widgets/  common.dart, charts.dart
test/  indicators, strategy_engine, backtest_engine, metrics, csv_parser,
       repository, widget_smoke, navigation
.github/workflows/  build.yml, release.yml
assets-repo/        manifest.example.json, chunk_assets.py, README.md
```

## 3. Navigation map
Single `Scaffold`. Sidebar (permanent ≥900 px, drawer below) with three tabs:
- **Navigate** → Dashboard · Market Data · Strategy Lab · Backtest · Results
- **API Keys** → per-provider key entry + connection test
- **Configs** → appearance, backtest defaults, asset-pack base URL + sync

Main content switches with a fade/slide transition.

## 4. Data architecture
- **Entities:** Candle, Dataset, StrategySpec (rules + sizing + SL/TP), Trade,
  EquityPoint, BacktestResult, AssetPack.
- **Storage:** SQLite (`datasets`, `candles`, `strategies`, `backtests`,
  `settings`) on Android/Windows via `sqflite` (+ `sqflite_common_ffi` on
  desktop); in-memory on web. Wrapped behind an `AppDatabase` interface and four
  repositories so the domain never sees SQL.
- **Secrets:** OS secure store (`flutter_secure_storage`); never in SQLite/logs.
- **Migrations:** DB version constant; schema created on first open.

## 5. State management
Riverpod 3.4. Synchronous `Provider`s for infrastructure (overridden with the
opened DB in `main()`), `FutureProvider`(+`.family`) for read models,
`NotifierProvider` for selections, the backtest runner and navigation.

## 6. Service contracts
`MarketDataClient.fetch(provider, apiKey, symbol, interval, outputSize, customUrl)`
→ `List<Candle>`; throws `MarketDataException(ErrorKind, message)`. Retries
transient errors with exponential backoff + jitter. Per-provider parsing
(Alpha Vantage, Twelve Data, Polygon, Finnhub, custom JSON array).

## 7. Backtest engine contract
Signals from bar `i` close execute at bar `i+1` open; SL/TP evaluated intra-bar
against high/low and filled at the trigger price; fees and slippage charged both
sides; long/short symmetric when enabled; open positions closed at the final
close. Pure function: `BacktestEngine.run(...) -> BacktestResult`.

## 8. Security model
Keys only in the OS secure store; HTTPS only; no PII logged; no analytics; all
data local. Input validated at parse boundaries (CSV, provider JSON).

## 9. Risk register
| Risk | Mitigation |
|---|---|
| Look-ahead bias | Next-open execution; causal indicators; explicit test |
| Overstated returns | Fees + slippage both sides; buy-&-hold comparison |
| Bad/partial data | Parser reports skipped rows; validation on import |
| Weak device memory | Charts downsample to ≤600 points; DB queries indexed |
| Sandbox cannot build APK/EXE | CI workflows build both; documented commands |
