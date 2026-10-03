"""Community mandi feed (mandi-api.onrender.com) - DEV-ONLY FALLBACK.

The only source in the registry whose payload has actually been seen and
parsed, which makes it the only one that can serve the Karnataka/onion vertical
slice during development. It is also the least trustworthy: community
contributed, unofficial, and the newest row observed was 7 days behind the
server's own clock.

That combination is why it is ``dev_only``. Two guards keep it from leaking
into production:

* :meth:`enabled` returns False when ``APP_ENV=production`` (checked in the
  base class via ``dev_only``).
* :meth:`fetch` is not overridden for that case - it does not exist - so the
  only way to get its numbers in production is to remove the ``dev_only`` flag
  from the config deliberately.

Staleness is surfaced, not hidden. The measured lag is in the config
(``typical_lag_days``) and every response carries ``stale: true`` plus the real
``fetched_at``, so the UI has to label it.
"""

from __future__ import annotations

from typing import Any

from .base import MarketSource, SourceUnavailable, to_float
from ..normalizer import canonical_commodity, normalize_market, normalize_state

#: The feed ignores ``limit``; this is what the server actually returns.
OBSERVED_PAGE_SIZE = 200

#: ``date=LATEST`` returns roughly the last 30 days per market, not a single day.
LATEST_SENTINEL = "LATEST"


class MandiApiSource(MarketSource):
    """Unofficial mandi prices. Verified live, low confidence, dev only."""

    name = "mandi_api"
    kind = "price"

    def __init__(self) -> None:
        super().__init__()
        self._base_url = str(self.config.get("base_url") or "https://mandi-api.onrender.com").rstrip("/")
        self._fields: dict[str, str] = dict(self.config.get("fields") or {})
        self.typical_lag_days: int = int(self.config.get("typical_lag_days") or 0)

    @property
    def ignores_limit(self) -> bool:
        return bool(self.config.get("ignores_limit_param"))

    def endpoint(self, key: str) -> str:
        path = (self.config.get("endpoints") or {}).get(key)
        if not path:
            raise SourceUnavailable(self.name, f"no endpoint configured for '{key}'")
        return f"{self._base_url}{path if path.startswith('/') else '/' + path}"

    def states(self) -> list[str]:
        """Supported states. Small and trustworthy: this one really is a list."""
        payload = self._request_json(self.endpoint("states"))
        rows = self._extract_payload(payload)
        return [str(r) for r in rows if isinstance(r, str)]

    def markets(self, state: str | None = None) -> list[dict[str, Any]]:
        """Mandi list with district, for the market picker."""
        payload = self._request_json(
            self.endpoint("markets"), params={"state": state} if state else None
        )
        out: list[dict[str, Any]] = []
        for row in self._extract_payload(payload):
            if not isinstance(row, dict):
                continue
            market = normalize_market(row.get("market"))
            if market:
                out.append(
                    {
                        "market": market,
                        "upstream_name": row.get("market"),
                        "district": row.get("district"),
                        "state": state,
                    }
                )
        return sorted(out, key=lambda r: (r["district"] or "", r["market"]))

    def history(
        self, state: str, commodity: str, days: int = 90
    ) -> list[dict[str, Any]]:
        """Daily average modal/min/max price series for one state+commodity.

        This is the series the price-momentum demand component and the Flutter
        sparkline both need, and it is the only feed we have that provides it.
        """
        payload = self._request_json(
            self.endpoint("history"),
            params={"state": state, "commodity": commodity, "days": days},
        )
        out: list[dict[str, Any]] = []
        for row in self._extract_payload(payload):
            if not isinstance(row, dict):
                continue
            day = row.get("arrival_date")
            modal = to_float(row.get("avg_modal_price"))
            if not day or modal is None:
                continue
            out.append(
                {
                    "date": day,
                    "modal_price": modal,
                    "min_price": to_float(row.get("avg_min_price")),
                    "max_price": to_float(row.get("avg_max_price")),
                    "data_points": to_float(row.get("data_points")),
                    "commodity": canonical_commodity(commodity),
                    "state": state,
                }
            )
        return sorted(out, key=lambda r: r["date"])

    def health(self) -> dict[str, Any]:
        try:
            payload = self._request_json(f"{self._base_url}/health")
        except SourceUnavailable as exc:
            return {
                "source": self.name,
                "ok": False,
                "enabled": self.enabled,
                "reason": exc.reason,
                "kind": exc.kind,
            }
        return {
            "source": self.name,
            "ok": True,
            "enabled": self.enabled,
            "reason": "healthy",
            "upstream": payload if isinstance(payload, dict) else None,
        }

    def _fetch(
        self,
        commodity: str | None = None,
        state: str | None = None,
        district: str | None = None,
        market: str | None = None,
        date: str | None = None,
        limit: int = OBSERVED_PAGE_SIZE,
    ) -> list[dict[str, Any]]:
        # ``limit`` is accepted for API symmetry with the other clients but not
        # sent, because the server ignores it. Filtering therefore has to happen
        # locally or a narrow query would silently return 200 unrelated rows.
        # HTTP 400 MISSING_PARAM without at least one of these, so a vague
        # "show me everything" request cannot be served by this feed at all.
        if not commodity and not state:
            raise SourceUnavailable(
                self.name,
                "requires state or commodity; this feed serves no unfiltered query",
                kind="bad_request",
            )

        query: dict[str, Any] = {}
        for key, value in (
            ("commodity", commodity),
            ("state", state),
            ("district", district),
            ("market", market),
            ("arrival_date", date),
        ):
            if value:
                query[key] = value

        payload = self._request_json(self.endpoint("prices"), params=query)
        records = self._extract_records(payload)
        if not records:
            raise SourceUnavailable(self.name, "no rows returned", kind="empty")

        rows = [mapped for mapped in (self._map_record(r) for r in records) if mapped]
        rows = self._filter(rows, commodity=commodity, state=state, district=district, market=market)

        if not rows:
            raise SourceUnavailable(self.name, "no rows matched the filter", kind="empty")
        return rows[:limit]

    @staticmethod
    def _extract_payload(payload: Any) -> list[Any]:
        """Unwrap the ``{"success": true, "data": [...]}`` envelope.

        An explicit ``success: false`` is treated as no data rather than a
        silently empty list, so the caller can fall through to the next source.
        """
        if isinstance(payload, list):
            return payload
        if isinstance(payload, dict):
            if payload.get("success") is False:
                error = payload.get("error") or {}
                raise SourceUnavailable(
                    "mandi_api",
                    f"{error.get('code', 'error')}: {error.get('message', 'request rejected')}"[:200],
                    kind="rejected",
                )
            for key in ("data", "prices", "records"):
                inner = payload.get(key)
                if isinstance(inner, list):
                    return inner
        return []

    def _extract_records(self, payload: Any) -> list[dict[str, Any]]:
        return [r for r in self._extract_payload(payload) if isinstance(r, dict)]

    def _map_record(self, record: dict[str, Any]) -> dict[str, Any] | None:
        f = self._fields
        low = to_float(record.get(f["min_price"]))
        modal = to_float(record.get(f["modal_price"]))
        high = to_float(record.get(f["max_price"]))
        if modal is None and low is None and high is None:
            return None
        return {
            "commodity": canonical_commodity(record.get(f["commodity"])),
            "variety": record.get(f.get("variety", "")) or None,
            "grade": record.get(f.get("grade", "")) or None,
            "state": normalize_state(record.get(f["state"])),
            "district": record.get(f.get("district", "")) or None,
            "market": normalize_market(record.get(f["market"])),
            "date": record.get(f.get("arrival_date", "")) or None,
            "min_price": low,
            "modal_price": modal,
            "max_price": high,
            "unit": None,
            "arrival_quantity": None,
            "upstream_id": record.get(f.get("upstream_id", "")),
            "upstream_fetched_at": record.get(f.get("fetched_at", "")) or None,
            "source": self.name,
        }

    @staticmethod
    def _filter(
        rows: list[dict[str, Any]],
        *,
        commodity: str | None,
        state: str | None,
        district: str | None,
        market: str | None,
    ) -> list[dict[str, Any]]:
        """Local filtering, because the server ignores every filter we send.

        Compared case-insensitively on the canonicalised values. A date filter is
        deliberately not applied here: ``LATEST`` already means a 30-day window
        and callers get to decide how to interpret that.
        """
        wanted = {
            "commodity": canonical_commodity(commodity) if commodity else None,
            "state": (state or "").strip().lower() or None,
            "district": (district or "").strip().lower() or None,
            "market": normalize_market(market).lower() if market else None,
        }
        out: list[dict[str, Any]] = []
        for row in rows:
            if wanted["commodity"] and (row.get("commodity") or "").lower() != wanted["commodity"].lower():
                continue
            if wanted["state"] and (row.get("state") or "").lower() != wanted["state"]:
                continue
            if wanted["district"] and (row.get("district") or "").lower() != wanted["district"]:
                continue
            if wanted["market"] and (row.get("market") or "").lower() != wanted["market"]:
                continue
            out.append(row)
        return out