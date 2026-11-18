"""Demand index tests.

The index is Tier D: a derived estimate. These tests are mostly about what it
declines to do. A test that passes because a score came back is much less
valuable than one that fails when a missing input is quietly imputed, when an
omitted component still carries weight, or when a single signal gets promoted
into a number that looks actionable.

Network is never touched: the index takes plain dicts, so inputs are injected.
"""

from __future__ import annotations

import pytest

from app.market.demand import (
    COMPONENT_ORDER,
    COMPONENTS,
    MIN_COMPONENTS,
    NOMINAL_WEIGHT_SUM,
    DemandInputs,
    DemandResult,
    band_for,
    clamp01,
    compute_demand,
    scale_linear,
)


# ------------------------------------------------------------------- inputs

def _history(*prices: float) -> list[dict]:
    """Chronological daily modal prices starting a month ago."""
    from datetime import date, timedelta

    start = date(2026, 8, 1)
    return [
        {"date": (start + timedelta(days=7 * i)).isoformat(), "modal_price": p}
        for i, p in enumerate(prices)
    ]


def _rows(*modal_prices: float) -> list[dict]:
    """One price row per mandi, with a plausible daily range."""
    out = []
    for i, modal in enumerate(modal_prices):
        out.append(
            {
                "market": f"Mandi {i}",
                "district": f"District {i}",
                "min_price": modal * 0.8,
                "modal_price": modal,
                "max_price": modal * 1.2,
            }
        )
    return out


def _components(result: DemandResult) -> dict[str, object]:
    return {c.name: c for c in result.components}


# ------------------------------------------------------------ weight contract

def test_weights_sum_to_exactly_one():
    assert NOMINAL_WEIGHT_SUM == pytest.approx(1.0)


def test_component_order_matches_documented_order():
    assert set(COMPONENT_ORDER) == set(COMPONENTS)
    assert len(COMPONENT_ORDER) == len(COMPONENTS)


def test_every_component_declares_what_it_needs():
    for name, spec in COMPONENTS.items():
        assert spec.needs, f"{name} declares no inputs, so it can never be gated"
        assert spec.label_en and spec.label_kn
        assert spec.direction_en, f"{name} has no plain-language direction"


def test_nine_components_cover_the_documented_pool():
    assert len(COMPONENTS) == 9


# ------------------------------------------------------ omission, not faking

def test_no_inputs_means_no_score_and_no_band():
    result = compute_demand(DemandInputs())

    assert result.score is None
    assert result.band == "insufficient_data"
    assert result.is_insufficient
    assert result.component_count == 0
    assert result.weights_used == 0


def test_one_component_is_not_enough_for_a_number():
    result = compute_demand(DemandInputs(price_history=_history(3000, 3100, 3200)))

    assert result.component_count < MIN_COMPONENTS
    assert result.score is None, "a single signal must never be promoted to a score"
    assert result.band == "insufficient_data"


def test_every_unavailable_component_carries_a_reason():
    result = compute_demand(DemandInputs())

    for component in result.components:
        assert component.available is False
        assert component.reason, f"{component.name} is omitted with no reason"
        assert component.reason_en and component.reason_kn
        assert component.normalised_value is None
        assert component.contribution is None
        assert component.effective_weight is None


def test_omitted_components_contribute_zero_weight():
    result = compute_demand(DemandInputs(price_rows=_rows(4000, 4200)))
    live = [c for c in result.components if c.available]
    dead = [c for c in result.components if not c.available]

    assert len(live) == 2
    assert len(dead) == 7
    assert sum(c.weight for c in live) == pytest.approx(result.weights_used)
    assert all(c.contribution is None for c in dead)


def test_traded_quantity_missing_is_named_not_estimated():
    result = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            price_history=_history(3900, 4100),
            arrivals=[{"date": "2026-09-01", "quantity": 500}],
        )
    )
    off_take = _components(result)["off_take_ratio"]

    assert off_take.available is False
    assert off_take.reason == "no_traded_quantity"


def test_msp_is_omitted_rather_than_guessed():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )
    msp = _components(result)["msp_premium"]

    assert msp.available is False
    assert msp.reason == "no_msp_resource"
    assert "guess" in msp.reason_en.lower()


def test_trade_count_absent_is_not_read_as_zero_competition():
    trade = _components(compute_demand(DemandInputs(price_rows=_rows(1, 2))))[
        "buyer_competition"
    ]

    assert trade.available is False
    assert trade.reason == "no_trade_count"


def test_zero_trade_count_is_treated_as_absent():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), trade_count=[0, 0])
    )

    assert _components(result)["buyer_competition"].available is False


def test_null_quantities_do_not_count_as_arrivals():
    result = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            arrivals=[{"quantity": None}, {"quantity": None}],
        )
    )

    assert _components(result)["arrival_trend"].reason == "no_arrival_data"


# --------------------------------------------------------------- renormalisation

def test_score_is_the_weighted_mean_of_what_survived():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )

    live = [c for c in result.components if c.available]
    expected = 100.0 * sum(c.contribution for c in live) / result.weights_used

    assert result.score == pytest.approx(expected, abs=0.11)
    assert 0.0 <= result.score <= 100.0


def test_coverage_reports_how_much_of_the_model_was_evaluated():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )

    assert result.coverage == pytest.approx(result.weights_used / NOMINAL_WEIGHT_SUM)
    assert result.coverage < 0.5
    assert result.confidence == "low"


def test_more_inputs_raise_confidence():
    thin = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )
    full = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200, 4100, 3900),
            price_history=_history(3900, 4100, 4300, 4400),
            arrivals=[
                {"date": "2026-08-01", "quantity": 900},
                {"date": "2026-09-01", "quantity": 600},
            ],
            traded_quantity=[500, 480],
            trade_count=[10, 12],
            msp=3500,
            inquiries=[{"id": 1}, {"id": 2}],
            sources=["enam", "mandi_api"],
        )
    )

    assert full.component_count > thin.component_count
    assert full.coverage > thin.coverage
    assert full.confidence != "low"


# ----------------------------------------------------------------- direction

def test_rising_prices_score_higher_than_falling_prices():
    rising = compute_demand(
        DemandInputs(price_history=_history(3000, 3600), price_rows=_rows(4000, 4200))
    )
    falling = compute_demand(
        DemandInputs(price_history=_history(3600, 3000), price_rows=_rows(4000, 4200))
    )

    assert rising.score > falling.score


def test_flat_prices_neutralise_the_momentum_component():
    flat = compute_demand(
        DemandInputs(price_history=_history(3300, 3300), price_rows=_rows(4000, 4200))
    )
    momentum = _components(flat)["price_momentum"]

    assert momentum.raw_value == pytest.approx(0.0)
    assert momentum.normalised_value == pytest.approx(0.5)
    # The other live components still move the index, so only momentum is
    # required to sit exactly on the midpoint.
    assert 40.0 <= flat.score <= 60.0


def test_falling_arrivals_pull_the_index_down():
    tightening = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            price_history=_history(3900, 4100),
            arrivals=[
                {"date": "2026-08-01", "quantity": 900},
                {"date": "2026-09-01", "quantity": 600},
            ],
        )
    )
    glut = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            price_history=_history(3900, 4100),
            arrivals=[
                {"date": "2026-08-01", "quantity": 600},
                {"date": "2026-09-01", "quantity": 900},
            ],
        )
    )

    assert _components(tightening)["arrival_trend"].raw_value < 0
    assert _components(glut)["arrival_trend"].raw_value > 0
    assert (
        _components(tightening)["arrival_trend"].normalised_value
        > _components(glut)["arrival_trend"].normalised_value
    )
    assert tightening.score > glut.score


# --------------------------------------------------------------------- bands

@pytest.mark.parametrize(
    ("score", "band"),
    [
        (95.0, "strong"),
        (70.0, "strong"),
        (69.9, "moderate"),
        (45.0, "moderate"),
        (44.9, "weak"),
        (0.0, "weak"),
    ],
)
def test_band_boundaries(score, band):
    assert band_for(score) == band


def test_band_has_english_and_kannada():
    for band in ("strong", "moderate", "weak", "insufficient_data"):
        result = DemandResult(band=band, score=0.0, component_count=0, weights_used=0.0)
        assert result.band_en and result.band_en != band
        assert result.band_kn and result.band_kn != band


# ------------------------------------------------------------------ language

def test_insufficient_result_says_so_instead_of_naming_a_band():
    result = compute_demand(DemandInputs())

    assert result.derived_label_en == "Not enough data"
    assert result.derived_label_kn
    assert any("at least 2" in line for line in result.explanations_en)
    assert result.explanations_kn


def test_partial_result_is_labelled_as_a_derived_estimate():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )

    assert result.derived_label_en == "Derived estimate - partial data"
    assert "Derived estimate" in result.derived_label_en


def test_explanations_name_what_was_left_out():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )
    joined = " ".join(result.explanations_en)

    assert "Not used:" in joined
    assert "Arrival trend" in joined
    assert "no reachable source" in joined or "not available" in joined


def test_explanations_are_available_in_kannada_too():
    result = compute_demand(
        DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))
    )

    assert len(result.explanations_kn) == len(result.explanations_en)
    assert any("ಒಳಗೊಂಡ" not in line and line for line in result.explanations_kn)


# ------------------------------------------------------------------ payload

def test_as_dict_exposes_the_full_breakdown():
    result = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            price_history=_history(3900, 4100),
            sources=["mandi_api"],
        )
    )
    payload = result.as_dict()

    for key in (
        "score",
        "band",
        "band_en",
        "band_kn",
        "is_derived",
        "derived_label_en",
        "derived_label_kn",
        "coverage",
        "confidence",
        "weights_used",
        "nominal_weight_sum",
        "component_count",
        "components_total",
        "explanations",
        "explanations_kn",
        "sources",
        "components",
        "sample_size",
    ):
        assert key in payload, f"{key} missing from the demand payload"

    assert payload["is_derived"] is True
    assert len(payload["components"]) == len(COMPONENTS)
    assert payload["sources"] == ["mandi_api"]


def test_each_component_payload_names_its_weight_and_omission():
    result = compute_demand(DemandInputs())
    first = result.as_dict()["components"][0]

    for key in (
        "component",
        "label_en",
        "label_kn",
        "weight",
        "direction",
        "available",
        "effective_weight",
        "unavailable_reason",
        "raw_value",
        "normalised_value",
        "contribution",
        "explanation_en",
        "explanation_kn",
    ):
        assert key in first

    assert first["available"] is False
    assert first["effective_weight"] is None
    assert first["unavailable_reason"]


def test_sources_flow_through_to_the_payload():
    result = compute_demand(
        DemandInputs(
            price_rows=_rows(4000, 4200),
            price_history=_history(3900, 4100),
            sources=["mandi_api", ""],
        )
    )

    assert result.sources == ["mandi_api"]


# ------------------------------------------------------------- pure helpers

@pytest.mark.parametrize(
    ("value", "expected"),
    [(-1.0, 0.0), (0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (2.0, 1.0)],
)
def test_clamp01(value, expected):
    assert clamp01(value) == expected


def test_clamp01_survives_nan_and_infinity():
    assert clamp01(float("nan")) == 0.0
    assert clamp01(float("inf")) == 1.0
    assert clamp01(float("-inf")) == 0.0


def test_scale_linear_puts_the_centre_at_half():
    assert scale_linear(0.0, centre=0.0, half_width=30.0) == pytest.approx(0.5)
    assert scale_linear(30.0, centre=0.0, half_width=30.0) == pytest.approx(1.0)
    assert scale_linear(-30.0, centre=0.0, half_width=30.0) == pytest.approx(0.0)
    assert scale_linear(999.0, centre=0.0, half_width=30.0) == pytest.approx(1.0)


def test_compute_demand_is_pure_across_calls():
    inputs = DemandInputs(price_rows=_rows(4000, 4200), price_history=_history(3900, 4100))

    first = compute_demand(inputs)
    second = compute_demand(inputs)

    assert first.as_dict() == second.as_dict()
