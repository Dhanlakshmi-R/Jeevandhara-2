"""Demand index computation.

WHAT THIS IS

A weighted blend of signals that indicate whether a crop is moving well at a
given mandi. It is an **estimate**, never a measurement, and every response says
so.

THE RULE THAT MATTERS MOST

A component whose inputs cannot be read is **omitted, not faked**. If a source
does not publish traded quantity, ``off_take_ratio`` does not get a plausible
stand-in value and it certainly does not get 0 — it gets
``available=False`` and a reason. The remaining weights are then renormalised
and the caller is told how much of the index survived.

Because the score is only as good as its coverage, a response with fewer than
``MIN_COMPONENTS`` available components returns ``band="insufficient_data"``
with **no score**. Returning a number derived from one weak signal would be
worse than returning nothing: it looks actionable and is not.

WHY THE POOL IS SO THIN TODAY

Of the nine components defined below, the sources that are actually reachable
in development supply three: ``price_momentum``, ``market_activity`` and
``price_dispersion``, all from price rows. ``arrival_trend`` needs eNAM, which
returns HTTP 500. ``off_take_ratio`` and ``money_turnover`` need traded
quantity, which eNAM's dashboard provably hardcodes to 0. ``buyer_competition``
needs a trade count that does not exist in the public feed. ``msp_premium``
needs an MSP resource id that has not been confirmed against the live catalogue.
``first_party`` needs inquiries from users.

That leaves 0.40 of the nominal 1.00 weight available by default, rising to
0.45 once a farmer submits an inquiry. The score is reported against the
weights actually used, with ``weights_used`` stored per reading so a 0.40-weight
index can never later be quoted as if it were a full one.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from statistics import fmean
from typing import Any, Iterable, Sequence

# Fewer than this many computable components and we decline to name a band.
MIN_COMPONENTS = 2

# Score bands (0-100).
STRONG_THRESHOLD = 70.0
MODERATE_THRESHOLD = 45.0

#: Component names in weight order, as documented in the schema comment.
#: Weights sum to 1.0 across the full nominal set.
COMPONENT_ORDER: tuple[str, ...] = (
    "price_momentum",
    "market_activity",
    "price_dispersion",
    "arrival_trend",
    "off_take_ratio",
    "money_turnover",
    "buyer_competition",
    "msp_premium",
    "first_party",
)


@dataclass(frozen=True)
class ComponentSpec:
    """One demand input: its nominal weight and what it needs to be computed."""

    name: str
    weight: float
    label_en: str
    label_kn: str
    #: What the raw value means, for the API's `explanation` fields.
    unit_en: str
    unit_kn: str
    #: Feature flag: which inputs this component needs. The demand builder
    #: matches these against what the data actually carries.
    needs: tuple[str, ...] = ()

    @property
    def direction_en(self) -> str:
        """Which way the component pushes the index, in plain language."""
        return {
            "price_momentum": "rising prices indicate stronger demand",
            "market_activity": "more mandis quoting means a more active market",
            "price_dispersion": "the modal price sitting high in its range "
            "indicates buyers bidding up",
            "arrival_trend": "falling arrivals with steady prices indicate tightening supply",
            "off_take_ratio": "more of the day's arrivals sold out indicates stronger take-up",
            "money_turnover": "higher traded value indicates deeper market activity",
            "buyer_competition": "more buyers chasing each lot indicates competition",
            "msp_premium": "prices above the support price indicate a strong market",
            "first_party": "more inquiries from farmers indicate buyer interest",
        }.get(self.name, "")


#: The full nominal component set. Weights sum to 1.0.
COMPONENTS: dict[str, ComponentSpec] = {
    spec.name: spec
    for spec in (
        ComponentSpec(
            name="price_momentum",
            weight=0.25,
            label_en="Price momentum",
            label_kn="ಬೆಲೆ ಚಲನೆ",
            unit_en="change over the last 7 days",
            unit_kn="ಕಳೆದ 7 ದಿನಗಳ ಬದಲಾವಣೆ",
            needs=("price_history",),
        ),
        ComponentSpec(
            name="market_activity",
            weight=0.10,
            label_en="Market activity",
            label_kn="ಮಾರುಕಟ್ಟೆ ಚಟುವಟಿಕೆ",
            unit_en="number of mandis quoting this crop",
            unit_kn="ಈ ಬೆಳೆಯನ್ನು ಉಲ್ಲೇಖಿಸುವ ಮಂಡಿಗಳ ಸಂಖ್ಯೆ",
            needs=("price_rows",),
        ),
        ComponentSpec(
            name="price_dispersion",
            weight=0.05,
            label_en="Price positioning",
            label_kn="ಬೆಲೆ ಸ್ಥಾನ",
            unit_en="where the modal price sits inside its daily range",
            unit_kn="ದಿನದ ವ್ಯಾಪ್ತಿಯಲ್ಲಿ ಮಾಡಲ್ ಬೆಲೆಯ ಸ್ಥಾನ",
            needs=("price_rows",),
        ),
        ComponentSpec(
            name="arrival_trend",
            weight=0.15,
            label_en="Arrival trend",
            label_kn="ಆಗಮನ ಪ್ರವೃತ್ತಿ",
            unit_en="change in arrivals over time",
            unit_kn="ಸಮಯದಲ್ಲಿ ಆಗಮನದ ಬದಲಾವಣೆ",
            needs=("arrivals",),
        ),
        ComponentSpec(
            name="off_take_ratio",
            weight=0.20,
            label_en="Off-take ratio",
            label_kn="ಖರೀದಿ ಅನುಪಾತ",
            unit_en="share of the day's arrivals that sold",
            unit_kn="ದಿನದ ಆಗಮನದಲ್ಲಿ ಮಾರಾಟವಾದ ಭಾಗ",
            needs=("traded_quantity", "arrivals"),
        ),
        ComponentSpec(
            name="money_turnover",
            weight=0.10,
            label_en="Market turnover",
            label_kn="ಮಾರುಕಟ್ಟೆ ವಹಿವಾಟು",
            unit_en="value traded per day",
            unit_kn="ದಿನದ ವಹಿವಾಟು ಮೌಲ್ಯ",
            needs=("traded_quantity",),
        ),
        ComponentSpec(
            name="buyer_competition",
            weight=0.05,
            label_en="Buyer competition",
            label_kn="ಖರೀದಿದಾರರ ಸ್ಪರ್ಧೆ",
            unit_en="number of completed trades",
            unit_kn="ಪೂರ್ಣಗೊಂಡ ವ್ಯವಹಾರಗಳ ಸಂಖ್ಯೆ",
            needs=("trade_count",),
        ),
        ComponentSpec(
            name="msp_premium",
            weight=0.05,
            label_en="Premium over support price",
            label_kn="ಕನಿಷ್ಠ ಬೆಂಬಲ ಬೆಲೆಗಿಂತ ಹೆಚ್ಚುವರಿ",
            unit_en="how far the market price sits above MSP",
            unit_kn="ಮಾರುಕಟ್ಟೆ ಬೆಲೆ ಎಷ್ಟು ಮಟ್ಟಿಗೆ ಎಂಎಸ್‌ಪಿಗಿಂತ ಮೇಲಿದೆ",
            needs=("msp",),
        ),
        ComponentSpec(
            name="first_party",
            weight=0.05,
            label_en="Buyer interest (our own inquiries)",
            label_kn="ಖರೀದಿದಾರರ ಆಸಕ್ತಿ (ನಮ್ಮ ವಿಚಾರಣೆಗಳು)",
            unit_en="inquiries farmers have logged for this crop",
            unit_kn="ರೈತರು ಈ ಬೆಳೆಗಾಗಿ ನಮೂದಿಸಿದ ವಿಚಾರಣೆಗಳು",
            needs=("inquiries",),
        ),
    )
}

NOMINAL_WEIGHT_SUM = round(sum(spec.weight for spec in COMPONENTS.values()), 6)

if abs(NOMINAL_WEIGHT_SUM - 1.0) > 1e-9:  # pragma: no cover - guard against weight drift
    raise RuntimeError(
        f"Demand component weights must sum to 1.0, got {NOMINAL_WEIGHT_SUM}. "
        "Any weight change has to be re-derived against the whole set, so this "
        "check stops a partial edit from shipping."
    )


@dataclass
class ComponentResult:
    """A component's outcome: computed, or omitted with a stated reason."""

    name: str
    weight: float
    available: bool
    raw_value: float | None = None
    normalised_value: float | None = None  # 0-1, before weight applied
    contribution: float | None = None
    sample_size: int | None = None
    reason: str | None = None
    reason_en: str | None = None
    reason_kn: str | None = None
    explanation_en: str | None = None
    explanation_kn: str | None = None
    source_name: str | None = None

    @property
    def spec(self) -> ComponentSpec:
        return COMPONENTS[self.name]

    @property
    def label_en(self) -> str:
        return self.spec.label_en

    @property
    def label_kn(self) -> str:
        return self.spec.label_kn

    @property
    def direction_en(self) -> str:
        return self.spec.direction_en

    @property
    def effective_weight(self) -> float | None:
        """Weight this component actually carried, or None when omitted."""
        return self.weight if self.available else None

    def as_dict(self) -> dict[str, Any]:
        spec = self.spec
        return {
            "component": self.name,
            "label_en": spec.label_en,
            "label_kn": spec.label_kn,
            "weight": self.weight,
            "direction": spec.direction_en,
            "available": self.available,
            "effective_weight": self.effective_weight,
            "unavailable_reason": self.reason,
            "raw_value": self.raw_value,
            "normalised_value": self.normalised_value,
            "contribution": self.contribution,
            "sample_size": self.sample_size,
            "explanation_en": self.explanation_en,
            "explanation_kn": self.explanation_kn,
            "source": self.source_name,
        }


@dataclass
class DemandResult:
    """The whole index: score (or none), band, coverage and components."""

    band: str
    score: float | None
    component_count: int
    weights_used: float
    components: list[ComponentResult] = field(default_factory=list)
    confidence: str = "low"
    sample_size: int | None = None
    explanations_en: list[str] = field(default_factory=list)
    explanations_kn: list[str] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)

    @property
    def band_en(self) -> str:
        return {
            "strong": "Strong demand",
            "moderate": "Moderate demand",
            "weak": "Weak demand",
            "insufficient_data": "Not enough data yet",
        }.get(self.band, self.band)

    @property
    def band_kn(self) -> str:
        return {
            "strong": "ಬಲವಾದ ಬೇಡಿಕೆ",
            "moderate": "ಮಧ್ಯಮ ಬೇಡಿಕೆ",
            "weak": "ದುರ್ಬಲ ಬೇಡಿಕೆ",
            "insufficient_data": "ಇನ್ನೂ ಸಾಕಷ್ಟು ದತ್ತಾಂಶವಿಲ್ಲ",
        }.get(self.band, self.band)

    @property
    def is_insufficient(self) -> bool:
        return self.band == "insufficient_data"

    @property
    def coverage(self) -> float:
        """Share of the nominal weight that could actually be computed."""
        return round(self.weights_used / NOMINAL_WEIGHT_SUM, 4) if NOMINAL_WEIGHT_SUM else 0.0

    @property
    def derived_label_en(self) -> str:
        """The string the UI must show next to the number."""
        if self.is_insufficient:
            return "Not enough data"
        if self.coverage < 0.8:
            return "Derived estimate - partial data"
        return "Derived estimate"

    @property
    def derived_label_kn(self) -> str:
        if self.is_insufficient:
            return "ಸಾಕಷ್ಟು ದತ್ತಾಂಶವಿಲ್ಲ"
        if self.coverage < 0.8:
            return "ಉತ್ಪಾದಿಸಿದ ಅಂದಾಜು - ಭಾಗಶಃ ದತ್ತಾಂಶ"
        return "ಉತ್ಪಾದಿಸಿದ ಅಂದಾಜು"

    def as_dict(self) -> dict[str, Any]:
        return {
            "score": self.score,
            "band": self.band,
            "band_en": self.band_en,
            "band_kn": self.band_kn,
            "is_derived": True,
            "derived_label_en": self.derived_label_en,
            "derived_label_kn": self.derived_label_kn,
            "component_count": self.component_count,
            "components_total": len(COMPONENTS),
            "weights_used": round(self.weights_used, 4),
            "nominal_weight_sum": NOMINAL_WEIGHT_SUM,
            "coverage": self.coverage,
            "confidence": self.confidence,
            "sample_size": self.sample_size,
            "explanations": self.explanations_en,
            "explanations_kn": self.explanations_kn,
            "sources": self.sources,
            "components": [c.as_dict() for c in self.components],
        }


# ---------------------------------------------------------------- inputs


@dataclass
class DemandInputs:
    """Everything the index can be computed from.

    Every field defaults to empty/None. A component whose inputs are absent
    stays unavailable, which is the entire mechanism of the honesty guarantee -
    there is no path from "field missing" to "plausible value".
    """

    #: Chronological daily average prices, oldest first. Each item needs
    #: at least a date and a modal price; `data_points` is optional.
    price_history: Sequence[dict[str, Any]] = field(default_factory=list)
    #: Latest price rows (one per mandi, ideally).
    price_rows: Sequence[dict[str, Any]] = field(default_factory=list)
    #: Chronological arrival quantities, oldest first, as quintals.
    arrivals: Sequence[dict[str, Any]] = field(default_factory=list)
    #: Traded quantity per period, in quintals. Almost never published.
    traded_quantity: Sequence[float] | None = None
    #: Completed trade count per period. Almost never published.
    trade_count: Sequence[int] | None = None
    #: MSP for this commodity, in INR per quintal. NULL resource today.
    msp: float | None = None
    #: First-party inquiry rows for this mandi+commodity.
    inquiries: Sequence[dict[str, Any]] = field(default_factory=list)

    #: Provenance of the inputs themselves.
    sources: list[str] = field(default_factory=list)
    observed_at: datetime | None = None

    def has(self, need: str) -> bool:
        """True when the data needed for `need` is actually present.

        Deliberately checks substance, not presence of a key: a non-empty
        `arrivals` list containing only None quantities does not count, because
        it would produce a component that computes to garbage.
        """
        if need == "price_history":
            return bool(_usable(self.price_history, "modal_price"))
        if need == "price_rows":
            return bool(self.price_rows)
        if need == "arrivals":
            return bool(_usable(self.arrivals, "quantity"))
        if need == "traded_quantity":
            return self.traded_quantity is not None and any(
                v is not None for v in self.traded_quantity
            )
        if need == "trade_count":
            return self.trade_count is not None and any(v for v in self.trade_count)
        if need == "msp":
            return self.msp is not None and self.msp > 0
        if need == "inquiries":
            return bool(self.inquiries)
        return False

    def missing(self, need: str) -> bool:
        return not self.has(need)


def _usable(rows: Iterable[dict[str, Any]], key: str) -> list[dict[str, Any]]:
    out = []
    for row in rows:
        value = row.get(key)
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            out.append(row)
    return out


# -------------------------------------------------------- normalisation


def clamp01(value: float) -> float:
    if math.isnan(value):
        return 0.0
    return max(0.0, min(1.0, value))


def scale_linear(value: float, centre: float, half_width: float) -> float:
    """Map `value` onto 0-1 with `centre` becoming 0.5.

    Used where the input is an unbounded physical quantity (a percentage
    change) and no natural 0/1 exists. `half_width` is the distance from centre
    that saturates the scale, chosen from domain judgement and stated in the
    explanation text so a reader can see the assumption.
    """
    if half_width <= 0:
        return clamp01(value)
    return clamp01(0.5 + (value - centre) / (2.0 * half_width))


def scale_log(count: float, saturation: float) -> float:
    """Map a non-negative count onto 0-1 with logarithmic saturation.

    Counts of mandis or inquiries are skewed: going from 1 to 3 is a big deal,
    from 50 to 52 is not. A log scale reflects that, and `saturation` is the
    count at which the component is considered full strength.
    """
    if count <= 0:
        return 0.0
    if saturation <= 1:
        return 1.0
    return clamp01(math.log1p(count) / math.log1p(saturation))


# ------------------------------------------------------------- compute


def _momentum_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["price_momentum"]
    history = [
        r for r in _usable(inputs.price_history, "modal_price")
        if r.get("date")
    ]
    if len(history) < 2:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="insufficient_history",
            reason_en="Not enough days of price history to measure a trend.",
            reason_kn="ಪ್ರವೃತ್ತಿ ಅಳೆಯಲು ಸಾಕಷ್ಟು ದಿನಗಳ ಬೆಲೆ ಇತಿಹಾಸ ಇಲ್ಲ.",
        )

    history = sorted(history, key=lambda r: str(r["date"]))
    latest = float(history[-1]["modal_price"])
    # Compare against the last observation on or before 7 days earlier; fall
    # back to the oldest point when the window is not covered.
    target_date = _days_before(str(history[-1]["date"]), 7)
    baseline_row = None
    for row in history:
        if str(row["date"]) <= target_date:
            baseline_row = row
    if baseline_row is None:
        baseline_row = history[0]
    baseline = float(baseline_row["modal_price"])
    if baseline <= 0:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="non_positive_baseline",
            reason_en="Baseline price was not usable for a percentage change.",
            reason_kn="ಪ್ರಾರಂಭ ಬೆಲೆ ಶೇಕಡಾ ಬದಲಾವಣೆಗೆ ಬಳಕೆಗೆ ಯೋಗ್ಯವಾಗಿರಲಿಲ್ಲ.",
        )

    change_pct = ((latest - baseline) / baseline) * 100.0
    normalised = scale_linear(change_pct, centre=0.0, half_width=15.0)
    samples = len(history)

    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=round(change_pct, 2),
        normalised_value=round(normalised, 4),
        sample_size=samples,
        explanation_en=(
            f"Modal price moved {change_pct:+.1f}% from {baseline_row['date']} to "
            f"{history[-1]['date']}. 15% either way is treated as neutral."
        ),
        explanation_kn=(
            f"ಮಾಡಲ್ ಬೆಲೆ {baseline_row['date']} ರಿಂದ {history[-1]['date']} ವರೆಗೆ "
            f"{change_pct:+.1f}% ಬದಲಾಗಿದೆ. ಎರಡೆಡೆ 15% ವರೆಗೆ ತಟಸ್ಥ ಎಂದು ಪರಿಗಣಿಸಲಾಗುತ್ತದೆ."
        ),
        source_name=_first_source(inputs, "price_history"),
    )


def _market_activity_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["market_activity"]
    rows = inputs.price_rows
    if not rows:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_price_rows",
            reason_en="No price rows available to count active mandis.",
            reason_kn="ಸಕ್ರಿಯ ಮಂಡಿಗಳನ್ನು ಎಣಿಸಲು ಬೆಲೆ ಸಾಲುಗಳಿಲ್ಲ.",
        )

    mandis = {str(r.get("market") or "").strip() for r in rows if r.get("market")}
    mandis.discard("")
    districts = {str(r.get("district") or "").strip() for r in rows if r.get("district")}
    districts.discard("")
    count = len(mandis) or len(rows)
    normalised = scale_log(count, saturation=30)

    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=float(count),
        normalised_value=round(normalised, 4),
        sample_size=len(rows),
        explanation_en=(
            f"{count} mandi{'s' if count != 1 else ''}"
            + (f" across {len(districts)} district{'s' if len(districts) != 1 else ''}" if districts else "")
            + " are quoting this crop. 30 mandis is treated as full strength."
        ),
        explanation_kn=(
            f"{count} ಮಂಡಿಗಳು ಈ ಬೆಳೆಯ ಬೆಲೆ ನೀಡುತ್ತಿವೆ"
            + (f", {len(districts)} ಜಿಲ್ಲೆಗಳಲ್ಲಿ" if districts else "")
            + ". 30 ಮಂಡಿಗಳು ಪೂರ್ಣ ಪ್ರಮಾಣ ಎಂದು ಪರಿಗಣಿಸಲಾಗುತ್ತದೆ."
        ),
        source_name=_first_source(inputs, "price_rows"),
    )


def _price_dispersion_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["price_dispersion"]
    rows = _usable(inputs.price_rows, "modal_price")
    if not rows:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_price_rows",
            reason_en="No price rows with a usable range.",
            reason_kn="ಬಳಕೆಗೆ ಯೋಗ್ಯ ವ್ಯಾಪ್ತಿಯೊಂದಿಗೆ ಬೆಲೆ ಸಾಲುಗಳಿಲ್ಲ.",
        )

    positions: list[float] = []
    for row in rows:
        low = _num(row.get("min_price"))
        high = _num(row.get("max_price"))
        modal = _num(row.get("modal_price"))
        if modal is None or low is None or high is None:
            continue
        if high <= low:
            # A collapsed range gives no information about where the modal sits.
            continue
        positions.append(clamp01((modal - low) / (high - low)))
    if not positions:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_usable_range",
            reason_en="No row had a usable minimum, modal and maximum price.",
            reason_kn="ಕನಿಷ್ಠ, ಮಾಡಲ್ ಮತ್ತು ಗರಿಷ್ಠ ಬೆಲೆ ಹೊಂದಿದ ಯಾವುದೇ ಸಾಲು ಇರಲಿಲ್ಲ.",
        )

    mean_position = fmean(positions)
    normalised = clamp01(mean_position)

    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=round(mean_position, 4),
        normalised_value=round(normalised, 4),
        sample_size=len(positions),
        explanation_en=(
            f"The modal price sits {mean_position * 100:.0f}% of the way up its "
            "daily range across the sampled rows. Higher means buyers are "
            "pushing towards the top of the day's prices."
        ),
        explanation_kn=(
            f"ಸ್ಯಾಂಪಲ್ ಮಾಡಿದ ಸಾಲುಗಳಲ್ಲಿ ಮಾಡಲ್ ಬೆಲೆ ದಿನದ ವ್ಯಾಪ್ತಿಯ {mean_position * 100:.0f}% "
            "ನಷ್ಟು ಎತ್ತರದಲ್ಲಿದೆ. ಹೆಚ್ಚು ಎಂದರೆ ಖರೀದಿದಾರರು ದಿನದ ಗರಿಷ್ಠ ಬೆಲೆ ಕಡೆಗೆ "
            "ಸಾಗುತ್ತಿದ್ದಾರೆ ಎಂದರ್ಥ."
        ),
        source_name=_first_source(inputs, "price_rows"),
    )


def _arrival_trend_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["arrival_trend"]
    rows = [r for r in _usable(inputs.arrivals, "quantity") if r.get("date")]
    if len(rows) < 2:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_arrival_data",
            reason_en=(
                "Arrival quantities are not available from any reachable source. "
                "eNAM, the only feed that publishes them, is returning errors."
            ),
            reason_kn=(
                "ಯಾವುದೇ ಲಭ್ಯ ಮೂಲದಿಂದ ಆಗಮನ ಪ್ರಮಾಣ ಲಭ್ಯವಿಲ್ಲ. ಅವುಗಳನ್ನು "
                "ಪ್ರಕಟಿಸುವ ಏಕೈಕ ಮೂಲವಾದ eNAM ದೋಷಗಳನ್ನು ನೀಡುತ್ತಿದೆ."
            ),
        )

    rows = sorted(rows, key=lambda r: str(r["date"]))
    recent = rows[-1]
    older = rows[0]
    latest_q = float(recent["quantity"])
    older_q = float(older["quantity"])
    if older_q <= 0:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="zero_baseline",
            reason_en="Baseline arrivals were zero, so no percentage can be computed.",
            reason_kn="ಪ್ರಾರಂಭ ಆಗಮನ ಶೂನ್ಯವಾಗಿದ್ದು, ಶೇಕಡಾವಾರು ಲೆಕ್ಕಹಾಕಲಾಗದು.",
        )

    change_pct = ((latest_q - older_q) / older_q) * 100.0
    # Inverted on purpose: fewer arrivals, everything else equal, means tighter
    # supply and a stronger position for whoever still has stock to sell. The
    # direction note states this rather than leaving the sign implicit.
    normalised = scale_linear(-change_pct, centre=0.0, half_width=25.0)

    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=round(change_pct, 2),
        normalised_value=round(normalised, 4),
        sample_size=len(rows),
        explanation_en=(
            f"Arrivals changed {change_pct:+.1f}% from {older['date']} to "
            f"{recent['date']}. Fewer arrivals mean a tighter market, so the "
            "index rises when arrivals fall. 25% either way is neutral."
        ),
        explanation_kn=(
            f"ಆಗಮನ {older['date']} ರಿಂದ {recent['date']} ವರೆಗೆ {change_pct:+.1f}% "
            "ಬದಲಾಗಿದೆ. ಕಡಿಮೆ ಆಗಮನ ಎಂದರೆ ತುಸು ಬಿಗಿ ಮಾರುಕಟ್ಟೆ, ಆದ್ದರಿಂದ ಆಗಮನ "
            "ಕಡಿಮೆಯಾದಾಗ ಸೂಚ್ಯಂಕ ಏರುತ್ತದೆ. ಎರಡೆಡೆ 25% ವರೆಗೆ ತಟಸ್ಥ."
        ),
        source_name=_first_source(inputs, "arrivals"),
    )


def _unavailable(name: str, code: str, reason_en: str, reason_kn: str) -> ComponentResult:
    """Omit a component with an explicit, human-readable reason.

    Every omission path goes through here, so there is no way to leave a
    component available-with-no-data, which would silently weight it at its
    nominal weight while contributing nothing.
    """
    spec = COMPONENTS[name]
    return ComponentResult(
        name=name,
        weight=spec.weight,
        available=False,
        reason=code,
        reason_en=reason_en,
        reason_kn=reason_kn,
    )


def _off_take_component(inputs: DemandInputs) -> ComponentResult:
    if inputs.missing("arrivals"):
        return _unavailable(
            "off_take_ratio",
            "no_arrival_data",
            "Arrival quantities are not available from any reachable source.",
            "ಯಾವುದೇ ಲಭ್ಯ ಮೂಲದಿಂದ ಆಗಮನ ಪ್ರಮಾಣ ಲಭ್ಯವಿಲ್ಲ.",
        )
    if inputs.missing("traded_quantity"):
        return _unavailable(
            "off_take_ratio",
            "no_traded_quantity",
            "The public eNAM dashboard does not publish traded quantity — its "
            "trades column is hardcoded to 0. This component is omitted rather "
            "than estimated.",
            "ಸಾರ್ವಜನಿಕ eNAM ಡ್ಯಾಶ್‌ಬೋರ್ಡ್ ಮಾರಾಟ ಪ್ರಮಾಣವನ್ನು ಪ್ರಕಟಿಸುವುದಿಲ್ಲ — "
            "ಅದರ ವ್ಯವಹಾರ ಕಾಲಮ್ ಶೂನ್ಯಕ್ಕೆ ಹೊಂದಿಕೆ ಮಾಡಲಾಗಿದೆ. ಈ ಅಂಶವನ್ನು ಅಂದಾಜು "
            "ಮಾಡದೆ ಕೈಬಿಡಲಾಗಿದೆ.",
        )
    return _unavailable(
        "off_take_ratio",
        "uncomputable",
        "Off-take could not be computed from the supplied data.",
        "ನೀಡಿದ ದತ್ತಾಂಶದಿಂದ ಖರೀದಿ ಅನುಪಾತವನ್ನು ಲೆಕ್ಕಹಾಕಲಾಗದು.",
    )


def _money_turnover_component(inputs: DemandInputs) -> ComponentResult:
    if inputs.missing("traded_quantity"):
        return _unavailable(
            "money_turnover",
            "no_traded_quantity",
            "Traded quantity is not published by any reachable source, so "
            "turnover cannot be computed. Omitted rather than estimated.",
            "ಯಾವುದೇ ಲಭ್ಯ ಮೂಲವು ಮಾರಾಟ ಪ್ರಮಾಣವನ್ನು ಪ್ರಕಟಿಸದ ಕಾರಣ ವಹಿವಾಟು "
            "ಲೆಕ್ಕಹಾಕಲಾಗದು. ಅಂದಾಜು ಮಾಡದೆ ಕೈಬಿಡಲಾಗಿದೆ.",
        )
    return _unavailable(
        "money_turnover",
        "uncomputable",
        "Turnover could not be computed from the supplied data.",
        "ನೀಡಿದ ದತ್ತಾಂಶದಿಂದ ವಹಿವಾಟನ್ನು ಲೆಕ್ಕಹಾಕಲಾಗದು.",
    )


def _buyer_competition_component(inputs: DemandInputs) -> ComponentResult:
    if inputs.missing("trade_count"):
        return _unavailable(
            "buyer_competition",
            "no_trade_count",
            "No reachable source publishes a completed-trade count. Omitted "
            "rather than treated as zero, which would mean 'no competition'.",
            "ಯಾವುದೇ ಲಭ್ಯ ಮೂಲವು ಪೂರ್ಣಗೊಂಡ ವ್ಯವಹಾರಗಳ ಸಂಖ್ಯೆಯನ್ನು ಪ್ರಕಟಿಸುವುದಿಲ್ಲ. "
            "ಶೂನ್ಯ ಎಂದು ಪರಿಗಣಿಸದೆ ಕೈಬಿಡಲಾಗಿದೆ — ಅದರರ್ಥ 'ಸ್ಪರ್ಧೆ ಇಲ್ಲ' ಆಗುತ್ತಿತ್ತು.",
        )
    return _unavailable(
        "buyer_competition",
        "uncomputable",
        "Buyer competition could not be computed from the supplied data.",
        "ನೀಡಿದ ದತ್ತಾಂಶದಿಂದ ಖರೀದಿದಾರರ ಸ್ಪರ್ಧೆಯನ್ನು ಲೆಕ್ಕಹಾಕಲಾಗದು.",
    )


def _msp_premium_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["msp_premium"]
    if inputs.missing("msp"):
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_msp_resource",
            reason_en=(
                "No support-price resource has been confirmed against the live "
                "catalogue, so MSP is unknown for this crop. A guessed resource "
                "id could return a different crop's support price."
            ),
            reason_kn=(
                "ಯಾವುದೇ ಬೆಂಬಲ ಬೆಲೆ ಮೂಲವು ಲೈವ್ ಕ್ಯಾಟಲಾಗ್‌ನೊಂದಿಗೆ ದೃಢೀಕರಿಸಲ್ಪಟ್ಟಿಲ್ಲ, "
                "ಆದ್ದರಿಂದ ಈ ಬೆಳೆಗೆ ಎಂಎಸ್‌ಪಿ ತಿಳಿದಿಲ್ಲ. ಊಹಿತ ಮೂಲ ಐಡಿ ಬೇರೆ ಬೆಳೆಯ "
                "ಬೆಂಬಲ ಬೆಲೆಯನ್ನು ಮರಳಿಸಬಹುದು."
            ),
        )
    if inputs.missing("price_rows"):
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_current_price",
            reason_en="Support price found but no current market price to compare against.",
            reason_kn="ಬೆಂಬಲ ಬೆಲೆ ಸಿಕ್ಕಿದೆ ಆದರೆ ಹೋಲಿಸಲು ಪ್ರಸ್ತುತ ಮಾರುಕಟ್ಟೆ ಬೆಲೆ ಇಲ್ಲ.",
        )

    modal = next(
        (m for m in (_num(r.get("modal_price")) for r in inputs.price_rows) if m),
        None,
    )
    if modal is None or inputs.msp is None or inputs.msp <= 0:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_current_price",
            reason_en="Support price found but no usable market price.",
            reason_kn="ಬೆಂಬಲ ಬೆಲೆ ಸಿಕ್ಕಿದೆ ಆದರೆ ಬಳಕೆಗೆ ಯೋಗ್ಯ ಮಾರುಕಟ್ಟೆ ಬೆಲೆ ಇಲ್ಲ.",
        )

    premium_pct = ((modal - inputs.msp) / inputs.msp) * 100.0
    normalised = scale_linear(premium_pct, centre=0.0, half_width=30.0)
    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=round(premium_pct, 2),
        normalised_value=round(normalised, 4),
        sample_size=1,
        explanation_en=(
            f"The modal price sits {premium_pct:+.1f}% relative to the support "
            "price. 30% either way is treated as neutral."
        ),
        explanation_kn=(
            f"ಮಾಡಲ್ ಬೆಲೆ ಬೆಂಬಲ ಬೆಲೆಗೆ ಹೋಲಿಸಿ {premium_pct:+.1f}% ಇದೆ. ಎರಡೆಡೆ "
            "30% ವರೆಗೆ ತಟಸ್ಥ ಎಂದು ಪರಿಗಣಿಸಲಾಗುತ್ತದೆ."
        ),
        source_name=_first_source(inputs, "msp"),
    )


def _first_party_component(inputs: DemandInputs) -> ComponentResult:
    spec = COMPONENTS["first_party"]
    rows = list(inputs.inquiries)
    if not rows:
        return ComponentResult(
            name=spec.name,
            weight=spec.weight,
            available=False,
            reason="no_inquiries",
            reason_en=(
                "No farmers have logged an inquiry for this crop here yet. This is "
                "the one component we can improve directly — submit an inquiry from "
                "the market screen and it starts counting."
            ),
            reason_kn=(
                "ಈ ಸ್ಥಳದಲ್ಲಿ ಈ ಬೆಳೆಗಾಗಿ ಯಾವುದೇ ರೈತರು ವಿಚಾರಣೆ ನಮೂದಿಸಿಲ್ಲ. ಇದು ನೇರವಾಗಿ "
                "ಸುಧಾರಿಸಬಹುದಾದ ಏಕೈಕ ಅಂಶ — ಮಾರುಕಟ್ಟೆ ಪರದೆಯಿಂದ ವಿಚಾರಣೆ ಸಲ್ಲಿಸಿ, ಅದು "
                "ಲೆಕ್ಕಕ್ಕೆ ಬರಲು ಆರಂಭಿಸುತ್ತದೆ."
            ),
        )

    count = len(rows)
    normalised = scale_log(count, saturation=15)

    return ComponentResult(
        name=spec.name,
        weight=spec.weight,
        available=True,
        raw_value=float(count),
        normalised_value=round(normalised, 4),
        sample_size=count,
        explanation_en=(
            f"{count} farmer inquiry{'ies' if count != 1 else 'y'} for this crop. "
            "15 inquiries is treated as full strength."
        ),
        explanation_kn=(
            f"ಈ ಬೆಳೆಗಾಗಿ {count} ರೈತ ವಿಚಾರಣೆಗಳು. 15 ವಿಚಾರಣೆಗಳು ಪೂರ್ಣ ಪ್ರಮಾಣ ಎಂದು "
            "ಪರಿಗಣಿಸಲಾಗುತ್ತದೆ."
        ),
        source_name="inquiries",
    )


_COMPUTE = {
    "price_momentum": _momentum_component,
    "market_activity": _market_activity_component,
    "price_dispersion": _price_dispersion_component,
    "arrival_trend": _arrival_trend_component,
    "off_take_ratio": _off_take_component,
    "money_turnover": _money_turnover_component,
    "buyer_competition": _buyer_competition_component,
    "msp_premium": _msp_premium_component,
    "first_party": _first_party_component,
}


def compute_demand(inputs: DemandInputs) -> DemandResult:
    """Build the index from whatever inputs are actually present.

    Always returns every component, including the omitted ones, so the caller
    can show exactly what the score is and is not built from. The omissions are
    the useful part of the answer.
    """
    components = [_COMPUTE[name](inputs) for name in COMPONENT_ORDER]

    available = [c for c in components if c.available and c.normalised_value is not None]
    weights_used = sum(c.weight for c in available)

    for component in components:
        if component.available and weights_used > 0:
            # Contribution is expressed against the full nominal weight, so the
            # score is the weighted mean of the available components.
            component.contribution = round(
                component.weight * (component.normalised_value or 0.0), 6
            )

    component_count = len(available)
    sources = [s for s in inputs.sources if s]

    if component_count < MIN_COMPONENTS or weights_used <= 0:
        return DemandResult(
            band="insufficient_data",
            score=None,
            component_count=component_count,
            weights_used=round(weights_used, 4),
            components=components,
            confidence="low",
            sample_size=_sample_size(components),
            explanations_en=_insufficient_explanations(components),
            explanations_kn=_insufficient_explanations_kn(components),
            sources=sources,
        )

    score = 100.0 * (sum(c.contribution or 0.0 for c in available) / weights_used)
    score = round(max(0.0, min(100.0, score)), 1)

    if score >= STRONG_THRESHOLD:
        band = "strong"
    elif score >= MODERATE_THRESHOLD:
        band = "moderate"
    else:
        band = "weak"

    return DemandResult(
        band=band,
        score=score,
        component_count=component_count,
        weights_used=round(weights_used, 4),
        components=components,
        confidence=_confidence(component_count, weights_used),
        sample_size=_sample_size(components),
        explanations_en=_available_explanations(components, score),
        explanations_kn=_available_explanations_kn(components, score),
        sources=sources,
    )


def _confidence(component_count: int, weights_used: float) -> str:
    """Coverage decides confidence, not the score's apparent precision.

    A 0.40-weight index made of three price-derived components is `low` no
    matter how tidy the number looks, because two thirds of the nominal model
    was never evaluated.
    """
    coverage = weights_used / NOMINAL_WEIGHT_SUM if NOMINAL_WEIGHT_SUM else 0.0
    if coverage >= 0.8 and component_count >= 5:
        return "high"
    if coverage >= 0.5 and component_count >= 3:
        return "medium"
    return "low"


def _sample_size(components: Sequence[ComponentResult]) -> int | None:
    sizes = [c.sample_size for c in components if c.sample_size]
    return max(sizes) if sizes else None


def _available_explanations(
    components: Sequence[ComponentResult], score: float
) -> list[str]:
    """Plain-language read-out: what moved the number, and what was left out."""
    out: list[str] = [
        f"Derived estimate from {sum(1 for c in components if c.available)} "
        f"of {len(components)} possible inputs."
    ]
    ranked = sorted(
        (c for c in components if c.available and c.contribution),
        key=lambda c: c.contribution,
        reverse=True,
    )
    for component in ranked[:3]:
        out.append(f"{component.label_en}: {component.explanation_en}")
    omitted = [c for c in components if not c.available]
    if omitted:
        out.append(
            "Not used: "
            + "; ".join(f"{c.label_en} ({c.reason_en})" for c in omitted)
            + "."
        )
    return out


def _available_explanations_kn(
    components: Sequence[ComponentResult], score: float
) -> list[str]:
    out: list[str] = [
        f"{len(components)} ಸಾಧ್ಯ ಮೂಲಗಳಲ್ಲಿ "
        f"{sum(1 for c in components if c.available)} ರಿಂದ ಉತ್ಪಾದಿಸಿದ ಅಂದಾಜು."
    ]
    ranked = sorted(
        (c for c in components if c.available and c.contribution),
        key=lambda c: c.contribution,
        reverse=True,
    )
    for component in ranked[:3]:
        out.append(f"{component.label_kn}: {component.explanation_kn}")
    omitted = [c for c in components if not c.available]
    if omitted:
        out.append(
            "ಬಳಸಲಾಗಿಲ್ಲ: "
            + "; ".join(f"{c.label_kn} ({c.reason_kn})" for c in omitted)
            + "."
        )
    return out


def _insufficient_explanations(components: Sequence[ComponentResult]) -> list[str]:
    available = [c for c in components if c.available]
    omitted = [c for c in components if not c.available]
    out = [
        f"Only {len(available)} of {len(components)} inputs could be computed, "
        f"and at least {MIN_COMPONENTS} are needed before a number is worth "
        "showing. No score is given rather than a misleading one."
    ]
    for component in omitted:
        out.append(f"{component.label_en}: {component.reason_en}")
    if available:
        out.append(
            "Computed but not used on its own: "
            + ", ".join(f"{c.label_en} ({c.explanation_en})" for c in available)
            + "."
        )
    return out


def _insufficient_explanations_kn(components: Sequence[ComponentResult]) -> list[str]:
    available = [c for c in components if c.available]
    omitted = [c for c in components if not c.available]
    out = [
        f"{len(components)} ಮೂಲಗಳಲ್ಲಿ ಕೇವಲ {len(available)} ಅನ್ನು ಲೆಕ್ಕಹಾಕಲಾಯಿತು, "
        f"ಸಂಖ್ಯೆ ತೋರಿಸಲು ಕನಿಷ್ಠ {MIN_COMPONENTS} ಬೇಕು. ತಪ್ಪು ದಾರಿ ತೋರಿಸುವ ಬದಲು "
        "ಯಾವುದೇ ಅಂಕಿ ನೀಡಲಾಗಿಲ್ಲ."
    ]
    for component in omitted:
        out.append(f"{component.label_kn}: {component.reason_kn}")
    if available:
        out.append(
            "ಲೆಕ್ಕಹಾಕಲಾಗಿದೆ ಆದರೆ ಒಂಟಿಯಾಗಿ ಬಳಸಲಾಗಿಲ್ಲ: "
            + ", ".join(f"{c.label_kn} ({c.explanation_kn})" for c in available)
            + "."
        )
    return out


# ------------------------------------------------------------- helpers


def _num(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def _days_before(iso_date: str, days: int) -> str:
    try:
        parsed = datetime.strptime(iso_date, "%Y-%m-%d").date()
    except ValueError:
        return iso_date
    return (parsed - timedelta(days=days)).isoformat()


def _first_source(inputs: DemandInputs, field_name: str) -> str | None:
    if inputs.sources:
        return inputs.sources[0]
    return None


def band_for(score: float | None) -> str:
    """Map a 0-100 score onto a band, sharing the thresholds above."""
    if score is None:
        return "insufficient_data"
    if score >= STRONG_THRESHOLD:
        return "strong"
    if score >= MODERATE_THRESHOLD:
        return "moderate"
    return "weak"


__all__ = [
    "COMPONENTS",
    "COMPONENT_ORDER",
    "ComponentResult",
    "ComponentSpec",
    "DemandInputs",
    "DemandResult",
    "MIN_COMPONENTS",
    "NOMINAL_WEIGHT_SUM",
    "band_for",
    "clamp01",
    "compute_demand",
    "scale_linear",
    "scale_log",
]