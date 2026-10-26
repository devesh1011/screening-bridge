# Screening Bridge

Screening Bridge helps independent cinemas explore local collaborations for an already-chosen film. Qloo provides cultural ranking; public sources establish partner identity and activities; the operator reviews proposals and edits outreach drafts before saving a plan. Nothing sends messages automatically.

**Current implementation:** native SwiftUI app with separate sample/live modes, an authenticated local discovery backend, bounded OpenAI web research and Qloo tool calling, cited partner snapshots and local plan persistence. The live starter area is deliberately limited to Nitehawk Williamsburg and the verified candidate catalogue. The hosted browser demo and public live API are milestone-3 work.

- [Implementation spec](SPEC.md)
- [Milestone 1 findings and sourced example](MILESTONE-1.md)
- [Milestone 2 setup and verification](MILESTONE-2.md)
- [Discovery contract](contracts/README.md)
- [Project issue tracker](https://github.com/devesh1011/screening-bridge/issues)

## Run the checks

Requires Python 3.13+ and uv.

```sh
cd backend
uv sync
uv run pytest -q
uv run mypy screening_bridge --ignore-missing-imports
uv run python -m screening_bridge.export_contract --check
```

## Repeat the live coverage probe

Provide `QLOO_API_KEY` in the shell environment using your preferred secret manager, then run from `backend`:

```sh
uv run python -m screening_bridge.probe
```

The probe performs 11 bounded entity searches and four ranking requests for two fixed candidate pools. A failed identity can reduce that count. Each call has a 30-second timeout; the probe does not retry automatically. It defaults to the Qloo hackathon endpoint. `QLOO_BASE_URL` can select `https://api.qloo.com` when using a compatible production account; other hosts are rejected.

Results are written to a timestamped, ignored `.local/coverage` JSON file with owner-only permissions. They include public entity metadata and ranking provenance, never authentication headers. The probe resolves identities and inspects API coverage; it does not automatically reverify businesses against their websites. A successful probe can legitimately contain omitted IDs or an empty ranking. Inspect the report before claiming useful coverage. Credentials are not needed for tests or schema checks.

## Observed limitation

All eight candidate identities in the expanded Brooklyn pool resolved, but only three were scored. The three had the same order for Perfect Days and School of Rock. This demonstrates a usable data path with partial coverage, not superior recommendations or ticket-sales uplift. The example screenings are hypothetical and imply no affiliation with the named businesses.

Original code is provided under the [MIT license](LICENSE). Third-party services, linked content and provider data retain their respective terms; the software license does not grant redistribution rights to those materials.

## Native live development

See the milestone-2 guide for the local backend and device build. Provider credentials stay in the backend environment. The ignored development configuration contains only the backend address and a scoped development-access token. A public [health endpoint](https://screening-bridge-api.vercel.app/health) and [starter catalogue](https://screening-bridge-api.vercel.app/v1/catalog) verify hosting; paid discovery is disabled on that deployment.
