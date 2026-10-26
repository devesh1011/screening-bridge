"""Reproduce the bounded, manually reviewed Brooklyn coverage experiment.

This is an API coverage probe, not autonomous web verification or a live app.
Results stay local; no provider response dataset is intended for publication.
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time
from uuid import UUID

import httpx

from .contract import Coordinates
from .qloo import QlooClient, QlooError


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def resolve(rows: list[dict], expected: dict, entity_type: str) -> dict | None:
    """Never accept the first fuzzy search result without checking identity."""
    matches = []
    for row in rows:
        props = row.get("properties") or {}
        if not isinstance(props, dict) or f"urn:entity:{entity_type}" not in row.get("types", []):
            continue
        if normalize(row.get("name", "")) != normalize(expected["name"]):
            continue
        if entity_type == "movie" and props.get("release_year") != expected["year"]:
            continue
        if entity_type == "place" and not all(normalize(term) in normalize(props.get("address", "")) for term in expected["address_terms"]):
            continue
        try:
            entity_id = str(UUID(row["entity_id"]))
            location = row.get("location")
            coordinates = None
            if entity_type == "place":
                if not isinstance(location, dict):
                    continue
                coordinates = Coordinates(latitude=location["lat"], longitude=location["lon"]).model_dump()
        except (KeyError, TypeError, ValueError):
            continue
        matches.append({"entity_id": entity_id, "name": row["name"], "address": props.get("address"), "year": props.get("release_year"), "coordinates": coordinates})
    return matches[0] if len(matches) == 1 else None


def run_probe(api: QlooClient, config: dict) -> dict:
    origin = Coordinates.model_validate(config["origin"])
    radius = config["radius_m"]
    result = {"started_at": datetime.now(timezone.utc).isoformat(), "case": config["case"], "identities": {}, "rankings": {}}
    items = [("venue", config["venue"], "place")]
    items += [(film["key"], film, "movie") for film in config["films"]]
    items += [(partner["key"], partner, "place") for partner in config["candidates"]]
    for key, expected, kind in items:
        start = time.monotonic()
        try:
            rows = api.search(expected["query"], kind, origin if kind == "place" else None, radius)
            match = resolve(rows, expected, kind)
            result["identities"][key] = {"status": "resolved" if match else "needs_review", "match": match, "elapsed_seconds": round(time.monotonic() - start, 3)}
        except QlooError as error:
            result["identities"][key] = {"status": "unavailable", "error": str(error)}
    venue = result["identities"]["venue"]["match"] if result["identities"]["venue"].get("status") == "resolved" else None
    if not venue:
        result["status"] = "venue_unresolved"
        return result
    # Rank around the newly resolved venue coordinates, not a stale seed point.
    origin = Coordinates.model_validate(venue["coordinates"])
    for pool_name, keys in config["pools"].items():
        ids = [UUID(result["identities"][key]["match"]["entity_id"]) for key in keys if result["identities"][key]["status"] == "resolved"]
        unresolved = [key for key in keys if result["identities"][key]["status"] != "resolved"]
        for film in config["films"]:
            key = f"{pool_name}/{film['key']}"
            identity = result["identities"][film["key"]]
            if not ids or identity["status"] != "resolved":
                result["rankings"][key] = {"status": "needs_review", "unresolved_candidates": unresolved}
                continue
            start = time.monotonic()
            try:
                ranking = api.rank(UUID(identity["match"]["entity_id"]), ids, origin, radius)
                result["rankings"][key] = {"status": "ok", **ranking, "unresolved_candidates": unresolved, "elapsed_seconds": round(time.monotonic() - start, 3)}
            except QlooError as error:
                result["rankings"][key] = {"status": "unavailable", "error": str(error)}
    result["status"] = "complete" if all(value["status"] == "ok" for value in result["rankings"].values()) else "incomplete"
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(__file__).resolve().parents[2] / "contracts/brooklyn-coverage.json")
    parser.add_argument("--output", type=Path, default=Path(".local/coverage") / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ.json"))
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation prevents accidental replacement of an earlier evidence record.
    with args.output.open("x") as output:
        args.output.chmod(0o600)
        with httpx.Client(timeout=30) as client:
            result = run_probe(QlooClient.from_environment(client), config)
        json.dump(result, output, indent=2)
        output.write("\n")
    print(json.dumps({"output": str(args.output), "identities": {key: value["status"] for key, value in result["identities"].items()}, "rankings": {key: {"status": value["status"], "returned": len(value.get("ranked", [])), "unscored": len(value.get("unscored_ids", []))} for key, value in result["rankings"].items()}}, indent=2))
    if result["status"] != "complete":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
