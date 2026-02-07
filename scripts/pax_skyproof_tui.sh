#!/usr/bin/env bash
set -uo pipefail

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
LAST_SIGNED_JSON=""
LAST_SIGNED_HEX=""

COLOR_RESET=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_MAGENTA=""
COLOR_CYAN=""

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_BOLD=$'\033[1m'
  COLOR_DIM=$'\033[2m'
  COLOR_RED=$'\033[31m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_BLUE=$'\033[34m'
  COLOR_MAGENTA=$'\033[35m'
  COLOR_CYAN=$'\033[36m'
fi

ui_h1() { printf '%s\n' "${COLOR_BOLD}${COLOR_CYAN}$*${COLOR_RESET}"; }
ui_ok() { printf '%s\n' "${COLOR_GREEN}$*${COLOR_RESET}"; }
ui_warn() { printf '%s\n' "${COLOR_YELLOW}$*${COLOR_RESET}" >&2; }
ui_err() { printf '%s\n' "${COLOR_BOLD}${COLOR_RED}$*${COLOR_RESET}" >&2; }
ui_dim() { printf '%s\n' "${COLOR_DIM}$*${COLOR_RESET}" >&2; }

press_enter() {
  echo
  read -r -p "Press Enter to continue..." _ || true
}

mktemp_file() {
  local f
  f="$(mktemp 2>/dev/null || true)"
  if [[ -z "$f" ]]; then
    f="/tmp/pax_skyproof.$$.$RANDOM"
    : >"$f"
  fi
  printf '%s' "$f"
}

is_encrypted_wallet_error() {
  local msg="${1,,}"
  [[ "$msg" == *"wallet"* && ( "$msg" == *"encrypt"* || "$msg" == *"password"* || "$msg" == *"passphrase"* ) ]]
}

decrypt_wallet_interactive() {
  local wallet="$1"
  ui_warn "Wallet appears to be encrypted: $wallet"
  read -r -p "Decrypt wallet now (writes decrypted wallet to disk)? [y/N] (b=back, q=quit): " ans
  case "$ans" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
    [Yy]*)
      echo
      ui_dim "Running: decryptWallet \"$wallet\""
      if ! run_priv_cli decryptWallet "$wallet"; then
        ui_err "decryptWallet failed"
        return 1
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

fatal_exit() {
  ui_err "$1"
  return 1
}

is_port_listening() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -E "LISTEN\s+.*:${port}\\b" >/dev/null 2>&1
    return $?
  fi

  if command -v netstat >/dev/null 2>&1; then
    # Windows netstat output includes e.g. 0.0.0.0:6662
    netstat -ano 2>/dev/null | grep -E "LISTENING\s+.*:${port}\\b" >/dev/null 2>&1
    return $?
  fi

  return 1
}

ensure_docker_image_present() {
  local image="$1"

  if ! command -v docker >/dev/null 2>&1; then
    ui_err "Docker is not installed or not in PATH; cannot start ${image}"
    return 1
  fi

  if docker image inspect "$image" >/dev/null 2>&1; then
    return 0
  fi

  ui_warn "Docker image not present locally: $image"
  read -r -p "Pull it from hub.docker.com now? [y/N] " ans
  case "$ans" in
    [Yy]*)
      docker pull "$image"
      return $?
      ;;
    *)
      ui_warn "Skipped pulling $image"
      return 1
      ;;
  esac
}

ensure_container_running() {
  local name="$1"
  local image="$2"
  local port="$3"
  local run_args="$4"

  if is_port_listening "$port"; then
    return 0
  fi

  ui_warn "Required service is not listening on :$port"
  if command -v ss >/dev/null 2>&1; then
    ui_dim "(Diagnostic: ss -tlnp | grep :$port)"
    ss -tlnp 2>/dev/null | grep -E ":${port}\\b" || true
  fi

  if ! command -v docker >/dev/null 2>&1; then
    ui_err "Docker is not installed or not in PATH; cannot start container $name"
    return 1
  fi

  read -r -p "Start Docker container '$name' (image: $image) now? [y/N] " ans
  case "$ans" in
    [Yy]*) ;;
    *) return 1 ;;
  esac

  if ! ensure_docker_image_present "$image"; then
    return 1
  fi

  if docker container inspect "$name" >/dev/null 2>&1; then
    ui_dim "Starting existing container: $name"
    docker start "$name"
  else
    ui_dim "Creating and starting container: $name"
    ui_dim "Running: docker run -d --name $name $run_args $image"
    # Do not capture output; let docker print container id/errors directly.
    docker run -d --name "$name" $run_args "$image"
  fi

  ui_dim "Waiting for :$port to become ready..."
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if is_port_listening "$port"; then
      ui_ok "Service is now listening on :$port"
      return 0
    fi
    sleep 1
  done

  ui_err "Service still not listening on :$port after waiting."
  ui_dim "You may want to inspect logs: docker logs --tail 200 $name"
  return 1
}

ensure_emercoin_core_running() {
  # Emercoin Core RPC expected on 6662
  ensure_container_running "emercoin-core" "nessnetwork/emercoin-core" "6662" "-p 6662:6662"
}

ensure_privateness_running() {
  # Privateness RPC expected on 6660

  if run_priv_cli status >/dev/null 2>&1; then
    return 0
  fi

  if is_port_listening "6660"; then
    ui_err "Port :6660 is listening but 'privateness-cli status' failed; refusing to start docker (port may be in use or RPC creds wrong)."
    if command -v ss >/dev/null 2>&1; then
      ss -tlnp 2>/dev/null | grep -E ":6660\\b" || true
    elif command -v netstat >/dev/null 2>&1; then
      netstat -ano 2>/dev/null | grep -E ":6660\\b" || true
    fi
    return 1
  fi

  if ! ensure_container_running "privateness" "nessnetwork/privateness" "6660" "-p 6660:6660"; then
    return 1
  fi

  if run_priv_cli status >/dev/null 2>&1; then
    return 0
  fi

  ui_err "Privateness service appears to be listening on :6660 but 'privateness-cli status' is still failing."
  return 1
}

ensure_services_running() {
  if ! ensure_emercoin_core_running; then
    return 1
  fi
  if ! ensure_privateness_running; then
    return 1
  fi
  return 0
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    ui_err "Missing required command: $1"
    return 1
  fi
}

require_basics() {
  require_cmd "$PYTHON_BIN"
  require_cmd "$EMER_CLI"

  if ! ensure_emercoin_core_running; then
    ui_err "Emercoin Core is required for this option (emercoin-core :6662)."
    return 1
  fi

  if [[ ! -f "$SCRIPT_DIR/emercoin-value.py" ]]; then
    ui_err "Missing $SCRIPT_DIR/emercoin-value.py (required for EmerNVS value extraction)"
    return 1
  fi
}

require_pynacl() {
  if ! "$PYTHON_BIN" - <<'PY'
import sys
try:
    import nacl.signing  # noqa: F401
except Exception:
    sys.exit(1)
PY
  then
    ui_err "Python module 'nacl' (PyNaCl) is required; install with: pip install pynacl"
    return 1
  fi
}

require_priv_tx_cli() {
  require_cmd "$PYTHON_BIN"

  if command -v "$PRIV_CLI" >/dev/null 2>&1; then
    if ! ensure_privateness_running; then
      ui_err "Privateness service is required for this option (privateness :6660)."
      return 1
    fi
    return 0
  fi

  if [[ -z "${GOPATH:-}" ]]; then
    ui_err "privateness-cli not found in PATH and GOPATH not set; cannot fallback to go run"
    return 1
  fi

  local go_src="$GOPATH/src/github.com/ness-network/ness/cmd/privateness-cli/privateness-cli.go"

  if [[ ! -f "$go_src" ]]; then
    ui_err "privateness-cli not found in PATH and $go_src does not exist; cannot fallback to go run"
    return 1
  fi

  require_cmd go

  if ! ensure_privateness_running; then
    ui_err "Privateness service is required for this option (privateness :6660)."
    return 1
  fi
}

run_priv_cli() {
  local cli="${PRIV_CLI:-privateness-cli}"
  if command -v "$cli" >/dev/null 2>&1; then
    "$cli" "$@"
    local rc=$?
    if [[ $rc -ne 126 && $rc -ne 127 ]]; then
      return $rc
    fi
  fi

  if [[ -z "${GOPATH:-}" ]]; then
    ui_err "privateness-cli not found in PATH and GOPATH not set; cannot fallback to go run"
    return 1
  fi

  local go_src="$GOPATH/src/github.com/ness-network/ness/cmd/privateness-cli/privateness-cli.go"

  if [[ ! -f "$go_src" ]]; then
    ui_err "privateness-cli not found in PATH and $go_src does not exist; cannot fallback to go run"
    return 1
  fi

  if ! command -v go >/dev/null 2>&1; then
    ui_err "'go' command not found; cannot run privateness-cli via go run"
    return 1
  fi

  local repo_root="$GOPATH/src/github.com/ness-network/ness"

  if [[ ! -d "$repo_root" ]]; then
    ui_err "Repository root $repo_root does not exist; cannot fallback to go run"
    return 1
  fi

  (
    cd "$repo_root" &&
    go run cmd/privateness-cli/privateness-cli.go "$@"
  )
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
  ui_h1 "=== EmerNVS bootstrap: ness:wallet ==="
  local value
  if ! value="$(emer_value name_show ness:wallet)"; then
    ui_err "Failed to read EmerNVS record ness:wallet"
    return 1
  fi

  echo
  echo "EmerNVS value for ness:wallet:"
  echo "--------------------------------"
  echo "$value"
  echo "--------------------------------"
  echo "This is expected to be a shell command (e.g. 'curl ... | bash')."
  read -r -p "Execute this value as a shell command? [y/N] (b=back, q=quit): " ans
  case "$ans" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
    [Yy]*)
      echo
      echo "Executing: $value"
      bash -c "$value"
      ;;
    *)
      echo "Skipped execution."
      ;;
  esac

  press_enter
}

create_pax_identity() {
  echo
  ui_h1 "=== Create PAX Ed25519 identity via PrivatenessTools (keygen user) ==="

  if [[ -z "$TOOLS_DIR" ]]; then
    if TOOLS_DIR_TMP="$(cd "$SCRIPT_DIR/../privatenesstools" 2>/dev/null && pwd)"; then
      TOOLS_DIR="$TOOLS_DIR_TMP"
    else
      TOOLS_DIR=""
    fi
  fi

  if [[ -z "$TOOLS_DIR" || ! -f "$TOOLS_DIR/keygen.py" ]]; then
    ui_err "PrivatenessTools keygen.py not found (expected at $SCRIPT_DIR/../privatenesstools/keygen.py)"
    return 1
  fi

  read -r -p "PAX username (Privateness user name) (b=back, q=quit): " username
  case "$username" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
  if [[ -z "$username" ]]; then
    ui_err "Username is required"
    return 1
  fi

  local entropy_default=100
  echo "Entropy level is the number of iterations keygen uses in KeyManager.__generate_seed(entropy): each iteration draws 1024 random bytes from os.urandom and feeds them into the UhePrng entropy pool. Higher values are slower but mix in more OS randomness."
  read -r -p "Entropy level for keygen [press Enter for default ${entropy_default}] (b=back, q=quit): " entropy
  case "$entropy" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
  if [[ -z "$entropy" ]]; then
    entropy="$entropy_default"
  fi
  if ! [[ "$entropy" =~ ^[0-9]+$ ]] || (( entropy < 1 )); then
    ui_err "Entropy level must be a positive integer"
    return 1
  fi

  echo "Using PrivatenessTools keys directory: $HOME/.privateness-keys"
  echo "Running: $PYTHON_BIN $TOOLS_DIR/keygen.py user \"$username\" \"$entropy\""
  "$PYTHON_BIN" "$TOOLS_DIR/keygen.py" user "$username" "$entropy"

  press_enter
}

select_wallet_and_address() {
	echo
	ui_h1 "=== Wallet selection (privateness-cli listWallets) ==="
	echo "Discovering wallets..."

	local wallets_json
	if ! wallets_json="$(run_priv_cli listWallets 2>/dev/null)"; then
		ui_err "(listWallets failed or not available)"
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
    ui_err "Failed to parse listWallets JSON"
    return 1
  fi

  local dir=""
  local entries=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == NOWALLETS ]]; then
      ui_err "No wallets found in listWallets output"
      return 1
    fi
    if [[ "$line" == DIR\|* ]]; then
      dir="${line#DIR|}"
    else
      entries+=("$line")
    fi
  done <<< "$parsed"

  if ((${#entries[@]} == 0)); then
    ui_err "No wallets found in listWallets output"
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
  read -r -p "Select wallet [1-${#entries[@]}] (b=back, q=quit): " choice
  case "$choice" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#entries[@]} )); then
    ui_err "Invalid selection"
    return 1
  fi
  local selected="${entries[$((choice-1))]}"
  IFS='|' read -r _idx wallet _label <<< "$selected"

  WALLET_NAME="$wallet"
  export WALLET_NAME
  echo "Selected WALLET_NAME: $WALLET_NAME"

  # Try to auto-detect a default self-spend address as the last non-zero
  # balance address in this wallet, using privateness-cli walletOutputs.
  local default_address=""
  local wallet_outputs
  # Use the same wallet identifier that createRawTransactionV2 uses (name only),
  # not a filesystem path, to match privateness-cli expectations.
  local wallet_outputs_err
  wallet_outputs_err="$(mktemp_file)"
  if wallet_outputs="$(run_priv_cli walletOutputs "$wallet" --json 2>"$wallet_outputs_err")"; then
    if default_address="$(printf '%s\n' "$wallet_outputs" | "$PYTHON_BIN" -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)


def iter_outputs(d):
    # Support both {"outputs": [...]} and {"data": {"outputs": [...]}}
    if isinstance(d, dict):
        outs = d.get("outputs") or []
        if isinstance(outs, list):
            for o in outs:
                yield o
        head = d.get("head_outputs") or []
        if isinstance(head, list):
            for o in head:
                yield o
        data2 = d.get("data")
        if isinstance(data2, dict):
            for o in iter_outputs(data2):
                yield o


last_addr = ""

for o in iter_outputs(data):
    addr = o.get("address")
    coins = o.get("coins")
    if not addr or coins in (None, "", "0", 0):
        continue
    try:
        # coins may be int or string; we only care that it is > 0
        value = float(str(coins))
    except Exception:
        continue
    if value <= 0:
        continue
    # "last non-zero balance discovered"
    last_addr = addr

if not last_addr:
    sys.exit(1)

print(last_addr)
')"; then
    # strip any CR/LF that might sneak in
    default_address="${default_address//$'\r'/}"
    default_address="${default_address//$'\n'/}"
  fi
  else
    local wallet_outputs_err_text
    wallet_outputs_err_text="$(cat "$wallet_outputs_err" 2>/dev/null || true)"
    if is_encrypted_wallet_error "$wallet_outputs_err_text"; then
      if decrypt_wallet_interactive "$wallet"; then
        if wallet_outputs="$(run_priv_cli walletOutputs "$wallet" --json 2>"$wallet_outputs_err")"; then
          if default_address="$(printf '%s\n' "$wallet_outputs" | "$PYTHON_BIN" -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)


def iter_outputs(d):
    if isinstance(d, dict):
        outs = d.get("outputs") or []
        if isinstance(outs, list):
            for o in outs:
                yield o
        head = d.get("head_outputs") or []
        if isinstance(head, list):
            for o in head:
                yield o
        data2 = d.get("data")
        if isinstance(data2, dict):
            for o in iter_outputs(data2):
                yield o


last_addr = ""

for o in iter_outputs(data):
    addr = o.get("address")
    coins = o.get("coins")
    if not addr or coins in (None, "", "0", 0):
        continue
    try:
        value = float(str(coins))
    except Exception:
        continue
    if value <= 0:
        continue
    last_addr = addr

if not last_addr:
    sys.exit(1)

print(last_addr)
')"; then
            default_address="${default_address//$'\r'/}"
            default_address="${default_address//$'\n'/}"
          fi
        fi
      else
        local rc=$?
        if [[ $rc -eq 2 ]]; then
          rm -f "$wallet_outputs_err" >/dev/null 2>&1 || true
          return 2
        fi
      fi
    fi
  fi
  rm -f "$wallet_outputs_err" >/dev/null 2>&1 || true

 local address
 if [[ -n "$default_address" ]]; then
  echo "Detected last non-zero balance address: $default_address"
  read -r -p "Self-spend address [$default_address] (b=back, q=quit): " address
  case "$address" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
  if [[ -z "$address" ]]; then
    address="$default_address"
  fi
else
  read -r -p "Self-spend address (b=back, q=quit): " address
  case "$address" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
fi

if [[ -z "$address" ]]; then
  ui_err "Address is required"
  return 1
fi

read -r -p "Amount (integer coins, e.g. 1) (b=back, q=quit): " coins
case "$coins" in
  [Bb]) return 2 ;;
  [Qq]) echo "Bye."; exit 0 ;;
esac
if ! [[ "$coins" =~ ^[0-9]+$ ]]; then
  ui_err "Amount must be an integer number of whole coins"
  return 1
fi

LAST_WALLET="$WALLET_NAME"
LAST_ADDRESS="$address"
LAST_COINS="$coins"
}

create_unsigned_tx() {
  echo
  ui_h1 "=== Create unsigned self-spend transaction (createRawTransactionV2) ==="

  if [[ -z "${LAST_WALLET}" || -z "${LAST_ADDRESS}" || -z "${LAST_COINS}" ]]; then
    if ! select_wallet_and_address; then
      local rc=$?
      if [[ $rc -eq 2 ]]; then
        return 2
      fi
      return 1
    fi
  else
    echo "Using last selection:"
    echo "  Wallet : $LAST_WALLET"
    echo "  Address: $LAST_ADDRESS"
    echo "  Coins  : $LAST_COINS"
    read -r -p "Reuse these values? [Y/n] (b=back, q=quit): " reuse
    case "$reuse" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
    esac
    case "$reuse" in
      [Nn]*)

        if ! select_wallet_and_address; then
          local rc=$?
          if [[ $rc -eq 2 ]]; then
            return 2
          fi
          return 1
        fi
        ;;
    esac
  fi

  local wallet="$LAST_WALLET"
  local address="$LAST_ADDRESS"
  local coins="$LAST_COINS"

  echo
  echo "Running:"
  echo "  run_priv_cli createRawTransactionV2 \"$wallet\" \"$address\" \"$coins\" --from-address \"$address\" --unsign --json"
  local raw_create
  local create_err
  create_err="$(mktemp_file)"
  if ! raw_create="$(run_priv_cli createRawTransactionV2 "$wallet" "$address" "$coins" \
    --from-address "$address" \
    --unsign \
    --json 2>"$create_err")"; then
    local create_err_text
    create_err_text="$(cat "$create_err" 2>/dev/null || true)"
    if is_encrypted_wallet_error "$create_err_text"; then
      if decrypt_wallet_interactive "$wallet"; then
        if ! raw_create="$(run_priv_cli createRawTransactionV2 "$wallet" "$address" "$coins" \
          --from-address "$address" \
          --unsign \
          --json 2>"$create_err")"; then
          ui_err "createRawTransactionV2 failed"
          rm -f "$create_err" >/dev/null 2>&1 || true
          return 1
        fi
      else
        local rc=$?
        rm -f "$create_err" >/dev/null 2>&1 || true
        if [[ $rc -eq 2 ]]; then
          return 2
        fi
        ui_err "createRawTransactionV2 failed"
        return 1
      fi
    else
      ui_err "createRawTransactionV2 failed"
      rm -f "$create_err" >/dev/null 2>&1 || true
      return 1
    fi
  fi
  rm -f "$create_err" >/dev/null 2>&1 || true

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local out_json="$SCRIPT_DIR/unsigned-${ts}.json"
  printf '%s\n' "$raw_create" >"$out_json"

  local unsigned_hex
  if ! unsigned_hex="$(printf '%s\n' "$raw_create" | json_extract_hex unsigned)"; then
    ui_err "Failed to extract unsigned transaction hex from createRawTransactionV2 JSON"
    ui_dim "See full JSON in: $out_json"
    return 1
  fi

  LAST_UNSIGNED_JSON="$out_json"

  echo
  echo "Unsigned transaction JSON saved to: $out_json"
  echo "Unsigned transaction hex (first 80 chars):"
  echo "${unsigned_hex:0:80}..."

  press_enter
}

sign_transaction_from_json() {
  echo
  ui_h1 "=== Sign transaction (signTransaction) ==="

  if [[ -z "${LAST_WALLET}" ]]; then
    read -r -p "Wallet file to use for signing (b=back, q=quit): " wallet
    case "$wallet" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
    esac
    if [[ -z "$wallet" ]]; then
      ui_err "Wallet is required"
      return 1
    fi
    LAST_WALLET="$wallet"
  fi

  local wallet="$LAST_WALLET"

  local json_path
  if [[ -n "${LAST_UNSIGNED_JSON}" && -f "${LAST_UNSIGNED_JSON}" ]]; then
    echo "Last unsigned JSON file: $LAST_UNSIGNED_JSON"
    read -r -p "Use this file? [Y/n] (b=back, q=quit): " use_last
    case "$use_last" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
      [Nn]*)
        read -r -p "Path to unsigned transaction JSON file (b=back, q=quit): " json_path
        case "$json_path" in
          [Bb]) return 2 ;;
          [Qq]) echo "Bye."; exit 0 ;;
        esac
        ;;
      *)
        json_path="$LAST_UNSIGNED_JSON"
        ;;
    esac
  else
    read -r -p "Path to unsigned transaction JSON file (b=back, q=quit): " json_path
    case "$json_path" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
    esac
  fi

  if [[ -z "$json_path" || ! -f "$json_path" ]]; then
    ui_err "Invalid JSON file path: $json_path"
    return 1
  fi

  local raw_create
  raw_create="$(cat "$json_path")"

  local unsigned_hex
  if ! unsigned_hex="$(printf '%s\n' "$raw_create" | json_extract_hex unsigned)"; then
    ui_err "Failed to extract unsigned transaction hex from JSON file"
    return 1
  fi

  echo
  echo "Running:"
  echo "  run_priv_cli signTransaction \"$wallet\" <unsigned_hex> --json"
  local raw_sign
  local sign_err
  sign_err="$(mktemp_file)"
  if ! raw_sign="$(run_priv_cli signTransaction "$wallet" "$unsigned_hex" --json 2>"$sign_err")"; then
    local sign_err_text
    sign_err_text="$(cat "$sign_err" 2>/dev/null || true)"
    if is_encrypted_wallet_error "$sign_err_text"; then
      if decrypt_wallet_interactive "$wallet"; then
        if ! raw_sign="$(run_priv_cli signTransaction "$wallet" "$unsigned_hex" --json 2>"$sign_err")"; then
          ui_err "signTransaction failed"
          rm -f "$sign_err" >/dev/null 2>&1 || true
          return 1
        fi
      else
        local rc=$?
        rm -f "$sign_err" >/dev/null 2>&1 || true
        if [[ $rc -eq 2 ]]; then
          return 2
        fi
        ui_err "signTransaction failed"
        return 1
      fi
    else
      ui_err "signTransaction failed"
      rm -f "$sign_err" >/dev/null 2>&1 || true
      return 1
    fi
  fi
  rm -f "$sign_err" >/dev/null 2>&1 || true

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local signed_json="$SCRIPT_DIR/signed-${ts}.json"
  printf '%s\n' "$raw_sign" >"$signed_json"

  local signed_hex
  if ! signed_hex="$(printf '%s\n' "$raw_sign" | json_extract_hex signed)"; then
    signed_hex=""
  fi

  LAST_SIGNED_JSON="$signed_json"
  LAST_SIGNED_HEX="$signed_hex"

  echo
  echo "Signed transaction JSON saved to: $signed_json"
  if [[ -n "$signed_hex" ]]; then
    echo "Signed transaction hex (first 80 chars):"
    echo "${signed_hex:0:80}..."
  else
    ui_warn "Could not extract signed transaction hex; inspect JSON manually."
  fi

  press_enter
}

canonical_sky_proof() {
  echo
  ui_h1 "=== Canonical sky_proof JSON (self-spend) ==="

  if [[ -z "${LAST_WALLET}" || -z "${LAST_ADDRESS}" || -z "${LAST_COINS}" ]]; then
    if ! select_wallet_and_address; then
      local rc=$?
      if [[ $rc -eq 2 ]]; then
        return 2
      fi
      return 1
    fi
  else
    echo "Using last selection:"
    echo "  Wallet : $LAST_WALLET"
    echo "  Address: $LAST_ADDRESS"
    echo "  Coins  : $LAST_COINS"
    read -r -p "Reuse these values? [Y/n] (b=back, q=quit): " reuse
    case "$reuse" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
    esac
    case "$reuse" in
      [Nn]*)
        if ! select_wallet_and_address; then
          local rc=$?
          if [[ $rc -eq 2 ]]; then
            return 2
          fi
          return 1
        fi
        ;;
    esac
  fi

  local wallet="$LAST_WALLET"
  local address="$LAST_ADDRESS"
  local coins="$LAST_COINS"

  require_cmd jq

  local network_default="privateness-mainnet"
  local network
  read -r -p "Network [$network_default] (b=back, q=quit): " network
  case "$network" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
  esac
  if [[ -z "$network" ]]; then
    network="$network_default"
  fi

  ui_dim "[1/4] Creating canonical self-spend (from $address to itself for $coins coin(s))"
  local raw_create
  local create_err
  create_err="$(mktemp_file)"
  if ! raw_create="$(run_priv_cli createRawTransactionV2 "$wallet" "$address" "$coins" \
    --from-address "$address" \
    --unsign \
    --json 2>"$create_err")"; then
    local create_err_text
    create_err_text="$(cat "$create_err" 2>/dev/null || true)"
    if is_encrypted_wallet_error "$create_err_text"; then
      if decrypt_wallet_interactive "$wallet"; then
        if ! raw_create="$(run_priv_cli createRawTransactionV2 "$wallet" "$address" "$coins" \
          --from-address "$address" \
          --unsign \
          --json 2>"$create_err")"; then
          ui_err "createRawTransactionV2 failed"
          rm -f "$create_err" >/dev/null 2>&1 || true
          return 1
        fi
      else
        local rc=$?
        rm -f "$create_err" >/dev/null 2>&1 || true
        if [[ $rc -eq 2 ]]; then
          return 2
        fi
        ui_err "createRawTransactionV2 failed"
        return 1
      fi
    else
      ui_err "createRawTransactionV2 failed"
      rm -f "$create_err" >/dev/null 2>&1 || true
      return 1
    fi
  fi
  rm -f "$create_err" >/dev/null 2>&1 || true

  local unsigned_hex
  unsigned_hex="$(printf '%s\n' "$raw_create" | jq -r '.data.encoded_transaction // .data.unsigned_tx // .encoded_transaction // .unsigned_tx // empty')"
  if [[ -z "$unsigned_hex" || "$unsigned_hex" == "null" ]]; then
    ui_err "Failed to extract unsigned transaction hex from createRawTransactionV2 output"
    return 1
  fi

  ui_dim "[2/4] Signing transaction with $wallet"
  local raw_sign
  local sign_err
  sign_err="$(mktemp_file)"
  if ! raw_sign="$(run_priv_cli signTransaction "$wallet" "$unsigned_hex" --json 2>"$sign_err")"; then
    local sign_err_text
    sign_err_text="$(cat "$sign_err" 2>/dev/null || true)"
    if is_encrypted_wallet_error "$sign_err_text"; then
      if decrypt_wallet_interactive "$wallet"; then
        if ! raw_sign="$(run_priv_cli signTransaction "$wallet" "$unsigned_hex" --json 2>"$sign_err")"; then
          ui_err "signTransaction failed"
          rm -f "$sign_err" >/dev/null 2>&1 || true
          return 1
        fi
      else
        local rc=$?
        rm -f "$sign_err" >/dev/null 2>&1 || true
        if [[ $rc -eq 2 ]]; then
          return 2
        fi
        ui_err "signTransaction failed"
        return 1
      fi
    else
      ui_err "signTransaction failed"
      rm -f "$sign_err" >/dev/null 2>&1 || true
      return 1
    fi
  fi
  rm -f "$sign_err" >/dev/null 2>&1 || true

  local signed_hex
  signed_hex="$(printf '%s\n' "$raw_sign" | jq -r '.data.encoded_transaction // .data.signed_tx // .encoded_transaction // .signed_tx // empty')"
  if [[ -z "$signed_hex" || "$signed_hex" == "null" ]]; then
    ui_err "Failed to extract signed transaction hex from signTransaction output"
    return 1
  fi

  LAST_SIGNED_HEX="$signed_hex"

  ui_dim "[3/4] Decoding signed transaction for metadata"
  local raw_decode
  if ! raw_decode="$(run_priv_cli decodeRawTransaction "$signed_hex" --json)"; then
    ui_err "decodeRawTransaction failed"
    return 1
  fi

  local txid
  txid="$(printf '%s\n' "$raw_decode" | jq -r '.data.txid // .txid // empty')"
  if [[ -z "$txid" || "$txid" == "null" ]]; then
    txid="(not-yet-broadcast)"
  fi

  local output_addresses
  output_addresses="$(printf '%s\n' "$raw_decode" | jq -r '[.data.tx.outputs // .tx.outputs // empty][]?.address // empty')"

  if [[ -n "$output_addresses" ]]; then
    local unique_outputs
    unique_outputs="$(printf '%s\n' "$output_addresses" | sort -u)"
    if [[ "$(printf '%s\n' "$unique_outputs" | wc -l)" -ne 1 || "$unique_outputs" != "$address" ]]; then
      ui_warn "Warning: decoded outputs do not exclusively target $address"
    fi
  else
    ui_warn "Warning: could not parse outputs from decodeRawTransaction; skipping canonical check"
  fi

  ui_dim "[4/4] Emitting PAX sky_proof JSON"

  jq -n \
    --arg network "$network" \
    --arg address "$address" \
    --arg unsigned "$unsigned_hex" \
    --arg signed "$signed_hex" \
    --arg txid "$txid" \
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

  press_enter
}

broadcast_signed_tx() {
  echo
  ui_h1 "=== OPTIONAL: Broadcast signed transaction (broadcastTransaction) ==="

  local signed_hex=""

  if [[ -n "${LAST_SIGNED_HEX}" ]]; then
    echo "Last signed transaction hex (first 80 chars):"
    echo "${LAST_SIGNED_HEX:0:80}..."
    read -r -p "Use this signed transaction? [Y/n] (b=back, q=quit): " use_last
    case "$use_last" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
      ""|[Yy]*)
        signed_hex="$LAST_SIGNED_HEX"
        ;;
    esac
  fi

  if [[ -z "$signed_hex" ]]; then
    echo "You can provide either a signed transaction JSON file or raw hex."
    read -r -p "Path to signed transaction JSON file (leave blank to paste hex) (b=back, q=quit): " json_path
    case "$json_path" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
    esac
    if [[ -n "$json_path" ]]; then
      if [[ ! -f "$json_path" ]]; then
        ui_err "File not found: $json_path"
        return 1
      fi
      local raw_json
      raw_json="$(cat "$json_path")"
      if ! signed_hex="$(printf '%s\n' "$raw_json" | json_extract_hex signed)"; then
        ui_err "Failed to extract signed transaction hex from JSON file"
        return 1
      fi
    else
      ui_dim "Paste signed transaction hex, then press Ctrl-D:"
      local pasted
      pasted="$(cat)"
      # Strip CR/LF
      pasted="${pasted//$'\r'/}"
      pasted="${pasted//$'\n'/}"
      signed_hex="$pasted"
      if [[ -z "$signed_hex" ]]; then
        ui_err "No hex provided"
        return 1
      fi
    fi
  fi

  echo
  echo "About to broadcast this transaction via privateness-cli broadcastTransaction:"
  echo "  (first 80 chars): ${signed_hex:0:80}..."
  read -r -p "Really broadcast to the configured Privateness node? [y/N] (b=back, q=quit): " confirm
  case "$confirm" in
    [Bb]) return 2 ;;
    [Qq]) echo "Bye."; exit 0 ;;
    [Yy]*)
      echo
      echo "Running: broadcastTransaction <signed_hex>"
      if ! run_priv_cli broadcastTransaction "$signed_hex"; then
        ui_err "broadcastTransaction failed"
        return 1
      fi
      ;;
    *)
      echo "Broadcast cancelled."
      ;;
  esac

  press_enter
}

services_menu() {
  while true; do
    echo
    ui_h1 "================ Services ================"
    echo "1) Ensure privateness (:6660) (status-based)"
    echo "2) Ensure emercoin-core (:6662)"
    echo "3) Ensure BOTH services"
    echo "b) Back"
    echo "q) Quit"
    ui_h1 "=========================================="
    read -r -p "Select option [1-3] (b=back, q=quit): " choice || return 2
    case "$choice" in
      [Bb]) return 2 ;;
      [Qq]) echo "Bye."; exit 0 ;;
      1)
        if ! ensure_privateness_running; then
          ui_err "(Error)"
        fi
        press_enter
        ;;
      2)
        if ! ensure_emercoin_core_running; then
          ui_err "(Error)"
        fi
        press_enter
        ;;
      3)
        if ! ensure_services_running; then
          ui_err "(Error)"
        fi
        press_enter
        ;;
      *)
        ui_warn "Invalid choice: $choice"
        ;;
    esac
  done
}

main_menu() {
  while true; do
    echo
    ui_h1 "================ PAX / SKY-PROOF helper ================"
    echo "0) Services (manage/check)"
    echo "1) Bootstrap ness client wallet from EmerNVS (ness:wallet)"
    echo "2) Create PAX Ed25519 identity (user.key.json)"
    echo "3) Create unsigned self-spend tx (createRawTransactionV2 --unsign --json)"
    echo "4) Sign unsigned transaction (signTransaction --json)"
    echo "5) Canonical sky_proof JSON (self-spend, signed)"
    echo "6) OPTIONAL: Broadcast signed transaction (broadcastTransaction)"
    echo "7) Quit"
    ui_h1 "========================================================"
    read -r -p "Select option [0-7] (q=quit): " choice || exit 0
    case "$choice" in
      [Qq]|7)
        ui_ok "Bye."
        exit 0
        ;;
      0)
        services_menu
        rc=$?
        if [[ $rc -ne 0 && $rc -ne 2 ]]; then
          ui_err "(Error)"
          press_enter
        fi
        ;;
      1)
        if ! require_basics; then
          press_enter
          continue
        fi
        if ! bootstrap_ness_wallet; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      2)
        require_cmd "$PYTHON_BIN"
        if ! require_pynacl; then
          press_enter
          continue
        fi
        if ! create_pax_identity; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      3)
        if ! require_priv_tx_cli; then
          press_enter
          continue
        fi
        if ! create_unsigned_tx; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      4)
        if ! require_priv_tx_cli; then
          press_enter
          continue
        fi
        if ! sign_transaction_from_json; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      5)
        if ! require_priv_tx_cli; then
          press_enter
          continue
        fi
        if ! canonical_sky_proof; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      6)
        if ! require_priv_tx_cli; then
          press_enter
          continue
        fi
        if ! broadcast_signed_tx; then
          rc=$?
          if [[ $rc -ne 2 ]]; then
            ui_err "(Error)"
            press_enter
          fi
        fi
        ;;
      *)
        ui_warn "Invalid choice: $choice"
        ;;
    esac
  done
}

main_menu