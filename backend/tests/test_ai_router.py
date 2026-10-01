"""Contract tests for the /ai router.

Covers response headers, the terminal `done` frame and the capabilities
payload the Flutter client reads to build its tool list.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _frames(response) -> list[tuple[str, dict]]:
    import json

    parsed = []
    for block in response.text.split("\n\n"):
        block = block.strip()
        if not block:
            continue
        event, data = "", ""
        for line in block.splitlines():
            if line.startswith("event: "):
                event = line[len("event: ") :]
            elif line.startswith("data: "):
                data = line[len("data: ") :]
        parsed.append((event, json.loads(data)))
    return parsed


def test_chat_streams_sse():
    response = client.post("/ai/chat", json={"prompt": "hello"})
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    # Required for nginx not to buffer the stream into one blob.
    assert response.headers["x-accel-buffering"] == "no"

    events = _frames(response)
    assert [name for name, _ in events][-1] == "done"


def test_chat_weather_with_coordinates_emits_a_tool_frame():
    response = client.post(
        "/ai/chat",
        json={"prompt": "is it raining?", "lat": 15.36, "lon": 75.12, "place_name": "Hubballi"},
    )
    assert response.status_code == 200
    tools = [data for name, data in _frames(response) if name == "tool"]
    assert tools and tools[0]["tool"] == "weather.get"
    assert "place" in tools[0]["payload"]


def test_chat_rejects_an_out_of_range_latitude():
    response = client.post("/ai/chat", json={"prompt": "hi", "lat": 999})
    assert response.status_code == 422


def test_chat_rejects_an_empty_prompt():
    response = client.post("/ai/chat", json={"prompt": ""})
    assert response.status_code == 422


def test_capabilities_lists_the_client_tool_registry():
    response = client.get("/ai/capabilities")
    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "rule-based"
    assert isinstance(body["llm_configured"], bool)

    tools = {tool["name"] for tool in body["tools"]}
    assert "weather.get" in tools
    assert "prices.lookup" in tools
    # Only the weather tool needs coordinates; the rest must be reachable
    # without a location or the client would gate them wrongly.
    needs_location = {t["name"] for t in body["tools"] if t["needs_location"]}
    assert needs_location == {"weather.get"}
