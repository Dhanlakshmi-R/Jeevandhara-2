"""eNAM / Agmarknet client - ARRIVAL and DEMAND source.

Endpoint paths and POST parameter names were recovered from the dashboard's own
JavaScript, so the *contract* is believed correct. But every data endpoint
returned HTTP 500 with an empty body during Phase 0, with and without a session
cookie and Referer header. No live row was ever parsed.

Consequences, all of which are deliberate:

* The breaker makes this source cost approximately nothing once it starts
  failing - it will not slow down a user request every 30 minutes.
* :meth:`health` is cheap and explicit so ``/market/status`` can say *why*
  arrivals are unavailable instead of silently dropping a demand component.
* Field types are treated as unknown. Everything is passed through
  :func:`app.market.normalizer.to_float`, so a type surprise produces a
  ``None`` we can drop rather than a wrong number.
* This source publishes **arrival quantities but no traded quantity or trade
  count**. ``off_take_ratio`` and ``buyer_competition`` therefore cannot be
  computed here and are dropped by :mod:`app.market.demand`.
"""

from __future__ import annotations

import re
from typing import Any

from .base import MarketSource, SourceUnavailable, to_float
from ..normalizer import canonical_commodity, normalize_market, normalize_state, to_quintals

#: Their renderer hardcodes 0 for the trades column, so we record 0 explicitly
#: rather than pretending we read a number. ``None`` would be a lie in the other
#: direction - the field genuinely does not exist in the feed.
NO_TRADE_COUNT = 0


class EnamSource(MarketSource):
    """Trade and arrival data from enam.gov.in / Agmarknet."""

    name = "enam"
    kind = "arrival"

    def __init__(self) -> None:
        super().__init__()
        self._base_url = str(self.config.get("base_url") or "https://enam.gov.in").rstrip("/")
        self._endpoints: dict[str, str] = dict(self.config.get("endpoints") or {})
        self._fields: dict[str, str] = dict(self.config.get("fields") or {})
        self._session_cookie: str | None = None

    def endpoint(self, key: str) -> str:
        path = self._endpoints.get(key)
        if not path:
            raise SourceUnavailable(self.name, f"no endpoint configured for '{key}'")
        return f"{self._base_url}/{path.lstrip('/')}"

    # ---------------------------------------------------------- references

    def states(self) -> list[str]:
        """Known state names, for the location filter."""
        rows = self._post(self.endpoint("states"), {})
        return [
            normalize_state(row if isinstance(row, str) else row.get("state") or row.get("name"))
            for row in rows
            if row
        ]

    def commodities(self) -> list[str]:
        """Commodity vocabulary, canonicalised for search."""
        rows = self._post(self.endpoint("commodities"), {})
        out: list[str] = []
        for row in rows:
            raw = row if isinstance(row, str) else row.get("commodity") or row.get("Commodity")
            name = canonical_commodity(raw)
            if name and name not in out:
                out.append(name)
        return sorted(out)

    # ------------------------------------------------------------- health

    def health(self) -> dict[str, Any]:
        """Probe the cheapest endpoint. Does not consume the price breaker."""
        if not self.enabled:
            return {"source": self.name, "ok": False, "enabled": False, "reason": "disabled"}
        try:
            self._post(self.endpoint("states"), {})
        except SourceUnavailable as exc:
            return {
                "source": self.name,
                "ok": False,
                "enabled": True,
                "reason": exc.reason,
                "kind": exc.kind,
                "breaker": self.breaker.state(),
            }
        return {"source": self.name, "ok": True, "enabled": True, "reason": "responded"}

    # -------------------------------------------------------------- fetch

    def _fetch(
        self,
        commodity: str | None = None,
        state: str | None = None,
        district: str | None = None,
        market: str | None = None,
        date: str | None = None,
        limit: int = 200,
    ) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {
            "commodity": commodity or "",
            "state": state or "",
            "district": district or "",
            "apmc": market or "",
            "trn_date": date or "",
            "rows": limit,
        }
        raw = self._post(self.endpoint("trade_data"), payload)

        rows: list[dict[str, Any]] = []
        for record in _records_from(raw):
            mapped = self._map_record(record)
            if mapped:
                rows.append(mapped)
        if not rows:
            raise SourceUnavailable(self.name, "no usable rows in response", kind="empty")
        return rows

    def _map_record(self, record: dict[str, Any]) -> dict[str, Any] | None:
        f = self._fields
        modal = to_float(record.get(f["modal_price"]))
        low = to_float(record.get(f["min_price"]))
        high = to_float(record.get(f["max_price"]))
        if modal is None and low is None and high is None:
            return None

        unit = record.get(f.get("unit", "")) or None
        arrival = to_float(record.get(f.get("arrival_quantity", "")))
        # arrival_qty upstream is variously quintals and tonnes depending on the
        # Unit column, so it must be converted rather than assumed.
        arrival_quintals = to_quintals(arrival, unit)

        traded_flag = to_float(record.get(f.get("enam_traded_flag", "")))

        return {
            "commodity": canonical_commodity(record.get(f["commodity"])),
            "variety": record.get(f.get("variety", "")) or None,
            "state": normalize_state(record.get(f["state"])),
            "district": record.get(f.get("district", "")) or None,
            "market": normalize_market(record.get(f.get("market", ""))),
            "date": _normalise_date(record.get(f.get("date", ""))),
            "min_price": low,
            "modal_price": modal,
            "max_price": high,
            "unit": unit,
            "arrival_quantity": arrival_quintals,
            # Recorded as 0, never as a real observation: see NO_TRADE_COUNT.
            "trade_count": NO_TRADE_COUNT,
            "traded_quantity": None,
            "enam_traded": (traded_flag == 0) if traded_flag is not None else None,
            "source": self.name,
        }

    # ---------------------------------------------------------------- http

    def _post(self, url: str, payload: dict[str, Any]) -> Any:
        """POST with the headers their dashboard sends.

        Their endpoints appear to be plain form POSTs (the dashboard's JS does
        not send JSON), so data is form-encoded by the base helper.
        """
        return self._request_json(url, data={k: v for k, v in payload.items() if v != ""})


_DATE_FORMATS = (
    "%Y-%m-%d",
    "%d-%m-%Y",
    "%d/%m/%Y",
    "%Y/%m/%d",
    "%d-%b-%Y",
    "%d %b %Y",
)


def _normalise_date(raw: Any) -> str | None:
    """Reduce the many date spellings to ``YYYY-MM-DD``, or None."""
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", text):
        return text
    for fmt in _DATE_FORMATS:
        try:
            from datetime import datetime

            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def _records_from(payload: Any) -> list[dict[str, Any]]:
    """Pull the row list out of the several shapes these endpoints return.

    Their endpoints have been observed returning a bare list, a ``{"data": []}``
    envelope and a DataTables-style ``{"data": {"data": []}}`` envelope.
    """
    if payload is None:
        return []
    if isinstance(payload, list):
        return [row for row in payload if isinstance(row, dict)]
    if isinstance(payload, dict):
        for key in ("records", "data", "rows", "aaData", "result"):
            if key not in payload:
                continue
            inner = payload[key]
            if isinstance(inner, list):
                return [row for row in inner if isinstance(row, dict)]
            if isinstance(inner, dict):
                return _records_from(inner)
    return []