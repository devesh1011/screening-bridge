"""Run the local development backend using the ignored client configuration."""

import json
import os
from pathlib import Path
from urllib.parse import urlparse

import uvicorn


def main() -> None:
    path = Path(__file__).resolve().parents[2] / ".local/LiveConfig.json"
    if not path.exists():
        raise SystemExit("Run scripts/configure_local_backend.py first.")
    configuration = json.loads(path.read_text())
    if not os.environ.get("QLOO_API_KEY") or not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("Export QLOO_API_KEY and OPENAI_API_KEY before starting live discovery.")
    os.environ["SCREENING_BRIDGE_TOKEN"] = configuration["accessToken"]
    port = urlparse(configuration["backendURL"]).port or 8765
    uvicorn.run("screening_bridge.api:app", host="0.0.0.0", port=port, access_log=False)


if __name__ == "__main__":
    main()
