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
