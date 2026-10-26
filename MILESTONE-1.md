# Milestone 1 — coverage and discovery contract

26 October 2026. Technical gate: **pass for a constrained Brooklyn demo**, with partial coverage and no demonstrated change in shortlist order between the two tested films. This is a feasibility probe plus manually prepared proposal, not a completed agent or deployed app.

## Confirmed identities

- **Perfect Days (2023), Wim Wenders.** Qloo Search returned the 2023 film separately from a similarly named 2011 film. The year/director are corroborated by [Criterion's film page](https://www.criterion.com/films/34274).
- **School of Rock (2003), Richard Linklater.** This is the comparison film, corroborated by [Paramount](https://www.paramount.com/movies/school-of-rock).
- **Nitehawk Cinema Williamsburg**, 136 Metropolitan Avenue, Brooklyn. Qloo returned both Williamsburg and Prospect Park; the exact address selects Williamsburg. The cinema's [official contact page](https://nitehawkcinema.com/williamsburg/contact/) confirms the address. Coordinates from the matched Qloo place are 40.7159722, -73.962575; venue timezone is America/New_York.

These are hypothetical screening briefs, not claims that Nitehawk has scheduled either film, granted screening rights, or agreed to use this app.

## Coverage experiment

Start with a two-mile search radius (rounded to 3,219 meters for Insights). Resolve named candidates by name and address, then submit the identical candidate IDs for each film. Use direct movie-to-place signals, a fixed radius and explainability metadata. Independently check great-circle distance.

The initial six-candidate pool returned only Choplet for each film. Removing the geographic filter did not recover the omitted candidates. Individual queries for Spoonbill and Captured also returned no scored result. Therefore the omissions are not explained by the tested radius, but their precise provider-side cause remains unknown.

A broader, category-filtered Perfect Days query surfaced additional local candidates. Quimby's and For The Record were checked against their official sites and added to an expanded eight-candidate pool. The expanded pool was frozen and submitted for both films. Because these additions were discovered using Perfect Days, this is an exploratory coverage check, not an unbiased quality benchmark.

| Candidate | Approximate straight-line distance | Expanded-pool result for both films | Public verification in this milestone |
| --- | ---: | --- | --- |
| Choplet Ceramic Studio & Gallery | 394 m | Rank 1 | Official address and adult/private-class offering checked |
| Quimby's Bookstore NYC | 1,006 m | Rank 2 | Official Brooklyn store identity/address checked |
| For The Record | 2,339 m | Rank 3 | Official address and record-shop/café offering checked |
| Spoonbill & Sugartown Books | 288 m | No score returned | Search identity matched; full source verification deferred |
| McNally Jackson Books Williamsburg | 192 m | No score returned | Search identity matched; official site fetch blocked |
| WORD Greenpoint | 1,524 m | No score returned | Search identity matched; official site fetch blocked |
| Captured Record Shop | 1,435 m | No score returned | Search identity matched to current-address candidate; official site fetch unavailable |
| CLAY SPACE Ceramic Center | 1,892 m | No score returned | Search identity matched; full address verification deferred |

Academy Records was excluded before ranking: the initial search returned its Manhattan branch, not the intended Brooklyn Annex. Rough Trade was also not used as a Brooklyn candidate; its [current official US stores page](https://www.roughtrade.com/en-us/stores) lists Rockefeller Center locations. These illustrate why a familiar business name or old directory is insufficient.

**Interpretation:** eight place identities can be resolved in Search; three receive scores in the expanded Insights requests. Search availability does not imply ranking coverage. The three returned partners have first-party identity support. This is enough for a bounded live demonstration across the existing three partner categories, with explicit warnings about the five omitted candidates.

## What changing the film did

The returned order was **Choplet → Quimby's → For The Record** for both Perfect Days and School of Rock. Provider score values changed, but these are normalized per request and should not be interpreted as absolute cross-film differences. The unchanged order does not demonstrate a recommendation change or useful superiority over an LLM-only baseline.

Explainability attributed each result to the supplied film ID, with contribution 1.0 because there was only one film input. That is provenance metadata, not evidence of perfect audience fit. The broader six-brief evaluation remains milestone-4 work. See Qloo's [affinity interpretation guidance](https://docs.qloo.com/docs/interpreting-affinity-scores).

## One sourced collaboration proposal

**Candidate:** Choplet Ceramic Studio & Gallery, 238 Grand Street, Williamsburg.

**Verified basis:** the [official contact page](https://choplet.com/contact-directions/) corroborates this branch's address. Its [adult classes page](https://choplet.com/ceramic-classes/classes-at-choplet-williamsburg/) advertises handbuilding, wheel throwing and private instruction/events. The direct Perfect Days Insights request returned Choplet first within the tested pool. The independently calculated distance from the cinema is approximately 394 meters, not a walking-time estimate.

**Proposed activity:** invite Choplet to discuss a short handbuilding session paired with a hypothetical Perfect Days screening. The connection between careful making and the film's attention to everyday life is our interpretation, informed by the film description and studio activity; Qloo supplies ranking evidence, not that narrative explanation.

**Draft introduction:** “Hello, we're exploring a Perfect Days screening in Williamsburg and wondered whether your studio would be interested in discussing a small handbuilding session alongside it. Your public programme includes handbuilding and private classes. If the idea interests you, we could compare dates, group size, costs and a workable format.”

**Still to confirm:** venue and partner interest, event date, capacity, pricing, accessibility details, travel arrangement, promotion responsibilities and screening permissions. No contact was made and nothing was booked. This proposal was prepared manually for the feasibility milestone; it is not an OpenAI-generated app result.

## Other supported candidate sources

- [Quimby's NYC](https://quimbysnyc.com/) lists the Brooklyn address at 536 Metropolitan Avenue. Do not import Chicago store events or programmes as Brooklyn facts.
- [For The Record](https://fortherecordnyc.com/) identifies itself as a café and record shop and lists 1107 Manhattan Avenue. Qloo's primary category is coffee shop, so the product's record-shop eligibility uses the corroborated offering rather than only the primary category label. Availability for a listening event is unconfirmed.

## Delivered technical boundary

- Executable Pydantic request/event models, generated JSON Schemas and synthetic examples.
- Request/revision/mode correlation; progress and terminal outcomes; evidence references; direct Qloo provenance; partial coverage; constraints; durable partner snapshots.
- Read-only Qloo adapter with explicit omitted IDs, WKT geography, unit conversion, malformed-response checks and sanitized errors.
- A repeatable probe with film-year and place-address matching; no automatic acceptance of the first fuzzy result.
- Focused automated tests covering contract behaviour, provider parsing, constraints, source integrity, stale results, interrupted streams and identity ambiguity.

See [the contract](contracts/README.md) and [probe configuration](contracts/brooklyn-coverage.json). Live observations and any raw provider records are local evidence, not a public dataset. The public repository contains only reproducible code, probe inputs, synthetic contract fixtures and this concise findings report.

Verification: **28 automated tests passed**. A fresh probe at 10:37 IST resolved all 11 input identities (two films, cinema, eight candidates) and completed all four pool/film ranking calls. The 11 lookups took approximately 3.67 seconds in aggregate; individual ranking requests took approximately 0.33 seconds. These are single-run Qloo timings, excluding web research and OpenAI; they are not an end-to-end latency guarantee.

The first reusable-adapter run caught a response-shape assumption: Insights emits `subtype`, while Search emits `types`. The adapter and synthetic provider fixture were corrected to the observed shape, then the entire probe was rerun successfully. The earlier failed run is retained locally, alongside the successful run, rather than overwritten.

## Limits and next milestone

The next milestone should build the bounded research/agent service and connect these results to native screens. The adapter does not yet implement production retries, the service deadline, session isolation or cost controls. Contract validation does not verify a source's truth. There is no OpenAI integration, HTTP server, automatic web verification or hosted demo yet, and the current native app still uses sample data.

Keep the demo initially bounded to verified Brooklyn cases. Expand coverage only with evidence. Preserve sample mode and existing device data while migrating saved plans to full partner snapshots.
