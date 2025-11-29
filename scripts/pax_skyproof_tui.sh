#!/usr/bin/env bash
set -euo pipefail

# PAX / SKY-PROOF helper TUI
# Requires:
#   - Bash (Git Bash on Windows is fine)
#   - python (with nacl for Ed25519)
#   - jq
#   - emercoin-cli(.exe) and privateness-cli(.exe) in ./scripts/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH="$SCRIPT_DIR:$PATH"

EMER_CLI="${EMER_CLI:-emercoin-cli}"
PRIV_CLI="${PRIV_CLI:-privateness-cli}"
PYTHON_BIN="${PYTHON_BIN:-python}"

TOOLS_DIR="${TOOLS_DIR:-}"


LAST_WALLET=""
LAST_ADDRESS=""
LAST_COINS=""
LAST_UNSIGNED_JSON=""

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_basics() {
  require_cmd "$PYTHON_BIN"
  require_cmd "$EMER_CLI"
  require_cmd "$PRIV_CLI"

  if ! "$PYTHON_BIN" - <<'PY'
import sys
try:
    import nacl.signing  # noqa: F401
except Exception:
    sys.exit(1)
PY
  then
    echo "Python module 'nacl' (PyNaCl) is required; install with: pip install pynacl" >&2
    exit 1
  fi

  if [[ ! -f "$SCRIPT_DIR/emercoin-value.py" ]]; then
    echo "Missing $SCRIPT_DIR/emercoin-value.py (required for EmerNVS value extraction)" >&2
    exit 1
  fi
}

emer_value() {
  # All emercoin-cli calls go through emercoin-value.py to extract .value
  "$EMER_CLI" "$@" | "$PYTHON_BIN" "$SCRIPT_DIR/emercoin-value.py"
}

json_extract_hex() {
  local mode="$1"
  "$PYTHON_BIN" -c '
import sys, json

if len(sys.argv) != 2:
    sys.exit(1)

mode = sys.argv[1]

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)


def find_first(d, paths):
    for path in paths:
        cur = d
        try:
            for key in path:
                cur = cur[key]
        except Exception:
            continue
        if isinstance(cur, str) and cur:
            return cur
    return ""


if mode == "unsigned":
    paths = [
        ("data", "encoded_transaction"),
        ("data", "unsigned_tx"),
        ("encoded_transaction",),
        ("unsigned_tx",),
    ]
else:
    paths = [
        ("data", "encoded_transaction"),
        ("data", "signed_tx"),
        ("encoded_transaction",),
        ("signed_tx",),
    ]

val = find_first(data, paths)
if not val:
    sys.exit(1)

print(val)
' "$mode"
}

bootstrap_ness_wallet() {
  echo
  echo "=== EmerNVS bootstrap: ness:wallet ==="
  local value
  if ! value="$(emer_value name_show ness:wallet)"; then
    echo "Failed to read EmerNVS record ness:wallet" >&2
    return 1
  fi

  echo
  echo "EmerNVS value for ness:wallet:"
  echo "--------------------------------"
  echo "$value"
  echo "--------------------------------"
  echo "This is expected to be a shell command (e.g. 'curl ... | bash')."
  read -r -p "Execute this value as a shell command? [y/N] " ans
  case "$ans" in
    [Yy]*)
      echo
      echo "Executing: $value"
      bash -c "$value"
      ;;
    *)
      echo "Skipped execution."
      ;;
  esac
}

create_pax_identity() {
  echo
  echo "=== Create PAX Ed25519 identity via PrivatenessTools (keygen user) ==="

  if [[ -z "$TOOLS_DIR" ]]; then
    if TOOLS_DIR_TMP="$(cd "$SCRIPT_DIR/../privatenesstools" 2>/dev/null && pwd)"; then
      TOOLS_DIR="$TOOLS_DIR_TMP"
    else
      TOOLS_DIR=""
    fi
  fi

  if [[ -z "$TOOLS_DIR" || ! -f "$TOOLS_DIR/keygen.py" ]]; then
    echo "PrivatenessTools keygen.py not found (expected at $SCRIPT_DIR/../privatenesstools/keygen.py)" >&2
    return 1
  fi

  read -r -p "PAX username (Privateness user name): " username
  if [[ -z "$username" ]]; then
    echo "Username is required" >&2
    return 1
  fi

  local entropy_default=100
  echo "Entropy level is the number of iterations keygen uses in KeyManager.__generate_seed(entropy): each iteration draws 1024 random bytes from os.urandom and feeds them into the UhePrng entropy pool. Higher values are slower but mix in more OS randomness."
  read -r -p "Entropy level for keygen [press Enter for default ${entropy_default}]: " entropy
  if [[ -z "$entropy" ]]; then
    entropy="$entropy_default"
  fi
  if ! [[ "$entropy" =~ ^[0-9]+$ ]] || (( entropy < 1 )); then
    echo "Entropy level must be a positive integer" >&2
    return 1
  fi

  echo "Using PrivatenessTools keys directory: $HOME/.privateness-keys"
  echo "Running: $PYTHON_BIN $TOOLS_DIR/keygen.py user \"$username\" \"$entropy\""
  "$PYTHON_BIN" "$TOOLS_DIR/keygen.py" user "$username" "$entropy"
}

select_wallet_and_address() {
	echo
	echo "=== Wallet selection (privateness-cli listWallets) ==="
	echo "Discovering wallets..."

	local wallets_json
	if ! wallets_json="$("$PRIV_CLI" listWallets 2>/dev/null)"; then
		echo "(listWallets failed or not available)" >&2
		return 1
	fi

	echo "Existing wallets (raw listWallets output):"
	echo "--------------------------------"
	printf '%s\n' "$wallets_json"
	echo "--------------------------------"

	local parsed
	if ! parsed="$(printf '%s\n' "$wallets_json" | "$PYTHON_BIN" -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

directory = data.get("directory") or ""
wallets = data.get("wallets") or []

if not wallets:
    print("NOWALLETS")
    sys.exit(0)

print("DIR|" + directory)
for idx, w in enumerate(wallets, 1):
    name = w.get("name", "")
    label = w.get("label", "")
    print(f"{idx}|{name}|{label}")
')"; then
		echo "Failed to parse listWallets JSON" >&2
		return 1
	fi

	local dir=""
	local entries=()
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		if [[ "$line" == NOWALLETS ]]; then
			echo "No wallets found in listWallets output" >&2
			return 1
		fi
		if [[ "$line" == DIR\|* ]]; then
			dir="${line#DIR|}"
		else
			entries+=("$line")
		fi
	done <<< "$parsed"

	if ((${#entries[@]} == 0)); then
		echo "No wallets found in listWallets output" >&2
		return 1
	fi

	if [[ -n "$dir" ]]; then
		WALLET_DIR="$dir"
	else
		WALLET_DIR="$HOME/.privateness/wallets"
	fi
	export WALLET_DIR
	echo "Detected WALLET_DIR: $WALLET_DIR"

	echo "Available wallets:"
	local e
	for e in "${entries[@]}"; do
		IFS='|' read -r idx name label <<< "$e"
		if [[ -n "$label" ]]; then
			echo "  $idx) $name  [$label]"
		else
			echo "  $idx) $name"
		fi
	done

	local choice
	read -r -p "Select wallet [1-${#entries[@]}]: " choice
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#entries[@]} )); then
		echo "Invalid selection" >&2
		return 1
	fi
	local selected="${entries[$((choice-1))]}"
	IFS='|' read -r _idx wallet _label <<< "$selected"

	WALLET_NAME="$wallet"
	export WALLET_NAME
	echo "Selected WALLET_NAME: $WALLET_NAME"

  read -r -p "Self-spend address: " address
  if [[ -z "$address" ]]; then
    echo "Address is required" >&2
    return 1
  fi

  read -r -p "Amount (coins, e.g. 0.001): " coins
  if [[ -z "$coins" ]]; then
    echo "Amount is required" >&2
    return 1
  fi

  	LAST_WALLET="$WALLET_NAME"
  LAST_ADDRESS="$address"
  LAST_COINS="$coins"
}

create_unsigned_tx() {
  echo
  echo "=== Create unsigned self-spend transaction (createRawTransactionV2) ==="

  if [[ -z "${LAST_WALLET}" || -z "${LAST_ADDRESS}" || -z "${LAST_COINS}" ]]; then
    select_wallet_and_address || return 1
  else
    echo "Using last selection:"
    echo "  Wallet : $LAST_WALLET"
    echo "  Address: $LAST_ADDRESS"
    echo "  Coins  : $LAST_COINS"
    read -r -p "Reuse these values? [Y/n] " reuse
    case "$reuse" in
      [Nn]*)
        select_wallet_and_address || return 1
        ;;
    esac
  fi

  local wallet="$LAST_WALLET"
  local address="$LAST_ADDRESS"
  local coins="$LAST_COINS"

  echo
  echo "Running:"
  echo "  $PRIV_CLI createRawTransactionV2 \"$wallet\" \"$address\" \"$coins\" --from-address \"$address\" --unsign --json"
  local raw_create
  if ! raw_create="$("$PRIV_CLI" createRawTransactionV2 "$wallet" "$address" "$coins" \
      --from-address "$address" \
      --unsign \
      --json)"; then
    echo "createRawTransactionV2 failed" >&2
    return 1
  fi

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local out_json="$SCRIPT_DIR/unsigned-${ts}.json"
  printf '%s\n' "$raw_create" >"$out_json"

  local unsigned_hex
  if ! unsigned_hex="$(printf '%s\n' "$raw_create" | json_extract_hex unsigned)"; then
    echo "Failed to extract unsigned transaction hex from createRawTransactionV2 JSON" >&2
    echo "See full JSON in: $out_json" >&2
    return 1
  fi

  LAST_UNSIGNED_JSON="$out_json"

  echo
  echo "Unsigned transaction JSON saved to: $out_json"
  echo "Unsigned transaction hex (first 80 chars):"
  echo "${unsigned_hex:0:80}..."
}

sign_transaction_from_json() {
  echo
  echo "=== Sign transaction (signTransaction) ==="

  if [[ -z "${LAST_WALLET}" ]]; then
    read -r -p "Wallet file to use for signing: " wallet
    if [[ -z "$wallet" ]]; then
      echo "Wallet is required" >&2
      return 1
    fi
    LAST_WALLET="$wallet"
  fi

  local wallet="$LAST_WALLET"

  local json_path
  if [[ -n "${LAST_UNSIGNED_JSON}" && -f "${LAST_UNSIGNED_JSON}" ]]; then
    echo "Last unsigned JSON file: $LAST_UNSIGNED_JSON"
    read -r -p "Use this file? [Y/n] " use_last
    case "$use_last" in
      [Nn]*)
        read -r -p "Path to unsigned transaction JSON file: " json_path
        ;;
      *)
        json_path="$LAST_UNSIGNED_JSON"
        ;;
    esac
  else
    read -r -p "Path to unsigned transaction JSON file: " json_path
  fi

  if [[ -z "$json_path" || ! -f "$json_path" ]]; then
    echo "Invalid JSON file path: $json_path" >&2
    return 1
  fi

  local raw_create
  raw_create="$(cat "$json_path")"

  local unsigned_hex
  if ! unsigned_hex="$(printf '%s\n' "$raw_create" | json_extract_hex unsigned)"; then
    echo "Failed to extract unsigned transaction hex from JSON file" >&2
    return 1
  fi

  echo
  echo "Running:"
  echo "  $PRIV_CLI signTransaction \"$wallet\" <unsigned_hex> --json"
  local raw_sign
  if ! raw_sign="$("$PRIV_CLI" signTransaction "$wallet" "$unsigned_hex" --json)"; then
    echo "signTransaction failed" >&2
    return 1
  fi

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local signed_json="$SCRIPT_DIR/signed-${ts}.json"
  printf '%s\n' "$raw_sign" >"$signed_json"

  local signed_hex
  if ! signed_hex="$(printf '%s\n' "$raw_sign" | json_extract_hex signed)"; then
    signed_hex=""
  fi

  echo
  echo "Signed transaction JSON saved to: $signed_json"
  if [[ -n "$signed_hex" ]]; then
    echo "Signed transaction hex (first 80 chars):"
    echo "${signed_hex:0:80}..."
  else
    echo "Could not extract signed transaction hex; inspect JSON manually." >&2
  fi
}

main_menu() {
  require_basics

  while true; do
    echo
    echo "================ PAX / SKY-PROOF helper ================"
    echo "1) Bootstrap ness client wallet from EmerNVS (ness:wallet)"
    echo "2) Create PAX Ed25519 identity (user.key.json)"
    echo "3) Create unsigned self-spend tx (createRawTransactionV2 --unsign --json)"
    echo "4) Sign unsigned transaction (signTransaction --json)"
    echo "5) Quit"
    echo "========================================================"
    read -r -p "Select option [1-5]: " choice || exit 0
    case "$choice" in
      1) bootstrap_ness_wallet ;;
      2) create_pax_identity ;;
      3) create_unsigned_tx ;;
      4) sign_transaction_from_json ;;
      5) echo "Bye."; exit 0 ;;
      *) echo "Invalid choice: $choice" >&2 ;;
    esac
  done
}

main_menu