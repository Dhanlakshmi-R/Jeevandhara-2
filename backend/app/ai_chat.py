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
import re
from dataclasses import dataclass, field
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
    r"\b(price|rate|mandi|market|mandi|ದರ|ಮಾರುಕಟ್ಟೆ|ಕಿಲೋ|quintal)\w*",
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
    r"\b(help|what can you do|capabilities|how do|ಸಹಾಯ|ಏನು)\w*", re.IGNORECASE
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


def _price_reply() -> Reply:
    return Reply(
        text=(
            "I can talk through prices, but be aware of how the numbers here "
            "work:\n\n"
            "- The **Market Prices** tool shows the latest rates and trend for "
            "each crop, with a sparkline so you can see the direction.\n"
            "- Mandi rates move daily and differ by mandi, so treat a single "
            "figure as a starting point, not a guarantee.\n"
            "- Before you sell, compare at least two nearby mandis and check "
            "whether the trend is up or down that week.\n\n"
            "Tell me the crop and quantity and I will help you work out a "
            "target price. Opening the Market Prices tool will show you the "
            "live table."
        ),
        citations=[
            Citation(
                label="Market Prices",
                kind=KIND_PRICE,
                detail="Rates and trend per crop",
            )
        ],
        thinking=["Loading the price feature map"],
    )


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
) -> Reply:
    """Pick an intent and build the reply. Pure and unit-testable."""
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
        return _price_reply()
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
) -> AsyncIterator[str]:
    """Yield the reply as SSE frames.

    Kept as a generator so the router can hand it straight to
    `StreamingResponse` without buffering the whole answer.
    """
    reply = compose_reply(prompt, lat, lon, place_name)

    for line in reply.thinking:
        await asyncio.sleep(STATUS_DELAY / max(len(reply.thinking), 1))
        yield _sse("status", {"text": line})

    for tool in reply.tools:
        yield _sse("tool", tool.as_event())

    for citation in reply.citations:
        yield _sse("citation", citation.as_event())

    # Split on whitespace but keep it, so the client can reassemble exactly.
    for chunk in reply.text.split(" "):
        await asyncio.sleep(CHUNK_DELAY)
        yield _sse("delta", {"text": chunk + " "})

    yield _sse("done", {"provider": "rule-based"})


def has_llm_key() -> bool:
    return bool(os.getenv("LLM_API_KEY", "").strip())


def gazetteer_available() -> bool:
    try:
        places.gazetteer()
    except Exception:  # noqa: BLE001
        return False
    return True
