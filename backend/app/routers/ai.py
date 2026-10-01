"""`/ai/chat` — streaming assistant endpoint.

SSE rather than WebSockets: the reply is one-directional, it works through
proxies that block upgrades, and the `http` client on the Flutter side already
speaks it.
"""

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from .. import ai_chat

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatTurn(BaseModel):
    """One message from the user, plus the context the assistant needs."""

    prompt: str = Field(..., min_length=1, max_length=2000)
    # Optional location so the assistant can answer weather questions without
    # a second round-trip to the gazetteer.
    lat: float | None = Field(None, ge=-90, le=90)
    lon: float | None = Field(None, ge=-180, le=180)
    place_name: str = Field("", max_length=160)
    history: list[dict] = Field(default_factory=list, max_length=40)


@router.post("/chat")
def chat(turn: ChatTurn) -> StreamingResponse:
    """Stream an assistant answer as server-sent events.

    Frames: `status` (thinking indicator text), `tool` (a card to render
    inline), `citation` (a source chip), `delta` (answer text, token by
    token) and `done`. Always ends with `done`, including on failure, so the
    client always has a terminal state to leave its streaming UI.
    """
    return StreamingResponse(
        ai_chat.stream_reply(
            prompt=turn.prompt,
            lat=turn.lat,
            lon=turn.lon,
            place_name=turn.place_name,
        ),
        media_type="text/event-stream",
        headers={
            # Nginx buffers text/event-stream by default, which would defeat
            # the point of streaming.
            "X-Accel-Buffering": "no",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@router.get("/capabilities")
def capabilities() -> dict:
    """What the assistant can do, so the client can render its tool list."""
    return {
        "provider": "rule-based",
        "llm_configured": ai_chat.has_llm_key(),
        "gazetteer": ai_chat.gazetteer_available(),
        "tools": [
            {"name": "weather.get", "label": "Live weather", "needs_location": True},
            {"name": "prices.lookup", "label": "Market prices", "needs_location": False},
            {"name": "crops.list", "label": "My crops", "needs_location": False},
            {"name": "traders.find", "label": "Find traders", "needs_location": False},
            {"name": "quality.analyze", "label": "Quality analysis", "needs_location": False},
            {"name": "rental.search", "label": "Tool rental", "needs_location": False},
            {"name": "marketplace.browse", "label": "Marketplace", "needs_location": False},
        ],
    }
