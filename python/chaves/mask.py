"""Mascara secrets. Nunca devolve o valor completo."""

from __future__ import annotations

import re

PLACEHOLDER_RE = re.compile(
    r"^(your[_-]?key|changeme|xxx+|sk-\.\.\.|todo|placeholder)$",
    re.IGNORECASE,
)
NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def is_storable_name(name: str) -> bool:
    return bool(NAME_RE.match((name or "").strip()))


def is_placeholder(value: str) -> bool:
    text = (value or "").strip()
    if not text:
        return True
    return bool(PLACEHOLDER_RE.match(text))


def mask_secret(value: str, *, keep: int = 4) -> str:
    text = (value or "").strip()
    if not text:
        return ""
    if len(text) <= keep * 2:
        return "•" * min(8, len(text))
    prefix = text[: min(4, keep)]
    suffix = text[-keep:]
    return f"{prefix}…{suffix}"
