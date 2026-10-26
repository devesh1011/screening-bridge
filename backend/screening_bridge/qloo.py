"""Small, read-only Qloo adapter with explicit missing-coverage reporting."""

from datetime import datetime, timezone
import math
import os
from uuid import UUID, uuid4

import httpx

from .contract import Coordinates, distance_m


class QlooError(RuntimeError):
    """Sanitized provider failure; never contains headers or credentials."""


class QlooClient:
    def __init__(self, api_key: str, client: httpx.Client, base_url: str = "https://hackathon.api.qloo.com"):
        if not api_key:
            raise QlooError("missing_api_key")
        if base_url not in {"https://hackathon.api.qloo.com", "https://api.qloo.com"}:
            raise ValueError("Unsupported Qloo host")
        self._api_key = api_key
        self._client = client
        self._base_url = base_url

    @classmethod
    def from_environment(cls, client: httpx.Client) -> "QlooClient":
        return cls(os.environ.get("QLOO_API_KEY", ""), client, os.environ.get("QLOO_BASE_URL", "https://hackathon.api.qloo.com"))

    def _get(self, path: str, params: dict) -> dict:
        try:
            response = self._client.get(
                self._base_url + path, params=params,
                headers={"X-Api-Key": self._api_key}, follow_redirects=False,
            )
        except httpx.HTTPError:
            raise QlooError("network_error") from None
        if response.status_code == 404 and path == "/search":
            return {"results": []}
        if response.status_code != 200:
            raise QlooError(f"http_{response.status_code}")
        try:
            data = response.json()
        except ValueError:
            raise QlooError("invalid_json") from None
        if not isinstance(data, dict) or data.get("success") is False or data.get("errors"):
            raise QlooError("invalid_response")
        return data

    def search(self, query: str, entity_type: str, origin: Coordinates | None = None, radius_m: int = 3219) -> list[dict]:
        if entity_type not in {"movie", "place"}:
            raise ValueError("Only movie and place lookup is supported")
        params = {"query": query, "types": f"urn:entity:{entity_type}", "take": 10}
        if origin is not None:
            # Search uses miles; Insights uses meters. Keep this conversion here.
            params.update({"filter.location": f"{origin.latitude},{origin.longitude}", "filter.radius": radius_m / 1609.344})
        data = self._get("/search", params)
        rows = data.get("results")
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise QlooError("invalid_search_shape")
        return rows

    def rank(self, film_id: UUID, candidate_ids: list[UUID], origin: Coordinates, radius_m: int) -> dict:
        if not 1 <= len(candidate_ids) <= 50 or len(set(candidate_ids)) != len(candidate_ids):
            raise ValueError("Supply 1–50 unique candidate IDs")
        params = {
            "filter.type": "urn:entity:place",
            "signal.interests.entities": str(film_id),
            "filter.results.entities": ",".join(map(str, candidate_ids)),
            # The live hackathon Insights endpoint rejected comma-separated coordinates.
            "filter.location": f"POINT({origin.longitude} {origin.latitude})",
            "filter.location.radius": radius_m,
            "feature.explainability": "true",
            "take": len(candidate_ids),
        }
        data = self._get("/v2/insights", params)
        rows = data.get("results", {}).get("entities") if isinstance(data.get("results"), dict) else None
        if not isinstance(rows, list):
            raise QlooError("invalid_ranking_shape")
        ranked, seen = [], set()
        for index, row in enumerate(rows, 1):
            try:
                entity_id = UUID(row["entity_id"])
                score = row["query"]["affinity"]
                location = Coordinates(latitude=row["location"]["lat"], longitude=row["location"]["lon"])
                # Insights uses subtype; Search uses a types array.
                if row["subtype"] != "urn:entity:place":
                    raise ValueError("Wrong type")
            except (KeyError, TypeError, ValueError, AttributeError):
                raise QlooError("invalid_ranking_row") from None
            if entity_id not in candidate_ids or entity_id in seen:
                raise QlooError("unexpected_or_duplicate_entity")
            if isinstance(score, bool) or not isinstance(score, (float, int)) or not math.isfinite(score) or not 0 <= score <= 1:
                raise QlooError("invalid_affinity")
            actual_distance = distance_m(origin, location)
            if actual_distance > radius_m:
                raise QlooError("radius_filter_not_respected")
            seen.add(entity_id)
            ranked.append({
                "entity_id": str(entity_id), "name": row.get("name"),
                "returned_rank": index, "affinity": score,
                "distance_m": round(actual_distance, 3), "distance_method": "great_circle",
                "coordinates": location.model_dump(),
                "explainability": row["query"].get("explainability"),
            })
        return {
            "query_id": str(uuid4()), "retrieved_at": datetime.now(timezone.utc).isoformat(),
            "params": params, "ranked": ranked,
            "unscored_ids": [str(entity_id) for entity_id in candidate_ids if entity_id not in seen],
        }
