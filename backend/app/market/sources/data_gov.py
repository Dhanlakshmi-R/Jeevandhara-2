"""data.gov.in Open Government Data client - PRIMARY PRICE SOURCE.

**UNVERIFIED AGAINST A LIVE RESPONSE.** ``api.data.gov.in`` could not be reached
from the development network (the origin IP refuses TCP on 443 and 80), so this
client is written to the published OGD API documentation and is gated behind
``DATA_GOV_API_KEY``. With no key set it never runs. See
``data_sources.yaml`` -> ``sources.data_gov_in.verification_note``.

If the field names turn out to differ in production, the fix is confined to
``_RESOURCE_FIELDS`` below; the failover chain and every caller are unaffected.
"""

from __future__ import annotations

import os
from typing import Any

from .base import (
    CACHE_TTL,
    SOURCES,
    MarketSource,
    SourceUnavailable,
    to_float,
)

# Resource id -> which upstream field holds each value we care about.
# Mirrors data_sources.yaml; kept here so a schema correction is a one-line edit.
_RESOURCE_FIELDS: dict[str, dict[str, str]] = {
    "9ef84268-d588-465a-a308-a864a43d0070": {
        "state": "state",
        "district": "district",
        "market": "market",
        "commodity": "commodity",
        "variety": "variety",
        "date": "arrival_date",
        "min_price": "min_price",
        "modal_price": "modal_price",
        "max_price": "max_price",
    },
}

#: Filter name -> the query key OGD expects.
_FILTER_KEYS = {
    "state": "filters[state]",
    "district": "filters[district]",
    "market": "filters[market]",
    "commodity": "filters[commodity]",
    "date": "filters[arrival_date]",
}

_API_BASE = "https://api.data.gov.in"


class DataGovSource(MarketSource):
    """Mandi wholesale prices from the Ministry of Agriculture OGD catalogue."""

    name = "data_gov_in"
    kind = "price"

    def __init__(self) -> None:
        super().__init__()
        self._api_key = os.getenv("DATA_GOV_API_KEY", "").strip()
        self._base_url = str(self.config.get("base_url") or _API_BASE)

    @property
    def enabled(self) -> bool:
        # Deliberately stricter than the base class: a guessed key against an
        # unverified endpoint is worse than no source at all.
        if not super().enabled:
            return False
        return bool(self._api_key)

    def resource_ids(self, *, include_disabled: bool = False) -> list[str]:
        """Every configured resource id - not just one hardcoded id."""
        out: list[str] = []
        for resource in SOURCES[self.name].get("resources", []):
            if not resource.get("id"):
                continue
            if not include_disabled and not resource.get("enabled"):
                continue
            out.append(str(resource["id"]))
        return out

    def health(self) -> dict[str, Any]:
        """Cheap probe: is the key accepted and the endpoint reachable?"""
        if not self._api_key:
            return {
                "source": self.name,
                "ok": False,
                "enabled": False,
                "reason": "DATA_GOV_API_KEY not set",
            }
        ids = self.resource_ids()
        if not ids:
            return {
                "source": self.name,
                "ok": False,
                "enabled": False,
                "reason": "no enabled resource ids configured",
            }
        try:
            payload = self._get(ids[0], limit=1)
        except SourceUnavailable as exc:
            return {
                "source": self.name,
                "ok": False,
                "enabled": True,
                "reason": exc.reason,
                "kind": exc.kind,
            }
        return {
            "source": self.name,
            "ok": True,
            "enabled": True,
            "reason": "responded",
            "records": len(payload.get("records", [])),
            "total": payload.get("total"),
        }

    # ------------------------------------------------------------- fetch

    def _fetch(
        self,
        commodity: str | None = None,
        state: str | None = None,
        district: str | None = None,
        market: str | None = None,
        date: str | None = None,
        limit: int = 500,
    ) -> list[dict[str, Any]]:
        wanted = {
            k: v
            for k, v in {
                "commodity": commodity,
                "state": state,
                "district": district,
                "market": market,
                "date": date,
            }.items()
            if v
        }

        rows: list[dict[str, Any]] = []
        errors: list[str] = []
        for resource_id in self.resource_ids():
            fields = _RESOURCE_FIELDS.get(resource_id)
            if fields is None:
                # Unknown mapping for this id: refuse rather than guess columns.
                errors.append(f"no field mapping for resource {resource_id}")
                continue
            try:
                payload = self._get(
                    resource_id,
                    limit=limit,
                    filters={k: wanted[k] for k in wanted if k in _FILTER_KEYS},
                )
            except SourceUnavailable as exc:
                errors.append(exc.reason)
                continue

            for record in payload.get("records", []):
                mapped = self._map_record(record, fields)
                if mapped:
                    rows.append(mapped)
            if rows:
                break

        if not rows:
            raise SourceUnavailable(
                self.name,
                "; ".join(errors) or "no records returned",
                kind="empty",
            )
        return rows

    def _map_record(self, record: dict[str, Any], fields: dict[str, str]) -> dict[str, Any] | None:
        modal = to_float(record.get(fields["modal_price"]))
        low = to_float(record.get(fields["min_price"]))
        high = to_float(record.get(fields["max_price"]))
        # A row with no usable price is not a row. Dropping it keeps the UI
        # honest instead of rendering a 0.00 rate.
        if modal is None and low is None and high is None:
            return None
        return {
            "commodity": record.get(fields["commodity"]),
            "variety": record.get(fields["variety"]),
            "state": record.get(fields["state"]),
            "district": record.get(fields["district"]),
            "market": record.get(fields["market"]),
            "date": record.get(fields["date"]),
            "min_price": low,
            "modal_price": modal,
            "max_price": high,
            "unit": None,
            "arrival_quantity": None,
            "source": self.name,
        }

    def _get(
        self,
        resource_id: str,
        *,
        limit: int = 500,
        filters: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        query: dict[str, Any] = {
            "api-key": self._api_key,
            "format": "json",
            "limit": limit,
            "offset": 0,
        }
        for key, value in (filters or {}).items():
            query[_FILTER_KEYS[key]] = value
        payload = self._request_json(f"{self._base_url}/resource/{resource_id}", params=query)
        if not isinstance(payload, dict):
            raise SourceUnavailable(self.name, "unexpected payload shape", kind="bad_payload")
        if "records" not in payload:
            # OGD signals quota/auth problems with an `message` and no records.
            message = payload.get("message") or payload.get("description") or "no records key"
            raise SourceUnavailable(self.name, str(message)[:200], kind="rejected")
        return payload