"""Build the all-India place gazetteer from GeoNames.

Why this exists
---------------
Weather is only fetched by latitude/longitude, so "real weather for the
village the user picked" requires real coordinates for that place. The
bundled Census 2011 file (`karnataka_places.json`) has names only -- zero
coordinates -- and covers one state. GeoNames carries coordinates for every
Indian settlement plus every state, district and sub-district, which is what
the browse hierarchy needs.

Output: `app/data/india_places.db` (SQLite, ~16 MB, ~6 MB gzipped).

Design notes
------------
Villages are stored one blob per sub-district rather than one indexed row per
village. A row-per-village design with a b-tree over 558k names came to
66 MB; grouping the names into a single tab/newline-delimited blob per
sub-district stores each name once and cuts that to 16 MB while keeping
sub-district lookups at ~1 ms.

Coordinates are integers scaled by 10_000 (four decimal places, ~11 m
precision -- far finer than a weather grid cell).

Usage
-----
    python scripts/build_india_places.py                # download + build
    python scripts/build_india_places.py --from-file IN.txt
    python scripts/build_india_places.py --out custom.db

Source: https://download.geonames.org/export/dump/IN.zip (15 MB, CC BY 4.0,
no key or registration required).
"""

from __future__ import annotations

import argparse
import io
import os
import re
import sqlite3
import sys
import tempfile
import time
import unicodedata
import urllib.request
import zipfile
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

GEONAMES_URL = "https://download.geonames.org/export/dump/IN.zip"
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "app" / "data" / "india_places.db"

# Populated-place feature codes (cities, towns, villages, suburbs, hamlets...).
PLACE_CODES = {
    "PPL", "PPLA", "PPLA2", "PPLA3", "PPLA4", "PPLA5",
    "PPLL", "PPLX", "PPLQ", "PPLF", "PPLR", "PPLS", "PPLC", "PPLW",
}

SCALE = 10_000  # lat/lon stored as int(lat * 10000)

_PREFIXES = re.compile(
    r"^(state|union territory|national capital territory|territory) of\s+", re.I
)

SCHEMA = """
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;

CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- States & union territories.
CREATE TABLE a1 (
    code INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    lat  REAL NOT NULL,
    lon  REAL NOT NULL
);

-- Districts. `places` holds settlements that belong to a district but carry
-- no sub-district of their own.
CREATE TABLE a2 (
    a1     INTEGER NOT NULL,
    code   INTEGER NOT NULL,
    name   TEXT    NOT NULL,
    lat    REAL    NOT NULL,
    lon    REAL    NOT NULL,
    places BLOB,
    PRIMARY KEY (a1, code)
);

-- Sub-districts (taluks / mandals / tehsils). `villages` holds the
-- settlements inside each one.
CREATE TABLE a3 (
    a1       INTEGER NOT NULL,
    a2       INTEGER NOT NULL,
    code     INTEGER NOT NULL,
    name     TEXT    NOT NULL,
    lat      REAL    NOT NULL,
    lon      REAL    NOT NULL,
    villages BLOB,
    PRIMARY KEY (a1, a2, code)
);

CREATE INDEX ix_a2_name ON a2 (a1, name);
CREATE INDEX ix_a3_name ON a3 (a1, a2, name);
"""


def clean_name(raw: str, *, strip_suffix: str | None = None) -> str:
    """Display name: de-accent, drop GeoNames' legal prefixes and suffixes.

    "State of Karnātake" -> "Karnataka", "Badami Taluk" -> "Badami".
    """
    text = unicodedata.normalize("NFKD", raw)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = _PREFIXES.sub("", text).strip()
    if strip_suffix and text.lower().endswith(strip_suffix.lower()):
        text = text[: -len(strip_suffix)].strip()
    return " ".join(text.split())


def code_of(value: str | None) -> int | None:
    """GeoNames admin codes are numeric; blanks become None."""
    value = (value or "").strip()
    return int(value) if value.lstrip("-").isdigit() else None


def download(dest_dir: Path) -> Path:
    """Fetch and extract IN.zip, returning the path to IN.txt."""
    archive = dest_dir / "IN.zip"
    target = dest_dir / "IN.txt"
    if target.exists():
        print(f"reusing {target}")
        return target
    print(f"downloading {GEONAMES_URL} ...")
    with urllib.request.urlopen(GEONAMES_URL, timeout=120) as response:
        blob = response.read()
    archive.write_bytes(blob)
    print(f"  {len(blob) / 1024 / 1024:.1f} MB")
    with zipfile.ZipFile(archive) as zf:
        zf.extract("IN.txt", dest_dir)
    return target


def read_rows(path: Path):
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 15:
                yield parts


def build(source: Path, out: Path) -> None:
    started = time.time()
    out.parent.mkdir(parents=True, exist_ok=True)
    for suffix in ("", "-wal", "-shm"):
        stale = Path(str(out) + suffix)
        if stale.exists():
            stale.unlink()

    db = sqlite3.connect(out)
    db.executescript(SCHEMA)

    a1: set[int] = set()
    a2: set[tuple[int, int]] = set()
    a3: set[tuple[int, int, int]] = set()

    for r in read_rows(source):
        if r[6] != "A":
            continue
        feature = r[7]
        if feature == "ADM1":
            c = code_of(r[10])
            if c is not None:
                a1.add(c)
                db.execute(
                    "INSERT OR REPLACE INTO a1 VALUES (?,?,?,?)",
                    (c, clean_name(r[1]), float(r[4]), float(r[5])),
                )
    db.commit()
    print(f"states/UTs      : {len(a1)}")

    for r in read_rows(source):
        if r[6] != "A" or r[7] != "ADM2":
            continue
        parent, c = code_of(r[10]), code_of(r[11])
        if parent in a1 and c is not None:
            a2.add((parent, c))
            db.execute(
                "INSERT OR REPLACE INTO a2 VALUES (?,?,?,?,?,NULL)",
                (parent, c, clean_name(r[1]), float(r[4]), float(r[5])),
            )
    db.commit()
    print(f"districts       : {len(a2)}")

    for r in read_rows(source):
        if r[6] != "A" or r[7] != "ADM3":
            continue
        s, d, c = code_of(r[10]), code_of(r[11]), code_of(r[12])
        if s in a1 and (s, d) in a2 and c is not None:
            a3.add((s, d, c))
            db.execute(
                "INSERT OR REPLACE INTO a3 VALUES (?,?,?,?,?,?,NULL)",
                (s, d, c, clean_name(r[1], strip_suffix=" Taluk"), float(r[4]), float(r[5])),
            )
    db.commit()
    print(f"sub-districts   : {len(a3)}")

    by_a3: dict[tuple[int, int, int], list[str]] = {}
    by_a2: dict[tuple[int, int], list[str]] = {}
    orphan = 0
    for r in read_rows(source):
        if r[6] != "P" or r[7] not in PLACE_CODES:
            continue
        try:
            lat = int(round(float(r[4]) * SCALE))
            lon = int(round(float(r[5]) * SCALE))
        except ValueError:
            continue
        entry = f"{clean_name(r[1])}\t{lat}\t{lon}"
        s, d, c = code_of(r[10]), code_of(r[11]), code_of(r[12])
        if (s, d, c) in a3:
            by_a3.setdefault((s, d, c), []).append(entry)
        elif (s, d) in a2:
            by_a2.setdefault((s, d), []).append(entry)
        else:
            orphan += 1

    db.executemany(
        "UPDATE a3 SET villages = ? WHERE a1 = ? AND a2 = ? AND code = ?",
        [("\n".join(v), k[0], k[1], k[2]) for k, v in by_a3.items()],
    )
    db.executemany(
        "UPDATE a2 SET places = ? WHERE a1 = ? AND code = ?",
        [("\n".join(v), k[0], k[1]) for k, v in by_a2.items()],
    )
    print(f"settlements     : {sum(len(v) for v in by_a3.values()):,} under a sub-district")
    print(f"                  {sum(len(v) for v in by_a2.values()):,} district-only, {orphan:,} unlinked (dropped)")

    db.executemany(
        "INSERT OR REPLACE INTO meta VALUES (?,?)",
        [
            ("source", "GeoNames IN (https://download.geonames.org/export/dump/IN.zip)"),
            ("license", "CC BY 4.0"),
            ("built", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())),
            ("states", str(len(a1))),
            ("districts", str(len(a2))),
            ("subdistricts", str(len(a3))),
        ],
    )
    db.commit()
    db.execute("VACUUM")
    db.close()

    size = out.stat().st_size
    print(f"\nwrote {out}")
    print(f"  {size / 1024 / 1024:.1f} MB in {time.time() - started:.1f}s")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-file", type=Path, help="use a local IN.txt instead of downloading")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"output path (default {DEFAULT_OUT})")
    args = parser.parse_args()

    source = args.from_file
    if source is None:
        with tempfile.TemporaryDirectory() as tmp:
            source = download(Path(tmp))
            build(source, args.out)
    else:
        build(source, args.out)


if __name__ == "__main__":
    main()
