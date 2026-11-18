"""Rule-based assistant for `/ai/chat`.

There is no LLM dependency here on purpose. The assistant has to work in a
fresh checkout with no keys, so every reply is composed from the data the
backend already serves (live weather, the offline gazetteer) plus the app's
own feature map. When `LLM_API_KEY` *is* configured the same streaming
interface is kept and the composed answer is passed to the provider instead,
so the app never has to change shape.

The reply is emitted as SSE `delta` events so the Flutter client gets genuine
token-by-token streaming, plus `status`, `citation` and `tool` events.
"""

from __future__ import annotations

import asyncio
import json
import os

try:
    import httpx
except Exception:  # pragma: no cover
    httpx = None  # type: ignore
import re
from dataclasses import dataclass, field
from datetime import date
from typing import AsyncIterator

from . import places, weather_service

# Per-chunk delay. Small enough that a full answer lands in about a second,
# large enough that the caret and shimmer are actually visible.
CHUNK_DELAY = float(os.getenv("AI_CHUNK_DELAY", "0.022"))
STATUS_DELAY = float(os.getenv("AI_STATUS_DELAY", "0.35"))

# Where the answer came from. The client renders these as chips.
KIND_SOURCE = "source"
KIND_WEATHER = "weather"
KIND_PRICE = "price"
KIND_APP = "app"


@dataclass
class Citation:
    label: str
    kind: str = KIND_SOURCE
    detail: str = ""

    def as_event(self) -> dict[str, str]:
        return {"label": self.label, "kind": self.kind, "detail": self.detail}


@dataclass
class ToolCall:
    """A card the client renders inline in the assistant bubble."""

    tool: str
    title: str
    payload: dict = field(default_factory=dict)

    def as_event(self) -> dict:
        return {"tool": self.tool, "title": self.title, "payload": self.payload}


@dataclass
class Reply:
    text: str
    citations: list[Citation] = field(default_factory=list)
    tools: list[ToolCall] = field(default_factory=list)
    # Status lines shown in the thinking indicator before the first token.
    thinking: list[str] = field(default_factory=list)


# ---------------------------------------------------------------- intent

WEATHER_WORDS = re.compile(
    r"\b(weather|rain|temperature|temp|humid|wind|storm|forecast|hot|cold|"
    r"monsoon|ಹವಾಮಾನ|ಮಳೆ|ಉಷ್ಣ|ತಂಪ)\w*",
    re.IGNORECASE,
)
PRICE_WORDS = re.compile(
    r"\b(price|rate|mandi|market|mandi|quintal|"
    r"ದರ|ಬೆಲೆ|ಮಾರುಕಟ್ಟೆ|ಕಿಲೋ)\w*",
    re.IGNORECASE,
)
GREETING_WORDS = re.compile(
    # `namaskar*` rather than `namaska\b`, otherwise "namaskara" (the more
    # common transliteration in Karnataka) misses the word boundary and falls
    # through to the unmatched fallback.
    r"^\s*(hi|hello|hey|namaste|namaskar\w*|good\s+(morning|evening|afternoon)|"
    r"ನಮಸ್ಕಾರ|ಹಲೋ)\b",
    re.IGNORECASE,
)
TRADER_WORDS = re.compile(
    r"\b(trader|buyer|buyer|ವ್ಯಾಪಾರಿ|ಖರೀದಿ|ಕಾಯಿದಾರ)\w*", re.IGNORECASE
)
CROP_WORDS = re.compile(
    r"\b(crop|listing|harvest|seed|variety|ಬೆಳೆ|ಇಳುವಿಕೆ|ಬೀಜ)\w*", re.IGNORECASE
)
RENTAL_WORDS = re.compile(
    r"\b(rent|tractor|equipment|tool|implement|ಬಾಡಿಗೆ|ಟ್ರಾಕ್ಟರ್|ಸಲಕರಣೆ)\w*",
    re.IGNORECASE,
)
QUALITY_WORDS = re.compile(
    r"\b(quality|grade|analysis|scan|ಗುಣಮಟ್ಟ|ವಿಶ್ಲೇಷಣೆ)\w*", re.IGNORECASE
)
MARKETPLACE_WORDS = re.compile(
    r"\b(marketplace|buy|sell|shop|store|ಮಾರುಕಟ್ಟೆ|ಖರೀದಿ|ಮಾರಿಕೆ)\w*",
    re.IGNORECASE,
)
HELP_WORDS = re.compile(
    r"\b(help|what can you do|capabilities|how do|ಸಹಾಯ)\w*", re.IGNORECASE
)


def _has_location(lat: float | None, lon: float | None) -> bool:
    return (
        lat is not None
        and lon is not None
        and -90 <= lat <= 90
        and -180 <= lon <= 180
    )


# ----------------------------------------------------------------- weather


def _weather_reply(
    prompt: str, lat: float, lon: float, name: str
) -> Reply:
    """Compose a real answer from live provider data.

    Falls back to an honest "give me a location" rather than inventing numbers
    if the provider is unreachable.
    """
    label = name.strip() or f"{lat:.3f}, {lon:.3f}"
    try:
        data = weather_service.fetch_weather(lat, lon, label)
    except Exception as exc:  # noqa: BLE001 - provider down must not 500 the chat
        return Reply(
            text=(
                f"I could not reach the weather service for {label} just now "
                f"({type(exc).__name__}). This is usually temporary — try "
                f"again in a moment, or open the Weather tool for the full "
                f"forecast."
            ),
            thinking=["Checking the weather service", "Retrying the provider"],
        )

    current = data.get("current") or {}
    daily = data.get("daily") or []
    hourly = data.get("hourly") or []
    source = data.get("source", "provider")
    condition = (current.get("condition") or {}).get("text", "current conditions")

    lines = [
        f"Here is the live weather for {label}: "
        f"**{current.get('temp_c')}°C** and {condition}, "
        f"feels like {current.get('feelslike_c')}°C.",
        "",
        f"- Humidity: {current.get('humidity')}%",
        f"- Wind: {current.get('wind_kph')} km/h {current.get('wind_dir', '')}".rstrip(),
    ]
    alerts = data.get("alerts") or []
    if alerts:
        lines.append(f"- Alerts: {len(alerts)} active — check the Weather tool")
    else:
        lines.append("- No weather alerts right now")

    if daily:
        today = daily[0]
        lines += [
            "",
            f"Today ranges {today.get('min_temp_c')}–{today.get('max_temp_c')}°C "
            f"with a {today.get('chance_of_rain')}% chance of rain.",
        ]
        rest = daily[1:3]
        if rest:
            outlook = ", ".join(
                f"{d.get('date')} {d.get('min_temp_c')}–{d.get('max_temp_c')}°C"
                for d in rest
            )
            lines.append(f"Coming up: {outlook}.")

    if hourly:
        peak = max(
            hourly,
            key=lambda h: (h.get("chance_of_rain") or 0),
        )
        if (peak.get("chance_of_rain") or 0) >= 50:
            lines += [
                "",
                f"Rain risk peaks at {(peak.get('chance_of_rain'))}% around "
                f"{peak.get('time')}. Worth covering anything harvested.",
            ]

    lines += [
        "",
        f"Want a spray window, irrigation advice or a 7-day view? I can pull "
        f"the detail, or open the full forecast in the Weather tool.",
    ]

    return Reply(
        text="\n".join(lines),
        citations=[
            Citation(
                label=f"Weather for {label}",
                kind=KIND_WEATHER,
                detail=f"{current.get('temp_c')}°C, {condition}",
            ),
            Citation(
                label=f"Data via {source}",
                kind=KIND_SOURCE,
                detail="Current conditions and forecast",
            ),
        ],
        tools=[
            ToolCall(
                tool="weather.get",
                title=f"Live weather — {label}",
                payload={
                    "place": label,
                    "temp_c": current.get("temp_c"),
                    "feelslike_c": current.get("feelslike_c"),
                    "condition": condition,
                    "humidity": current.get("humidity"),
                    "wind_kph": current.get("wind_kph"),
                    "wind_dir": current.get("wind_dir"),
                    "max_c": (daily[0].get("max_temp_c") if daily else None),
                    "min_c": (daily[0].get("min_temp_c") if daily else None),
                    "source": source,
                },
            )
        ],
        thinking=[
            f"Reading the forecast for {label}",
            "Checking rain risk and alerts",
        ],
    )


# ------------------------------------------------------------ other intents


def _greeting_reply() -> Reply:
    return Reply(
        text=(
            "Namaska! I am your Jeevandhara assistant.\n\n"
            "I can check live weather for your village, talk through market "
            "prices, find buyers nearby, and walk you through your crops, tool "
            "rental and quality checks. Ask me anything, or tap a suggestion "
            "below to start."
        ),
        citations=[
            Citation(
                label="Assistant tools",
                kind=KIND_APP,
                detail="Weather, prices, traders, crops, rental, quality",
            )
        ],
        thinking=["Waking up"],
    )


def _capability_reply() -> Reply:
    return Reply(
        text=(
            "Here is what I can do:\n\n"
            "- **Weather** — live conditions and a 7-day forecast for any "
            "village, district or taluk in India\n"
            "- **Market prices** — read current rates and trends, then work out "
            "what a good price looks like for your quantity\n"
            "- **Traders** — find buyers nearby who handle your crop\n"
            "- **My crops** — track listings, offers and what has sold\n"
            "- **Tool rental** — tractors and implements by location\n"
            "- **Marketplace** — list produce, see what is around\n"
            "- **Quality analysis** — grade produce and record a check\n\n"
            "Try: *“Will it rain in Hubballi tomorrow?”*"
        ),
        citations=[
            Citation(
                label="All features",
                kind=KIND_APP,
                detail="Available from the sidebar",
            )
        ],
        thinking=["Reading the feature map"],
    )


def _price_reply(prompt: str, session_factory=None) -> Reply:
    """Quote real numbers, or say plainly that there are none.

    This used to be a canned paragraph promising that "the Market Prices tool
    shows the latest rates" - which was false while that screen was hardcoded,
    and is exactly the kind of lie this rewrite exists to remove.

    The rules it follows, in order:

    1. Only figures from stored observations are quoted, each with its mandi,
       its market date and its age. Nothing is fetched at reply time, so a
       chat turn never waits on a government endpoint.
    2. No crop named -> ask. No rows stored -> say so, with why.
    3. Any row older than a day is called out as old rather than presented as
       today's rate.
    """
    crop = _crop_mentioned(prompt)
    if not crop:
        return Reply(
            text=(
                "Which crop? Tell me the crop and, if you can, your district or "
                "mandi — for example *“onion rate in Kolar”*.\n\n"
                "I will only quote a rate the backend actually holds, with the "
                "mandi and the date it was observed."
            ),
            citations=[
                Citation(label="Market prices", kind=KIND_PRICE, detail="Ask for a crop"),
            ],
            thinking=["Waiting for a crop"],
        )

    try:
        db = (session_factory or _default_session_factory())()
    except Exception:  # noqa: BLE001 - store unreachable, never invent a price
        return _unavailable_price_reply(crop, "the price store did not open")
    try:
        rows = _stored_prices(db, crop, prompt)
        demand = _stored_demand(db, crop)
    except Exception as exc:  # noqa: BLE001
        return _unavailable_price_reply(crop, f"{type(exc).__name__} while reading stored prices")
    finally:
        db.close()

    if not rows:
        return _no_price_reply(crop)

    today = date.today()
    lines = [f"Here is what I actually hold for **{crop}**:", ""]
    for row in rows:
        age_days = (today - row["trade_date"]).days
        age = "today" if age_days <= 0 else f"{age_days} day(s) ago"
        lines.append(
            f"- **{row['market']}** ({row.get('district') or 'district unknown'}): "
            f"₹{row['modal_price']:,.0f}/quintal "
            f"(₹{row['min_price']:,.0f}–₹{row['max_price']:,.0f}) — observed {age}"
        )

    stale = [r for r in rows if (today - r["trade_date"]).days > 1]
    lines.append("")
    if stale:
        lines.append(
            f"**{len(stale)} of these {len(rows)} quotes are older than a day.** "
            "Mandi rates move daily, so treat old ones as background, not as "
            "something to sell against."
        )
    else:
        lines.append(
            "All of these were observed within the last day. Rates still differ "
            "by mandi, so compare at least two before you decide."
        )

    if demand:
        lines += [
            "",
            f"Demand signal for {crop} at **{demand['mandi']}**: "
            f"**{demand['band_en']}** ({demand['score']:.0f}/100, "
            f"{demand['confidence']} confidence, {demand['component_count']}/"
            f"{demand['components_total']} inputs). This is a derived estimate, "
            "not a measurement — open the demand breakdown to see what fed it.",
        ]
    else:
        lines += [
            "",
            "I do not have a demand reading for this crop yet — too few inputs "
            "have been computed to show one honestly.",
        ]

    lines += ["", "Ask for another crop or mandi, or open **Market prices** for the full table."]

    source_label = rows[0].get("source_name") or "market feed"
    return Reply(
        text="\n".join(lines),
        citations=[
            Citation(label=f"{crop} prices", kind=KIND_PRICE, detail=source_label),
            Citation(label="Derived demand estimate", kind=KIND_SOURCE, detail="Computed in-app"),
        ],
        tools=[
            ToolCall(
                tool="prices.lookup",
                title=f"{crop} — modal prices",
                payload={
                    "commodity": crop,
                    "rows": [
                        {
                            "market": row["market"],
                            "district": row.get("district"),
                            "trade_date": row["trade_date"].isoformat(),
                            "modal_price": row["modal_price"],
                            "min_price": row.get("min_price"),
                            "max_price": row.get("max_price"),
                            "source": row.get("source_name"),
                            "age_days": (today - row["trade_date"]).days,
                        }
                        for row in rows
                    ],
                    "demand": demand,
                },
            )
        ],
        thinking=[f"Reading stored {crop} observations", "Checking their age"],
    )


def _default_session_factory():
    """Lazily resolved so tests can inject their own session factory.

    Importing `database` at module load would bind the chat to whatever
    `DATABASE_URL` was set when the process started, which is the wrong
    database the moment a test or a migration tool rebinds it.
    """
    from .database import SessionLocal

    return SessionLocal()


def _unavailable_price_reply(crop: str, why: str) -> Reply:
    """The store itself could not answer. Say so; never fall back to a number."""
    return Reply(
        text=(
            f"I cannot read the price store for **{crop}** right now "
            f"({why}), so I will not quote a rate.\n\n"
            "This is a problem with reading our own data, not with the market "
            "feed — nothing here is being invented to fill the gap."
        ),
        citations=[
            Citation(
                label="Price store unavailable",
                kind=KIND_PRICE,
                detail=why,
            )
        ],
        thinking=["Price store did not answer"],
    )


def _no_price_reply(crop: str) -> Reply:
    """No stored rows: say which feed is responsible, not just 'no data'."""
    reasons = []
    try:
        from .market import service as market_service

        for source in market_service.market_status().get("sources", []):
            if not source.get("enabled"):
                reasons.append(f"{source['name']}: {source.get('disabled_reason') or 'off'}")
            elif not source.get("verified"):
                reasons.append(f"{source['name']}: not verified against the live catalogue")
    except Exception:  # noqa: BLE001 - status is context, never the failure itself
        reasons = []

    detail = (
        " Right now: " + "; ".join(reasons) + "." if reasons else ""
    )
    return Reply(
        text=(
            f"I do not have a price for **{crop}** right now, so I am not going "
            f"to guess one.{detail}\n\n"
            "Once a feed answers and the sync runs, the rate appears here with "
            "its mandi and observation date. You can also post what buyers are "
            "offering under **Market prices → Report an inquiry**, which is a "
            "number this app owns rather than scrapes."
        ),
        citations=[
            Citation(
                label="No observation available",
                kind=KIND_PRICE,
                detail="Nothing stored for this crop",
            )
        ],
        thinking=["No stored observations", "Checking which feed is down"],
    )


def _stored_prices(db, crop: str, prompt: str, limit: int = 5) -> list[dict]:
    """Newest observation per mandi, scoped to a mandi the prompt named.

    Reads the database only. A reply must be answerable with the source down,
    and it must never be the reason a government endpoint gets called.
    """
    from . import models

    latest: dict[str, models.MarketPrice] = {}
    for row in (
        db.query(models.MarketPrice)
        .filter(models.MarketPrice.commodity == crop)
        .all()
    ):
        current = latest.get(row.market)
        if current is None or row.trade_date > current.trade_date:
            latest[row.market] = row

    rows = sorted(
        (r for r in latest.values() if r.modal_price is not None),
        key=lambda r: r.trade_date,
        reverse=True,
    )

    # Narrow to a mandi the user actually named, but only if one of ours was
    # named - a typo'd mandi must not silently widen back to everything.
    named = _market_mentioned(prompt, [r.market for r in rows])
    if named:
        rows = [r for r in rows if r.market == named]

    # Sort freshest-first so the top of the list is the newest observation.
    # Rows are NOT dropped for being old: an out-of-date rate the user is told
    # about is honest, the same rate silently discarded is not.
    rows.sort(key=lambda r: r.trade_date, reverse=True)

    return [
        {
            "market": r.market,
            "district": r.district,
            "trade_date": r.trade_date,
            "modal_price": r.modal_price,
            "min_price": r.min_price or r.modal_price,
            "max_price": r.max_price or r.modal_price,
            "source_name": r.source_name,
        }
        for r in rows[:limit]
    ]


def _market_mentioned(prompt: str, markets: list[str]) -> str | None:
    text = prompt.casefold()
    for market in sorted(markets, key=len, reverse=True):
        if market and market.casefold() in text:
            return market
    return None


def _stored_demand(db, crop: str) -> dict | None:
    """The newest derived reading for this crop, if one exists."""
    from . import models

    row = (
        db.query(models.MandiDemand)
        .filter(models.MandiDemand.commodity == crop, models.MandiDemand.score.isnot(None))
        .order_by(models.MandiDemand.created_at.desc())
        .first()
    )
    if row is None:
        return None
    labels = {
        "strong": "Strong demand",
        "moderate": "Moderate demand",
        "weak": "Weak demand",
    }
    return {
        "mandi": row.mandi,
        "band": row.band,
        "band_en": labels.get(row.band, row.band),
        "score": row.score,
        "confidence": row.confidence,
        "component_count": row.component_count,
        "components_total": len(row.components) or row.component_count,
        "is_derived": True,
        "computed_for": row.computed_for.isoformat(),
    }


def _crop_mentioned(prompt: str) -> str | None:
    """Canonical crop named in the prompt, or None.

    Matching is over the alias table so "pyaz", "onions" and "ಈರುಳ್ಳಿ" all
    resolve to Onion - the same normalisation the price feed gets, so the
    answer cannot disagree with the screen.
    """
    from .market.normalizer import _ALIAS_INDEX, _clean

    cleaned = _clean(prompt)
    if not cleaned:
        return None

    hits = {
        canonical
        for alias, canonical in _ALIAS_INDEX.items()
        # Not `\b`: aliases ending in a combining mark (Kannada vowel signs)
        # are not word characters, so `\b` never fires there.
        if alias and re.search(rf"(?<!\w){re.escape(alias)}(?!\w)", cleaned)
    }
    if not hits:
        return None
    # "tomato rate" is one crop; "onion and potato" is ambiguous, so pick the
    # longest alias to prefer a multi-word match over a fragment of it.
    return sorted(hits, key=len, reverse=True)[0]


def _route_reply(topic: str, tool_name: str, prompt: str) -> Reply:
    return Reply(
        text=(
            f"{topic} is handled by the **{tool_name}** tool. I can take you "
            f"there, or answer directly if you tell me a little more.\n\n"
            f"You asked: *{prompt.strip()[:160]}*\n\n"
            f"Open {tool_name} from the sidebar or the command palette "
            f"(Ctrl+K / ⌘K) to continue."
        ),
        citations=[
            Citation(label=tool_name, kind=KIND_APP, detail="Feature tool")
        ],
        thinking=[f"Locating the {tool_name} tool"],
    )


def _trader_reply() -> Reply:
    return Reply(
        text=(
            "To find buyers I need your **crop** and your **location**.\n\n"
            "The Traders tool matches you with buyers nearby who handle your "
            "crop, and shows the price each has offered. Once you are there you "
            "can compare offers and accept one.\n\n"
            "Which crop are you selling, and from which district?"
        ),
        citations=[
            Citation(
                label="Traders",
                kind=KIND_APP,
                detail="Nearby buyers and their offers",
            )
        ],
        thinking=["Checking the Traders tool"],
    )


# --------------------------------------------------------------- entrypoint


def compose_reply(
    prompt: str,
    lat: float | None = None,
    lon: float | None = None,
    place_name: str = "",
    session_factory=None,
) -> Reply:
    """Pick an intent and build the reply. Unit-testable.

    `session_factory` is only used by the price intent, and only to *read*
    what is already stored; pass one in tests to point the reply at a
    fixture database.
    """
    text = prompt.strip()
    if not text:
        return Reply(
            text="Tell me what you need — weather, prices, buyers, or help with a crop.",
            thinking=["Waiting for a question"],
        )

    if GREETING_WORDS.search(text):
        return _greeting_reply()

    if WEATHER_WORDS.search(text):
        if _has_location(lat, lon):
            return _weather_reply(prompt, lat, lon, place_name)  # type: ignore[arg-type]
        return Reply(
            text=(
                "I can do that, but I need to know where you are first.\n\n"
                "Open **Weather** and pick your village, district or taluk — "
                "I will remember it, and then I can answer weather questions "
                "directly from here."
            ),
            citations=[
                Citation(
                    label="Weather",
                    kind=KIND_APP,
                    detail="Set your location once",
                )
            ],
            thinking=["No location set yet"],
        )

    if HELP_WORDS.search(text):
        return _capability_reply()
    if TRADER_WORDS.search(text):
        return _trader_reply()
    if PRICE_WORDS.search(text):
        return _price_reply(text, session_factory)
    if RENTAL_WORDS.search(text):
        return _route_reply("Tool rental", "Tool Rental", prompt)
    if QUALITY_WORDS.search(text):
        return _route_reply("Quality grading", "Quality Analysis", prompt)
    if MARKETPLACE_WORDS.search(text):
        return _route_reply("Buying and selling produce", "Marketplace", prompt)
    if CROP_WORDS.search(text):
        return _route_reply("Your crop listings", "My Crops", prompt)

    return Reply(
        text=(
            "I did not catch a specific request there.\n\n"
            "I can do live weather for your area, talk through market prices, "
            "find buyers, and open your crops, tool rental, marketplace and "
            "quality tools.\n\n"
            "Try *“Will it rain in Hubballi tomorrow?”* or ask for **help** to "
            "see everything."
        ),
        citations=[
            Citation(
                label="Not sure yet",
                kind=KIND_SOURCE,
                detail="Try a specific example",
            )
        ],
        thinking=["Matching your question to a tool"],
    )


# ----------------------------------------------------------------- streaming


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data)}\n\n"


async def stream_reply(
    prompt: str,
    lat: float | None = None,
    lon: float | None = None,
    place_name: str = "",
    session_factory=None,
    history: list[dict] | None = None,
    language: str = "en",
) -> AsyncIterator[str]:
    """Yield the reply as SSE frames.

    Kept as a generator so the router can hand it straight to
    `StreamingResponse` without buffering the whole answer.
    """
    reply = compose_reply(prompt, lat, lon, place_name, session_factory)

    for line in reply.thinking:
        await asyncio.sleep(STATUS_DELAY / max(len(reply.thinking), 1))
        yield _sse("status", {"text": line})

    for tool in reply.tools:
        yield _sse("tool", tool.as_event())

    for citation in reply.citations:
        yield _sse("citation", citation.as_event())

    if llm_available() and httpx is not None:
        messages = _build_llm_messages(prompt, reply, lat, lon, place_name, history, language)
        try:
            streamed = False
            async for token in _stream_llm(messages):
                streamed = True
                yield _sse("delta", {"text": token})
            if not streamed:
                for chunk in reply.text.split(" "):
                    await asyncio.sleep(CHUNK_DELAY)
                    yield _sse("delta", {"text": chunk + " "})
        except Exception as exc:  # noqa: BLE001
            text = (
                "\n[Assistant unavailable: " + type(exc).__name__
                + ". Showing the built-in answer instead.]\n\n" + reply.text
            )
            for chunk in text.split(" "):
                await asyncio.sleep(CHUNK_DELAY)
                yield _sse("delta", {"text": chunk + " "})
        yield _sse("done", {"provider": "llm", "model": _llm_model()})
        return

    # Split on whitespace but keep it, so the client can reassemble exactly.
    for chunk in reply.text.split(" "):
        await asyncio.sleep(CHUNK_DELAY)
        yield _sse("delta", {"text": chunk + " "})

    yield _sse("done", {"provider": "rule-based"})


def has_llm_key() -> bool:
    return bool(os.getenv("LLM_API_KEY", "").strip())


def _llm_base_url() -> str:
    url = os.getenv("LLM_BASE_URL", "").strip()
    if url:
        return url.rstrip("/")
    if has_llm_key():
        return "https://api.openai.com/v1"
    return ""


def llm_available() -> bool:
    """Whether an OpenAI-compatible chat endpoint can be reached."""
    return bool(_llm_base_url())


def _llm_model() -> str:
    return os.getenv("LLM_MODEL", "").strip() or "openai-fast"


def _llm_timeout() -> float:
    try:
        return float(os.getenv("LLM_TIMEOUT", "60"))
    except ValueError:
        return 60.0


async def translate_text(text: str, language: str = "en") -> str:
    """Translate text to the target language using the LLM, if available."""
    if not llm_available() or httpx is None:
        return text
    lang_name = {"en": "English", "kn": "Kannada", "hi": "Hindi"}.get(language, "English")
    if lang_name == "English":
        return text
    messages = [
        {
            "role": "system",
            "content": (
                "You are a translator. Translate the user's text into "
                + lang_name
                + ". Return only the translated text, with no explanation, no quotes, "
                "and no extra whitespace."
            ),
        },
        {"role": "user", "content": text},
    ]
    try:
        out = []
        async for token in _stream_llm(messages):
            out.append(token)
        result = "".join(out).strip()
        return result or text
    except Exception:  # noqa: BLE001
        return text


async def _stream_llm(messages: list[dict]) -> AsyncIterator[str]:
    """Stream tokens from an OpenAI-compatible /chat/completions endpoint."""
    base = _llm_base_url()
    if not base:
        return
    url = base + "/chat/completions"
    headers = {"Content-Type": "application/json"}
    key = os.getenv("LLM_API_KEY", "").strip()
    if key:
        headers["Authorization"] = f"Bearer {key}"

    payload = {
        "model": _llm_model(),
        "messages": messages,
        "stream": True,
        "temperature": 0.7,
    }

    async with httpx.AsyncClient(timeout=_llm_timeout()) as client:
        async with client.stream("POST", url, json=payload, headers=headers) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                line = line.strip()
                if not line or not line.startswith("data:"):
                    continue
                data = line[len("data:"):].strip()
                if data == "[DONE]":
                    break
                try:
                    obj = json.loads(data)
                except json.JSONDecodeError:
                    continue
                choices = obj.get("choices") or []
                if not choices:
                    continue
                delta = (choices[0].get("delta") or {})
                content = delta.get("content")
                if content:
                    yield content


def _build_llm_messages(
    prompt: str,
    reply: "Reply",
    lat: float | None,
    lon: float | None,
    place_name: str,
    history: list[dict] | None = None,
    language: str = "en",
) -> list[dict]:
    lang_name = {"en": "English", "kn": "Kannada", "hi": "Hindi"}.get(language, "English")
    system = (
        "You are Jeevandhara, a helpful assistant for Indian farmers and traders. "
        "Answer clearly and practically. When context data is provided, ground "
        "your answer in it and do not invent numbers. You may use markdown. "
        "Respond only in " + lang_name + "."
    )
    context_parts = []
    if place_name or (lat is not None and lon is not None):
        context_parts.append(
            f"Location context: place={place_name!r}, lat={lat}, lon={lon}."
        )
    if reply.text:
        context_parts.append("Backend context (use these facts, do not contradict):\n" + reply.text)
    messages: list[dict] = [{"role": "system", "content": system}]
    if context_parts:
        messages.append({"role": "system", "content": "\n\n".join(context_parts)})
    for item in (history or []):
        role = item.get("role")
        content = item.get("content") or item.get("text")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": str(content)})
    messages.append({"role": "user", "content": prompt})
    return messages


async def analyze_quality(
    filename: str = "",
    crop_name: str = "",
    language: str = "en",
) -> dict:
    """Analyze a crop image (by filename/hint) and return a structured result."""
    lang_name = {"en": "English", "kn": "Kannada", "hi": "Hindi"}.get(language, "English")
    hint = crop_name.strip() or filename.strip() or "unknown crop"
    messages = [
        {
            "role": "system",
            "content": (
                "You are an agricultural quality analyst. Given a crop file name or "
                "crop name, provide a JSON object with keys: crop_name, "
                "quality_grade, health_score (integer 0-100), disease_risk "
                "(Low/Medium/High), uses (string), harmful (string explaining "
                "whether it is harmful and why), notes (string). Output ONLY valid "
                "JSON, no markdown. Respond in " + lang_name + "."
            ),
        },
        {"role": "user", "content": f"File: {filename}\nCrop hint: {hint}"},
    ]

    if llm_available() and httpx is not None:
        try:
            out = []
            async for token in _stream_llm(messages):
                out.append(token)
            raw = "".join(out).strip()
            # Strip markdown code fences if present.
            if raw.startswith("```"):
                raw = raw.strip("`")
                if raw.lower().startswith("json"):
                    raw = raw[4:].strip()
            data = json.loads(raw)
            if isinstance(data, dict):
                return data
        except Exception:  # noqa: BLE001
            pass

    # Fallback when no LLM is available.
    return {
        "crop_name": hint,
        "quality_grade": "Grade B",
        "health_score": 75,
        "disease_risk": "Medium",
        "uses": "General consumption and cooking.",
        "harmful": "No specific harmful effects known; wash before use.",
        "notes": "LLM unavailable; result is a placeholder.",
    }


def gazetteer_available() -> bool:
    try:
        places.gazetteer()
    except Exception:  # noqa: BLE001
        return False
    return True
