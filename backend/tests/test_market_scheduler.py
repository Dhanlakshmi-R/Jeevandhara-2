"""Sync coverage and pacing.

Two failures used to compound here and cost the app its data:

1. The crop list was held-crops-plus-three-references, so Tomato and Potato
   were never polled and the market screen had nothing to show for them.
2. ``min_interval_seconds`` is a *per-source* floor, so the second crop of a
   pass was rejected as rate limited and every remaining crop silently
   followed it. The loop now paces itself, and the floor is only lowered while
   a bulk sync is running.

No network: pacing is asserted on the gate itself, and the crop list is pure
storage.
"""

from __future__ import annotations

import time

from app.market import scheduler
from app.market.normalizer import COMMODITY_ALIASES
from app.market.sources import registry
from app.market.sources.enam import EnamSource
from app.market.sources.mandi_api import MandiApiSource


def test_crop_list_covers_the_whole_alias_table(setup):
    """Every chip a screen can offer is a crop the sync stocks."""
    db = setup.SessionLocal()
    try:
        crops = scheduler._crop_list(db)
    finally:
        db.close()

    missing = set(COMMODITY_ALIASES) - set(crops)
    assert not missing, f"crops never synced: {sorted(missing)}"
    assert "Tomato" in crops
    assert "Chilli" in crops
    assert len(crops) <= scheduler._TOP_CROPS_LIMIT


def test_crop_list_puts_what_we_hold_first(setup):
    """Storage leads: the sync refreshes what is already on screen first."""
    from app import models
    from app.market.sources.base import utcnow

    db = setup.SessionLocal()
    try:
        db.add(
            models.MarketPrice(
                commodity="Zzz Custom Crop",
                market="Somewhere",
                trade_date=utcnow().date(),
                modal_price=100.0,
                source_name="mandi_api",
                source_confidence="low",
                source_verified=True,
            )
        )
        db.commit()
        crops = scheduler._crop_list(db)
    finally:
        db.close()

    assert crops[0] == "Zzz Custom Crop"


class TestPacing:
    def test_interactive_floor_is_untouched(self):
        source = MandiApiSource()
        source._last_call_at = time.monotonic()
        assert source.min_interval == 60
        assert source.rate_limit_ok() is False

    def test_bulk_sync_may_lower_the_floor_only_for_that_sync(self):
        source = MandiApiSource()
        source._last_call_at = time.monotonic() - 5.5

        assert source.rate_limit_ok() is False, "60s floor still guards reads"
        source.set_bulk_pace(source.sync_pace)
        try:
            assert source.sync_pace == 5
            assert source.rate_limit_ok() is True
        finally:
            source.set_bulk_pace(None)
        assert source.rate_limit_ok() is False, "floor restored after the sync"

    def test_bulk_pace_never_exceeds_the_interactive_floor(self):
        assert EnamSource().sync_pace == EnamSource().min_interval == 1800

    def test_sync_pace_is_declared_in_config(self):
        source = MandiApiSource()
        assert source.config["sync_min_interval_seconds"] == 5
        assert source.sync_pace == 5

    def test_bulk_sync_pace_follows_the_fast_feeds(self):
        registry.begin_bulk_sync()
        try:
            assert registry.bulk_sync_pace() == 5
        finally:
            registry.end_bulk_sync()

    def test_end_bulk_sync_clears_every_source(self):
        registry.begin_bulk_sync()
        registry.end_bulk_sync()
        for name in registry.available_sources() + ["data_gov_in"]:
            assert registry.get_source(name)._bulk_pace is None
