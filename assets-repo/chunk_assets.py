#!/usr/bin/env python3
"""Chunk a large data file for the Quant RD runtime asset-pack downloader.

Splits an input file into fixed-size chunks, writes them under
``packs/<id>/``, and prints the ``manifest.json`` entry (including the SHA-256
of the *assembled* file) that the app expects.

Usage:
    python3 chunk_assets.py --input data.csv --id nifty50-1d \
        --name "NIFTY 50 daily" \
        --base-url https://raw.githubusercontent.com/ORG/quant-rd-assets/main \
        --chunk-size-mb 8
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Chunk a file for runtime asset packs.")
    parser.add_argument("--input", required=True, help="Path to the file to chunk")
    parser.add_argument("--id", required=True, help="Pack id (e.g. nifty50-1d)")
    parser.add_argument("--name", required=True, help="Human-readable pack name")
    parser.add_argument("--base-url", required=True, help="Base URL where chunks will be hosted")
    parser.add_argument("--version", default="1.0.0", help="Pack version")
    parser.add_argument("--description", default="", help="Pack description")
    parser.add_argument("--category", default="data", help="Pack category")
    parser.add_argument("--chunk-size-mb", type=int, default=8, help="Chunk size in MB")
    parser.add_argument("--out", default=".", help="Output directory (default: current)")
    args = parser.parse_args()

    chunk_bytes = args.chunk_size_mb * 1024 * 1024
    total = os.path.getsize(args.input)
    chunk_count = max(1, math.ceil(total / chunk_bytes))

    pack_dir = os.path.join(args.out, "packs", args.id)
    os.makedirs(pack_dir, exist_ok=True)

    base = args.base_url.rstrip("/")
    chunk_urls = []
    with open(args.input, "rb") as fh:
        for i in range(chunk_count):
            data = fh.read(chunk_bytes)
            part_name = f"{args.id}.part-{i:03d}"
            with open(os.path.join(pack_dir, part_name), "wb") as out:
                out.write(data)
            chunk_urls.append(f"{base}/packs/{args.id}/{part_name}")

    entry = {
        "id": args.id,
        "name": args.name,
        "description": args.description,
        "version": args.version,
        "category": args.category,
        "size_bytes": total,
        "sha256": sha256_of(args.input),
        "chunk_urls": chunk_urls,
        "file_name": os.path.basename(args.input),
    }
    print(f"Wrote {chunk_count} chunk(s) to {pack_dir}")
    print("Manifest entry:")
    print(json.dumps(entry, indent=2))


if __name__ == "__main__":
    main()
