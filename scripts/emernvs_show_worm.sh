#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/emernvs_show_worm.sh <username>
# Requires: emercoin daemon + emercoin-cli configured (emercoin.conf).

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

USERNAME="$1"
NVS_NAME="worm:user:ness:${USERNAME}"

# Query EmerNVS for the WORM XML record (value is base64-encoded)
emercoin-cli name_show "$NVS_NAME" '' base64
