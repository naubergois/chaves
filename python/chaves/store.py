"""Lê e grava no mesmo documento Mongo `env_keys` do QClaw."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

from .catalog import all_catalog_names, catalog_entry
from .mask import is_placeholder, is_storable_name, mask_secret

HOME = Path.home()
QCLAW_CANDIDATES = [
    Path(os.environ.get("CHAVES_QCLAW_ROOT") or ""),
    HOME / "qclawmonitor",
    Path("/Users/naubergois/qclawmonitor"),
    Path("/Volumes/NAUBER/qclawmonitor"),
]


def qclaw_root() -> Path | None:
    for path in QCLAW_CANDIDATES:
        if path and (path / "src" / "gois").is_dir():
            return path
    return None


def _load_dotenv(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:]
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip("'").strip('"')
        values[key.strip()] = value
    return values


def mongo_settings() -> tuple[str, str]:
    env = dict(os.environ)
    root = qclaw_root()
    if root:
        for name, value in _load_dotenv(root / ".env").items():
            env.setdefault(name, value)
    uri = (env.get("MONGODB_URI") or "mongodb://localhost:27017").strip()
    db = (env.get("MONGODB_DB") or "gois").strip()
    return uri, db


def _gois_store():
    root = qclaw_root()
    if root:
        src = str(root / "src")
        if src not in sys.path:
            sys.path.insert(0, src)
    try:
        from gois.env_keys_mongo import EnvKeysStore

        return EnvKeysStore()
    except Exception:
        return None


def _pymongo_keys() -> dict[str, str]:
    uri, db_name = mongo_settings()
    from pymongo import MongoClient

    client = MongoClient(uri, serverSelectionTimeoutMS=4000)
    doc = client[db_name]["env_keys"].find_one({"_id": "default"}) or {}
    raw = doc.get("keys")
    if not isinstance(raw, dict):
        return {}
    return {
        str(k).strip(): str(v).strip()
        for k, v in raw.items()
        if str(k).strip() and str(v).strip() and not is_placeholder(str(v))
    }


def read_keys() -> dict[str, str]:
    store = _gois_store()
    if store is not None:
        try:
            return dict(store.get_all(use_cache=False))
        except TypeError:
            return dict(store.get_all())
    return _pymongo_keys()


def upsert_key(name: str, value: str) -> dict[str, Any]:
    name = (name or "").strip().upper()
    value = (value or "").strip()
    if not is_storable_name(name):
        return {"ok": False, "error": f"nome inválido: {name!r}"}
    if is_placeholder(value):
        return {"ok": False, "error": "valor vazio ou placeholder"}
    store = _gois_store()
    if store is not None:
        written = store.upsert({name: value}, merge=True, allow_all=True)
        return {"ok": True, "name": name, "updated": written, "masked": mask_secret(value)}
    uri, db_name = mongo_settings()
    from pymongo import MongoClient

    client = MongoClient(uri, serverSelectionTimeoutMS=4000)
    col = client[db_name]["env_keys"]
    existing = col.find_one({"_id": "default"}) or {}
    merged = dict(existing.get("keys") or {})
    merged[name] = value
    col.replace_one(
        {"_id": "default"},
        {"_id": "default", "keys": merged},
        upsert=True,
    )
    return {"ok": True, "name": name, "updated": 1, "masked": mask_secret(value)}


def delete_keys(names: list[str]) -> dict[str, Any]:
    cleaned = [n.strip().upper() for n in names if n and is_storable_name(n.strip())]
    if not cleaned:
        return {"ok": False, "error": "informe ao menos um nome válido"}
    store = _gois_store()
    if store is not None and hasattr(store, "delete"):
        removed = store.delete(cleaned)
        return {"ok": True, "deleted": cleaned, "removed": removed}
    uri, db_name = mongo_settings()
    from pymongo import MongoClient

    client = MongoClient(uri, serverSelectionTimeoutMS=4000)
    col = client[db_name]["env_keys"]
    existing = col.find_one({"_id": "default"}) or {}
    merged = dict(existing.get("keys") or {})
    removed = 0
    for name in cleaned:
        if name in merged:
            merged.pop(name)
            removed += 1
    col.replace_one(
        {"_id": "default"},
        {"_id": "default", "keys": merged},
        upsert=True,
    )
    return {"ok": True, "deleted": cleaned, "removed": removed}


def rows(stored: dict[str, str] | None = None) -> list[dict[str, Any]]:
    stored = stored if stored is not None else read_keys()
    names: list[str] = []
    seen: set[str] = set()
    for name in sorted(stored):
        if name not in seen:
            names.append(name)
            seen.add(name)
    for name in all_catalog_names():
        if name not in seen:
            names.append(name)
            seen.add(name)
    out: list[dict[str, Any]] = []
    for name in names:
        value = stored.get(name, "")
        entry = catalog_entry(name)
        out.append(
            {
                **entry,
                "configured": bool(value),
                "masked": mask_secret(value) if value else "",
                "source": "mongodb" if value else "",
            }
        )
    return out
