"""Commodity, unit and mandi-name normalisation.

Upstream spellings are wildly inconsistent. Observed examples across the feeds
we touch:

    "Onion", "Arecanut(Betelnut/Supari)", "Alsandikai", "Alasande Gram",
    "Arhar/Tur/Red gram", "Jowar/Sorghum", "Methi(Leaves)", "Tur/Arhar",
    "Bengaluru APMC", "APMC Hubballi", "Bangarpet APMC"

A farmer types "Onion / Pyaz / ಈರುಳ್ಳಿ". If these strings do not collapse to one
canonical key, then asking the AI for onion prices can silently return nothing
while the screen shows a perfectly plausible empty state. That is the failure
this module exists to prevent.

Everything here is deterministic and unit-testable with no network.
"""

from __future__ import annotations

import re
import unicodedata

# --------------------------------------------------------------- units

#: Everything is normalised to quintal (100 kg), the unit Indian mandi
#: quotations are conventionally expressed in.
KG_PER_QUINTAL = 100.0
KG_PER_TONNE = 1000.0

_UNIT_TO_KG: dict[str, float] = {
    "kg": 1.0,
    "kgs": 1.0,
    "kilogram": 1.0,
    "kilograms": 1.0,
    "q": KG_PER_QUINTAL,
    "quintal": KG_PER_QUINTAL,
    "quintals": KG_PER_QUINTAL,
    "qtl": KG_PER_QUINTAL,
    "quintal(s)": KG_PER_QUINTAL,
    "t": KG_PER_TONNE,
    "tonne": KG_PER_TONNE,
    "tonnes": KG_PER_TONNE,
    "ton": KG_PER_TONNE,
    "mt": KG_PER_TONNE,
    "metric ton": KG_PER_TONNE,
    "metric tonne": KG_PER_TONNE,
    "metric tonnes": KG_PER_TONNE,
}


#: Longest tokens first so "metric tonnes" is never matched as "tonnes" before
#: "quintal" claims a decorated string containing both.
_UNIT_TO_KG: dict[str, float] = {
    "metric tonnes": KG_PER_TONNE,
    "metric ton": KG_PER_TONNE,
    "metric tonne": KG_PER_TONNE,
    "kilogram": 1.0,
    "kilograms": 1.0,
    "quintal(s)": KG_PER_QUINTAL,
    "quintals": KG_PER_QUINTAL,
    "quintal": KG_PER_QUINTAL,
    "tonnes": KG_PER_TONNE,
    "tonne": KG_PER_TONNE,
    "qtl": KG_PER_QUINTAL,
    "kgs": 1.0,
    "kg": 1.0,
    "q": KG_PER_QUINTAL,
    "ton": KG_PER_TONNE,
    "mt": KG_PER_TONNE,
    "t": KG_PER_TONNE,
}

_UNIT_CANONICAL = {1.0: "kg", KG_PER_QUINTAL: "quintal", KG_PER_TONNE: "tonne"}


def _resolve_unit_key(key: str) -> tuple[float, bool]:
    """Return ``(kg_per_unit, recognised)`` for a cleaned unit string.

    Decorated spellings such as "quintal (100 kg)" contain more than one unit
    name. We take the **first** token in the unit's own left-to-right order,
    which matches how a reader of the string would name it: "quintal (100 kg)"
    is a quintal, not 100 kg.
    """
    if not key:
        return KG_PER_QUINTAL, False
    if key in _UNIT_TO_KG:
        return _UNIT_TO_KG[key], True
    best: tuple[int, float] | None = None
    for token, kg in _UNIT_TO_KG.items():
        pos = key.find(token)
        if pos == -1:
            continue
        if best is None or pos < best[0] or (pos == best[0] and len(token) > best[1]):
            best = (pos, kg)
    if best is not None:
        return best[1], True
    return KG_PER_QUINTAL, False


def normalize_unit(raw: str | None) -> str:
    """Return a canonical unit token, defaulting to quintal.

    An unknown unit becomes ``quintal`` because that is what the overwhelming
    majority of Indian mandi rows use; :func:`unit_is_known` lets callers that
    care check first.
    """
    kg, _ = _resolve_unit_key(_clean(raw))
    return _UNIT_CANONICAL.get(kg, "quintal")


def unit_is_known(raw: str | None) -> bool:
    """False when the unit was not recognised and we fell back to quintal."""
    _, recognised = _resolve_unit_key(_clean(raw))
    return recognised


def to_quintals(quantity: float | None, unit: str | None) -> float | None:
    """Convert a quantity into quintals. ``None`` in, ``None`` out."""
    if quantity is None:
        return None
    kg, _ = _resolve_unit_key(_clean(unit or "quintal"))
    if kg <= 0:
        return None
    return quantity * kg / KG_PER_QUINTAL


def quintals_to_kg(quintals: float | None) -> float | None:
    return None if quintals is None else quintals * KG_PER_QUINTAL


# ----------------------------------------------------------- commodities

#: Canonical English name -> aliases seen upstream, plus the Kannada and
#: transliterated forms a farmer might type or speak.
#:
#: Keys are the canonical commodity names used by the rest of the app.
COMMODITY_ALIASES: dict[str, tuple[str, ...]] = {
    "Onion": ("onions", "pyaz", "pyaaz", "eerullli", "ಈರುಳ್ಳಿ", "kanda", "kanda pyaaz"),
    "Tomato": ("tomatoes", "tamatar", "ಟೊಮೇಟೊ", "tameta"),
    "Potato": ("potatoes", "aloo", "alu", "ಆಲೂಗಡ್ಡೆ", "alugadda"),
    "Rice": ("paddy", "dhan", "ಭತ್ತು", "dhanyalu"),
    "Wheat": ("gehun", "godhi", "ಗೋಧಿ", "godhiga"),
    "Maize": ("corn", "makka", "ಮೆಕ್ಕೆಜೋಳ", "makka naati"),
    "Bajra": ("pearl millet", "bajra jowar", "ಬಜ್ರೆ", "bajari"),
    "Jowar": ("sorghum", "shalmillet", "ಜೋಳ", "jowari"),
    "Tur/Arhar": ("arhar", "tur", "red gram", "redgram", "pigeon pea", "tur dal", "ತುರ್", "tur"),
    "Urad": ("urad dal", "black gram", "ಉದ್ದು", "urad"),
    "Moong": ("moong dal", "green gram", "ಮೂಂಗು", "moonga"),
    "Gram": ("chana", "chickpea", "gram dal", "ಕಡಲೆ", "chana dal"),
    "Groundnut": ("peanut", "ground nuts", "ಎಣ್ಣೆಕಾಯಿ", "shengalaga"),
    "Soybean": ("soy bean", "soyabean", "ಸೋಯಬಿನ್", "soyabean naati"),
    "Sunflower": ("sun flower", "ಸೂರ್ಯಕಾಂತಿ", "suryakanti"),
    "Mustard": ("rapeseed", "sarson", "ಎಣ್ಣೆ", "sarson naati"),
    "Cotton": ("kapas", "ಹತ್ತಿ", "kapasa"),
    "Sugarcane": ("sugar cane", "ಕಬ್ಬು", "kabbu"),
    "Coffee": ("coffee beans", "ಕಾಫಿ", "kafi"),
    "Arecanut": ("betelnut", "supari", "bettige", "areca nut"),
    "Chilli": ("chili", "chillies", "ಮೆಣಸು", "mirch", "red chilli"),
    "Turmeric": ("haldi", "ಅರಿಮೆನ್", "haladhi"),
    "Ginger": ("sonth", "adrak", "ಶುಂಗು", "shungi"),
    "Coriander": ("dhania", "ಕೊತ್ತೊಳೆ", "kothimbari"),
    "Methi": ("fenugreek", "methi leaves", "ಮೆಥಿ", "methi patre"),
    "Cabbage": ("pattanagere", "ಬೆಕ್ಕು", "bekke"),
    "Cauliflower": ("flower cabbage", "ಹೂಳಿಕೋಸು", "hoolikose"),
    "Bitter Gourd": ("karela", "ಕಾರ್ಲಾ", "hagga"),
    "Beans": ("green beans", "ಹಸಿರುಬೀನ್", "green beans naati"),
    "Bajra Peas": ("field pea", "ಅರಬೆಳೆ", "arabele"),
    "Coriander Leaves": ("dhania leaves", "ಕೊತ್ತೊಳೆ ಎಲೆ"),
}

#: Parenthetical and slash-separated fragments we can resolve, e.g.
#: "Arecanut(Betelnut/Supari)" -> "Arecanut".
_PAREN = re.compile(r"\s*\([^)]*\)\s*")
_SLASH = re.compile(r"\s*/\s*")


def _clean(value: str | None) -> str:
    """Lowercase, strip accents, collapse whitespace."""
    if not value:
        return ""
    text = unicodedata.normalize("NFKD", str(value))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", text).strip().lower()


def _alias_key(value: str) -> str:
    return _clean(value)


#: Flattened reverse lookup: normalised alias -> canonical name.
_ALIAS_INDEX: dict[str, str] = {}
for _canonical, _aliases in COMMODITY_ALIASES.items():
    _ALIAS_INDEX[_alias_key(_canonical)] = _canonical
    for _alias in _aliases:
        _ALIAS_INDEX.setdefault(_alias_key(_alias), _canonical)


def canonical_commodity(raw: str | None) -> str:
    """Map an upstream or user-typed commodity onto a canonical name.

    Tries, in order: exact alias hit, parenthetical-stripped hit, slash-split
    fragments, then the cleaned original. Unknown values are returned cleaned
    but otherwise untouched - we never invent a commodity, because inventing
    one would return another crop's price.
    """
    if not raw:
        return ""
    cleaned = _clean(raw)
    if not cleaned:
        return ""

    if cleaned in _ALIAS_INDEX:
        return _ALIAS_INDEX[cleaned]

    without_paren = _PAREN.sub(" ", cleaned).strip()
    if without_paren and without_paren in _ALIAS_INDEX:
        return _ALIAS_INDEX[without_paren]

    for fragment in _SLASH.split(cleaned):
        fragment = fragment.strip()
        if fragment and fragment in _ALIAS_INDEX:
            return _ALIAS_INDEX[fragment]

    return cleaned


def commodity_aliases(canonical: str) -> list[str]:
    """Every spelling that should resolve to ``canonical``."""
    aliases = [k for k, v in _ALIAS_INDEX.items() if v == canonical]
    return sorted(set(aliases))


def search_aliases(query: str) -> list[str]:
    """Canonical commodities whose name or any alias contains ``query``."""
    needle = _clean(query)
    if not needle:
        return []
    hits = {
        canonical
        for alias, canonical in _ALIAS_INDEX.items()
        if needle in alias
    }
    return sorted(hits)


# --------------------------------------------------------- mandi / place

#: APMC noise appears as a suffix ("Bangarpet APMC") or a prefix
#: ("APMC Hubballi"), so both ends have to be handled.
_APMC_TOKEN = re.compile(r"\bAPMC\b", re.IGNORECASE)
_MANDI_SUFFIX = re.compile(r"\s+(?:mandi|market)\s*$", re.IGNORECASE)


def normalize_market(raw: str | None) -> str:
    """Strip the decorations sources bolt onto mandi names.

    "Bangarpet APMC" -> "Bangarpet", "APMC Hubballi" -> "Hubballi".
    Also used before matching against the bundled places gazetteer.
    """
    if not raw:
        return ""
    text = re.sub(r"\s+", " ", str(raw)).strip()
    text = _APMC_TOKEN.sub(" ", text)
    text = _MANDI_SUFFIX.sub("", text)
    text = re.sub(r"\s*[-–]\s*$", "", text)
    return re.sub(r"\s+", " ", text).strip()


def normalize_state(raw: str | None) -> str:
    """Title-case a state name and drop a trailing "State"/"(KA)" decoration."""
    if not raw:
        return ""
    text = re.sub(r"\s+", " ", str(raw)).strip()
    text = re.sub(r"\s*\((?:[A-Za-z]{1,3})\)\s*$", "", text).strip()
    text = re.sub(r"\s+state\s*$", "", text, flags=re.IGNORECASE).strip()
    if not text:
        return ""
    return text.title() if text.islower() else text