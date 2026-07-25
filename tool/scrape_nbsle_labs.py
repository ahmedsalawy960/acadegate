#!/usr/bin/env python3
"""Offline NBSLE scraper → CSV for AcadeGate lab import.

Usage:
  python tool/scrape_nbsle_labs.py
  python tool/scrape_nbsle_labs.py --max-pages 5 --out seed_data/csv/nbsle_labs.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

BASE = "https://nbsle.scu.eg"
UA = "AcadeGate/1.0 (lab discovery; +https://acadegate.app)"
ROW_RE = re.compile(
    r"<tr>\s*<td>\d+</td>\s*<td>([^<]+)</td>\s*<td>[\s\S]*?</td>\s*"
    r"<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>[\s\S]*?"
    r'href="(https://nbsle\.scu\.eg/device/[^"]+)"',
    re.I,
)
PAGE_RE = re.compile(r"all-devices\?page=(\d+)")
DEVICE_URL_RE = re.compile(r"/device/(\d+)/(\d+)/")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    with urllib.request.urlopen(req, timeout=45) as resp:
        return resp.read().decode("utf-8", errors="replace")


def total_pages() -> int:
    html = fetch(f"{BASE}/all-devices")
    pages = [int(m.group(1)) for m in PAGE_RE.finditer(html)]
    return max(pages) if pages else 1


def parse_page(html: str) -> list[dict]:
    rows = []
    for m in ROW_RE.finditer(html):
        device, lab, uni, faculty, url = (g.strip() for g in m.groups())
        ids = DEVICE_URL_RE.search(url)
        rows.append(
            {
                "device": device,
                "lab": lab,
                "university": uni,
                "faculty": faculty,
                "url": url,
                "lab_id": ids.group(2) if ids else "",
            }
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-pages", type=int, default=None)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("seed_data/csv/nbsle_labs.csv"),
    )
    args = parser.parse_args()

    pages = total_pages()
    if args.max_pages:
        pages = min(pages, args.max_pages)
    print(f"Fetching {pages} pages…")

    devices: list[dict] = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(fetch, f"{BASE}/all-devices?page={p}"): p
            for p in range(1, pages + 1)
        }
        done = 0
        for fut in as_completed(futures):
            page = futures[fut]
            html = fut.result()
            devices.extend(parse_page(html))
            done += 1
            if done % 25 == 0 or done == pages:
                print(f"  {done}/{pages} pages — {len(devices)} devices")
            time.sleep(0.05)

    buckets: dict[str, dict] = {}
    for d in devices:
        key = f"id:{d['lab_id']}" if d["lab_id"] else f"name:{d['lab']}|{d['university']}|{d['faculty']}".lower()
        bucket = buckets.setdefault(
            key,
            {
                "name": d["lab"],
                "university": d["university"],
                "faculty": d["faculty"],
                "equipment": set(),
                "externalId": d["lab_id"],
                "sourceUrl": d["url"],
            },
        )
        bucket["equipment"].add(d["device"])

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "name",
                "university",
                "city",
                "location",
                "labType",
                "faculty",
                "description",
                "equipment",
                "tags",
                "contactEmail",
            ],
        )
        writer.writeheader()
        for b in sorted(buckets.values(), key=lambda x: (x["university"], x["name"])):
            eq = sorted(b["equipment"])[:120]
            writer.writerow(
                {
                    "name": b["name"],
                    "university": b["university"],
                    "city": "",
                    "location": f"{b['faculty']} — {b['university']}",
                    "labType": "university_lab",
                    "faculty": b["faculty"],
                    "description": f"Imported from NBSLE — {b['faculty']} / {b['university']}",
                    "equipment": ";".join(eq),
                    "tags": "NBSLE;مصر",
                    "contactEmail": "",
                }
            )

    print(f"Wrote {len(buckets)} labs → {args.out}")


if __name__ == "__main__":
    main()
