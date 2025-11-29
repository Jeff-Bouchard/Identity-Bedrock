#!/usr/bin/env python3
import sys
import json
import base64

from nacl.signing import SigningKey


def canonical_bytes(obj: dict) -> bytes:
    """Deterministic JSON encoding for demo purposes.

    For a production PAX implementation, replace this with a full JCS implementation
    so that canonicalization is interoperable across languages.
    """

    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <user.key.json> <challenge.json>", file=sys.stderr)
        sys.exit(1)

    key_path = sys.argv[1]
    challenge_path = sys.argv[2]

    with open(key_path, "r", encoding="utf-8") as f:
        key_data = json.load(f)

    with open(challenge_path, "r", encoding="utf-8") as f:
        challenge = json.load(f)

    try:
        private_b64 = key_data["private"]
        username = key_data["username"]
    except KeyError as e:
        print(f"missing field in user.key.json: {e}", file=sys.stderr)
        sys.exit(1)

    expected_id = f"urn:privateness:user:{username}"
    if challenge.get("id") != expected_id:
        print(
            f"warning: challenge.id ({challenge.get('id')!r}) != {expected_id!r}",
            file=sys.stderr,
        )

    try:
        private_bytes = base64.b64decode(private_b64)
        signing_key = SigningKey(private_bytes)
    except Exception as e:  # noqa: BLE001
        print(f"failed to construct SigningKey from user.key.json: {e}", file=sys.stderr)
        sys.exit(1)

    msg = canonical_bytes(challenge)
    sig = signing_key.sign(msg).signature
    sig_b64url = base64.urlsafe_b64encode(sig).rstrip(b"=").decode("ascii")

    result = {
        "username": username,
        "pax_sign": {
            "challenge": challenge,
            "signature": sig_b64url,
        },
    }

    json.dump(result, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
