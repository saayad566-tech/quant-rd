# KNOWN_ISSUES — Quant RD

## Open

| # | Severity | Issue | Plan |
|---|---|---|---|
| 1 | Low | The **Binance** free source could not be exercised live from the build sandbox — `api.binance.com`, `data-api.binance.vision`, `api.binance.us` and `api.coingecko.com` are all blocked by its egress proxy. | The parser is covered by a unit test built on Binance's documented kline shape, and **Yahoo Finance also serves crypto** (`BTC-USD`), so crypto fetching works regardless. Verify Binance on a device with open network. |
| 2 | Low | The **keyed** provider paths (Alpha Vantage, Twelve Data, Polygon, Finnhub, custom) are implemented to their documented JSON shapes but were not exercised end-to-end — no API key was available. | Error mapping and retry/backoff are structurally covered by tests. The keyless Yahoo path *was* verified against live data. |
| 3 | Low | Web build stores data in memory only (session-scoped). | Web is a demo target; Android/Windows use SQLite. IndexedDB persistence is a future enhancement. |
| 4 | Low | Runtime asset-pack download is IO-only; on web it reports "only available in the Android and Windows builds". | Intended — large packs target the shipping platforms. |
| 5 | Low | The Android APKs are signed with the **debug** key (CI has no release keystore configured). | Fine for direct installation and testing. For Play Store distribution, add the `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` repository secrets; `release.yml` then signs with the release key automatically. |
| 6 | Low | `flutter_secure_storage` on Linux desktop may need a system keyring. | Linux desktop is not a shipping target (Android/Windows only). |

## Closed
- **No data when a symbol was missing** → smart fallback chain (cache → free keyless → keyed) with a helpful error instead of a dead end.
- **Free sources required a key** → added keyless Yahoo Finance and Binance.
- **No strategy install/management UI** → "Install / Import", "Export" and an Active/Disabled toggle.
- **No JSON import** → `JsonCandleParser` for objects, arrays, wrappers, Yahoo and Binance payloads.
- **Android/Windows CI builds failed** (binary assets not committed) → binaries committed as base64.
- **Web CI upload hit the artifact quota** → builds publish to GitHub Releases instead.
- **`release.yml` was invalid** (`secrets` in a step `if:`) → replaced with a shell check.
- Backtest pending-exit ambiguity → loop rewritten.
- Warm-up over-skipping → corrected to count only referenced periods.
- `MetricTile` overflow → made overflow-proof.
- `csv` 8.x API change → parser migrated to the `Csv` codec.
- Timezone-dependent CSV parsing → timestamps normalised to UTC.
- **Local sandbox could not build the APK/EXE** → built in CI; both artifacts now exist.

## Non-issues (by design)
- No live trading / broker execution — research tool by design.
- No cloud sync / accounts — offline-first by design.
- No iOS artifact — no macOS available.
