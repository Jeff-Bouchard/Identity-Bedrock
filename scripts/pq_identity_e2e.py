#!/usr/bin/env python3
"""PQ identity end-to-end (e2e) health check.

Checks:
- Local Privateness users.key.json for a current user and PQ metadata.
- Optional: matching EmerNVS PQ identity record via emercoin-cli, parsed
  through scripts/emercoin-value.py so other scripts can consume it.

Outputs a single JSON object on stdout, e.g.:

{
  "ok": true,
  "local": {"has_pq": true, "username": "alice", "algo": "ml-dsa-65"},
  "onchain": {
    "name": "ness:pq:user:alice",
    "reachable": true,
    "exists": true,
    "matches_local": true
  },
  "error": null
}

Exit code is 0 on ok, 1 on failure, to simplify scripting.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict


SCRIPT_DIR = Path(__file__).resolve().parent
USERS_KEY_PATH = Path.home() / ".privateness-keys" / "users.key.json"


def load_local_pq() -> Dict[str, Any]:
    """Load current user and PQ metadata from users.key.json if present.

    Returns a dict with at least:
      - has_pq: bool
      - username: str | None
      - algo: str | None
    """

    result: Dict[str, Any] = {
        "has_pq": False,
        "username": None,
        "algo": None,
    }

    if not USERS_KEY_PATH.is_file():
        result["error"] = f"Missing {USERS_KEY_PATH}"
        return result

    try:
        data = json.loads(USERS_KEY_PATH.read_text(encoding="utf-8"))
        cur = data.get("current")
        users = data.get("users", {}) or {}
        if not cur or cur not in users:
            result["error"] = "No current user in users.key.json"
            return result

        u = users[cur]
        result["username"] = cur
        algo = u.get("pq_algo")
        pq_pub = u.get("pq_public")
        if algo and pq_pub:
            result["has_pq"] = True
            result["algo"] = str(algo)
        else:
            result["error"] = "Current user has no pq_algo/pq_public fields"
    except Exception as e:  # noqa: BLE001
        result["error"] = f"Failed to parse users.key.json: {e}"

    return result


def run_emercoin_cli(args: list[str]) -> str:
    """Run emercoin-cli, preferring the emercoin-core Docker container.

    Falls back to host emercoin-cli if the container is not available.
    Returns stdout as text, or raises RuntimeError.
    """

    # First try inside emercoin-core container (stack-deployed case)
    docker_args = [
        "docker",
        "exec",
        "emercoin-core",
        "emercoin-cli",
        "-datadir=/data",
        *args,
    ]
    try:
        out = subprocess.check_output(
            docker_args,
            stderr=subprocess.STDOUT,
            env={**os.environ, "MSYS_NO_PATHCONV": "1"},
        )
        return out.decode("utf-8", errors="ignore").strip()
    except Exception:  # noqa: BLE001
        # Fallback: host emercoin-cli on PATH
        try:
            out = subprocess.check_output(
                ["emercoin-cli", *args], stderr=subprocess.STDOUT
            )
            return out.decode("utf-8", errors="ignore").strip()
        except FileNotFoundError as e:  # noqa: B904
            raise RuntimeError("emercoin-cli not found (container or host)") from e
        except subprocess.CalledProcessError as e:  # noqa: BLE001
            raise RuntimeError(
                f"emercoin-cli {' '.join(args)} failed: "
                f"{e.output.decode(errors='ignore').strip()}"
            ) from e


def extract_value_via_helper(raw: str) -> str:
    """Pipe Emercoin raw JSON through scripts/emercoin-value.py to get .value.

    Returns the helper's stdout (stripped). On error, returns an empty string.
    """

    helper = SCRIPT_DIR / "emercoin-value.py"
    if not helper.is_file():
        # Best-effort: return raw, caller can decide what to do.
        return ""

    try:
        out = subprocess.check_output(
            [sys.executable, str(helper)],
            input=raw.encode("utf-8", errors="ignore"),
            stderr=subprocess.STDOUT,
        )
        return out.decode("utf-8", errors="ignore").strip()
    except Exception:  # noqa: BLE001
        return ""


def check_onchain_pq(username: str | None, local_algo: str | None) -> Dict[str, Any]:
    """Check for an EmerNVS PQ identity record for the given username.

    Assumes the canonical NVS name pattern:
      ness:pq:user:<username>

    Expects the NVS value (after emercoin-value.py) to be JSON, e.g.:
      {
        "type": "ness-pq-user",
        "username": "alice",
        "algo": "ml-dsa-65",
        "public_key": "..."
      }
    """

    result: Dict[str, Any] = {
        "name": None,
        "reachable": False,
        "exists": False,
        "matches_local": None,
        "algo": None,
        "error": None,
    }

    if not username:
        result["error"] = "No username to check on-chain"
        return result

    nvs_name = f"ness:pq:user:{username}"
    result["name"] = nvs_name

    try:
        raw = run_emercoin_cli(["-f", "name_show", nvs_name])
    except Exception as e:  # noqa: BLE001
        result["error"] = f"emercoin-cli failure: {e}"
        return result

    result["reachable"] = True

    value = extract_value_via_helper(raw)
    if not value or value.startswith("Invalid JSON") or "No 'value' found" in value:
        # Either no record or not in expected JSON form
        result["exists"] = False
        result["error"] = (
            "No usable NVS value for PQ identity; "
            "expecting JSON in the .value field"
        )
        return result

    try:
        data = json.loads(value)
    except json.JSONDecodeError as e:  # noqa: BLE001
        result["exists"] = False
        result["error"] = f"NVS value is not valid JSON: {e}"
        return result

    result["exists"] = True
    algo = data.get("algo")
    result["algo"] = algo

    # Compare on-chain algo with local algo, if both present
    if local_algo and algo:
        result["matches_local"] = (str(local_algo) == str(algo))
    else:
        result["matches_local"] = None

    return result


def main() -> None:
    overall: Dict[str, Any] = {
        "ok": True,
        "local": {},
        "onchain": {},
        "error": None,
    }

    local = load_local_pq()
    overall["local"] = local

    if not local.get("has_pq"):
        overall["ok"] = False
        overall["error"] = local.get("error") or "No local PQ identity configured"
        print(json.dumps(overall, sort_keys=True))
        sys.exit(1)

    username = local.get("username")
    algo = local.get("algo")

    onchain = check_onchain_pq(username, algo)
    overall["onchain"] = onchain

    if not onchain.get("reachable") or (onchain.get("exists") is False):
        overall["ok"] = False
        if overall.get("error"):
            overall["error"] += "; " + (onchain.get("error") or "on-chain PQ record missing")
        else:
            overall["error"] = onchain.get("error") or "on-chain PQ record missing"
    elif onchain.get("matches_local") is False:
        overall["ok"] = False
        overall["error"] = (
            overall.get("error") or "On-chain PQ algo does not match local pq_algo"
        )

    print(json.dumps(overall, sort_keys=True))
    sys.exit(0 if overall.get("ok") else 1)


if __name__ == "__main__":
    main()
