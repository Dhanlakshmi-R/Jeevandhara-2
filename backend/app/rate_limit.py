"""Tiny in-memory, per-key sliding-window throttle (process-local).

Enough to rate-limit OTP sending in a single-process uvicorn deployment and to
spike-protect during development. For multi-worker/horizontal deployments,
move this to Redis or the database — the column-backed resend_count gives a
second, stronger layer of protection that survives restarts.
"""
import os
import threading
import time

_MIN_INTERVAL_S = float(os.getenv("OTP_MIN_INTERVAL_SECONDS", "30"))
_WINDOW_S = float(os.getenv("OTP_RATE_WINDOW_SECONDS", "3600"))
_MAX_PER_WINDOW = int(os.getenv("OTP_MAX_PER_WINDOW", "5"))


class RateLimiter:
    def __init__(
        self,
        min_interval: float = _MIN_INTERVAL_S,
        window: float = _WINDOW_S,
        max_calls: int = _MAX_PER_WINDOW,
    ) -> None:
        self.min_interval = min_interval
        self.window = window
        self.max_calls = max_calls
        self._lock = threading.Lock()
        self._history: dict[str, list[float]] = {}

    def check(self, key: str) -> int:
        """
        Register a call for `key`. Returns 0 if allowed; otherwise the number
        of seconds the caller must wait before retrying.
        """
        now = time.monotonic()
        with self._lock:
            times = [t for t in self._history.get(key, []) if now - t < self.window]
            if times and now - times[-1] < self.min_interval:
                self._history[key] = times
                return int(self.min_interval - (now - times[-1])) + 1
            if len(times) >= self.max_calls:
                self._history[key] = times
                return int(self.window - (now - times[0])) + 1
            times.append(now)
            self._history[key] = times
        return 0


otp_rate_limiter = RateLimiter()


def get_rate_limiter() -> RateLimiter:
    """FastAPI dependency returning the shared OTP limiter. Override in tests."""
    return otp_rate_limiter