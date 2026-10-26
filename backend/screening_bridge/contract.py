"""Versioned wire models; no network calls or provider credentials.

These validators enforce structural integrity, not the truth of cited claims.
The discovery service must verify identities and sources before emitting results.
"""

from math import asin, cos, radians, sin, sqrt
from typing import Annotated, Literal, Self
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import (
    AwareDatetime, BaseModel, ConfigDict, Field, HttpUrl, TypeAdapter,
    field_validator, model_validator,
)

Text = Annotated[str, Field(min_length=1, max_length=2000)]
Category = Literal["bookshop", "record_shop", "ceramics_studio"]


class WireModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, allow_inf_nan=False)


class Coordinates(WireModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


def distance_m(origin: Coordinates, destination: Coordinates) -> float:
    """Great-circle distance, never a route length or walking-time estimate."""
    a = sin(radians(destination.latitude - origin.latitude) / 2) ** 2
    a += cos(radians(origin.latitude)) * cos(radians(destination.latitude)) * sin(
        radians(destination.longitude - origin.longitude) / 2
    ) ** 2
    return 6_371_008.8 * 2 * asin(sqrt(min(1.0, max(0.0, a))))


class FilmIdentity(WireModel):
    entity_id: UUID
    title: Text
    year: int = Field(ge=1888, le=2100)
    director: Text | None = None


class VenueIdentity(WireModel):
    entity_id: UUID
    name: Text
    address: Text
    coordinates: Coordinates
    timezone: str = Field(min_length=1, max_length=100)

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as error:
            raise ValueError("Use an IANA venue timezone") from error
        return value


class DiscoveryRequest(WireModel):
    schema_version: Literal["1.0"] = "1.0"
    request_id: UUID
    brief_revision: int = Field(ge=1, strict=True)
    mode: Literal["live", "sample"]
    film: FilmIdentity
    venue: VenueIdentity
    screening_at: AwareDatetime
    radius_m: int = Field(gt=0, le=16094, strict=True)
    categories: list[Category] = Field(min_length=1, max_length=3)
    excluded_partner_ids: list[UUID] = Field(default_factory=list, max_length=50)
    notes: str = Field(default="", max_length=2000)

    @model_validator(mode="after")
    def unique_constraints(self) -> Self:
        if len(set(self.categories)) != len(self.categories):
            raise ValueError("Duplicate categories")
        if len(set(self.excluded_partner_ids)) != len(self.excluded_partner_ids):
            raise ValueError("Duplicate exclusions")
        return self


class Source(WireModel):
    source_id: str = Field(min_length=1, max_length=100)
    url: HttpUrl
    title: Text
    retrieved_at: AwareDatetime


class SourcedClaim(WireModel):
    text: Text
    source_ids: list[str] = Field(min_length=1, max_length=10)


class CulturalSignal(WireModel):
    kind: Literal["direct_qloo"] = "direct_qloo"
    query_id: UUID
    film_entity_id: UUID
    candidate_pool_ids: list[UUID] = Field(min_length=1, max_length=50)
    returned_rank: int = Field(ge=1, le=50, strict=True)
    affinity: float = Field(ge=0, le=1)
    retrieved_at: AwareDatetime
    # Metadata only: a single input can have contribution 1.0 for every result.
    input_contribution: float | None = Field(default=None, ge=0, le=1)

    @model_validator(mode="after")
    def valid_pool(self) -> Self:
        if len(set(self.candidate_pool_ids)) != len(self.candidate_pool_ids):
            raise ValueError("Duplicate IDs in Qloo candidate pool")
        if self.returned_rank > len(self.candidate_pool_ids):
            raise ValueError("Rank exceeds candidate pool")
        return self


class PartnerRecommendation(WireModel):
    partner_id: UUID
    name: Text
    category: Category
    address: Text
    coordinates: Coordinates
    distance_m: float = Field(ge=0)
    distance_method: Literal["great_circle"] = "great_circle"
    identity_source_ids: list[str] = Field(min_length=1, max_length=10)
    facts: list[SourcedClaim] = Field(min_length=1, max_length=20)
    cultural_signal: CulturalSignal
    # Explicitly an interpretation and proposal, not a claim about Qloo's reasoning.
    interpretation: Text
    proposed_activity: Text
    introduction: Text
    availability: Literal["unconfirmed"] = "unconfirmed"
    willingness: Literal["unconfirmed"] = "unconfirmed"
    still_to_confirm: list[Text] = Field(min_length=1, max_length=10)

    @model_validator(mode="after")
    def belongs_to_pool(self) -> Self:
        if self.partner_id not in self.cultural_signal.candidate_pool_ids:
            raise ValueError("Recommendation is absent from its Qloo candidate pool")
        return self


class EventBase(WireModel):
    schema_version: Literal["1.0"] = "1.0"
    request_id: UUID
    brief_revision: int = Field(ge=1, strict=True)
    mode: Literal["live", "sample"]
    sequence: int = Field(ge=1, strict=True)
    emitted_at: AwareDatetime


class ProgressEvent(EventBase):
    type: Literal["progress"] = "progress"
    stage: Literal["resolving", "researching", "ranking", "preparing"]


class CompletedEvent(EventBase):
    type: Literal["completed"] = "completed"
    recommendations: list[PartnerRecommendation] = Field(min_length=1, max_length=3)
    sources: list[Source] = Field(min_length=1, max_length=50)
    unscored_partner_ids: list[UUID] = Field(default_factory=list, max_length=50)
    warnings: list[Text] = Field(default_factory=list, max_length=20)

    @model_validator(mode="after")
    def evidence_integrity(self) -> Self:
        ids = [source.source_id for source in self.sources]
        if len(set(ids)) != len(ids):
            raise ValueError("Duplicate source IDs")
        partners = [partner.partner_id for partner in self.recommendations]
        if len(set(partners)) != len(partners):
            raise ValueError("Duplicate recommended partners")
        if set(partners).intersection(self.unscored_partner_ids):
            raise ValueError("A scored recommendation cannot also be unscored")
        if self.unscored_partner_ids and not self.warnings:
            raise ValueError("Partial Qloo coverage requires a visible warning")
        for partner in self.recommendations:
            refs = set(partner.identity_source_ids)
            refs.update(ref for claim in partner.facts for ref in claim.source_ids)
            if not refs.issubset(ids):
                raise ValueError("Unresolved evidence reference")
        return self


class StoppedEvent(EventBase):
    type: Literal["no_matches", "needs_input", "unavailable", "cancelled"]
    code: Literal[
        "no_eligible_candidates", "no_qloo_coverage", "ambiguous_film",
        "ambiguous_venue", "invalid_brief", "provider_unavailable", "timeout",
        "rate_limited", "capacity", "cancelled",
    ]
    message: Text
    retryable: bool
    input_field: Literal["film", "venue", "screening_at", "constraints"] | None = None

    @model_validator(mode="after")
    def valid_outcome(self) -> Self:
        allowed = {
            "no_matches": {"no_eligible_candidates", "no_qloo_coverage"},
            "needs_input": {"ambiguous_film", "ambiguous_venue", "invalid_brief"},
            "unavailable": {"provider_unavailable", "timeout", "rate_limited", "capacity"},
            "cancelled": {"cancelled"},
        }
        if self.code not in allowed[self.type]:
            raise ValueError("Outcome and error code disagree")
        if (self.type == "needs_input") != (self.input_field is not None):
            raise ValueError("Only needs_input outcomes identify a field to correct")
        if self.type in {"cancelled", "needs_input", "no_matches"} and self.retryable:
            raise ValueError("This outcome requires a new action or revised brief")
        return self


DiscoveryEvent = Annotated[
    ProgressEvent | CompletedEvent | StoppedEvent, Field(discriminator="type")
]
event_adapter = TypeAdapter(DiscoveryEvent)


def validate_event_for_request(
    request: DiscoveryRequest, event: DiscoveryEvent,
) -> None:
    """Public contract check shared by service tests and transport integration."""
    if (event.request_id, event.brief_revision, event.mode) != (
        request.request_id, request.brief_revision, request.mode
    ):
        raise ValueError("Event belongs to a different request, revision or mode")
    if not isinstance(event, CompletedEvent):
        return
    for partner in event.recommendations:
        if partner.category not in request.categories:
            raise ValueError("Recommendation violates category constraints")
        if partner.partner_id in request.excluded_partner_ids:
            raise ValueError("Recommendation was explicitly excluded")
        actual = distance_m(request.venue.coordinates, partner.coordinates)
        if actual > request.radius_m or abs(actual - partner.distance_m) > 1:
            raise ValueError("Recommendation has invalid distance or exceeds radius")
        if partner.cultural_signal.film_entity_id != request.film.entity_id:
            raise ValueError("Qloo signal belongs to another film")


def validate_event_stream(request: DiscoveryRequest, events: list[DiscoveryEvent]) -> None:
    """A finished stream has ordered events and exactly one final outcome."""
    if not events or isinstance(events[-1], ProgressEvent):
        raise ValueError("Stream ended without a terminal outcome")
    for index, event in enumerate(events):
        validate_event_for_request(request, event)
        if index and event.sequence <= events[index - 1].sequence:
            raise ValueError("Event sequence must increase")
        if index < len(events) - 1 and not isinstance(event, ProgressEvent):
            raise ValueError("Events arrived after a terminal outcome")
