"""CLI JSON para a janela do Mac e para o servidor MCP."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from .credits import attach_credits, load_cache, refresh_credits
from .store import delete_keys, mongo_settings, qclaw_root, read_keys, rows, upsert_key


def _print(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("ok") else 1


def _stats(items: list[dict[str, Any]]) -> dict[str, Any]:
    configured = [r for r in items if r.get("configured")]
    with_credit = [
        r for r in configured
        if isinstance(r.get("credit"), dict) and r["credit"].get("ok")
    ]
    return {
        "configured": len(configured),
        "total": len(items),
        "missing": len(items) - len(configured),
        "with_credit": len(with_credit),
    }


def _payload(include_credits: bool, refresh: bool, names: list[str] | None = None,
             configured_only: bool = False, category: str = "") -> dict[str, Any]:
    stored = read_keys()
    items = rows(stored)
    if names:
        wanted = {n.strip().upper() for n in names if n.strip()}
        items = [r for r in items if r.get("name") in wanted]
    if category:
        cat = category.strip().lower()
        items = [r for r in items if str(r.get("category") or "") == cat]
    if configured_only:
        items = [r for r in items if r.get("configured")]
    credit_data = None
    if refresh:
        providers = sorted(
            {
                str(r.get("credit_provider"))
                for r in items
                if r.get("configured") and r.get("credit_provider")
            }
        )
        credit_data = refresh_credits(stored, providers=providers or None)
    elif include_credits:
        credit_data = load_cache()
    if include_credits or refresh:
        items = attach_credits(items, credit_data)
    uri, db = mongo_settings()
    return {
        "ok": True,
        "keys": items,
        "stats": _stats(items),
        "credits": {
            "updated_at": (credit_data or {}).get("updated_at"),
            "providers": (credit_data or {}).get("providers") or {},
        } if (include_credits or refresh) else None,
        "store": {
            "mongodb_uri": uri.split("@")[-1] if "@" in uri else uri,
            "mongodb_db": db,
            "qclaw_root": str(qclaw_root() or ""),
        },
    }


def cmd_list(args: argparse.Namespace) -> int:
    names = [args.name] if args.name else None
    return _print(
        _payload(
            include_credits=args.credits or args.refresh,
            refresh=args.refresh,
            names=names,
            configured_only=args.configured_only,
            category=args.category or "",
        )
    )


def cmd_credits(args: argparse.Namespace) -> int:
    stored = read_keys()
    providers = args.providers or None
    data = refresh_credits(stored, providers=providers)
    return _print(data)


def cmd_upsert(args: argparse.Namespace) -> int:
    result = upsert_key(args.name, args.value)
    if result.get("ok"):
        result.update(_payload(include_credits=False, refresh=False, names=[args.name]))
        result["ok"] = True
    return _print(result)


def cmd_delete(args: argparse.Namespace) -> int:
    names = list(args.names or [])
    if args.names_csv:
        names.extend(n.strip() for n in str(args.names_csv).split(",") if n.strip())
    result = delete_keys(names)
    if result.get("ok"):
        result.update(_payload(include_credits=False, refresh=False))
        result["ok"] = True
    return _print(result)


def cmd_status(_args: argparse.Namespace) -> int:
    try:
        stored = read_keys()
        mongo_ok = True
        error = None
    except Exception as exc:
        stored = {}
        mongo_ok = False
        error = str(exc)
    uri, db = mongo_settings()
    return _print(
        {
            "ok": mongo_ok,
            "mongodb": mongo_ok,
            "error": error,
            "configured": len(stored),
            "store": {
                "mongodb_uri": uri.split("@")[-1] if "@" in uri else uri,
                "mongodb_db": db,
                "qclaw_root": str(qclaw_root() or ""),
            },
        }
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Cofre de chaves e créditos")
    sub = parser.add_subparsers(dest="cmd", required=True)

    listing = sub.add_parser("list", help="Listar chaves mascaradas")
    listing.add_argument("--name")
    listing.add_argument("--category")
    listing.add_argument("--configured-only", action="store_true")
    listing.add_argument("--credits", action="store_true", help="Anexar último saldo em cache")
    listing.add_argument("--refresh", action="store_true", help="Sondar saldo agora")
    listing.set_defaults(func=cmd_list)

    credits = sub.add_parser("credits", help="Sondar saldo dos provedores")
    credits.add_argument("--provider", dest="providers", action="append")
    credits.set_defaults(func=cmd_credits)

    upsert = sub.add_parser("upsert", help="Gravar uma chave")
    upsert.add_argument("--name", required=True)
    upsert.add_argument("--value", required=True)
    upsert.set_defaults(func=cmd_upsert)

    delete = sub.add_parser("delete", help="Apagar chaves")
    delete.add_argument("--name", action="append", dest="names")
    delete.add_argument("--names", dest="names_csv")
    delete.set_defaults(func=cmd_delete)

    status = sub.add_parser("status", help="Saúde do Mongo e do cofre")
    status.set_defaults(func=cmd_status)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
