#!/usr/bin/env bash
set -euo pipefail

# PAX canonical Sky/Privateness self-spend helper
#
# Automates the canonical self-spend proof described in the PAX docs:
#   1. Use inputs exclusively from a single Sky/Privateness address
#   2. Create an unsigned self-spend transaction (address -> same address)
#   3. Sign it with privateness-cli
#   4. Emit a normalized JSON blob ready for the PAX sky_proof payload
#
# Usage:
#   ./scripts/pax_canonical_selfspend.sh <wallet.wlt> <address> <coins> [network]
#
# Requirements:
#   - privateness-cli on PATH (e.g. $HOME/go/src/github.com/ness-network/ness/cmd/privateness-cli/privateness-cli.go build)
#   - jq for JSON parsing

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <wallet.wlt> <address> <coins> [network]" >&2
  exit 1
fi

command -v privateness-cli >/dev/null 2>&1 || {
  echo "privateness-cli not found in PATH" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "jq is required to parse privateness-cli JSON output" >&2
  exit 1
}

WALLET=$1
ADDRESS=$2
COINS=$3
NETWORK=${4:-privateness-mainnet}

if ! [[ $COINS =~ ^[0-9]+$ ]]; then
  echo "Coins value must be an integer number of whole coins" >&2
  exit 1
fi

echo "[1/4] Creating canonical self-spend (from $ADDRESS to itself for $COINS coin(s))" >&2
RAW_CREATE=$(privateness-cli createRawTransactionV2 "$WALLET" "$ADDRESS" "$COINS" \
  --from-address "$ADDRESS" \
  --unsign \
  --json)

UNSIGNED_HEX=$(echo "$RAW_CREATE" | jq -r '.data.encoded_transaction // .data.unsigned_tx // .encoded_transaction // .unsigned_tx // empty')

if [[ -z $UNSIGNED_HEX || $UNSIGNED_HEX == "null" ]]; then
  echo "Failed to extract unsigned transaction hex from createRawTransactionV2 output" >&2
  exit 1
fi

echo "[2/4] Signing transaction with $WALLET" >&2
RAW_SIGN=$(privateness-cli signTransaction "$WALLET" "$UNSIGNED_HEX" --json)

SIGNED_HEX=$(echo "$RAW_SIGN" | jq -r '.data.encoded_transaction // .data.signed_tx // .encoded_transaction // .signed_tx // empty')

if [[ -z $SIGNED_HEX || $SIGNED_HEX == "null" ]]; then
  echo "Failed to extract signed transaction hex from signTransaction output" >&2
  exit 1
fi

echo "[3/4] Decoding signed transaction for metadata" >&2
RAW_DECODE=$(privateness-cli decodeRawTransaction "$SIGNED_HEX" --json)

TXID=$(echo "$RAW_DECODE" | jq -r '.data.txid // .txid // empty')
[[ -n $TXID && $TXID != "null" ]] || TXID="(not-yet-broadcast)"

OUTPUT_ADDRESSES=$(echo "$RAW_DECODE" | jq -r '[.data.tx.outputs // .tx.outputs // empty][]?.address // empty')

if [[ -n $OUTPUT_ADDRESSES ]]; then
  UNIQUE_OUTPUTS=$(echo "$OUTPUT_ADDRESSES" | sort -u)
  if [[ $(echo "$UNIQUE_OUTPUTS" | wc -l) -ne 1 || $UNIQUE_OUTPUTS != "$ADDRESS" ]]; then
    echo "Warning: decoded outputs do not exclusively target $ADDRESS" >&2
  fi
else
  echo "Warning: could not parse outputs from decodeRawTransaction; skipping canonical check" >&2
fi

echo "[4/4] Emitting PAX sky_proof JSON" >&2

jq -n \
  --arg network "$NETWORK" \
  --arg address "$ADDRESS" \
  --arg unsigned "$UNSIGNED_HEX" \
  --arg signed "$SIGNED_HEX" \
  --arg txid "$TXID" \
  '{
    sky_proof: {
      network: $network,
      policy: {
        type: "canonical-self-spend",
        address: $address,
        self_spend: true
      },
      txid: $txid,
      unsigned_tx_hex: $unsigned,
      signed_tx_hex: $signed
    }
  }'

cat >&2 <<'EOF'

Paste the JSON above into your PAX completion payload under the "sky_proof" field.
Broadcasting is optional; if you later broadcast, replace txid with the on-chain value.
EOF
