#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/sky_selfspend_demo.sh <wallet.wlt> <address> <coins>
# Demonstrates creation and signing of a canonical self-spend transaction
# using privateness-cli, without broadcasting.

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <wallet.wlt> <address> <coins>" >&2
  exit 1
fi

WALLET="$1"
ADDRESS="$2"
COINS="$3"

echo "Creating unsigned self-spend transaction..." >&2
go run $HOME/go/src/github.com/ness-network/ness/cmd/privateness-cli/privateness-cli.go createRawTransactionV2 "$WALLET" "$ADDRESS" "$COINS" \
  --from-address "$ADDRESS" \
  --unsign \
  --json

echo >&2
echo "Copy the unsigned transaction hex from the JSON output above and paste it below, then press Ctrl-D." >&2

UNSIGNED_HEX="$(cat)"

echo >&2
echo "Signing transaction..." >&2
privateness-cli signTransaction "$WALLET" "$UNSIGNED_HEX" --json
