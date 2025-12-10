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
from pathlib import Path
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


def run_emercoin_value(raw: str) -> str:
    """Pipe emercoin-cli output through emercoin-value.py and return the extracted value.

    This mirrors the manual usage pattern:

        emercoin-cli name_show <name> | emercoin-value.py

    so that all name_show callers share the same cleaning/parsing logic.
    """

    script_path = Path(__file__).with_name("emercoin-value.py")

    try:
        out = subprocess.check_output(
            [sys.executable, str(script_path)],
            input=raw.encode("utf-8", errors="ignore"),
            stderr=subprocess.STDOUT,
        )
    except FileNotFoundError as e:  # noqa: BLE001
        raise RuntimeError(f"emercoin-value.py not found at {script_path}") from e
    except subprocess.CalledProcessError as e:  # noqa: BLE001
        raise RuntimeError(
            f"emercoin-value.py failed: {e.output.decode(errors='ignore').strip()}"
        ) from e

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
        # Call emercoin-cli name_show without extra flags for maximum compatibility
        raw = run_cli(["name_show", CHECKPOINT_NAME])
    except Exception as e:  # noqa: BLE001
        result["ok"] = False
        result["name_exists"] = False
        if result.get("error"):
            # Append detail
            result["error"] += f"; name_show {CHECKPOINT_NAME} failed: {e}"
        else:
            result["error"] = f"name_show {CHECKPOINT_NAME} failed: {e}"
        return

    # First, try the shared emercoin-value.py helper
    try:
        value = run_emercoin_value(raw)
    except Exception as e:  # noqa: BLE001
        # If emercoin-value.py itself fails, fall back to raw existence check
        if CHECKPOINT_NAME in raw:
            result["name_exists"] = True
            if result.get("error"):
                result["error"] += f"; emercoin-value.py failed but raw output contained {CHECKPOINT_NAME}: {e}"
            else:
                result["error"] = f"emercoin-value.py failed but raw output contained {CHECKPOINT_NAME}: {e}"
            return

        result["ok"] = False
        result["name_exists"] = False
        if result.get("error"):
            result["error"] += f"; emercoin-value.py failed and name not found in raw output: {e}"
        else:
            result["error"] = f"emercoin-value.py failed and name not found in raw output: {e}"
        return

    # If emercoin-value.py could not parse JSON, it prefixes with "Invalid JSON input:".
    # If it did not find a value field, it returns "No 'value' found".
    cleaned = value.strip()
    if cleaned.startswith("Invalid JSON input:") or cleaned == "No 'value' found":
        # Fallback: if the raw output still clearly contains the checkpoint name,
        # we treat that as evidence that the name exists, even if the value
        # extraction failed.
        if CHECKPOINT_NAME in raw:
            result["name_exists"] = True
            if result.get("error"):
                result["error"] += "; emercoin-value.py reported invalid JSON, but raw output contained the name"
            else:
                result["error"] = "emercoin-value.py reported invalid JSON, but raw output contained the name"
            return

        result["ok"] = False
        result["name_exists"] = False
        if result.get("error"):
            result["error"] += "; unexpected name_show output or missing value"
        else:
            result["error"] = "unexpected name_show output or missing value"
        return

    # Any other non-empty string from emercoin-value.py is treated as evidence
    # that the name exists and has some value.
    result["name_exists"] = True


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
