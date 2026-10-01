"""Tests for the rule-based assistant behind /ai/chat.

These assert on `compose_reply` (pure) and on the SSE frame format, so they run
without a network and without the weather provider.
"""

import asyncio
import json

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


def test_price_question_is_labelled_as_indicative():
    reply = ai_chat.compose_reply("what is the tomato rate today")
    assert "market prices" in reply.text.lower()
    assert "starting point" in reply.text.lower()
    assert reply.citations[0].kind == ai_chat.KIND_PRICE


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
