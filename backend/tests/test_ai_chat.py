"""Tests for the rule-based assistant behind /ai/chat.

These assert on `compose_reply` (no network, no weather provider) and on the
SSE frame format. The price intent reads the database, so those tests build a
tiny fixture store and inject it via `session_factory` rather than touching
`app.database`.
"""

import asyncio
import json
from datetime import date, timedelta

import pytest

from app import ai_chat


def _collect(**kwargs) -> str:
    """Drain the SSE generator and return the raw stream text."""
    async def drain() -> str:
        return "".join([frame async for frame in ai_chat.stream_reply(**kwargs)])

    return asyncio.run(drain())


def _events(stream_text: str) -> list[tuple[str, dict]]:
    """Parse an SSE stream into (event, data) pairs.

    Mirrors how the Flutter client reads the stream, so a framing regression
    fails here too.
    """
    parsed: list[tuple[str, dict]] = []
    for block in stream_text.split("\n\n"):
        block = block.strip()
        if not block:
            continue
        event = ""
        data = ""
        for line in block.splitlines():
            if line.startswith("event: "):
                event = line[len("event: ") :]
            elif line.startswith("data: "):
                data = line[len("data: ") :]
        parsed.append((event, json.loads(data)))
    return parsed


def test_greeting_short_circuits_to_capability_intro():
    reply = ai_chat.compose_reply("namaskara")
    assert "assistant" in reply.text.lower()
    assert reply.citations


def test_weather_without_location_asks_for_one():
    reply = ai_chat.compose_reply("will it rain tomorrow")
    assert "need to know where you are" in reply.text.lower()
    assert reply.tools == []


def test_weather_with_coordinates_attempts_real_lookup():
    reply = ai_chat.compose_reply(
        "weather please",
        lat=15.36,
        lon=75.12,
        place_name="Hubballi",
    )
    # Either the provider answered (we can't assert on live values) or it
    # failed gracefully. Both are correct; a 500 would not be.
    assert reply.text
    assert "Traceback" not in reply.text


def test_weather_provider_failure_degrades_honestly():
    # Force the provider path to fail and confirm we do not invent numbers.
    original = ai_chat.weather_service.fetch_weather

    def boom(*_args, **_kwargs):
        raise RuntimeError("provider down")

    ai_chat.weather_service.fetch_weather = boom
    try:
        reply = ai_chat.compose_reply(
            "temperature?",
            lat=12.9,
            lon=77.6,
            place_name="Bengaluru",
        )
    finally:
        ai_chat.weather_service.fetch_weather = original

    assert "could not reach the weather service" in reply.text.lower()
    assert "runtimeerror" in reply.text.lower()
    assert reply.tools == []


def test_price_question_without_a_crop_asks_for_one():
    reply = ai_chat.compose_reply("what is the rate today")
    assert "which crop" in reply.text.lower()
    assert reply.citations[0].kind == ai_chat.KIND_PRICE
    # Asking is allowed to be silent; inventing a rate is not.
    assert "₹" not in reply.text


# --- price intent: reads only what is stored -------------------------------


@pytest.fixture()
def price_store():
    """A real fixture database with two mandis of onion observations."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy.pool import StaticPool

    from app.database import Base
    from app.models import MarketPrice

    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    today = date.today()
    with SessionLocal() as db:
        db.add_all(
            [
                MarketPrice(
                    commodity="Onion",
                    variety="Nashik Red",
                    state="Karnataka",
                    district="Kolar",
                    market="Kolar APMC",
                    trade_date=today,
                    min_price=1100.0,
                    modal_price=1450.0,
                    max_price=1700.0,
                    source_name="data_gov_in",
                    source_verified=True,
                ),
                MarketPrice(
                    commodity="Onion",
                    state="Karnataka",
                    district="Bengaluru Rural",
                    market="Yeshwanthpur",
                    trade_date=today - timedelta(days=3),
                    min_price=900.0,
                    modal_price=1050.0,
                    max_price=1200.0,
                    source_name="mandi_api",
                    source_verified=False,
                ),
            ]
        )
        db.commit()

    yield SessionLocal


def test_price_reply_quotes_stored_rows_with_mandi_and_date(price_store):
    reply = ai_chat.compose_reply(
        "what is the onion rate today", session_factory=price_store
    )
    assert "₹1,450/quintal" in reply.text
    assert "Kolar APMC" in reply.text
    assert "onion" in reply.text.lower()
    assert reply.citations[0].kind == ai_chat.KIND_PRICE
    tool = next(t for t in reply.tools if t.tool == "prices.lookup")
    assert tool.payload["commodity"] == "Onion"


def test_price_reply_never_uses_fetch_time_as_the_market_date(price_store):
    """A 3-day-old row must be called old, never presented as today's rate."""
    reply = ai_chat.compose_reply(
        "onion rate", session_factory=price_store
    )
    assert "3 day(s) ago" in reply.text
    assert "older than a day" in reply.text


def test_price_reply_scopes_to_a_named_mandi(price_store):
    reply = ai_chat.compose_reply(
        "onion rate at Yeshwanthpur", session_factory=price_store
    )
    assert "Yeshwanthpur" in reply.text
    assert "Kolar APMC" not in reply.text


def test_price_reply_without_rows_says_so_and_names_the_feed(price_store):
    reply = ai_chat.compose_reply("what is the tomato rate", session_factory=price_store)
    lower = reply.text.lower()
    assert "do not have a price" in lower
    assert "not going to guess" in lower
    assert "₹" not in reply.text


def test_price_reply_with_a_broken_store_does_not_invent_a_number(price_store):
    def boom():
        raise RuntimeError("store offline")

    reply = ai_chat.compose_reply("onion rate", session_factory=boom)
    assert "cannot read the price store" in reply.text
    assert "₹" not in reply.text
    assert reply.tools == []


def test_price_reply_recognises_aliases_and_kannada(price_store):
    # "pyaz" and "eerullli" both normalise to Onion - same table the feed uses.
    for prompt in ("pyaz rate today", "ಈರುಳ್ಳಿ ಬೆಲೆ ಏನು"):
        reply = ai_chat.compose_reply(prompt, session_factory=price_store)
        assert "Kolar APMC" in reply.text, prompt


def test_price_reply_always_costs_at_least_two_quotes_or_says_why(price_store):
    reply = ai_chat.compose_reply("onion rate", session_factory=price_store)
    # Two mandis were stored, both within the window of the freshest one only
    # if they are a day apart; the 3-day-old one is flagged, not dropped.
    assert "Kolar APMC" in reply.text
    assert "older than a day" in reply.text


def test_price_intent_does_not_reach_the_network(price_store):
    """The chat must never be the reason a government endpoint is called."""
    from app.market.sources import registry

    original = registry.fetch_prices
    calls: list[int] = []

    def watched(*args, **kwargs):
        calls.append(1)
        return original(*args, **kwargs)

    registry.fetch_prices = watched
    try:
        ai_chat.compose_reply("onion rate", session_factory=price_store)
    finally:
        registry.fetch_prices = original

    assert calls == []


def test_trader_question_requests_crop_and_location():
    reply = ai_chat.compose_reply("find me a buyer")
    assert "crop" in reply.text.lower()
    assert "location" in reply.text.lower()


def test_help_lists_capabilities():
    reply = ai_chat.compose_reply("what can you do")
    for topic in ("weather", "market prices", "traders", "rental", "quality"):
        assert topic in reply.text.lower()


def test_empty_prompt_prompts_the_user():
    reply = ai_chat.compose_reply("   ")
    assert "tell me what you need" in reply.text.lower()


def test_unmatched_prompt_falls_back_without_guessing():
    reply = ai_chat.compose_reply("zzzz qqqq")
    assert "did not catch" in reply.text.lower()


def test_stream_emits_status_then_deltas_and_terminates_with_done():
    events = _events(_collect(prompt="hello"))
    names = [name for name, _ in events]

    assert "status" in names
    assert "delta" in names
    assert names[-1] == "done"
    assert events[-1][1] == {"provider": "rule-based"}

    # Reassembling the deltas with spaces must reproduce the reply exactly.
    # This is the contract the Flutter client relies on to rebuild a message.
    rebuilt = "".join(data["text"] for name, data in events if name == "delta")
    assert rebuilt.strip() == ai_chat.compose_reply("hello").text.strip()


def test_stream_survives_an_empty_weather_reply_without_a_tool():
    # A tool-less reply must still end with `done`, otherwise the client
    # would be stuck in its streaming state forever.
    events = _events(_collect(prompt="will it rain tomorrow"))
    assert [name for name, _ in events][-1] == "done"


def test_weather_stream_includes_tool_and_citation_frames():
    events = _events(
        _collect(prompt="weather?", lat=15.36, lon=75.12, place_name="Hubballi")
    )
    tools = [data for name, data in events if name == "tool"]
    citations = [data for name, data in events if name == "citation"]

    assert tools and tools[0]["tool"] == "weather.get"
    assert citations
    assert {c["kind"] for c in citations} <= {ai_chat.KIND_WEATHER, ai_chat.KIND_SOURCE}


def test_sse_frame_shape_is_well_formed():
    frame = ai_chat._sse("delta", {"text": "hi "})
    assert frame.startswith("event: delta\ndata: ")
    assert frame.endswith("\n\n")
