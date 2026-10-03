"""Shared plumbing for market data sources.

Three things every source needs and that are easy to get subtly wrong:

1. A **TTL cache** so a request never waits on a slow upstream. Mirrors
   ``weather_service.TtlCache``.
2. A **circuit breaker** so a source that is down is not retried on every
   single request. After ``failure_threshold`` consecutive failures the
   breaker opens for ``recovery_seconds`` and calls fail fast with a clear
   reason instead of adding a timeout to every user request.
3. **Stale-on-error**. The whole point of this module is honesty: if a refresh
   fails we return the last known value flagged ``stale=True`` with the time it
   was actually fetched. We never return a number and hide that it is old.

Sources also carry a declared :class:`SourceStatus` so ``/market/status`` can
report which feeds are live without any source having to be asked at runtime.
"""

from __future__ import annotations

import logging
import os
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger("jeevandhara.market")

# .../market/sources/base.py -> .../market/data_sources.yaml
_CONFIG_PATH = str(Path(__file__).resolve().parent.parent / "data_sources.yaml")


def _load_config() -> dict[str, Any]:
    with open(_CONFIG_PATH, encoding="utf-8") as handle:
        return yaml.safe_load(handle)


CONFIG = _load_config()
CACHE_TTL: dict[str, int] = CONFIG["cache_ttl"]
SOURCES: dict[str, dict[str, Any]] = CONFIG["sources"]
PRICE_CHAIN: list[str] = CONFIG["price_chain"]
ARRIVAL_CHAIN: list[str] = CONFIG["arrival_chain"]


class TtlCache:
    """Thread-safe TTL cache with simple capacity eviction.

    Unlike ``weather_service.TtlCache`` this one can hand back an *expired*
    value, because a stale price with an honest timestamp is more useful to a
    farmer than an error page.
    """

    def __init__(self, ttl: float, max_items: int = 500) -> None:
        self._ttl = ttl
        self._max = max_items
        self._data: dict[str, tuple[float, Any]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> tuple[Any, bool] | None:
        """Return ``(value, is_fresh)``. ``None`` only when never cached."""
        with self._lock:
            item = self._data.get(key)
            if item is None:
                return None
            expires_at, value = item
            return value, time.monotonic() <= expires_at

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            if len(self._data) >= self._max and key not in self._data:
                oldest = min(self._data, key=lambda k: self._data[k][0])
                self._data.pop(oldest, None)
            self._data[key] = (time.monotonic() + self._ttl, value)


@dataclass
class CircuitBreaker:
    """Trips after consecutive failures so a dead upstream costs nothing.

    ``half_open`` lets exactly one probe through after ``recovery_seconds``; if
    it succeeds the breaker closes again.
    """

    failure_threshold: int = 3
    recovery_seconds: float = 300.0
    failures: int = 0
    opened_at: float | None = None
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    @property
    def is_open(self) -> bool:
        with self._lock:
            if self.opened_at is None:
                return False
            if time.monotonic() - self.opened_at >= self.recovery_seconds:
                # Half-open: allow one probe.
                return False
            return True

    def record_success(self) -> None:
        with self._lock:
            self.failures = 0
            self.opened_at = None

    def record_failure(self) -> None:
        with self._lock:
            self.failures += 1
            if self.failures >= self.failure_threshold:
                self.opened_at = time.monotonic()
                logger.warning(
                    "market circuit breaker opened after %s failures", self.failures
                )

    def state(self) -> str:
        if self.opened_at is None:
            return "closed"
        if time.monotonic() - self.opened_at >= self.recovery_seconds:
            return "half_open"
        return "open"


class SourceUnavailable(RuntimeError):
    """A source could not serve the request.

    Carries the source name and a human reason so the API can distinguish
    "no key configured" from "upstream is down" from "this source never published
    traded quantity" - three very different things to tell a user.
    """

    def __init__(self, source: str, reason: str, *, kind: str = "error") -> None:
        super().__init__(f"{source}: {reason}")
        self.source = source
        self.reason = reason
        self.kind = kind


@dataclass
class SourceStatus:
    """Declared + observed health of one source, for ``/market/status``."""

    name: str
    enabled: bool
    verified: bool
    confidence: str
    attribution: str
    provides_arrivals: bool = False
    provides_traded_quantity: bool = False
    provides_trade_count: bool = False
    dev_only: bool = False
    last_success_at: datetime | None = None
    last_error: str | None = None
    breaker_state: str = "closed"

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "enabled": self.enabled,
            "verified": self.verified,
            "confidence": self.confidence,
            "attribution": self.attribution,
            "provides_arrivals": self.provides_arrivals,
            "provides_traded_quantity": self.provides_traded_quantity,
            "provides_trade_count": self.provides_trade_count,
            "dev_only": self.dev_only,
            "last_success_at": _iso(self.last_success_at),
            "last_error": self.last_error,
            "breaker_state": self.breaker_state,
        }


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class MarketSource:
    """Base class for a price/arrival provider.

    Subclasses implement :meth:`_fetch` and inherit caching, the breaker and
    the stale-on-error behaviour, so no source can accidentally skip them.
    """

    #: Key into ``data_sources.yaml``.
    name: str = ""
    #: ``price`` or ``arrival`` - decides which chain the source is eligible for.
    kind: str = "price"

    def __init__(self) -> None:
        self.config: dict[str, Any] = SOURCES.get(self.name, {})
        self.breaker = CircuitBreaker()
        self.last_success_at: datetime | None = None
        self.last_error: str | None = None
        self._cache = TtlCache(self.cache_ttl)
        self._last_call_at: float | None = None

    # -------------------------------------------------------------- config

    @property
    def enabled(self) -> bool:
        """Config flag, production guard and API key gate, in that order.

        A source with no ``requires_key`` is enabled purely on its config flag -
        ``requires_key: null`` means "this feed needs no credentials", not
        "this feed is disabled".
        """
        if not self.config.get("enabled"):
            return False
        # dev_only sources are excluded when APP_ENV is production.
        if self.config.get("dev_only") and app_env() == "production":
            return False
        key = self.config.get("requires_key")
        if key and not self.has_key(str(key)):
            return False
        return True

    @property
    def missing_key(self) -> str | None:
        """The env var that is blocking this source, if any."""
        key = self.config.get("requires_key")
        if key and not self.has_key(str(key)):
            return str(key)
        return None

    @property
    def verified(self) -> bool:
        return bool(self.config.get("verified"))

    @property
    def confidence(self) -> str:
        return str(self.config.get("confidence", "unknown"))

    @property
    def attribution(self) -> str:
        return str(self.config.get("attribution", "Unknown source"))

    @property
    def cache_ttl(self) -> float:
        bucket = "arrivals" if self.kind == "arrival" else "prices"
        return float(CACHE_TTL.get(bucket, 900))

    @property
    def provides_arrivals(self) -> bool:
        return bool(self.config.get("provides_arrivals"))

    @property
    def provides_traded_quantity(self) -> bool:
        return bool(self.config.get("provides_traded_quantity"))

    @property
    def provides_trade_count(self) -> bool:
        return bool(self.config.get("provides_trade_count"))

    @staticmethod
    def has_key(name: str) -> bool:
        return bool(os.getenv(name, "").strip())

    @property
    def timeout(self) -> float:
        return float(self.config.get("timeout_seconds", 15))

    @property
    def min_interval(self) -> float:
        """Floor on how often we may call this source at all."""
        return float(self.config.get("min_interval_seconds", 0) or 0)

    def rate_limit_ok(self) -> bool:
        if not self.min_interval or self._last_call_at is None:
            return True
        return (time.monotonic() - self._last_call_at) >= self.min_interval

    # --------------------------------------------------------- public API

    def fetch(self, **params: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        """Cached, breaker-guarded fetch.

        Returns ``(rows, meta)``. ``meta`` always carries ``source``,
        ``fetched_at``, ``stale`` and ``attribution`` so a caller cannot
        accidentally present these numbers as anything else.
        """
        cache_key = self.cache_key(**params)
        cached = self._cache.get(cache_key)
        if cached is not None:
            rows, is_fresh = cached
            if is_fresh:
                return rows, self._meta(stale=False, fetched_at=self._cached_at(cache_key))
            # Expired: try to refresh, but keep the stale copy as a floor.
            if self.breaker.is_open or not self.rate_limit_ok():
                return rows, self._meta(
                    stale=True,
                    fetched_at=self._cached_at(cache_key),
                    note="refresh deferred" if self.breaker.is_open else "rate limited",
                )
        else:
            rows = None

        if not self.rate_limit_ok():
            if rows is not None:
                return rows, self._meta(stale=True, fetched_at=self._cached_at(cache_key))
            raise SourceUnavailable(
                self.name, "minimum interval not elapsed", kind="rate_limited"
            )

        try:
            self._last_call_at = time.monotonic()
            fresh_rows = self._fetch(**params)
        except SourceUnavailable:
            self.breaker.record_failure()
            self.last_error = "source unavailable"
            if rows is not None:
                return rows, self._meta(
                    stale=True,
                    fetched_at=self._cached_at(cache_key),
                    note="upstream failed; showing last known values",
                )
            raise
        except Exception as exc:  # noqa: BLE001 - normalised below
            self.breaker.record_failure()
            self.last_error = str(exc)[:300]
            logger.warning("market source %s failed: %s", self.name, exc)
            if rows is not None:
                return rows, self._meta(
                    stale=True,
                    fetched_at=self._cached_at(cache_key),
                    note="upstream failed; showing last known values",
                )
            raise SourceUnavailable(self.name, str(exc)[:300]) from exc

        self.breaker.record_success()
        self.last_success_at = utcnow()
        self.last_error = None
        self._cache.set(cache_key, fresh_rows)
        self._cache.set(cache_key + "::at", self.last_success_at)
        return fresh_rows, self._meta(stale=False, fetched_at=self.last_success_at)

    def cache_key(self, **params: Any) -> str:
        parts = [f"{k}={params[k]}" for k in sorted(params) if params[k] not in (None, "")]
        return f"{self.name}:" + "|".join(parts)

    def _cached_at(self, cache_key: str) -> datetime | None:
        hit = self._cache.get(cache_key + "::at")
        return hit[0] if hit else None

    def _meta(
        self,
        *,
        stale: bool,
        fetched_at: datetime | None,
        note: str | None = None,
    ) -> dict[str, Any]:
        return {
            "source": self.name,
            "confidence": self.confidence,
            "verified": self.verified,
            "attribution": self.attribution,
            "fetched_at": _iso(fetched_at),
            "stale": stale,
            "note": note,
        }

    def status(self) -> SourceStatus:
        return SourceStatus(
            name=self.name,
            enabled=self.enabled,
            verified=self.verified,
            confidence=self.confidence,
            attribution=self.attribution,
            provides_arrivals=self.provides_arrivals,
            provides_traded_quantity=self.provides_traded_quantity,
            provides_trade_count=self.provides_trade_count,
            dev_only=bool(self.config.get("dev_only")),
            last_success_at=self.last_success_at,
            last_error=self.last_error,
            breaker_state=self.breaker.state(),
        )

    # ------------------------------------------------------ to implement

    def _fetch(self, **params: Any) -> list[dict[str, Any]]:
        raise NotImplementedError

    # ------------------------------------------------------------ helpers

    def _request_json(
        self, url: str, *, data: dict[str, Any] | None = None, params: dict | None = None
    ) -> Any:
        """HTTP helper that raises :class:`SourceUnavailable` on any failure."""
        import json
        import urllib.error
        import urllib.parse
        import urllib.request

        body = None
        if data is not None:
            body = urllib.parse.urlencode(data).encode()
        elif params is not None:
            url = f"{url}?{urllib.parse.urlencode(params)}"

        request = urllib.request.Request(
            url,
            data=body,
            headers={
                "Accept": "application/json",
                "User-Agent": "Jeevandhara/1.0 (+market-data)",
                "X-Requested-With": "XMLHttpRequest",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:200]
            raise SourceUnavailable(
                self.name, f"HTTP {exc.code}: {detail or 'empty body'}", kind="http_error"
            ) from exc
        except urllib.error.URLError as exc:
            raise SourceUnavailable(self.name, f"network: {exc.reason}", kind="network") from exc

        if not raw.strip():
            raise SourceUnavailable(self.name, "empty response body", kind="empty")
        try:
            return json.loads(raw)
        except ValueError as exc:
            raise SourceUnavailable(
                self.name, "invalid JSON", kind="bad_payload"
            ) from exc


def app_env() -> str:
    return os.getenv("APP_ENV", "development").strip().lower()


def to_float(value: Any) -> float | None:
    """Parse a number out of a messy upstream value, or return None.

    Upstream price feeds send ``"3,000"``, ``"₹3000"``, ``""``, ``"NA"`` and
    numbers in the same column. Anything unparseable becomes None rather than a
    silent zero, because a fabricated 0 in a price table is exactly the failure
    this whole module exists to prevent.
    """
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text or text.lower() in {"na", "n/a", "-", "--", "null", "none"}:
        return None
    cleaned = text.replace(",", "").replace("₹", "").replace("Rs.", "").replace("Rs", "")
    cleaned = cleaned.replace(" ", "").strip()
    try:
        return float(cleaned)
    except ValueError:
        return None