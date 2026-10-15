# Quant RD — assets repository

This is the **second repository** referenced by the app. Large resources (sample
market-data packs, reference datasets) live here so the app binary stays small.
The app downloads only what the user asks for, at runtime, and verifies it.

## Layout

```
manifest.json            # the index the app reads
packs/
  <pack-id>/
    <pack-id>.part-000   # chunked file (GitHub-friendly sizes)
    <pack-id>.part-001
    ...
```

## How it works

1. `manifest.json` lists each pack with its final `sha256`, total `size_bytes`,
   the ordered `chunk_urls`, and the `file_name` to save it as.
2. The app fetches each chunk, concatenates them, verifies the SHA-256 and stores
   the file under the app-support directory for offline use.
3. Chunking keeps every individual file well under hosting size limits and makes
   downloads resumable at the chunk granularity.

## Producing a pack

```bash
python3 chunk_assets.py \
  --input nifty50_1d.csv \
  --id nifty50-1d \
  --name "NIFTY 50 daily" \
  --base-url https://raw.githubusercontent.com/<org>/<assets-repo>/main \
  --chunk-size-mb 8
```

The script writes `packs/<id>/<id>.part-*`, prints the manifest entry, and
prints the full `sha256` of the assembled file. Paste the entry into
`manifest.json`.

## Wiring it into the app

Open **Configs → Assets base URL**, paste this repository's raw/release base URL
(e.g. `https://raw.githubusercontent.com/<org>/<assets-repo>/main`), and press
**Check & download packs**. The app reads `<base-url>/manifest.json`.

## Data licensing

Only ship data you are licensed to redistribute. Prefer public-domain or
openly-licensed sources, and record attribution in the pack's `description`.
