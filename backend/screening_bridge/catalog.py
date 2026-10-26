"""Explicitly bounded starter area; identities are rechecked on each live run."""

from uuid import UUID
from typing import TypedDict

from .contract import Category, Coordinates, FilmIdentity, VenueIdentity


class Candidate(TypedDict):
    query: str
    name: str
    address_terms: list[str]
    category: Category
    url: str
    identity_terms: list[str]

FILMS = [
    FilmIdentity(entity_id=UUID("b30db61e-707c-421e-a1c4-1a912b7f067d"), title="Perfect Days", year=2023, director="Wim Wenders"),
    FilmIdentity(entity_id=UUID("fa0beb00-7fdc-4ff7-8a3d-22b8fb0477fa"), title="School of Rock", year=2003, director="Richard Linklater"),
]
VENUE = VenueIdentity(entity_id=UUID("619ee79f-7aa8-4cbb-a206-85692519ff54"), name="Nitehawk Cinema Williamsburg", address="136 Metropolitan Ave Brooklyn, NY 11249", coordinates=Coordinates(latitude=40.7159722, longitude=-73.962575), timezone="America/New_York")

PARTNERS: list[Candidate] = [
    {"query": "Choplet", "name": "Choplet Ceramic Studio & Gallery", "address_terms": ["238 Grand", "Brooklyn"], "category": "ceramics_studio", "url": "https://choplet.com/contact-directions/", "identity_terms": ["choplet", "238 grand", "brooklyn"]},
    {"query": "Quimbys", "name": "Quimby's Bookstore NYC", "address_terms": ["536 Metropolitan", "Brooklyn"], "category": "bookshop", "url": "https://quimbysnyc.com/", "identity_terms": ["quimby", "536 metropolitan", "brooklyn"]},
    {"query": "For The Record", "name": "For The Record", "address_terms": ["1107 Manhattan", "Brooklyn"], "category": "record_shop", "url": "https://fortherecordnyc.com/", "identity_terms": ["for the record", "1107 manhattan", "brooklyn", "vinyl"]},
]


def public_catalog() -> dict:
    return {
        "films": [film.model_dump(mode="json") for film in FILMS],
        "venues": [VENUE.model_dump(mode="json")],
        "scope": "Brooklyn starter demo: two films, Nitehawk Williamsburg and three researched partner candidates. Screenings are hypothetical.",
    }
