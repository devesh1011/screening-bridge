import asyncio
import json
from uuid import uuid4

import httpx
import pytest

from screening_bridge.contract import DiscoveryRequest, validate_event_stream
from screening_bridge.discovery import DiscoveryService
from fastapi.testclient import TestClient

FILM = "b30db61e-707c-421e-a1c4-1a912b7f067d"
VENUE = "619ee79f-7aa8-4cbb-a206-85692519ff54"
STUDIO = "2b5888a0-8a41-4f23-9e1e-0f52da29244a"


def brief():
    return DiscoveryRequest.model_validate({
        "request_id": str(uuid4()), "brief_revision": 1, "mode": "live",
        "film": {"entity_id": FILM, "title": "Perfect Days", "year": 2023, "director": "Wim Wenders"},
        "venue": {"entity_id": VENUE, "name": "Nitehawk Cinema Williamsburg", "address": "136 Metropolitan Ave Brooklyn, NY 11249", "coordinates": {"latitude": 40.7159722, "longitude": -73.962575}, "timezone": "America/New_York"},
        "screening_at": "2026-10-30T19:00:00-04:00", "radius_m": 3219,
        "categories": ["ceramics_studio"], "notes": "Small handbuilding session; nothing is booked.",
    })


def provider_response(request):
    if request.url.host == "choplet.com":
        return httpx.Response(200, text="<html><body>Choplet Ceramic Studio &amp; Gallery. 238 Grand Street Brooklyn, NY 11211. Adult handbuilding and private classes.</body></html>", headers={"content-type": "text/html"})
    if request.url.host == "nitehawkcinema.com":
        return httpx.Response(200, text="<html><body>Nitehawk Cinema Williamsburg. 136 Metropolitan Ave. Brooklyn, NY.</body></html>")
    if request.url.host == "www.criterion.com":
        return httpx.Response(200, text="<html><body>Perfect Days 2023 Wim Wenders. The wonders of everyday life.</body></html>")
    if request.url.path == "/search":
        query = request.url.params["query"]
        rows = {
            "Perfect Days": {"entity_id": FILM, "name": "Perfect Days", "types": ["urn:entity:movie"], "properties": {"release_year": 2023}},
            "Nitehawk Cinema": {"entity_id": VENUE, "name": "Nitehawk Cinema Williamsburg", "types": ["urn:entity:place"], "properties": {"address": "136 Metropolitan Ave Brooklyn, NY 11249"}, "location": {"lat": 40.7159722, "lon": -73.962575}},
            "Choplet": {"entity_id": STUDIO, "name": "Choplet Ceramic Studio & Gallery", "types": ["urn:entity:place"], "properties": {"address": "238 Grand St Brooklyn, NY 11211"}, "location": {"lat": 40.7134776, "lon": -73.9592514}},
        }
        return httpx.Response(200, json={"results": [rows[query]] if query in rows else []})
    if request.url.path == "/v2/insights":
        return httpx.Response(200, json={"results": {"entities": [{"entity_id": STUDIO, "name": "Choplet Ceramic Studio & Gallery", "type": "urn:entity", "subtype": "urn:entity:place", "location": {"lat": 40.7134776, "lon": -73.9592514}, "query": {"affinity": 0.62}}]}})
    if request.url.path == "/v1/responses":
        body = json.loads(request.content)
        if body.get("text"):
            proposal = {"partner_id": STUDIO, "interpretation": "Careful making could complement the film's attention to everyday life.", "proposed_activity": "Discuss a short handbuilding session.", "introduction": "Hello, would you be open to discussing a handbuilding session alongside our proposed screening?", "still_to_confirm": ["Interest, date, capacity and cost."]}
            return httpx.Response(200, json={"status": "completed", "output": [{"type": "message", "content": [{"type": "output_text", "text": json.dumps({"proposals": [proposal]})}]}]})
        if any(tool.get("name") == "rank_partners" for tool in body.get("tools", [])):
            return httpx.Response(200, json={"status": "completed", "output": [{"type": "function_call", "name": "rank_partners", "call_id": "call_rank", "arguments": "{}"}]})
        return httpx.Response(200, json={"status": "completed", "output": [{"type": "web_search_call", "status": "completed", "action": {"type": "search"}}, {"type": "message", "content": [{"type": "output_text", "text": "The official site offers handbuilding; availability remains unconfirmed.", "annotations": [{"type": "url_citation", "url": "https://choplet.com/contact-directions/", "title": "Choplet"}]}]}]})
    raise AssertionError(f"Unexpected external request: {request.url.host}{request.url.path}")


def test_live_brief_returns_grounded_partner_with_durable_evidence():
    async def scenario():
        transport = httpx.MockTransport(provider_response)
        async with httpx.AsyncClient(transport=transport) as client:
            service = DiscoveryService(client=client, qloo_key="test-qloo", openai_key="test-openai")
            request = brief()
            events = [event async for event in service.discover(request)]
            validate_event_stream(request, events)
            result = events[-1]
            assert result.type == "completed"
            assert result.recommendations[0].name == "Choplet Ceramic Studio & Gallery"
            assert result.recommendations[0].availability == "unconfirmed"
            assert any(str(source.url) == "https://choplet.com/contact-directions/" for source in result.sources)
            assert result.recommendations[0].cultural_signal.film_entity_id == request.film.entity_id
    asyncio.run(scenario())


def test_reconnecting_replays_a_completed_run_without_changing_the_plan(tmp_path):
    from screening_bridge.api import create_app
    client = httpx.AsyncClient(transport=httpx.MockTransport(provider_response))
    app = create_app(client=client, qloo_key="test-qloo", openai_key="test-openai", access_token="test-access", database=str(tmp_path / "runs.sqlite"))
    with TestClient(app) as api:
        headers = {"Authorization": "Bearer test-access", "X-Session-ID": str(uuid4())}
        payload = brief().model_dump(mode="json")
        first = api.post("/v1/discoveries", json=payload, headers=headers)
        second = api.post("/v1/discoveries", json=payload, headers=headers)
        assert first.status_code == second.status_code == 200
        assert first.text == second.text
        assert '"type":"completed"' in first.text
        payload["notes"] = "Changed brief under the same ID"
        assert api.post("/v1/discoveries", json=payload, headers=headers).status_code == 409
        assert api.post("/v1/discoveries", json=payload).status_code == 401


@pytest.mark.parametrize("failure", ["source_blocked", "qloo_outage", "unsupported_proposal", "deadline"])
def test_live_failures_preserve_an_honest_terminal_outcome(failure):
    async def scenario():
        async def response(request):
            if failure == "deadline":
                await asyncio.sleep(0.05)
            if failure == "source_blocked" and request.url.host == "choplet.com":
                return httpx.Response(403)
            if failure == "qloo_outage" and request.url.path == "/v2/insights":
                return httpx.Response(503)
            result = provider_response(request)
            if failure == "unsupported_proposal" and request.url.path == "/v1/responses" and json.loads(request.content).get("text"):
                data = result.json()
                data["output"][0]["content"][0]["text"] = json.dumps({"proposals": [{"partner_id": str(uuid4()), "interpretation": "Unsupported", "proposed_activity": "Unsupported", "introduction": "Unsupported", "still_to_confirm": ["Everything"]}]})
                return httpx.Response(200, json=data)
            return result
        async with httpx.AsyncClient(transport=httpx.MockTransport(response)) as client:
            service = DiscoveryService(client=client, qloo_key="test-qloo", openai_key="test-openai", deadline=0.01 if failure == "deadline" else 90)
            request = brief()
            events = [event async for event in service.discover(request)]
            validate_event_stream(request, events)
            assert events[-1].type == ("no_matches" if failure == "source_blocked" else "unavailable")
            assert all(event.type != "completed" for event in events)
    asyncio.run(scenario())
