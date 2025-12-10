from flask import Flask, request, render_template_string
import subprocess
import shlex

# Simple Ness Attack Web UI
# Purpose: orchestrate common self-pentest actions against your Ness stack
# from a single HTML page (buttons -> safe, predefined commands).
# Ethics: see EULA ("Do no harm"). This console is for authorized testing only.

app = Flask(__name__)

# HTML template (inline to keep deployment simple)
TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Ness Attack Console</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #111; color: #eee; padding: 1.5rem; }
    h1, h2 { color: #ff8c00; }
    form { margin-bottom: 1rem; padding: 1rem; border: 1px solid #333; border-radius: 6px; background: #181818; }
    label { display: inline-block; width: 6rem; }
    input[type=text] { background: #000; color: #eee; border: 1px solid #444; padding: 0.2rem 0.4rem; }
    button { margin: 0.25rem 0.25rem 0 0; padding: 0.35rem 0.7rem; border-radius: 4px; border: none; cursor: pointer; background: #333; color: #eee; }
    button.primary { background: #d87f1f; }
    button.danger { background: #aa3333; }
    small { color: #999; }
    pre { background: #000; color: #0f0; padding: 0.75rem; border-radius: 4px; max-height: 60vh; overflow: auto; }
    .note { font-size: 0.85rem; color: #bbb; margin-bottom: 0.8rem; }
  </style>
</head>
<body>
  <h1>Ness Attack Console</h1>
  <p class="note">
    For authorized defensive and research use only (systems you own or are trusted to protect). EULA applies: be a good internet person, do no harm.
  </p>

  <form method="post" action="/run">
    <h2>Target</h2>
    <label for="target">Host</label>
    <input type="text" id="target" name="target" value="{{ target }}" />
    <small>e.g. 127.0.0.1 or docker host IP</small>
    <br><br>

    <h2>Actions</h2>
    <button class="primary" name="action" value="nmap_quick">Nmap quick (1-1024)</button>
    <button name="action" value="nmap_full">Nmap full (-p-)</button>
    <button name="action" value="http_privatenesstools">HTTP /health (privatenesstools:8888)</button>
    <button name="action" value="dns_check">DNS check via dns-reverse-proxy</button>
    <button name="action" value="emc_rpc">Emercoin RPC (if reachable)</button>
  </form>

  {% if output %}
  <h2>Last command</h2>
  <p><strong>{{ last_label }}</strong></p>
  <pre>{{ output }}</pre>
  {% endif %}
</body>
</html>
"""

# Map UI actions to concrete command lines.
# We keep this explicit (no free-form shell) to avoid accidental misuse.


def build_command(action: str, target: str) -> tuple[list[str], str] | tuple[None, str]:
    """Return (argv, label) for a known action, or (None, error_label)."""
    t = target.strip() or "127.0.0.1"

    if action == "nmap_quick":
        return (["nmap", "-sV", "-p", "1-1024", t], f"nmap -sV -p 1-1024 {t}")
    if action == "nmap_full":
        return (["nmap", "-sV", "-p-", t], f"nmap -sV -p- {t}")
    if action == "http_privatenesstools":
        url = f"http://{t}:8888/health"
        return (["curl", "-v", "--max-time", "10", url], f"curl -v --max-time 10 {url}")
    if action == "dns_check":
        # Check that dns-reverse-proxy is answering on host (1053)
        # and can resolve a sample name.
        return (["dig", "@" + t, "example.com", "-p", "1053"], f"dig @{t} example.com -p 1053")
    if action == "emc_rpc":
        # If Emercoin RPC is exposed to this host, try a simple getblockchaininfo
        url = f"http://{t}:6662"  # adjust if you expose RPC elsewhere
        return (["curl", "--max-time", "10", url], f"curl --max-time 10 {url}")

    return None, f"Unknown action: {action}"


@app.route("/", methods=["GET"])
def index():
    target = request.args.get("target", "127.0.0.1")
    return render_template_string(TEMPLATE, target=target, output=None, last_label=None)


@app.route("/run", methods=["POST"])
def run_action():
    target = request.form.get("target", "127.0.0.1")
    action = request.form.get("action", "")

    cmd, label = build_command(action, target)
    if cmd is None:
        return render_template_string(TEMPLATE, target=target, output=label, last_label="Error")

    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        output = proc.stdout
    except Exception as e:  # best-effort UI, don't crash
        output = f"Error running command: {e}"

    return render_template_string(TEMPLATE, target=target, output=output, last_label=label)


if __name__ == "__main__":
    # Bind to 0.0.0.0 so host can reach it when container runs with --network host
    # Use 18080 by default to avoid clashing with common services like IPFS gateways.
    app.run(host="0.0.0.0", port=18080, debug=False)
