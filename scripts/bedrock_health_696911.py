#!/usr/bin/env python3
"""Bedrock health check anchored at Emercoin block 696911.

This script verifies that the local Emercoin core is:

1. Synced past block 696911, and
2. Able to resolve the well-known NVS name `ness:therulesoftheinternet`.

It prints a single JSON object on stdout with at least:

    {
      "ok": true/false,
      "height": <int or null>,
      "name_exists": true/false,
      "error": <string or null>
    }

Intended use:
- As a standalone CLI check.
- As the basis for an MCP tool (e.g. /tools/bedrock_health) that
  Identity Switch / Benji can call before doing anything else.
"""

import json
import subprocess
import sys
from typing import Any, Dict

CHECKPOINT_HEIGHT = 696911
CHECKPOINT_NAME = "ness:therulesoftheinternet"


def run_cli(args):
    """Run emercoin-cli with the given arguments, return stdout as text.

    This assumes `emercoin-cli` is on PATH or otherwise resolvable.
    """

    try:
        out = subprocess.check_output(["emercoin-cli", *args], stderr=subprocess.STDOUT)
    except FileNotFoundError as e:
        raise RuntimeError("emercoin-cli not found in PATH") from e
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"emercoin-cli {' '.join(args)} failed: {e.output.decode(errors='ignore').strip()}") from e

    return out.decode("utf-8", errors="ignore").strip()


def check_block_height(result: Dict[str, Any]) -> None:
    try:
        height_str = run_cli(["getblockcount"])  # returns an integer as text
        height = int(height_str)
    except Exception as e:  # noqa: BLE001
        result["ok"] = False
        result["error"] = f"getblockcount failed: {e}"
        result["height"] = None
        return

    result["height"] = height
    if height < CHECKPOINT_HEIGHT:
        result["ok"] = False
        result["error"] = (
            f"Emercoin height {height} < checkpoint {CHECKPOINT_HEIGHT}; "
            "node is not synced far enough to be trusted for Bedrock operations"
        )


def check_checkpoint_name(result: Dict[str, Any]) -> None:
    """Verify that CHECKPOINT_NAME exists in the local EmerNVS view.

    We do not hard-code its value here; the fact that the name resolves
    at all once the node is synced past CHECKPOINT_HEIGHT is enough to
    distinguish a healthy mainnet view from an obviously incomplete one.
    """

    try:
        # -f requests machine-parsable JSON metadata in recent emercoin-cli
        raw = run_cli(["-f", "name_show", CHECKPOINT_NAME])
    except Exception as e:  # noqa: BLE001
        result["ok"] = False
        result["name_exists"] = False
        if result.get("error"):
            # Append detail
            result["error"] += f"; name_show {CHECKPOINT_NAME} failed: {e}"
        else:
            result["error"] = f"name_show {CHECKPOINT_NAME} failed: {e}"
        return

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        # Older emercoin-cli or unexpected format; fall back to a simple existence check
        if CHECKPOINT_NAME not in raw:
            result["ok"] = False
            result["name_exists"] = False
            if result.get("error"):
                result["error"] += "; unexpected name_show output and name not present"
            else:
                result["error"] = "unexpected name_show output and name not present"
            return

        result["name_exists"] = True
        return

    # JSON-parsed path
    if isinstance(data, dict) and data.get("name") == CHECKPOINT_NAME:
        result["name_exists"] = True
    else:
        result["ok"] = False
        result["name_exists"] = False
        if result.get("error"):
            result["error"] += "; name_show JSON did not contain expected name"
        else:
            result["error"] = "name_show JSON did not contain expected name"


def main() -> None:
    result: Dict[str, Any] = {"ok": True, "height": None, "name_exists": False, "error": None}

    check_block_height(result)
    if result["ok"]:
        check_checkpoint_name(result)

    # Exit code is 0 on ok, 1 on failure, to make CLI scripting easy.
    print(json.dumps(result, sort_keys=True))
    sys.exit(0 if result.get("ok") else 1)


if __name__ == "__main__":
    main()
