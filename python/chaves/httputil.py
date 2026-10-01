"""GET JSON sem depender de httpx — o app do Mac usa o Python do sistema."""

from __future__ import annotations

import json
import ssl
import urllib.error
import urllib.request
from typing import Any


def get_json(
    url: str,
    *,
    headers: dict[str, str] | None = None,
    timeout: float = 12.0,
) -> tuple[int, Any, str]:
    req = urllib.request.Request(
        url,
        headers=headers or {},
        method="GET",
    )
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=context) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            status = int(getattr(resp, "status", 200) or 200)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        status = int(exc.code)
    except Exception as exc:
        return 0, None, str(exc)
    try:
        body = json.loads(raw) if raw else None
    except json.JSONDecodeError:
        body = None
    return status, body, raw[:400]
