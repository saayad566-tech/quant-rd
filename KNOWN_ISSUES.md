# KNOWN_ISSUES — Quant RD

## Open

| # | Severity | Issue | Plan |
|---|---|---|---|
| 1 | Medium | Live provider fetch paths (Alpha Vantage, Twelve Data, Polygon, Finnhub, custom) were implemented against their documented JSON shapes but **could not be exercised end-to-end** here because no API key is available in the sandbox. | First run with a real key on a real device will confirm; the error mapping and retry logic are unit-covered structurally. Documented in-app. |
| 2 | Low | Web build stores data in memory only (session-scoped). | Web is a demo target; Android/Windows use SQLite. Persisting web data (IndexedDB) is a future enhancement. |
| 3 | Low | Runtime asset-pack download is IO-only; on web it reports "only available in the Android and Windows builds". | Intended — large packs target the shipping platforms. |
| 4 | Low | `flutter_secure_storage` on Linux desktop may need a system keyring. | Linux desktop is not a shipping target (Android/Windows only). |

## Closed
- Backtest pending-exit ambiguity → loop rewritten.
- Warm-up over-skipping → corrected to count only referenced periods.
- `MetricTile` overflow → made overflow-proof; grid aspect relaxed.
- `csv` 8.x API change → parser migrated to `Csv` codec.
- Timezone-dependent CSV parsing → timestamps normalised to UTC.

## Non-issues (by design)
- No live trading / broker execution — research tool by design.
- No cloud sync / accounts — offline-first by design.
- No iOS artifact — no macOS available.
