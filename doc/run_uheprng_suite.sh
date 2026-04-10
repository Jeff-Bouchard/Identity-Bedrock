#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  # Convert MSYS paths (e.g. /d/...) to Windows paths with forward slashes (e.g. D:/...)
  # so native Windows Node.js and Python can resolve them correctly.
  ROOT_DIR="$(cygpath -m "$ROOT_DIR")"
fi
SUITE_PAGE="${ROOT_DIR}/uheprng_suite.html"
BENCH_DIR="${ROOT_DIR}/bench"
BENCH_JSON="${BENCH_DIR}/uheprng-benchmark-latest.json"
PORT="${PORT:-}"
SEED="${SEED:-ness-demo-123}"
ITERATIONS="${ITERATIONS:-250000}"
OPEN_BROWSER="${OPEN_BROWSER:-1}"
ACTION="all"

usage() {
  cat <<EOF
Usage: $(basename "$0") [serve|bench|all] [--port N] [--seed TEXT] [--iters N] [--open|--no-open]

serve  Start a local HTTP server for the demo suite.
bench  Run the UHE-PRNG benchmark and write ${BENCH_JSON}.
all    Run the benchmark, then start the suite server.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    serve|bench|all)
      ACTION="$1"
      shift
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --seed)
      SEED="${2:-}"
      shift 2
      ;;
    --iters)
      ITERATIONS="${2:-}"
      shift 2
      ;;
    --open)
      OPEN_BROWSER=1
      shift
      ;;
    --no-open)
      OPEN_BROWSER=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

log() {
  printf '%s\n' "$*"
}

choose_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=(python3)
  elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD=(python)
  elif command -v py >/dev/null 2>&1; then
    PYTHON_CMD=(py -3)
  else
    echo "Python is required for the local HTTP server." >&2
    exit 1
  fi
}

choose_node() {
  if command -v node >/dev/null 2>&1; then
    NODE_CMD=(node)
  elif command -v node.exe >/dev/null 2>&1; then
    NODE_CMD=(node.exe)
  else
    echo "Node.js is required for the benchmark." >&2
    exit 1
  fi
}

port_free() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q ":${port} "; then
      return 1
    fi
    return 0
  fi
  "${PYTHON_CMD[@]}" - "$port" <<'PY'
import socket
import sys
port = int(sys.argv[1])
probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    probe.bind(("127.0.0.1", port))
except OSError:
    sys.exit(1)
finally:
    probe.close()
PY
}

pick_port() {
  local tries=0
  local candidate
  while [[ $tries -lt 200 ]]; do
    candidate="$((50000 + (RANDOM % 10000)))"
    if port_free "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    tries=$((tries + 1))
  done
  echo "Could not find a free port above 50000." >&2
  exit 1
}

start_server() {
  local chosen_port="$1"
  local server_log="${BENCH_DIR}/http-server.log"
  mkdir -p "$BENCH_DIR"
  log "Starting local suite server on http://127.0.0.1:${chosen_port}"
  "${PYTHON_CMD[@]}" -m http.server "$chosen_port" --bind 127.0.0.1 --directory "$ROOT_DIR" > "$server_log" 2>&1 &
  SERVER_PID=$!
  sleep 1
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    echo "Server failed to start. See ${server_log}" >&2
    exit 1
  fi
}

open_browser() {
  local url="$1"
  if [[ "$OPEN_BROWSER" != "1" ]]; then
    return 0
  fi
  if command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1 || true
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Start-Process '$url'" >/dev/null 2>&1 || true
  fi
}

run_benchmark() {
  mkdir -p "$BENCH_DIR"
  choose_node
  log "Running UHE-PRNG benchmark with seed '${SEED}' and ${ITERATIONS} iterations"
  "${NODE_CMD[@]}" - "$ROOT_DIR" "$SEED" "$ITERATIONS" "$BENCH_JSON" <<'NODE'
const fs = require('fs');
const path = require('path');
const os = require('os');
const vm = require('vm');

const rootDir = process.argv[2];
const seed = process.argv[3];
const iterations = Number(process.argv[4]);
const outJson = process.argv[5];

const source = fs.readFileSync(path.join(rootDir, 'uheprng.js'), 'utf8');
vm.runInThisContext(source, { filename: 'uheprng.js' });

if (typeof uheprng !== 'function') {
  throw new Error('uheprng() was not loaded');
}

function nowNs() {
  return process.hrtime.bigint();
}

function fold(value, acc) {
  return Math.imul((acc ^ (value >>> 0)) >>> 0, 16777619) >>> 0;
}

function foldString(text) {
  let acc = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    acc = fold(text.charCodeAt(i), acc);
  }
  return acc >>> 0;
}

function makeGenerator(valueSeed) {
  const rng = uheprng();
  rng.initState();
  rng.hashString(valueSeed);
  return rng;
}

function makeResumePair(valueSeed, advanceCount) {
  const source = makeGenerator(valueSeed);
  for (let i = 0; i < advanceCount; i++) {
    source(1000000);
  }
  const snapshot = source.exportState();
  const target = uheprng();
  target.initState();
  target.importState(snapshot);
  return { source, target, snapshot };
}

function bench(label, count, fn) {
  let checksum = 0x811c9dc5;
  const start = nowNs();
  for (let i = 0; i < count; i++) {
    checksum = fold(fn(i), checksum);
  }
  const elapsedNs = Number(nowNs() - start);
  const seconds = elapsedNs / 1e9;
  return {
    label,
    iterations: count,
    seconds,
    opsPerSec: count / seconds,
    checksum
  };
}

const env = {
  node: process.versions.node,
  platform: process.platform,
  arch: process.arch,
  cpus: os.cpus().length,
  cpuModel: (os.cpus()[0] && os.cpus()[0].model) ? os.cpus()[0].model : 'unknown',
  totalMemBytes: os.totalmem(),
  release: os.release()
};

const replayCount = 16;
const replayA = makeGenerator(seed);
const replayB = makeGenerator(seed);
const seqA = [];
const seqB = [];
for (let i = 0; i < replayCount; i++) {
  seqA.push(replayA(1000000));
  seqB.push(replayB(1000000));
}

const deterministic = JSON.stringify(seqA) === JSON.stringify(seqB);

const speedMathRandom = bench('Math.random()', iterations, () => Math.floor(Math.random() * 1000000));
const speedUheRandomRng = makeGenerator(seed);
const speedUheRandom = bench('UHEPRNG random(1000000)', iterations, () => speedUheRandomRng(1000000));

const drawRng = makeGenerator(seed);
const stringIterations = Math.max(1000, Math.floor(iterations / 10));
const speedUheString = bench('UHEPRNG string(32)', stringIterations, () => foldString(drawRng.string(32)));

const initIterations = Math.max(1000, Math.floor(iterations / 20));
const speedUheInit = bench('UHEPRNG initState+hashString', initIterations, i => {
  const rng = uheprng();
  rng.initState();
  rng.hashString(`${seed}:${i}`);
  return rng(1000000);
});

const trustIterations = Math.max(1000, Math.floor(iterations / 50));
const trustExportState = bench('UHEPRNG exportState()', trustIterations, i => {
  const rng = makeGenerator(`${seed}:export:${i}`);
  rng(1000000);
  return foldString(JSON.stringify(rng.exportState()));
});

const trustImportState = bench('UHEPRNG importState()', trustIterations, i => {
  const pair = makeResumePair(`${seed}:restore:${i}`, 8);
  return pair.target(1000000);
});

const trustCloneReplay = bench('UHEPRNG clone() replay 16 draws', trustIterations, i => {
  const rng = makeGenerator(`${seed}:clone:${i}`);
  rng(1000000);
  const clone = rng.clone();
  let last = 0;
  for (let j = 0; j < 16; j++) {
    last = clone(1000000);
  }
  return last;
});

const results = {
  generatedAt: new Date().toISOString(),
  seed,
  iterations,
  environment: env,
  deterministic,
  firstSequence: seqA,
  speedBenchmarks: [speedMathRandom, speedUheRandom, speedUheString, speedUheInit],
  trustBenchmarks: [trustExportState, trustImportState, trustCloneReplay]
};

fs.writeFileSync(outJson, JSON.stringify(results, null, 2));
console.log(JSON.stringify(results, null, 2));
NODE
}

trap '[[ -n "${SERVER_PID:-}" ]] && kill "${SERVER_PID}" >/dev/null 2>&1 || true' EXIT

if [[ "$ACTION" == "bench" ]]; then
  run_benchmark
  exit 0
fi

if [[ "$ACTION" == "all" ]]; then
  run_benchmark
fi

choose_python
if [[ -z "$PORT" ]]; then
  PORT="$(pick_port)"
fi

if ! port_free "$PORT"; then
  echo "Port ${PORT} is already in use. Pick another one with --port or let the script choose automatically." >&2
  exit 1
fi

start_server "$PORT"
open_browser "http://127.0.0.1:${PORT}/uheprng_suite.html"
log "Suite page: http://127.0.0.1:${PORT}/uheprng_suite.html"
log "Demos:"
log "  - http://127.0.0.1:${PORT}/uheprng.html"
log "  - http://127.0.0.1:${PORT}/ness_entropy_demo.html"
log "  - http://127.0.0.1:${PORT}/ness_entropy_control.html"
log "  - http://127.0.0.1:${PORT}/privateness-ardropin.html"
log "Benchmark JSON: ${BENCH_JSON}"
log "Press Ctrl+C to stop the server."
wait "$SERVER_PID"
