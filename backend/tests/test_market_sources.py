"""Market data source tests.

Network is never touched here. Upstream responses are injected, which also
makes these tests the regression net for the field mappings - the exact thing
that could not be confirmed live against eNAM or data.gov.in.

Naming: the tests that matter most are the ones asserting we do NOT lie. A test
that passes because a price came back correctly is far less valuable than one
that fails when a stale rate is labelled fresh.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest

from app.market.normalizer import (
    canonical_commodity,
    commodity_aliases,
    normalize_market,
    normalize_state,
    normalize_unit,
    search_aliases,
    to_quintals,
    unit_is_known,
)
from app.market.sources import registry
from app.market.sources.base import (
    CircuitBreaker,
    SourceUnavailable,
    TtlCache,
    to_float,
)
from app.market.sources.data_gov import DataGovSource
from app.market.sources.enam import EnamSource, _normalise_date, _records_from
from app.market.sources.mandi_api import MandiApiSource
from app.market.sources.registry import (
    NoSourceAvailable,
    annotate_freshness,
    fetch_prices,
    market_status,
)

UTC = timezone.utc


# ---------------------------------------------------------------- fixtures

class _FakeSource:
    """Minimal stand-in for a MarketSource.

    Records call counts so a test can assert that a disabled source was never
    contacted at all - important because the whole point of the enabled gate is
    that no request leaves the process.
    """

    def __init__(self, name: str, *, enabled: bool, provides_arrivals: bool = True) -> None:
        self.name = name
        self.enabled = enabled
        self.kind = "price"
        self.provides_arrivals = provides_arrivals
        self.fetch_calls = 0
        self.missing_key = None

    def fetch(self, **params):
        self.fetch_calls += 1
        return (
            [{"commodity": "Onion", "modal_price": 4000.0}],
            {
                "source": self.name,
                "attribution": "test attribution",
                "confidence": "low",
                "verified": True,
                "stale": False,
                "fetched_at": None,
            },
        )

    def status(self):
        return _FakeStatus(self.name, enabled=self.enabled)


class _FakeStatus:
    def __init__(self, name: str, enabled: bool = True) -> None:
        self._payload = {
            "name": name,
            "enabled": enabled,
            "verified": True,
            "confidence": "low",
            "attribution": "test attribution",
        }

    def as_dict(self) -> dict:
        return dict(self._payload)


MANDI_RECORD = {
    "id": 259389,
    "state": "Karnataka",
    "district": "Bengaluru",
    "market": "Bengaluru APMC",
    "commodity": "Onion",
    "variety": "Puna",
    "grade": "Local",
    "arrival_date": "2026-09-24",
    "min_price": 3000,
    "max_price": 5200,
    "modal_price": 4400,
    "fetched_at": "2026-09-24T18:44:17.102+00:00",
}

ENAM_RECORD = {
    "state": "Karnataka",
    "District": "Bengaluru",
    "mandi": "Bengaluru",
    "Commodity": "Onion",
    "variety": "Puna",
    "arrival_qty": "1200",
    "minrate": "3000",
    "modelprice": "4400",
    "maxrate": "5200",
    "Unit": "Quintal",
    "trn_date": "24-09-2026",
    # eNAM's own renderer hardcodes this column to 0.
    "trades": 0,
}


def mandi_payload(*records: dict) -> str:
    return json.dumps({"success": True, "data": list(records)})


@pytest.fixture(autouse=True)
def _clean_registry():
    """Each test gets fresh shared instances and a deterministic env."""
    os.environ.pop("DATA_GOV_API_KEY", None)
    os.environ.setdefault("APP_ENV", "development")
    registry.reset_for_tests()
    yield
    registry.reset_for_tests()


# --------------------------------------------------------------- to_float

class TestToFloat:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            (3000, 3000.0),
            (3000.0, 3000.0),
            ("3,000", 3000.0),
            ("₹3,000", 3000.0),
            ("Rs. 4400", 4400.0),
            (" 4200 ", 4200.0),
            ("-500", -500.0),
        ],
    )
    def test_parses(self, raw, expected):
        assert to_float(raw) == expected

    @pytest.mark.parametrize("raw", [None, "", "   ", "NA", "n/a", "-", "--", "null", "abc"])
    def test_unparseable_is_none_not_zero(self, raw):
        """A missing price must be None. Zero would render as a real rate."""
        assert to_float(raw) is None

    def test_booleans_are_not_numbers(self):
        assert to_float(True) is None
        assert to_float(False) is None

    def test_single_parser_avoids_drift(self):
        """to_float lives in base and is re-exported; one parser, one behaviour."""
        from app.market.sources.base import to_float as from_base

        assert from_base is to_float


# ------------------------------------------------------------ normalizer

class TestCommodityNormalisation:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("Onion", "Onion"),
            ("onions", "Onion"),
            ("Onion ", "Onion"),
            ("Arecanut(Betelnut/Supari)", "Arecanut"),
            ("Jowar/Sorghum", "Jowar"),
            ("Arhar/Tur/Red gram", "Tur/Arhar"),
            ("Methi(Leaves)", "Methi"),
            ("tur dal", "Tur/Arhar"),
        ],
    )
    def test_maps_to_canonical(self, raw, expected):
        assert canonical_commodity(raw) == expected

    @pytest.mark.parametrize("raw", ["Onion", "Pyaz", "Pyaaz", "ಈರುಳ್ಳಿ", "onions", "Kanda"])
    def test_transliterated_and_kannada_forms(self, raw):
        assert canonical_commodity(raw) == "Onion"

    def test_unknown_is_passed_through_cleaned(self):
        """Unknown stays unknown. Inventing a match returns another crop's price."""
        assert canonical_commodity("  Dragonfruit  ") == "dragonfruit"

    def test_empty(self):
        assert canonical_commodity("") == ""
        assert canonical_commodity(None) == ""

    def test_aliases_round_trip(self):
        for alias in commodity_aliases("Onion"):
            assert canonical_commodity(alias) == "Onion"

    def test_search_is_substring_based(self):
        assert "Onion" in search_aliases("onion")
        assert "Tur/Arhar" in search_aliases("arhar")
        assert search_aliases("") == []


class TestUnitNormalisation:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("Quintal", "quintal"),
            ("quintal", "quintal"),
            ("Qtl", "quintal"),
            ("quintal (100 kg)", "quintal"),
            ("Kg", "kg"),
            ("kgs", "kg"),
            ("Tonnes", "tonne"),
            ("Metric Tonne", "tonne"),
        ],
    )
    def test_canonical_tokens(self, raw, expected):
        assert normalize_unit(raw) == expected

    def test_unknown_unit_is_flagged_and_defaults_to_quintal(self):
        assert normalize_unit("bananas") == "quintal"
        assert unit_is_known("bananas") is False
        assert unit_is_known("qtl") is True

    @pytest.mark.parametrize(
        "quantity,unit,expected",
        [
            (2000, "kg", 20.0),
            (2, "tonne", 20.0),
            (5, "quintal", 5.0),
            (20, "qtl", 20.0),
            (1, "Metric Tonne", 10.0),
        ],
    )
    def test_conversion_to_quintals(self, quantity, unit, expected):
        assert to_quintals(quantity, unit) == pytest.approx(expected)

    def test_none_passes_through(self):
        assert to_quintals(None, "kg") is None

    def test_kg_tonne_agree(self):
        assert to_quintals(2000, "kg") == to_quintals(2, "tonne")


class TestPlaceNormalisation:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("Bangarpet APMC", "Bangarpet"),
            ("APMC Hubballi", "Hubballi"),
            ("Bengaluru APMC", "Bengaluru"),
            ("APMC THIRTHAHALLI", "THIRTHAHALLI"),
            ("K.R. Pet APMC", "K.R. Pet"),
            ("Binny Mill (FF&V) Bengaluru APMC", "Binny Mill (FF&V) Bengaluru"),
        ],
    )
    def test_market(self, raw, expected):
        assert normalize_market(raw) == expected

    def test_state(self):
        assert normalize_state("karnataka") == "Karnataka"
        assert normalize_state("Karnataka State") == "Karnataka"
        assert normalize_state("Karnataka (KA)") == "Karnataka"


# ------------------------------------------------------------- date helper

class TestDateNormalisation:
    @pytest.mark.parametrize(
        "raw",
        ["2026-09-24", "24-09-2026", "24/09/2026", "2026/09/24"],
    )
    def test_known_formats(self, raw):
        assert _normalise_date(raw) == "2026-09-24"

    @pytest.mark.parametrize("raw", [None, "", "   ", "not-a-date"])
    def test_unparseable_is_none(self, raw):
        assert _normalise_date(raw) is None

    def test_iso_passes_through(self):
        assert _normalise_date("2026-09-24") == "2026-09-24"


class TestRecordExtraction:
    def test_bare_list(self):
        assert _records_from([{"a": 1}]) == [{"a": 1}]

    def test_data_envelope(self):
        assert _records_from({"data": [{"a": 1}]}) == [{"a": 1}]

    def test_nested_datatables_envelope(self):
        assert _records_from({"data": {"data": [{"a": 1}]}}) == [{"a": 1}]

    @pytest.mark.parametrize("payload", [None, {}, "", 0])
    def test_junk_yields_nothing(self, payload):
        assert _records_from(payload) == []

    def test_non_dict_rows_dropped(self):
        assert _records_from(["x", {"a": 1}]) == [{"a": 1}]


# ------------------------------------------------------------------ cache

class TestTtlCache:
    def test_fresh_then_stale(self):
        cache = TtlCache(ttl=100)
        assert cache.get("k") is None
        cache.set("k", "v")
        value, fresh = cache.get("k")
        assert value == "v" and fresh is True

    def test_expired_value_is_still_returned(self):
        """Stale-but-real beats an error. The caller labels it."""
        cache = TtlCache(ttl=-1)
        cache.set("k", "v")
        value, fresh = cache.get("k")
        assert value == "v"
        assert fresh is False

    def test_eviction_keeps_size_bounded(self):
        cache = TtlCache(ttl=100, max_items=3)
        for i in range(10):
            cache.set(f"k{i}", i)
        assert len(cache._data) <= 3


class TestCircuitBreaker:
    def test_opens_after_threshold(self):
        breaker = CircuitBreaker(failure_threshold=2, recovery_seconds=60)
        assert breaker.state() == "closed"
        breaker.record_failure()
        assert breaker.state() == "closed"
        breaker.record_failure()
        assert breaker.state() == "open"
        assert breaker.is_open is True

    def test_success_resets(self):
        breaker = CircuitBreaker(failure_threshold=2, recovery_seconds=60)
        breaker.record_failure()
        breaker.record_success()
        breaker.record_failure()
        assert breaker.state() == "closed"

    def test_half_opens_after_recovery(self):
        breaker = CircuitBreaker(failure_threshold=1, recovery_seconds=0)
        breaker.record_failure()
        assert breaker.state() == "half_open"
        assert breaker.is_open is False

    def test_recovers_after_half_open_success(self):
        breaker = CircuitBreaker(failure_threshold=1, recovery_seconds=0)
        breaker.record_failure()
        breaker.record_success()
        assert breaker.state() == "closed"


# ----------------------------------------------------------- mandi client

class TestMandiApiSource:
    def test_maps_observed_payload(self):
        source = MandiApiSource()
        with patch.object(source, "_request_json", return_value=json.loads(mandi_payload(MANDI_RECORD))):
            rows, meta = source.fetch(commodity="Onion", state="Karnataka")
        assert len(rows) == 1
        row = rows[0]
        assert row["commodity"] == "Onion"
        assert row["market"] == "Bengaluru"          # APMC stripped
        assert row["district"] == "Bengaluru"
        assert row["modal_price"] == 4400.0
        assert row["min_price"] == 3000.0
        assert row["max_price"] == 5200.0
        assert row["date"] == "2026-09-24"
        assert row["source"] == "mandi_api"
        assert meta["stale"] is False
        assert meta["verified"] is True
        assert meta["confidence"] == "low"
        assert meta["attribution"]

    def test_requires_state_or_commodity(self):
        """This feed 400s without one, so we refuse before spending a request."""
        source = MandiApiSource()
        with patch.object(source, "_request_json") as request:
            with pytest.raises(Exception) as excinfo:
                source.fetch()
        assert "state or commodity" in str(excinfo.value)
        request.assert_not_called()

    def test_local_filtering_because_server_ignores_params(self):
        source = MandiApiSource()
        other = dict(MANDI_RECORD, id=2, market="Shimoga APMC", district="Shivamogga")
        with patch.object(source, "_request_json", return_value=json.loads(mandi_payload(MANDI_RECORD, other))):
            rows, _ = source.fetch(commodity="Onion", state="Karnataka", market="Shimoga")
        assert [r["market"] for r in rows] == ["Shimoga"]

    def test_rows_without_any_price_are_dropped(self):
        source = MandiApiSource()
        blank = dict(MANDI_RECORD, id=3, min_price=None, max_price=None, modal_price="")
        with patch.object(source, "_request_json", return_value=json.loads(mandi_payload(MANDI_RECORD, blank))):
            rows, _ = source.fetch(commodity="Onion", state="Karnataka")
        assert len(rows) == 1
        assert rows[0]["id" if "id" in rows[0] else "upstream_id"] == MANDI_RECORD["id"]

    def test_success_envelope_false_raises(self):
        source = MandiApiSource()
        rejected = json.dumps({"success": False, "error": {"code": "MISSING_PARAM", "message": "nope"}})
        with patch.object(source, "_request_json", return_value=json.loads(rejected)):
            with pytest.raises(Exception) as excinfo:
                source.fetch(commodity="Onion")
        assert "MISSING_PARAM" in str(excinfo.value)

    def test_health_reports_failure_reason(self):
        """Health must explain itself; /market/status has nothing else to show."""
        source = MandiApiSource()
        failure = SourceUnavailable("mandi_api", "network: timed out", kind="network")
        with patch.object(type(source), "_request_json", side_effect=failure):
            health = source.health()
        assert health["ok"] is False
        assert "timed out" in health["reason"]
        assert health["kind"] == "network"

    def test_health_reports_ok(self):
        source = MandiApiSource()
        payload = json.dumps({"status": "ok", "service": "Mandi Price API", "version": "v1"})
        with patch.object(type(source), "_request_json", return_value=json.loads(payload)):
            health = source.health()
        assert health["ok"] is True
        assert health["upstream"]["version"] == "v1"

    def test_markets_carry_upstream_name(self):
        source = MandiApiSource()
        payload = json.dumps(
            {"success": True, "data": [{"market": "Bengaluru APMC", "district": "Bengaluru"}]}
        )
        with patch.object(source, "_request_json", return_value=json.loads(payload)):
            markets = source.markets("Karnataka")
        assert markets == [
            {
                "market": "Bengaluru",
                "upstream_name": "Bengaluru APMC",
                "district": "Bengaluru",
                "state": "Karnataka",
            }
        ]

    def test_history_sorted_and_filtered(self):
        source = MandiApiSource()
        payload = json.dumps(
            {
                "success": True,
                "data": [
                    {"arrival_date": "2026-09-24", "avg_modal_price": 3930, "data_points": 10},
                    {"arrival_date": "2026-07-28", "avg_modal_price": 2283, "data_points": 13},
                    {"arrival_date": "2026-08-01", "avg_modal_price": None, "data_points": 5},
                ],
            }
        )
        with patch.object(source, "_request_json", return_value=json.loads(payload)):
            history = source.history("Karnataka", "Onion")
        assert [h["date"] for h in history] == ["2026-07-28", "2026-09-24"]

    def test_disabled_in_production(self):
        with patch.dict(os.environ, {"APP_ENV": "production"}):
            assert MandiApiSource().enabled is False

    def test_enabled_in_development(self):
        with patch.dict(os.environ, {"APP_ENV": "development"}):
            assert MandiApiSource().enabled is True


# ------------------------------------------------------------ enam client

class TestEnamSource:
    def test_maps_documented_fields(self):
        source = EnamSource()
        payload = json.dumps({"data": [ENAM_RECORD]})
        with patch.object(source, "_request_json", return_value=json.loads(payload)):
            rows, _ = source.fetch(commodity="Onion", state="Karnataka")
        row = rows[0]
        assert row["commodity"] == "Onion"
        assert row["district"] == "Bengaluru"       # capital-D District field
        assert row["market"] == "Bengaluru"
        assert row["modal_price"] == 4400.0         # upstream "modelprice"
        assert row["min_price"] == 3000.0
        assert row["max_price"] == 5200.0
        assert row["date"] == "2026-09-24"          # from 24-09-2026
        assert row["arrival_quantity"] == 1200.0
        assert row["source"] == "enam"

    def test_trade_count_is_zero_but_traded_quantity_is_none(self):
        """Two different claims. Neither is a real observation."""
        source = EnamSource()
        payload = json.dumps({"data": [ENAM_RECORD]})
        with patch.object(source, "_request_json", return_value=json.loads(payload)):
            rows, _ = source.fetch(commodity="Onion")
        row = rows[0]
        assert row["trade_count"] == 0
        assert row["traded_quantity"] is None

    def test_does_not_claim_to_publish_traded_quantity(self):
        assert EnamSource().provides_traded_quantity is False
        assert EnamSource().provides_trade_count is False
        assert EnamSource().provides_arrivals is True

    def test_rows_without_price_dropped(self):
        source = EnamSource()
        blank = dict(ENAM_RECORD, minrate="", modelprice="", maxrate="")
        with patch.object(source, "_request_json", return_value=json.dumps({"data": [blank]})):
            with pytest.raises(Exception):
                source.fetch(commodity="Onion")

    def test_endpoints_resolve_to_configured_paths(self):
        source = EnamSource()
        assert source.endpoint("trade_data").endswith("Agm_ctrl/trade_data_list")
        assert source.endpoint("states").endswith("Agm_ctrl/states_name")

    def test_unknown_endpoint_raises(self):
        with pytest.raises(Exception):
            EnamSource().endpoint("nope")

    def test_rate_limited_to_30_minutes(self):
        assert EnamSource().min_interval == 1800


# --------------------------------------------------------- data.gov client

class TestDataGovSource:
    def test_disabled_without_key(self):
        assert DataGovSource().enabled is False

    def test_missing_key_is_reported(self):
        assert DataGovSource().missing_key == "DATA_GOV_API_KEY"

    def test_enabled_with_key(self):
        with patch.dict(os.environ, {"DATA_GOV_API_KEY": "test-key"}):
            assert DataGovSource().enabled is True

    def test_stays_unverified(self):
        """Never claim verification we could not perform."""
        assert DataGovSource().verified is False

    def test_health_says_key_missing(self):
        assert DataGovSource().health()["reason"] == "DATA_GOV_API_KEY not set"

    def test_maps_resource_record(self):
        with patch.dict(os.environ, {"DATA_GOV_API_KEY": "test-key"}):
            source = DataGovSource()
            payload = {"records": [dict(MANDI_RECORD)], "total": 1}
            with patch.object(source, "_get", return_value=payload):
                rows, _ = source.fetch(commodity="Onion", state="Karnataka")
        assert rows[0]["modal_price"] == 4400.0
        assert rows[0]["source"] == "data_gov_in"

    def test_unmapped_resource_is_skipped_not_guessed(self):
        with patch.dict(os.environ, {"DATA_GOV_API_KEY": "test-key"}):
            source = DataGovSource()
            source.resource_ids = lambda **kw: ["unknown-resource"]
            with pytest.raises(Exception) as excinfo:
                source.fetch(commodity="Onion")
        assert "no field mapping" in str(excinfo.value)

    def test_rejected_envelope_raises(self):
        with patch.dict(os.environ, {"DATA_GOV_API_KEY": "test-key"}):
            source = DataGovSource()
            with patch.object(source, "_get", side_effect=Exception("Invalid API key")):
                with pytest.raises(Exception):
                    source.fetch(commodity="Onion")


# ------------------------------------------------------------- freshness

class TestFreshness:
    """The most important tests in this file: we must not overstate data age."""

    def _rows(self, date: str) -> list[dict]:
        return [{"commodity": "Onion", "date": date, "modal_price": 4000.0}]

    def _meta(self, **overrides) -> dict:
        meta = {
            "source": "mandi_api",
            "verified": True,
            "stale": False,
            "confidence": "low",
            "attribution": "Community data",
            "fetched_at": datetime.now(UTC).isoformat(),
        }
        meta.update(overrides)
        return meta

    def test_todays_data_is_fresh_and_actionable(self):
        today = datetime.now(UTC).date().isoformat()
        rows = annotate_freshness(self._rows(today), self._meta())
        p = rows[0]["_provenance"]
        assert p["freshness"] == "fresh"
        assert p["actionable"] is True

    def test_seven_day_old_data_is_stale(self):
        """Regression: fetch-time freshness once labelled a 7-day-old rate fresh."""
        old = (datetime.now(UTC) - timedelta(days=7)).date().isoformat()
        rows = annotate_freshness(self._rows(old), self._meta())
        p = rows[0]["_provenance"]
        assert p["freshness"] == "stale"
        assert p["actionable"] is False
        assert p["lag_days"] >= 6.9

    def test_fast_fetch_does_not_make_old_data_fresh(self):
        """The exact bug: fetched_at is now, arrival_date is 7 days ago."""
        old = (datetime.now(UTC) - timedelta(days=7)).date().isoformat()
        meta = self._meta(fetched_at=datetime.now(UTC).isoformat())
        rows = annotate_freshness(self._rows(old), meta)
        assert rows[0]["_provenance"]["freshness"] == "stale"

    def test_unverified_feed_is_never_fresh(self):
        today = datetime.now(UTC).date().isoformat()
        rows = annotate_freshness(self._rows(today), self._meta(verified=False))
        assert rows[0]["_provenance"]["freshness"] == "unverified"
        assert rows[0]["_provenance"]["actionable"] is False

    def test_meta_stale_flag_forces_stale(self):
        today = datetime.now(UTC).date().isoformat()
        rows = annotate_freshness(self._rows(today), self._meta(stale=True))
        assert rows[0]["_provenance"]["freshness"] == "stale"

    def test_undated_row_is_stale_not_fresh(self):
        """No date means we cannot claim it is current."""
        rows = annotate_freshness([{"commodity": "Onion", "date": None}], self._meta())
        assert rows[0]["_provenance"]["freshness"] == "stale"

    def test_rows_can_have_different_verdicts(self):
        """A multi-day window legitimately contains both."""
        now = datetime.now(UTC)
        rows = [
            {"commodity": "Onion", "date": now.date().isoformat()},
            {"commodity": "Onion", "date": (now - timedelta(days=5)).date().isoformat()},
        ]
        rows = annotate_freshness(rows, self._meta())
        assert rows[0]["_provenance"]["freshness"] == "fresh"
        assert rows[1]["_provenance"]["freshness"] == "stale"

    def test_observed_at_is_the_row_date(self):
        rows = annotate_freshness(self._rows("2026-09-24"), self._meta())
        assert rows[0]["_provenance"]["observed_at"].startswith("2026-09-24")


# --------------------------------------------------------------- registry

class TestRegistry:
    def test_no_source_available_lists_each_reason(self):
        """The user must be able to tell 'no key' from 'upstream 500'."""
        registry.reset_for_tests()
        sources = {
            "data_gov_in": _FakeSource("data_gov_in", enabled=False),
            "enam": _FakeSource("enam", enabled=False),
            "mandi_api": _FakeSource("mandi_api", enabled=False),
        }
        with patch.object(registry, "get_source", side_effect=sources.__getitem__):
            with pytest.raises(NoSourceAvailable) as excinfo:
                registry.fetch_prices(commodity="Onion")
        assert len(excinfo.value.attempts) == 3
        assert all("disabled" in a["reason"] for a in excinfo.value.attempts)

    def test_a_failing_source_is_skipped_not_fatal(self):
        """One dead upstream must not stop a healthy fallback from serving."""
        broken = _FakeSource("enam", enabled=True)

        def fail(**params):
            broken.fetch_calls += 1
            raise SourceUnavailable("enam", "HTTP 500: empty body", kind="http_error")

        broken.fetch = fail
        working = _FakeSource("mandi_api", enabled=True)
        by_name = {"data_gov_in": _FakeSource("data_gov_in", enabled=False), "enam": broken, "mandi_api": working}
        with patch.object(registry, "get_source", side_effect=by_name.__getitem__):
            rows, meta = registry.fetch_prices(commodity="Onion", state="Karnataka")
        assert meta["source"] == "mandi_api"
        assert broken.fetch_calls == 1
        reasons = {a["source"]: a["reason"] for a in meta["attempts"]}
        assert reasons["enam"] == "HTTP 500: empty body"
        assert reasons["data_gov_in"] == "disabled or not configured"
        assert len(rows) == 1

    def test_arrival_never_served_by_price_only_source(self):
        registry.reset_for_tests()
        price_only = _FakeSource("enam", enabled=True, provides_arrivals=False)
        with patch.object(registry, "get_source", side_effect=lambda n: price_only):
            with pytest.raises(NoSourceAvailable) as excinfo:
                registry.fetch_arrivals(commodity="Onion")
        assert "does not publish arrival" in excinfo.value.attempts[0]["reason"]
        assert price_only.fetch_calls == 0

    def test_fallback_is_recorded_on_the_result(self):
        """A number from source 3 must say so, not silently look like source 1."""
        disabled = _FakeSource("data_gov_in", enabled=False)
        working = _FakeSource("mandi_api", enabled=True)
        with patch.object(registry, "get_source", side_effect=lambda n: disabled if n == "data_gov_in" else working):
            rows, meta = registry.fetch_prices(commodity="Onion", state="Karnataka")
        assert meta["source"] == "mandi_api"
        assert meta["fallback_used"] is True
        assert meta["attempts"][0]["source"] == "data_gov_in"
        assert rows[0]["_provenance"]["source"] == "mandi_api"

    def test_disabled_source_is_never_called(self):
        disabled = _FakeSource("data_gov_in", enabled=False)
        working = _FakeSource("mandi_api", enabled=True)
        with patch.object(registry, "get_source", side_effect=lambda n: disabled if n == "data_gov_in" else working):
            registry.fetch_prices(commodity="Onion")
        assert disabled.fetch_calls == 0

    def test_first_healthy_source_wins_without_fallback_flag(self):
        registry.reset_for_tests()
        source = _FakeSource("enam", enabled=True)
        with patch.object(registry, "get_source", side_effect=lambda n: source):
            rows, meta = registry.fetch_prices(commodity="Onion")
        assert meta["fallback_used"] is False
        assert meta["attempts"] == []
        assert source.fetch_calls == 1

    def test_every_row_carries_provenance(self):
        registry.reset_for_tests()
        source = _FakeSource("mandi_api", enabled=True)
        with patch.object(registry, "get_source", side_effect=lambda n: source):
            rows, _ = registry.fetch_prices(commodity="Onion")
        provenance = rows[0]["_provenance"]
        for key in ("source", "attribution", "confidence", "verified", "stale"):
            assert key in provenance

    def test_unknown_source_name_raises(self):
        with pytest.raises(KeyError):
            registry.get_source("nope")


class TestMarketStatus:
    def test_shape(self):
        status = market_status()
        assert "sources" in status
        assert "checked_at" in status
        assert status["live"] in {True, False}

    def test_live_requires_an_enabled_verified_price_source(self):
        registry.reset_for_tests()
        disabled = _FakeSource("mandi_api", enabled=False)
        with patch.object(registry, "get_source", side_effect=lambda n: disabled):
            status = market_status()
        assert status["live"] is False
        assert status["prices"] != "live"
        assert status["demand_capable"] is False

    def test_live_with_one_enabled_verified_source(self):
        registry.reset_for_tests()
        working = _FakeSource("mandi_api", enabled=True)
        with patch.object(registry, "get_source", side_effect=lambda n: working):
            status = market_status()
        assert status["live"] is True
        assert status["prices"] == "live"

    def test_arrivals_reported_separately_from_prices(self):
        """A live price must not imply live arrivals."""
        status = market_status()
        assert status["arrivals"] in {"live", "unavailable"}
        assert status["demand_capable"] == (status["arrivals"] == "live")
        assert any("does not imply" in note for note in status["notes"])

    def test_each_source_has_attribution_and_confidence(self):
        for entry in market_status()["sources"]:
            assert entry["attribution"]
            assert entry["confidence"] in {"high", "medium", "low"}

    def test_unverified_sources_carry_their_reason(self):
        entries = {e["name"]: e for e in market_status()["sources"]}
        assert entries["data_gov_in"]["verified"] is False
        assert entries["data_gov_in"]["disabled_reason"] == "DATA_GOV_API_KEY not set"
        assert entries["enam"]["verification_note"]