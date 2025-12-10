#!/usr/bin/env bash

# Ness Lab Recon Script
# Runs basic recon (nmap, HTTP health, DNS check) against a target host
# and writes results into a specified output directory.
# Scope: authorised defense of your own host and LAN, and systems you are trusted to protect.
# Ethic: EULA applies. Do no harm.

set -euo pipefail
IFS=$'\n\t'

TARGET="${1:-127.0.0.1}"
OUTDIR="${2:-}"       # if empty, create ./recon-<timestamp>
DNS_PORT="${DNS_PROXY_HOST_PORT:-1053}"

if [ -z "$OUTDIR" ]; then
  TS=$(date +"%Y%m%d-%H%M%S" 2>/dev/null || echo "unknown")
  OUTDIR="./recon-${TS}"
fi

mkdir -p "$OUTDIR"

META="$OUTDIR/meta.txt"

{
  echo "Target: $TARGET"
  echo "Date : $(date 2>/dev/null || echo '?')"
} >"$META" 2>/dev/null || true

echo "[lab] Running nmap quick scan against $TARGET..."
if command -v nmap >/dev/null 2>&1; then
  nmap -sV -p 1-1024 "$TARGET" >"$OUTDIR/nmap-quick.txt" 2>&1 || true
else
  echo "nmap not installed" >"$OUTDIR/nmap-quick.txt"
fi

echo "[lab] Probing HTTP /health on 8888 at $TARGET..."
if command -v curl >/dev/null 2>&1; then
  curl -v --max-time 10 "http://$TARGET:8888/health" >"$OUTDIR/http-8888-health.txt" 2>&1 || true
else
  echo "curl not installed" >"$OUTDIR/http-8888-health.txt"
fi

echo "[lab] DNS check via dns-reverse-proxy on port ${DNS_PORT} at $TARGET..."
if command -v dig >/dev/null 2>&1; then
  dig @"$TARGET" example.com -p "${DNS_PORT}" >"$OUTDIR/dns-check.txt" 2>&1 || true
else
  echo "dig not installed" >"$OUTDIR/dns-check.txt"
fi

echo "[lab] Recon complete. Output in: $OUTDIR"
