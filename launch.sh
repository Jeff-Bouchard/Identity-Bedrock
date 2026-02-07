#!/usr/bin/env bash
# Minimal Nano-Mina launcher for Git Bash (no shell hijack, no Powershell)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=${PYTHON:-python}
SEED="${1:-}"
SUPPLY="${2:-1000000}"

if [[ -z "$SEED" ]]; then
    echo "Usage: ./launch.sh \"seed phrase\" [supply]" >&2
    exit 1
fi

# Run node in foreground from repo root (no cd tricks)
"$PYTHON" "$ROOT_DIR/scripts/mina_lab/nanomina.py" node --words "$SEED" --supply "$SUPPLY"

# After node exits, instructions to open UI manually
echo "If node is running, open: http://localhost:61234/unified.html"
