# Discovery contract v1

This is the agreed application boundary for the native app and the future browser demo. The executable models are in `backend/screening_bridge/contract.py`; the adjacent JSON Schema files are generated from them. No HTTP server or agent loop is implemented in milestone 1.

## Request

The discovery service receives one `DiscoveryRequest`: schema version, request UUID, brief revision, sample/live mode, selected film and venue identities, screening instant, radius in meters, allowed categories, excluded partner IDs and notes. The venue carries its IANA timezone; render the screening instant in that timezone. An offset-aware instant makes daylight-saving transitions unambiguous. Never interpret the phone's timezone as the venue timezone.

Film and venue search/selection precede this request. The eventual service must revalidate selected identities and coordinates against server-side resolution data; client-supplied IDs and names are not evidence of verification. Unresolved identities yield `needs_input`, not a guessed match. Supported category identifiers are `bookshop`, `record_shop`, and `ceramics_studio`.

## Events

The proposed milestone-2 transport is `POST /v1/discoveries` returning an SSE stream. Each `data` record is one event JSON object. Event objects carry request UUID, brief revision, mode, increasing sequence number and an offset-aware emission time. The final transport must retain this logical contract even if hosting requires polling.

| Event type | Payload / behaviour |
| --- | --- |
| `progress` | Actual stage: `resolving`, `researching`, `ranking`, or `preparing`. Stages may repeat during bounded investigation; no fabricated percentage. |
| `completed` | One to three recommendations, source ledger, omitted candidate IDs and visible coverage warnings. |
| `no_matches` | No eligible candidates or no returned Qloo coverage. No automatic sample substitution. |
| `needs_input` | Ambiguous film/venue or invalid brief; identifies the field to correct. |
| `unavailable` | Provider, timeout, throttling or capacity failure, with explicit retryability. |
| `cancelled` | Terminal cancellation outcome when the connection remains available. |

A finished stream has exactly one terminal event. A connection ending without one is interrupted; the client retains the draft and offers a retry. On local cancellation the client immediately invalidates the request, even if it cannot receive the server's terminal event. It ignores all later events for that request. Events from older brief revisions or a different sample/live mode cannot change current UI state.

The service implementation must scope request IDs to anonymous sessions, bind each ID to the original payload, reject reuse with a different payload, and prevent duplicate paid work on retries. Deadline, cancellation propagation, session scoping, deduplication and actual SSE are milestone-2 work, not features delivered by these data models.

## Durable recommendations

Each recommendation includes its stable partner ID, identity and coordinates, independently computed great-circle distance, evidence references, factual claims, Qloo query provenance, interpretation, proposed activity, editable introduction and questions still to confirm. Store the full snapshot with the plan rather than looking up partner IDs from a global catalogue.

The Qloo record preserves the film ID, fixed candidate pool, returned rank, affinity and retrieval time. `input_contribution` is optional provider metadata. A contribution of 1.0 for a single input does not mean certainty or quality. The first version accepts direct film-to-place evidence only. Availability and willingness remain `unconfirmed`.

The evidence ledger stores URL, source title and retrieval time. Facts reference source IDs, while interpretation and proposed activity remain separate fields. Structural validation proves that references resolve, not that a source actually supports a claim; the service's source verification must establish that before emitting a result. Generated JSON Schema cannot encode every cross-field rule: the Python validators additionally check source references, pool membership, categories, exclusions, distance, film identity and request/revision integrity.

Omitted candidate IDs mean Qloo did not return a score in this request. They do not imply zero affinity, a closed business, or permanent absence from Qloo. Save partial-coverage warnings with the plan. The UI must show the recorded research time when reopening old results.

## Examples and verification

`examples/request.json` and `examples/events.json` are entirely synthetic sample-mode fixtures. Their addresses, IDs, scores and evidence URL do not describe real businesses. They exercise a successful plan payload with partial coverage. The real coverage experiment is documented in `../MILESTONE-1.md`; its raw responses remain local.

From `backend`:

```sh
uv run pytest -q
uv run python -m screening_bridge.export_contract --check
```

Regenerate schemas after intentional contract changes with `uv run python -m screening_bridge.export_contract`. Breaking changes require a new schema version and migration strategy.

## Provider boundary findings

- Search uses `types` in its response; Insights uses `type` plus `subtype`.
- Search's `filter.radius` is measured in miles. Insights' `filter.location.radius` is measured in meters.
- The tested hackathon Insights endpoint rejects comma-separated coordinates but accepts WKT `POINT(longitude latitude)`. The adapter uses WKT for Insights and recalculates distances from coordinates.
- `filter.results.entities` restricts a fixed candidate pool; the provider may return only a subset. Preserve omissions explicitly.
- Read-only failures are sanitized before reaching the caller. Secrets never appear in saved results or errors.

References: [Qloo Search](https://docs.qloo.com/reference/get-search), [Qloo Insights](https://docs.qloo.com/reference/insights-api-deep-dive), [Affinity interpretation](https://docs.qloo.com/docs/interpreting-affinity-scores), [Pydantic union validation](https://docs.pydantic.dev/latest/concepts/unions/).
