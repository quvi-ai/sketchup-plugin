#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
OUT="$ROOT/quviai_sketchup.rbz"

cd "$ROOT"

zip -r "$OUT" \
  quviai_sketchup.rb \
  quviai_sketchup/ \
  --exclude "*.DS_Store" \
  --exclude "*__pycache__*"

echo "Built: $OUT"
echo "Install in SketchUp: Window → Extension Manager → Install Extension…"
