from uuid import UUID

import httpx
import pytest

from screening_bridge.contract import Coordinates
from screening_bridge.probe import resolve
from screening_bridge.qloo import QlooClient, QlooError

FILM = UUID(int=1)
PARTNER = UUID(int=2)
OTHER = UUID(int=3)
ORIGIN = Coordinates(latitude=40.7, longitude=-73.9)


def row(entity_id=PARTNER):
    return {"entity_id": str(entity_id), "name": "Synthetic studio", "type": "urn:entity", "subtype": "urn:entity:place", "location": {"lat": 40.7, "lon": -73.9}, "query": {"affinity": 0.5}}


def test_partial_rank_is_explicit_and_insights_uses_wkt_and_meters():
    def response(request):
        assert request.url.params["filter.location"] == "POINT(-73.9 40.7)"
        assert request.url.params["filter.location.radius"] == "3219"
        assert set(request.url.params["filter.results.entities"].split(",")) == {str(PARTNER), str(OTHER)}
        return httpx.Response(200, json={"results": {"entities": [row()]}})
    with httpx.Client(transport=httpx.MockTransport(response)) as client:
        result = QlooClient("synthetic-key", client).rank(FILM, [PARTNER, OTHER], ORIGIN, 3219)
    assert result["unscored_ids"] == [str(OTHER)]
    assert result["ranked"][0]["distance_m"] == 0
    assert "synthetic-key" not in str(result)


@pytest.mark.parametrize("fault", ["unexpected_id", "duplicate_id", "invalid_score", "out_of_radius", "malformed_shape"])
def test_provider_contract_failures_cannot_become_recommendations(fault):
    rows = [row()]
    if fault == "unexpected_id":
        rows = [row(OTHER)]
    elif fault == "duplicate_id":
        rows.append(row())
    elif fault == "invalid_score":
        rows[0]["query"]["affinity"] = True
    elif fault == "out_of_radius":
        rows[0]["location"]["lat"] = 0
    payload = {"results": {"entities": rows}} if fault != "malformed_shape" else {"results": []}
    with httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(200, json=payload))) as client:
        with pytest.raises(QlooError):
            QlooClient("synthetic-key", client).rank(FILM, [PARTNER], ORIGIN, 3219)


def test_http_failure_does_not_echo_provider_body_or_key():
    with httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(401, text="secret provider message"))) as client:
        with pytest.raises(QlooError, match="^http_401$"):
            QlooClient("synthetic-key", client).search("film", "movie")


def test_search_radius_conversion_and_wrong_branch_rejection():
    def response(request):
        assert float(request.url.params["filter.radius"]) == 2
        return httpx.Response(200, json={"results": []})
    with httpx.Client(transport=httpx.MockTransport(response)) as client:
        assert QlooClient("synthetic-key", client).search("Cinema", "place", ORIGIN, 3218.688) == []
    candidate = row()
    candidate.update(name="Cinema", types=["urn:entity:place"], properties={"address": "188 Prospect Park W Brooklyn"})
    assert resolve([candidate], {"name": "Cinema", "address_terms": ["136 Metropolitan", "Brooklyn"]}, "place") is None


def test_same_title_wrong_year_and_multiple_matches_need_review():
    candidate = {"entity_id": str(FILM), "name": "Film", "types": ["urn:entity:movie"], "properties": {"release_year": 2011}}
    assert resolve([candidate], {"name": "Film", "year": 2023}, "movie") is None
    candidate["properties"]["release_year"] = 2023
    assert resolve([candidate, candidate], {"name": "Film", "year": 2023}, "movie") is None
