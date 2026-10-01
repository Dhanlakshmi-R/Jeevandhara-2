"""All-India location gazetteer with real coordinates (State → District → Taluk → Village).

Backed by `data/india_places.db`, generated from GeoNames by
`scripts/build_india_places.py`. Everything is local, so the browse picker
works offline and never burns a provider call.

Why coordinates matter
----------------------
Weather is fetched by lat/lon, so serving "real weather for the place the
user picked" means resolving that place to a point. The previous Census file
had names only -- picking a village fell back to district coordinates and
labelled the result with the village name. Now every listed place carries its
own coordinates.

Precision is reported honestly: `resolve()` returns the administrative level
whose coordinates were used (`village`, `taluk`, `district` or `state`) so
the UI can say "weather for Badami taluk -- nearest data point for X" instead
of implying village precision it does not have.

The router in `routers/places.py` exposes this as `/weather/places/...`.
No weather provider or API key is involved.
"""

from __future__ import annotations

import sqlite3
import threading
import unicodedata
from pathlib import Path

_DATA_DIR = Path(__file__).resolve().parent / "data"
_DB_FILE = _DATA_DIR / "india_places.db"

SCALE = 10_000  # matches the builder: lat/lon stored as lat * 10000


class PlaceLookupError(LookupError):
    """Raised when a name is not in the gazetteer (router maps to 404)."""


def _norm(value: str) -> str:
    """Case/space-insensitive key. Names are already de-accented at build."""
    return " ".join(value.split()).casefold()


def _readable(value: str) -> str:
    """Best-effort cleanup for names typed by hand or sent by an older client."""
    text = unicodedata.normalize("NFKD", value)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return " ".join(text.split())


class _State:
    __slots__ = ("code", "name", "lat", "lon", "districts")

    def __init__(self, code: int, name: str, lat: float, lon: float) -> None:
        self.code = code
        self.name = name
        self.lat = lat
        self.lon = lon
        self.districts: dict[str, _District] = {}


class _District:
    __slots__ = ("a1", "code", "name", "lat", "lon", "taluks")

    def __init__(self, a1: int, code: int, name: str, lat: float, lon: float) -> None:
        self.a1 = a1
        self.code = code
        self.name = name
        self.lat = lat
        self.lon = lon
        self.taluks: dict[str, _Taluk] = {}


class _Taluk:
    __slots__ = ("a1", "a2", "code", "name", "lat", "lon")

    def __init__(
        self, a1: int, a2: int, code: int, name: str, lat: float, lon: float
    ) -> None:
        self.a1 = a1
        self.a2 = a2
        self.code = code
        self.name = name
        self.lat = lat
        self.lon = lon


class Gazetteer:
    """Read-only view over the SQLite gazetteer.

    The admin tables total ~7.7k rows, small enough to hold in memory for
    instant name lookups. Village lists live as blobs and are read on demand,
    with a small LRU so flipping back and forth between taluks stays fast.
    """

    def __init__(self, path: Path = _DB_FILE, village_cache: int = 64) -> None:
        self._path = path
        self._lock = threading.Lock()
        self._village_cache: dict[tuple[int, int, int], list[list]] = {}
        self._village_cache_max = village_cache
        self._conn: sqlite3.Connection | None = None
        self._conn_local = threading.local()
        self._states: dict[str, _State] = {}
        self._load()

    # -- connection -----------------------------------------------------

    def _connection(self) -> sqlite3.Connection:
        conn = getattr(self._conn_local, "conn", None)
        if conn is None:
            if not self._path.exists():
                raise RuntimeError(
                    f"Place gazetteer missing ({self._path}). "
                    "Run: python scripts/build_india_places.py"
                )
            conn = sqlite3.connect(
                f"file:{self._path}?mode=ro", uri=True, check_same_thread=False
            )
            self._conn_local.conn = conn
        return conn

    def _load(self) -> None:
        if not self._path.exists():
            raise RuntimeError(
                f"Place gazetteer missing ({self._path}). "
                "Run: python scripts/build_india_places.py"
            )
        conn = self._connection()
        by_code: dict[int, _State] = {}
        for code, name, lat, lon in conn.execute("SELECT code, name, lat, lon FROM a1"):
            state = _State(code, name, lat, lon)
            by_code[code] = state
            self._states[_norm(name)] = state
            # Some GeoNames names carry a prefix the cleaner missed; index both.
            self._states.setdefault(_norm(name.split(" of ")[-1]), state)

        by_district_code: dict[tuple[int, int], _District] = {}
        for a1, code, name, lat, lon in conn.execute(
            "SELECT a1, code, name, lat, lon FROM a2"
        ):
            state = by_code.get(a1)
            if state is None:
                continue
            district = _District(a1, code, name, lat, lon)
            state.districts[_norm(name)] = district
            by_district_code[(a1, code)] = district

        for a1, a2, code, name, lat, lon in conn.execute(
            "SELECT a1, a2, code, name, lat, lon FROM a3"
        ):
            district = by_district_code.get((a1, a2))
            if district is None:
                continue
            district.taluks[_norm(name)] = _Taluk(a1, a2, code, name, lat, lon)

    # -- lookups --------------------------------------------------------

    def state(self, name: str) -> _State:
        key = _norm(_readable(name))
        found = self._states.get(key)
        if found is None:
            raise PlaceLookupError(f"Unknown state or union territory: {name}")
        return found

    def district(self, state_name: str, name: str) -> _District:
        state = self.state(state_name)
        found = state.districts.get(_norm(_readable(name)))
        if found is None:
            raise PlaceLookupError(f"District {name} not found in {state.name}.")
        return found

    def taluk(self, state_name: str, district_name: str, name: str) -> _Taluk:
        district = self.district(state_name, district_name)
        found = district.taluks.get(_norm(_readable(name)))
        if found is None:
            raise PlaceLookupError(
                f"Taluk {name} not found in {district.name}, {state_name}."
            )
        return found

    # -- listings -------------------------------------------------------

    def list_states(self) -> list[dict[str, object]]:
        seen: dict[int, _State] = {}
        for state in self._states.values():
            seen.setdefault(state.code, state)
        return [
            {
                "name": s.name,
                "code": s.code,
                "lat": s.lat,
                "lon": s.lon,
                # Every state now has districts, so all are browsable.
                "available": True,
                "districts": len(s.districts),
            }
            for s in sorted(seen.values(), key=lambda s: s.name)
        ]

    def list_districts(self, state_name: str) -> list[dict[str, object]]:
        state = self.state(state_name)
        return [
            {
                "name": d.name,
                "lat": d.lat,
                "lon": d.lon,
                "taluks": len(d.taluks),
            }
            for d in sorted(state.districts.values(), key=lambda d: d.name)
        ]

    def list_taluks(self, state_name: str, district_name: str) -> list[dict[str, object]]:
        district = self.district(state_name, district_name)
        return [
            {"name": t.name, "lat": t.lat, "lon": t.lon}
            for t in sorted(district.taluks.values(), key=lambda t: t.name)
        ]

    def list_villages(
        self, state_name: str, district_name: str, taluk_name: str
    ) -> list[dict[str, object]]:
        taluk = self.taluk(state_name, district_name, taluk_name)
        # GeoNames stores settlements in file order; the picker wants them
        # alphabetical, and this list is small enough to sort on read.
        return [
            {"name": name, "lat": lat / SCALE, "lon": lon / SCALE}
            for name, lat, lon in sorted(
                self._villages(taluk.a1, taluk.a2, taluk.code),
                key=lambda row: row[0].casefold(),
            )
        ]

    def _villages(self, a1: int, a2: int, a3: int) -> list[list]:
        key = (a1, a2, a3)
        with self._lock:
            cached = self._village_cache.get(key)
        if cached is not None:
            return cached

        row = self._connection().execute(
            "SELECT villages FROM a3 WHERE a1=? AND a2=? AND code=?", key
        ).fetchone()
        entries: list[list] = []
        if row and row[0]:
            for line in row[0].split("\n"):
                parts = line.split("\t")
                if len(parts) == 3:
                    entries.append([parts[0], int(parts[1]), int(parts[2])])

        with self._lock:
            if len(self._village_cache) >= self._village_cache_max:
                self._village_cache.clear()
            self._village_cache[key] = entries
        return entries

    # -- the part the weather screen actually needs ------------------------

    def resolve(
        self,
        state_name: str,
        district_name: str | None = None,
        taluk_name: str | None = None,
        village_name: str | None = None,
    ) -> dict[str, object]:
        """Coordinates for the most specific level the user supplied.

        The user may stop at any level -- picking a district is a legitimate
        choice and gets that district's coordinates. When a village is
        requested but absent from the gazetteer we fall back to its taluk and
        say so, rather than silently reporting district-level weather under
        the village's name.
        """
        state = self.state(state_name)
        parts: list[str] = [state.name]
        lat, lon = state.lat, state.lon
        level = "state"
        matched = state.name

        district = None
        if district_name:
            district = self.district(state_name, district_name)
            parts.append(district.name)
            lat, lon, level, matched = district.lat, district.lon, "district", district.name

        taluk = None
        if district is not None and taluk_name:
            taluk = self.taluk(state_name, district.name, taluk_name)
            parts.append(taluk.name)
            lat, lon, level, matched = taluk.lat, taluk.lon, "taluk", taluk.name

        if taluk is not None and village_name:
            wanted = _norm(_readable(village_name))
            for name, vlat, vlon in self._villages(taluk.a1, taluk.a2, taluk.code):
                if _norm(name) == wanted:
                    parts.append(name)
                    lat, lon = vlat / SCALE, vlon / SCALE
                    level, matched = "village", name
                    break
            else:
                # Nearest thing we can honestly offer, labelled as such.
                matched = taluk.name

        label = ", ".join(parts)
        return {
            "name": label,
            "label": label,
            "state": state.name,
            "district": district.name if district else None,
            "taluk": taluk.name if taluk else None,
            "village": parts[3] if level == "village" and len(parts) > 3 else None,
            "region": parts[1] if len(parts) > 1 else "",
            "country": "India",
            "lat": lat,
            "lon": lon,
            # `level` is the admin level the coordinates belong to; when it is
            # less specific than the deepest level requested, `fallback` is True.
            "level": level,
            "matched": matched,
            "fallback": level != "village" and bool(village_name),
        }


_GAZETTEER: Gazetteer | None = None


def gazetteer() -> Gazetteer:
    """Lazily built singleton -- import stays cheap, and tests can reset it."""
    global _GAZETTEER
    if _GAZETTEER is None:
        _GAZETTEER = Gazetteer()
    return _GAZETTEER


def is_available() -> bool:
    return _DB_FILE.exists()


def reset() -> None:
    """Drop the cached singleton (tests that build a temp DB)."""
    global _GAZETTEER
    _GAZETTEER = None
