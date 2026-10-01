"""Sonda o saldo de cada provedor. A chave nunca sai daqui."""

from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from .catalog import CATALOG
from .httputil import get_json

CACHE_PATH = Path.home() / "Library" / "Application Support" / "Chaves" / "credits.json"

Probe = Callable[[dict[str, str]], dict[str, Any]]


def _num(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _ok(provider: str, *, label: str, balance: float | None = None, unit: str = "",
        detail: str = "", extra: dict[str, Any] | None = None) -> dict[str, Any]:
    row = {
        "ok": True,
        "provider": provider,
        "status": "ok",
        "label": label,
        "detail": detail,
        "balance": balance,
        "unit": unit,
        "error": None,
    }
    if extra:
        row.update(extra)
    return row


def _fail(provider: str, error: str, *, hint: str = "") -> dict[str, Any]:
    return {
        "ok": False,
        "provider": provider,
        "status": "error",
        "label": "—",
        "detail": hint,
        "balance": None,
        "unit": "",
        "error": error,
    }


def _skip(provider: str, reason: str) -> dict[str, Any]:
    return {
        "ok": False,
        "provider": provider,
        "status": "missing_key",
        "label": "sem chave",
        "detail": reason,
        "balance": None,
        "unit": "",
        "error": reason,
    }


def _key(keys: dict[str, str], *names: str) -> str:
    for name in names:
        value = (keys.get(name) or "").strip()
        if value:
            return value
    return ""


def probe_openrouter(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "OPENROUTER_API_KEY")
    if not token:
        return _skip("openrouter", "OPENROUTER_API_KEY ausente")
    status, body, raw = get_json(
        "https://openrouter.ai/api/v1/credits",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("openrouter", f"HTTP {status}", hint=raw)
    data = body.get("data") if isinstance(body.get("data"), dict) else body
    total = _num(data.get("total_credits"))
    used = _num(data.get("total_usage"))
    if total is None:
        return _fail("openrouter", "resposta sem total_credits")
    remaining = max(0.0, total - (used or 0.0))
    return _ok(
        "openrouter",
        label=f"${remaining:.2f}",
        balance=remaining,
        unit="usd",
        detail=f"usado ${used or 0:.2f} de ${total:.2f}",
        extra={"total": total, "used": used},
    )


def probe_heygen(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "HEYGEN_API_KEY")
    if not token:
        return _skip("heygen", "HEYGEN_API_KEY ausente")
    status, body, raw = get_json(
        "https://api.heygen.com/v2/user/remaining_quota",
        headers={"x-api-key": token, "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("heygen", f"HTTP {status}", hint=raw)
    data = body.get("data") if isinstance(body.get("data"), dict) else body
    remaining = (
        _num(data.get("remaining_quota"))
        or _num(data.get("remaining"))
        or _num(data.get("quota_remaining"))
    )
    if remaining is None:
        return _fail("heygen", "quota não veio no JSON")
    return _ok(
        "heygen",
        label=f"{int(remaining)} cr",
        balance=remaining,
        unit="credits",
        detail="créditos de vídeo restantes",
    )


def probe_elevenlabs(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "ELEVENLABS_API_KEY")
    if not token:
        return _skip("elevenlabs", "ELEVENLABS_API_KEY ausente")
    status, body, raw = get_json(
        "https://api.elevenlabs.io/v1/user/subscription",
        headers={"xi-api-key": token, "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("elevenlabs", f"HTTP {status}", hint=raw)
    used = _num(body.get("character_count"))
    limit = _num(body.get("character_limit"))
    if used is None or limit is None:
        return _fail("elevenlabs", "subscription sem character_limit")
    remaining = max(0.0, limit - used)
    return _ok(
        "elevenlabs",
        label=f"{int(remaining):,} car".replace(",", "."),
        balance=remaining,
        unit="characters",
        detail=f"{int(used):,} de {int(limit):,} caracteres".replace(",", "."),
        extra={"used": used, "limit": limit, "tier": body.get("tier")},
    )


def probe_deepseek(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "DEEPSEEK_API_KEY")
    if not token:
        return _skip("deepseek", "DEEPSEEK_API_KEY ausente")
    status, body, raw = get_json(
        "https://api.deepseek.com/user/balance",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("deepseek", f"HTTP {status}", hint=raw)
    infos = body.get("balance_infos")
    if isinstance(infos, list) and infos and isinstance(infos[0], dict):
        row = infos[0]
        total = _num(row.get("total_balance"))
        currency = str(row.get("currency") or "USD")
        if total is not None:
            symbol = "$" if currency.upper() == "USD" else f"{currency} "
            return _ok(
                "deepseek",
                label=f"{symbol}{total:.2f}",
                balance=total,
                unit=currency.lower(),
                detail="saldo da conta",
            )
    return _fail("deepseek", "balance_infos vazio")


def probe_gamma(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "GAMMA_API_KEY")
    if not token:
        return _skip("gamma", "GAMMA_API_KEY ausente")
    status, body, raw = get_json(
        "https://public-api.gamma.app/v1.0/credits",
        headers={
            "X-API-KEY": token,
            "Accept": "application/json",
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            ),
        },
    )
    if status == 404:
        return _fail("gamma", "endpoint de créditos indisponível", hint="veja o console da Gamma")
    if status != 200 or not isinstance(body, dict):
        return _fail("gamma", f"HTTP {status}", hint=raw)
    remaining = _num(body.get("remaining") or body.get("credits_remaining") or body.get("balance"))
    if remaining is None:
        return _fail("gamma", "JSON sem remaining")
    return _ok(
        "gamma",
        label=f"{int(remaining)} cr",
        balance=remaining,
        unit="credits",
        detail="créditos de lâmina",
    )


def probe_stability(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "STABILITY_API_KEY", "STABILITY_AI_API_KEY")
    if not token:
        return _skip("stability", "STABILITY_API_KEY ausente")
    status, body, raw = get_json(
        "https://api.stability.ai/v1/user/balance",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("stability", f"HTTP {status}", hint=raw)
    credits = _num(body.get("credits"))
    if credits is None:
        return _fail("stability", "JSON sem credits")
    return _ok(
        "stability",
        label=f"{credits:.1f} cr",
        balance=credits,
        unit="credits",
        detail="créditos Stability",
    )


def probe_replicate(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "REPLICATE_API_TOKEN")
    if not token:
        return _skip("replicate", "REPLICATE_API_TOKEN ausente")
    status, body, raw = get_json(
        "https://api.replicate.com/v1/account",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("replicate", f"HTTP {status}", hint=raw)
    username = str(body.get("username") or body.get("name") or "ok")
    return _ok(
        "replicate",
        label="conta ok",
        balance=None,
        unit="",
        detail=f"@{username} — saldo só no console",
        extra={"username": username},
    )


def probe_civitai(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "CIVITAI_API_TOKEN", "CIVITAI_API_KEY")
    if not token:
        return _skip("civitai", "CIVITAI_API_TOKEN ausente")
    status, body, raw = get_json(
        "https://civitai.com/api/v1/me",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    if status != 200 or not isinstance(body, dict):
        return _fail("civitai", f"HTTP {status}", hint=raw)
    buzz = body.get("buzz")
    amount = None
    if isinstance(buzz, dict):
        amount = _num(buzz.get("balance") or buzz.get("total"))
    if amount is None:
        amount = _num(body.get("balance"))
    username = str(body.get("username") or "")
    if amount is None:
        return _ok(
            "civitai",
            label="conta ok",
            detail=f"@{username}" if username else "Buzz só no site",
            extra={"username": username},
        )
    return _ok(
        "civitai",
        label=f"{int(amount)} buzz",
        balance=amount,
        unit="buzz",
        detail=f"@{username}" if username else "saldo Buzz",
        extra={"username": username},
    )


def probe_fal(keys: dict[str, str]) -> dict[str, Any]:
    token = _key(keys, "FAL_KEY", "FAL_API_KEY")
    if not token:
        return _skip("fal", "FAL_KEY ausente")
    # fal não publica saldo estável; um GET autenticado confirma a chave.
    status, body, raw = get_json(
        "https://rest.alpha.fal.ai/tokens/",
        headers={"Authorization": f"Key {token}", "Accept": "application/json"},
    )
    if status in {401, 403}:
        return _fail("fal", "chave recusada")
    if status == 0:
        return _fail("fal", raw or "falha de rede")
    return _ok(
        "fal",
        label="chave ok",
        detail="saldo só no dashboard fal.ai",
    )


def probe_grok(keys: dict[str, str]) -> dict[str, Any]:
    mgmt = _key(keys, "XAI_MANAGEMENT_KEY")
    team = _key(keys, "XAI_TEAM_ID")
    if not mgmt:
        return _skip("grok", "XAI_MANAGEMENT_KEY ausente")
    if not team:
        return _skip("grok", "XAI_TEAM_ID ausente")
    try:
        from gois.api_credits import fetch_grok_prepaid_balance

        row = fetch_grok_prepaid_balance(mgmt, team)
        if row.get("ok"):
            bal = _num(row.get("balance_usd"))
            return _ok(
                "grok",
                label=f"${bal:.2f}" if bal is not None else "ok",
                balance=bal,
                unit="usd",
                detail="prepaid xAI",
                extra=row,
            )
        return _fail("grok", str(row.get("error") or "falha Grok"))
    except Exception:
        status, body, raw = get_json(
            f"https://management-api.x.ai/v1/billing/teams/{team}/prepaid/balance",
            headers={"Authorization": f"Bearer {mgmt}", "Accept": "application/json"},
        )
        if status != 200 or not isinstance(body, dict):
            return _fail("grok", f"HTTP {status}", hint=raw)
        total = body.get("total") if isinstance(body.get("total"), dict) else {}
        cents = _num(total.get("val"))
        dollars = abs(cents) / 100.0 if cents is not None else None
        return _ok(
            "grok",
            label=f"${dollars:.2f}" if dollars is not None else "ok",
            balance=dollars,
            unit="usd",
            detail="prepaid xAI",
        )


def probe_openai(keys: dict[str, str]) -> dict[str, Any]:
    admin = _key(keys, "OPENAI_ADMIN_API_KEY", "OPENAI_API_KEY")
    if not admin:
        return _skip("openai", "OPENAI_API_KEY ausente")
    try:
        from gois.api_credits import collect_api_credits

        data = collect_api_credits(days=30, providers=["openai"])
        row = (data.get("providers") or {}).get("openai") or {}
        if row.get("ok"):
            bal = _num(row.get("balance_usd"))
            spend = _num(row.get("spend_usd"))
            if bal is not None:
                label = f"${bal:.2f}"
                detail = "saldo disponível"
            elif spend is not None:
                label = f"${spend:.2f} / 30d"
                detail = "gasto — saldo só no billing"
            else:
                label = "ok"
                detail = "consulta ok"
            return _ok("openai", label=label, balance=bal if bal is not None else spend,
                       unit="usd", detail=detail, extra=row)
        return _fail("openai", str(row.get("error") or "falha OpenAI"))
    except Exception as exc:
        return _fail("openai", str(exc), hint="billing no console da OpenAI")


PROBES: dict[str, Probe] = {
    "openrouter": probe_openrouter,
    "heygen": probe_heygen,
    "elevenlabs": probe_elevenlabs,
    "deepseek": probe_deepseek,
    "gamma": probe_gamma,
    "stability": probe_stability,
    "replicate": probe_replicate,
    "civitai": probe_civitai,
    "fal": probe_fal,
    "grok": probe_grok,
    "openai": probe_openai,
}


def load_cache() -> dict[str, Any]:
    if not CACHE_PATH.is_file():
        return {}
    try:
        data = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def save_cache(providers: dict[str, Any]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "providers": providers,
    }
    CACHE_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def refresh_credits(keys: dict[str, str], *, providers: list[str] | None = None) -> dict[str, Any]:
    wanted = {p.strip().lower() for p in (providers or PROBES) if p.strip()}
    results: dict[str, Any] = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {
            pool.submit(PROBES[name], keys): name
            for name in wanted
            if name in PROBES
        }
        for future in as_completed(futures):
            name = futures[future]
            try:
                results[name] = future.result()
            except Exception as exc:
                results[name] = _fail(name, str(exc))
    save_cache(results)
    return {
        "ok": True,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "providers": results,
    }


def attach_credits(rows: list[dict[str, Any]], credits: dict[str, Any] | None) -> list[dict[str, Any]]:
    providers = (credits or {}).get("providers") or {}
    out: list[dict[str, Any]] = []
    for row in rows:
        name = str(row.get("name") or "")
        provider = str(row.get("credit_provider") or CATALOG.get(name, {}).get("credit_provider") or "")
        credit = providers.get(provider) if provider else None
        if not credit and not provider:
            credit = {
                "ok": False,
                "provider": "",
                "status": "unsupported",
                "label": "sem API de saldo",
                "detail": "a chave vale; o número mora no console deles",
                "balance": None,
                "unit": "",
                "error": None,
            } if row.get("configured") else None
        item = dict(row)
        item["credit"] = credit
        out.append(item)
    return out
