"""Prepare private development connection settings without printing credentials."""

import argparse
import json
from pathlib import Path
import secrets

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--host", required=True, help="LAN IP or hostname reachable by the iPhone")
parser.add_argument("--port", type=int, default=8765)
args = parser.parse_args()
if not args.host or any(char in args.host for char in "/@?# ") or not 1 <= args.port <= 65535:
    parser.error("Supply a hostname or IPv4 address and a valid port")
root = Path(__file__).resolve().parents[1]
path = root / ".local/LiveConfig.json"
path.parent.mkdir(parents=True, exist_ok=True)
existing = json.loads(path.read_text()) if path.exists() else {}
config = {"backendURL": f"http://{args.host}:{args.port}", "accessToken": existing.get("accessToken") or secrets.token_urlsafe(32)}
path.write_text(json.dumps(config, indent=2) + "\n")
path.chmod(0o600)
print("Private development connection saved. Regenerate and rebuild the iPhone app.")
