# Milestone 2 — first live journey

Completed 26 October 2026. Scope: live research → evidence → selection → edited introduction → saved/reopened plan, preserving the native sample flow. Verified on Simulator and the physical iPhone 17; the phone uses ngrok to reach the local backend.

## Implemented

- The discovery service revalidates the selected Qloo film and cinema, resolves eligible nearby starter candidates, retrieves their official pages and checks name/address evidence before including them.
- OpenAI Responses performs web research, requests the constrained Qloo ranking tool, receives its actual output and selects structured activity/focus options. The server renders tentative proposal and introduction wording from those choices and verified fields. Free-form model assertions cannot become displayed facts. Official research citations are retained in the source ledger. Provider credentials and ranking parameters stay server-side.
- A 90-second service deadline, at most three model requests, at most two built-in web tool calls, a fixed candidate ceiling and finite provider timeouts bound the work. Unsupported results return explicit outcomes, never sample substitutions.
- The local FastAPI service streams versioned events. SQLite claims bind a request ID to its brief and development session; completed retries replay saved events, changed payloads conflict, and interrupted work requires an explicit new search. Limits are two active runs and 50 new runs per day.
- The native app offers Sample and Live modes, the two supported films and the confirmed Williamsburg venue. Progress reflects actual stages. Venue times use America/New_York. Live businesses use category symbols and straight-line distance rather than fictional shop photographs or walking-time estimates.
- Partner snapshots retain evidence links, factual claims, Qloo query provenance, timestamps and unresolved questions. The complete wire response is also saved, retaining coordinates, structured addresses, claim/source associations and omitted IDs. Edited introductions survive reruns; widening filters retains selections until refreshed results arrive. Changed briefs invalidate results. Earlier sample archives remain readable and gain snapshots when next saved.
- Test resets require isolated UI-test mode. Project regeneration preserves an existing signing team. Device signing data and local connection files remain ignored.
- A Vercel deployment serves `/health` and `/v1/catalog`. Paid discovery is disabled there: the native journey uses a local authenticated backend. Serverless-local SQLite is not presented as a shared production store.

## Run locally

Requirements: Python 3.13+, uv, and Xcode supporting the project's iOS deployment target. Export `QLOO_API_KEY` and `OPENAI_API_KEY` using your normal secret-management workflow. The default model is `gpt-5.4-mini`; `OPENAI_MODEL` can select another compatible model.

From the repository root:

```sh
python3 scripts/configure_local_backend.py --host YOUR_MAC_LAN_ADDRESS
python3 scripts/generate_project.py
cd backend
uv sync
uv run python -m screening_bridge.devserver
```

Keep the server running, then open the generated Xcode project and build/install using your existing signing setup. A fresh checkout needs `scripts/generate_project.py --team YOUR_DEVELOPMENT_TEAM` for a physical device. Regeneration preserves a previously configured team automatically.

The phone must reach the host on the local network. Unlock it for installation/testing and allow the app's local-network prompt. Live mode uses `.local/LiveConfig.json`, included when present at project-generation time. This ignored file must not be committed or included in a distributed release build. It contains a development API-access token, never Qloo/OpenAI credentials. This connection is for a trusted development network; public access will use HTTPS and a different session model in milestone 3.

The public smoke deployment cannot replace the local server: its health response reports `live_discovery_enabled: false`.

### Optional ngrok connection

If direct LAN access fails, keep the backend local and forward it with the already configured ngrok CLI:

```sh
ngrok http 8765 --inspect=false
```

Then, in a separate terminal at the repository root:

```sh
python3 scripts/configure_local_backend.py --url https://YOUR_NGROK_ENDPOINT
python3 scripts/generate_project.py
```

Rebuild/install the native app to bundle the private connection configuration. The same SSE API, access token and saved-run protection are used; there is no separate buffered transport. The token is required for research even through the tunnel. Keep both the local server and ngrok process running while using this development build. No Cloudflare tunnel or dependency is used.

## Verification

- TDD at the agreed discovery-service and local-persistence boundaries: failing tests preceded the service, request-replay endpoint and native snapshot integration.
- First real service run: Perfect Days + Nitehawk Williamsburg + bookshop filter completed in approximately 13 seconds, including live Qloo, OpenAI web search, function calling and synthesis. This single run is not a latency guarantee.
- Focused checks cover success, source refusal, provider outage, unsupported model output, deadline and idempotent replay. Native checks cover snapshot reload, evidence preservation, user-edit preservation and invalidation after changing the brief.
- Hosted smoke: `https://screening-bridge-api.vercel.app/health` returned HTTP 200 with live discovery disabled.
- Backend full suite: **36 tests passed**; mypy passed for all nine service modules; generated contract schemas are current. The test tooling emits a non-blocking Starlette warning about its HTTPX-based test client.
- Native full suite on Simulator: **6 unit tests + 6 UI tests passed**, including the real-provider live journey. Physical iPhone 17: the live evidence/edit/save/relaunch/reopen test passed over ngrok in approximately 48 seconds including UI actions. The app was relaunched in normal mode afterward; test data stayed in isolated storage.
- The saved-card reopen test found a real hit-target bug: blank areas inside the card did not activate it. A full-label content shape fixed it; the sample end-to-end test now covers reopening too. Live film artwork also no longer includes the sample image's baked-in label.
- Standards and spec reviews were run separately. All reported findings were corrected and rechecked: complete evidence retention, needs-input recovery, filter selection preservation, centralized category mapping and prevention of unsupported generated claims.
- A bounded review of physical-phone shortlist, evidence and reopened-plan captures concluded ship for this milestone. A zero-selection disabled-action visibility observation is retained for the later broad UI audit; see REVIEW-MILESTONE-2.md.
- Direct LAN access remained unavailable on the phone despite confirmed permissions, a current host address and a disabled Mac firewall. Ngrok HTTPS resolved the device connection without changing the discovery transport.

## Limits and next milestone

Some official websites reject direct server fetches. Those candidates are omitted with a visible warning. The first live run used the retrievable Quimby's page; it did not reuse old research as fresh evidence. Public-source identity checks do not establish willingness, future availability or improved attendance. Activities remain suggestions and introductions need operator review.

The catalogue contains two films, one cinema and three partner candidates. Film search filters this starter catalogue; it is not unrestricted Qloo search. The model may investigate public context but cannot expand the eligible catalogue in this milestone.

No automatic sending, partner contact or bookings occur. Browser UI, anonymous public sessions, shared durable run storage, cross-instance rate limiting, wider coverage, broader accessibility review and the six-brief contribution evaluation remain later work. The local backend is not a public production service.
