from copy import deepcopy
import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from screening_bridge.contract import (
    CompletedEvent, DiscoveryRequest, event_adapter, validate_event_stream,
)

EXAMPLES = Path(__file__).resolve().parents[2] / "contracts/examples"


def load_example(name):
    return json.loads((EXAMPLES / name).read_text())


def validate(request, events):
    validate_event_stream(DiscoveryRequest.model_validate(request), [event_adapter.validate_python(event) for event in events])


def test_documented_sample_journey_and_snapshot_round_trip():
    request = load_example("request.json")
    events = load_example("events.json")
    validate(request, events)
    final = event_adapter.validate_python(events[-1])
    assert isinstance(final, CompletedEvent)
    # This same payload can be stored as a durable snapshot without fetching Qloo again.
    assert event_adapter.validate_json(final.model_dump_json()) == final


@pytest.mark.parametrize("field,value", [
    ("request_id", "00000000-0000-0000-0000-000000000099"),
    ("brief_revision", 2), ("mode", "live"),
])
def test_old_or_cross_mode_results_cannot_replace_current_brief(field, value):
    request = load_example("request.json")
    events = load_example("events.json")
    events[-1][field] = value
    with pytest.raises(ValueError, match="different request"):
        validate(request, events)


@pytest.mark.parametrize("change", ["missing_source", "duplicate_partner", "unscored_without_warning", "wrong_film", "fake_distance"])
def test_unsupported_results_are_rejected(change):
    request = load_example("request.json")
    events = load_example("events.json")
    final = events[-1]
    partner = final["recommendations"][0]
    if change == "missing_source":
        partner["facts"][0]["source_ids"] = ["invented-source"]
    elif change == "duplicate_partner":
        final["recommendations"].append(deepcopy(partner))
    elif change == "unscored_without_warning":
        final["warnings"] = []
    elif change == "wrong_film":
        partner["cultural_signal"]["film_entity_id"] = "00000000-0000-0000-0000-000000000099"
    else:
        partner["distance_m"] = 200
    with pytest.raises(ValueError):
        validate(request, events)


@pytest.mark.parametrize("constraint", ["radius", "category", "excluded"])
def test_current_brief_constraints_are_enforced(constraint):
    request = load_example("request.json")
    events = load_example("events.json")
    if constraint == "radius":
        request["radius_m"] = 10
    elif constraint == "category":
        request["categories"] = ["bookshop"]
    else:
        request["excluded_partner_ids"] = [events[-1]["recommendations"][0]["partner_id"]]
    with pytest.raises(ValueError):
        validate(request, events)


@pytest.mark.parametrize("change", ["no_terminal", "after_terminal", "sequence"])
def test_stream_cannot_finish_early_or_emit_after_completion(change):
    request = load_example("request.json")
    events = load_example("events.json")
    if change == "no_terminal":
        events.pop()
    elif change == "after_terminal":
        events.append(deepcopy(events[-1]))
    else:
        events[-1]["sequence"] = events[0]["sequence"]
    with pytest.raises(ValueError):
        validate(request, events)


@pytest.mark.parametrize("change", ["naive_time", "unknown_timezone", "secret_field"])
def test_invalid_or_unexpected_request_fields_are_rejected(change):
    request = load_example("request.json")
    if change == "naive_time":
        request["screening_at"] = "2026-10-30T19:00:00"
    elif change == "unknown_timezone":
        request["venue"]["timezone"] = "Not/A_Timezone"
    else:
        request["api_key"] = "not-a-real-secret"
    with pytest.raises(ValidationError):
        DiscoveryRequest.model_validate(request)


def test_no_coverage_is_a_terminal_outcome_not_an_empty_success():
    request = load_example("request.json")
    first = load_example("events.json")[0]
    outcome = {key: value for key, value in first.items() if key not in {"type", "stage"}}
    outcome.update(type="no_matches", code="no_qloo_coverage", message="No supported cultural matches.", retryable=False)
    validate(request, [outcome])
    outcome["type"] = "cancelled"
    with pytest.raises(ValidationError):
        event_adapter.validate_python(outcome)
