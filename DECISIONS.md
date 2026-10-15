# DECISIONS — Quant RD

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | Flutter for both Android and Windows | One codebase → two native binaries, premium custom UI | Electron+Capacitor (two build systems); Kotlin-only (no Windows) |
| 2 | Riverpod 3.x with `Notifier` / `FutureProvider` | Stable 3.x surface; testable; no codegen | `StateProvider` (moved to legacy); Provider (less composable) |
| 3 | `sqflite` + `sqflite_common_ffi` behind an interface | Real SQLite on device; web falls back to in-memory | Drift/Isar (codegen overhead); file-only store (weaker queries) |
| 4 | Execute signals on the **next bar's open** | Removes look-ahead bias; honest results | Same-bar close fills (optimistic, misleading) |
| 5 | Fees + slippage charged on both sides | Realistic P&L | Zero-cost fills (overstates returns) |
| 6 | `flutter_secure_storage` for API keys | OS Keystore / DPAPI; web supported | Plain SQLite/prefs (insecure) |
| 7 | `fl_chart` 1.x for charts | Mature, MIT, customisable | Custom painters (more work, more risk) |
| 8 | CSV parsed with `csv` 8.x `Csv` codec | Current API; delimiter auto-detect | Hand-rolled parser (fragile) |
| 9 | Asset packs chunked + SHA-256 in a separate repo | Keeps app binary small; matches the requested split-repo strategy | Bundling all data (large binary) |
| 10 | Timezone-less CSV timestamps treated as UTC | Deterministic results regardless of device timezone | Local-time interpretation (non-reproducible) |
| 11 | Synthetic sample data labelled as such | App usable offline instantly; honest labelling | No sample (empty first-run experience) |
| 12 | No telemetry, no backend | Privacy + offline-first + zero cost | Cloud analytics (privacy + cost) |
| 13 | Workspaces (project isolation) as a first-class concept | The protocol requires independent projects to be strictly separated; research tools need it | Single global pool (leaks unrelated research) |
| 14 | Built-ins are global templates (`workspace_id = ''`) | Available everywhere without duplication; deletion-protected | Per-workspace copies (duplication, drift) |
| 15 | Backdrop blur is opt-in, not default | A blur re-samples the backdrop every frame — the main cause of scroll jank | Blur on every card (pretty, slow) |
| 16 | Activity log persisted in the settings table | Survives restarts without a new table; small and simple | Separate log table / external file |
| 17 | CSV export writes to disk **and** copies to clipboard | Works on every platform, including web which has no filesystem | Disk-only (breaks web) |
| 18 | Deliver CI artifacts via GitHub Releases, not Actions artifacts | Releases are not subject to the artifact storage quota | Actions artifacts (quota-limited) |
| 19 | Keyless free sources (Yahoo Finance, Binance) as first-class providers | The brief demands zero-cost auto-fetch with no sign-up; a key requirement is the main reason data "fails" | Key-only providers (blocks first-run users) |
| 20 | Fallback order: cache → free keyless → keyed | Fastest and cheapest first; offline works out of the box | Provider-first (slower, costs quota, fails offline) |
| 21 | Every fetched dataset is persisted before returning | Makes the next backtest instant and offline | In-memory only (re-fetch every time) |
| 22 | Shared `CandleParseReport` with `typedef CsvParseReport` | One report type for CSV and JSON without churning call sites | Duplicate report classes |
| 23 | Strategy `enabled` flag in a v3 column migration | "Active status" needs durable, queryable state | Storing disabled ids in settings (opaque, no migration path) |
| 24 | Tolerant strategy import (fills defaults for missing keys) | Hand-written or third-party JSON should not be rejected outright | Strict parsing (rejects most real-world input) |
