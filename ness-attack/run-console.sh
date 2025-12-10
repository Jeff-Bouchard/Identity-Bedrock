#!/usr/bin/env bash

# Ness Attack Console launcher
# Builds (if needed) and runs the ness-attack container, starting the
# web UI on port 18080.
#
# Usage (from repo root or this directory):
#   ./ness-attack/run-console.sh
# Then open http://127.0.0.1:18080 in your browser.
#
# Scope: your own host and LAN, authorised lab / production defense only.
# Ethic: EULA applies. Do no harm.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_USER="${DOCKER_USER:-nessnetwork}"
IMAGE_NAME="${DOCKER_USER}/ness-attack:latest"

if ! command -v docker >/dev/null 2>&1; then
  echo "[attack-console] docker is required but not installed or not in PATH." >&2
  exit 1
fi

# Build image if it does not exist locally
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[attack-console] Building $IMAGE_NAME from ./ness-attack..."
  ( cd "$REPO_ROOT" && docker build -t "$IMAGE_NAME" ./ness-attack )
fi

echo "[attack-console] Starting Ness Attack web console on http://127.0.0.1:18080"

# Inside the container we have python3; fall back to python if needed.
docker run --rm -p 18080:18080 "$IMAGE_NAME" bash -lc 'command -v python3 >/dev/null 2>&1 && python3 /opt/ness-attack-webui/app.py || python /opt/ness-attack-webui/app.py'
