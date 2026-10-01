#!/usr/bin/env bash
# Monta AppIcon.icns a partir de um PNG/JPEG quadrado 1024.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/Resources/icon-source.png}"
ICONSET="$ROOT/Resources/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"

if [ ! -f "$SRC" ]; then
  echo "Fonte não encontrada: $SRC" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

SRC="$SRC" ICONSET="$ICONSET" python3 <<'PY'
import os
from PIL import Image

src = Image.open(os.environ["SRC"]).convert("RGBA")
folder = os.environ["ICONSET"]
sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    img = src.resize((size, size), Image.Resampling.LANCZOS)
    img.save(os.path.join(folder, name), format="PNG", optimize=True)
PY

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"
echo "OK -> $ICNS"
