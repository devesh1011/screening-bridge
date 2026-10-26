"""Export or check the committed schemas from the executable contract."""

import argparse
import json
from pathlib import Path

from .contract import DiscoveryRequest, event_adapter


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[2] / "contracts"
    schemas = {"request.schema.json": DiscoveryRequest.model_json_schema(), "event.schema.json": event_adapter.json_schema()}
    for filename, schema in schemas.items():
        path = directory / filename
        rendered = json.dumps(schema, indent=2) + "\n"
        if args.check:
            if not path.exists() or path.read_text() != rendered:
                raise SystemExit(f"Schema needs regeneration: {filename}")
        else:
            directory.mkdir(parents=True, exist_ok=True)
            path.write_text(rendered)
    print("Discovery schemas are current.")


if __name__ == "__main__":
    main()
