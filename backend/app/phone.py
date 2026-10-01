import re

# Accepts: 9876543210 | +919876543210 | 919876543210 | 09876543210
_PHONE_RE = re.compile(r"^(?:\+?91|0)?([6-9]\d{9})$")


def normalize_phone(raw: str) -> str | None:
    """
    Normalize an Indian mobile number to E.164 digits without the leading '+'
    (e.g. '919876543210'). Returns None if it is not a valid 10-digit mobile.
    """
    if not raw:
        return None
    cleaned = re.sub(r"[\s\-()]", "", raw.strip())
    match = _PHONE_RE.match(cleaned)
    if not match:
        return None
    return "91" + match.group(1)


def display_phone(normalized: str) -> str:
    """Format a normalized number like '+91 98765 43210' for display/logs."""
    if normalized and normalized.startswith("91") and len(normalized) == 12:
        return f"+91 {normalized[2:7]} {normalized[7:]}"
    return normalized