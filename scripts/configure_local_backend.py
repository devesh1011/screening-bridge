"""Prepare private development connection settings without printing credentials."""

import argparse
import json
from pathlib import Path
import secrets
from urllib.parse import urlparse

parser = argparse.ArgumentParser(description=__doc__)
address = parser.add_mutually_exclusive_group(required=True)
address.add_argument("--host", help="LAN IP or hostname reachable by the iPhone")
address.add_argument("--url", help="HTTPS ngrok endpoint forwarding to the local backend")
parser.add_argument("--port", type=int, default=8765)
args = parser.parse_args()
if not 1 <= args.port <= 65535:
    parser.error("Supply a valid port")
if args.url:
    parsed = urlparse(args.url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in {"", "/"}:
        parser.error("Supply an HTTPS base URL without credentials, query or path")
    backend_url = args.url.rstrip("/")
else:
    if not args.host or any(char in args.host for char in "/@?# "):
        parser.error("Supply a hostname or IPv4 address")
    backend_url = f"http://{args.host}:{args.port}"
root = Path(__file__).resolve().parents[1]
path = root / ".local/LiveConfig.json"
path.parent.mkdir(parents=True, exist_ok=True)
existing = json.loads(path.read_text()) if path.exists() else {}
config = {"backendURL": backend_url, "accessToken": existing.get("accessToken") or secrets.token_urlsafe(32)}
path.write_text(json.dumps(config, indent=2) + "\n")
path.chmod(0o600)
print("Private development connection saved. Regenerate and rebuild the iPhone app.")
