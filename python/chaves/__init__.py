"""Cofre de chaves e créditos — mesma fonte do QClaw (`env_keys` no Mongo)."""

from .catalog import CATALOG, catalog_entry
from .cli import main
from .mask import mask_secret

__all__ = ["CATALOG", "catalog_entry", "main", "mask_secret"]
