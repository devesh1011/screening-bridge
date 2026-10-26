# Screening Bridge — live discovery and hackathon delivery

Prepared 26 October 2026. Status: milestone 1 technical work complete; discovery-service testing boundary confirmed by the user. Repository and tracker: https://github.com/devesh1011/screening-bridge. Triage label: `ready-for-agent`. See MILESTONE-1.md for coverage findings and limits; later milestones remain pending.

## Problem Statement

An independent cinema programmer has already chosen a film and needs to identify nearby businesses or cultural organisations worth approaching for a collaboration. Research is fragmented, cultural compatibility is difficult to assess, and a plausible idea does not establish that a partner exists, is nearby, or is available.

Screening Bridge currently demonstrates this workflow through a native iPhone interface with fictional partners, simulated discovery and local plan persistence. It cannot yet research real partners, use Qloo evidence, or produce grounded collaboration proposals. Hackathon judges also need an externally hosted working demo they can access without a development environment.

## Solution

Complete the existing Screening Bridge experience: select a real film and cinema, set screening details and constraints, discover and verify local candidates, use Qloo to inform cultural ranking, and return up to three supported collaboration proposals. Each proposal explains the cultural signal, links to public evidence, distinguishes fact from suggestion, and lists what still needs confirmation. The programmer can revise the brief, choose partners, edit introductions, and save a plan without sending messages.

Preserve the approved native design. Add a compact hosted browser experience powered by the same discovery service, with clear sample/live labels and a complete research-to-saved-plan journey. Release the relevant source under an open-source license with reproducible setup instructions and a submission description that accurately explains Qloo's role.

This is a hackathon delivery scope. Merchant recruitment, ticket-sales experiments and proof of revenue uplift are not prerequisites.

## User Stories

1. As a cinema programmer, I want to find a film by title and confirm its year and director, so that recommendations use the correct film.
2. As a cinema programmer, I want to select a real cinema and confirm its address, so that local discovery starts from the correct location.
3. As a cinema programmer, I want to specify a screening date, local time and venue timezone, so that proposals refer to the intended event.
4. As a cinema programmer, I want to set a search radius and partner categories, so that the shortlist respects practical constraints.
5. As a cinema programmer, I want to describe the event format and exclusions in notes, so that the agent can tailor its research.
6. As a cinema programmer, I want ambiguous identities to require clarification, so that the app does not silently select a different film or venue.
7. As a cinema programmer, I want progress to reflect actual research stages, so that I understand what is happening.
8. As a cinema programmer, I want to cancel discovery without losing my brief, so that I can change direction safely.
9. As a cinema programmer, I want recommendations for real local partners, so that I can act on the shortlist.
10. As a cinema programmer, I want the partner's address, category and website to be checked, so that a same-name business elsewhere is not recommended.
11. As a cinema programmer, I want the agent to investigate relevant public programmes or activities, so that collaboration ideas have factual support.
12. As a cinema programmer, I want Qloo cultural evidence to influence the shortlist, so that the recommendations go beyond surface-level plot associations.
13. As a cinema programmer, I want to know when Qloo cannot match a partner, so that I can distinguish an unscored candidate from a graph-supported recommendation.
14. As a cinema programmer, I want proximity claims to identify their measurement method, so that an approximate distance is not mistaken for walking time.
15. As a cinema programmer, I want no more than three initial proposals, so that I can review the choices quickly.
16. As a cinema programmer, I want fewer than three results when evidence is weak, so that the agent does not fill the shortlist with invented options.
17. As a cinema programmer, I want every proposal to separate verified facts, cultural signals and suggested activities, so that I can assess its basis.
18. As a cinema programmer, I want clickable source links and research timestamps, so that I can inspect the supporting evidence.
19. As a cinema programmer, I want availability and willingness to collaborate marked as unconfirmed unless explicitly established, so that I do not mistake a suggestion for an agreement.
20. As a cinema programmer, I want to reject a candidate or refine my brief, so that a subsequent search incorporates my feedback.
21. As a cinema programmer, I want changes to film, venue or filters to invalidate outdated recommendations, so that my plan does not use results from a different brief.
22. As a cinema programmer, I want to select and deselect partners before building a plan, so that I control the final proposal.
23. As a cinema programmer, I want editable introduction drafts based on supported facts, so that I can prepare an appropriate approach.
24. As a cinema programmer, I want edits and copy feedback to work without sending a message, so that outreach remains under my control.
25. As a cinema programmer, I want saved plans to retain partner details, sources and my edits after relaunch, so that they do not depend on the latest search or a sample catalogue.
26. As a cinema programmer, I want existing sample plans to remain readable after the update, so that upgrading does not lose my work.
27. As a cinema programmer, I want errors and retries to preserve my brief and edits, so that temporary failures do not force me to start over.
28. As a cinema programmer, I want a clear distinction between sample data, recorded results and live research, so that I know what I am viewing.
29. As a cinema programmer using accessibility settings, I want readable text, accessible controls and appropriate motion, so that I can complete the same workflow.
30. As a hackathon judge, I want to open a hosted demo and run a supported example, so that I can evaluate the product without installing Xcode or an iPhone app.
31. As a hackathon judge, I want to inspect how Qloo changed a recommendation, so that I can understand the integration's contribution.
32. As a hackathon judge, I want limitations and unsupported locations to be explicit, so that a curated demo is not presented as universal coverage.
33. As a hackathon judge, I want a public repository, license and setup guide, so that I can inspect and reproduce the implementation.
34. As the project maintainer, I want provider secrets confined to the backend and bounded discovery costs, so that the public demo can remain available safely.
35. As the project maintainer, I want recorded functional checks and a fresh deployment smoke test, so that the submitted experience matches the project description.

## Implementation Decisions

These are proposed decisions for this delivery milestone, not claims that the functionality already exists.

1. **Keep Screening Bridge as the product.** Continue the SwiftUI app and its approved navigation, system controls, artwork and interaction direction. The café music idea is outside this spec. Existing Python experiments are reference material, not an already-completed backend.

2. **Prove the data path before building the full agent.** Start with the existing film, Perfect Days, and a real cinema in the existing Brooklyn demo area. The fictional Lantern Cinema and fictional partners remain sample-only. Resolve the film and venue, examine nearby candidate coverage, and produce one real, sourced recommendation. Test a second film against the same candidate pool to inspect sensitivity. If coverage is inadequate, document it and select a supported real demo area; do not substitute an unrelated chain or film silently. Initial supported examples will be explicitly listed.

3. **Use one application-level discovery boundary.** Introduce a discovery service consumed by the existing ScreeningStore and by the browser demo. A screening brief and constraints go in; actual progress, a terminal outcome, and structured candidate/evidence records come out. Film and venue resolution belong to the same service module. Keep provider-specific details behind this boundary. Preserve the existing LocalPlanRepository boundary for storage.

4. **Keep the backend small.** Extend the project's Python ecosystem with a dedicated Screening Bridge service, schema validation and a thin HTTPS interface. Reuse suitable HTTP, validation and OpenAI dependencies; isolate earlier merchandise experiments. Use one bounded agent loop rather than a multi-agent framework. Select the hosting provider during implementation based on existing access and the required request duration; no new paid plan is assumed.

5. **Resolve inputs before discovery.** Live film search supplies selectable entities with title, year and director where available. Venue resolution supplies a verified name, address, coordinates and timezone. Ambiguity is a recoverable input state. A small set of verified starter examples may accelerate the demo, but the app must identify any deliberately limited coverage. The sample film artwork is not presented as an official poster, and generic artwork is used for other films when licensed imagery is unavailable.

6. **Use an explicit discovery contract.** Each request carries a schema version, client request ID, brief revision, confirmed identities, screening time and timezone, radius, allowed categories, exclusions and notes. Dates cross the boundary with explicit timezone information; distance uses one canonical unit internally. Events distinguish resolving, researching, ranking and preparing proposals. Terminal outcomes distinguish completed, no supported matches, needs input, unavailable and cancelled. A completed result can contain one to three candidates and explicit partial-coverage warnings.

7. **Bound request lifetime and prevent stale results.** Start with a streamed response and a configurable 90-second overall deadline, including bounded provider timeouts and retries. Measure this budget during the first live slice. Cancellation stops scheduling additional calls; any provider call already in flight may still finish, but its output cannot update a cancelled client request. Only the active request ID and brief revision may replace visible results. Reconnection or retry never silently starts duplicate paid work; expired work returns an explicit retry state. If the selected host cannot support this lifecycle, move to a small job/polling interface under the same discovery contract before deployment.

8. **Use OpenAI for bounded research and synthesis.** Use the Responses API with hosted web search and application-controlled Qloo tools. Keep the model configurable and verify model/tool access during implementation. The agent may search, examine sources, resolve candidates, request cultural ranking and revise proposals within configured call/token/time limits. Validate tool arguments and final results in server code. Require actual research results before calling a candidate verified. Official guidance supports this tool-call loop and source-bearing search. [Function calling](https://developers.openai.com/api/docs/guides/function-calling), [Web search](https://developers.openai.com/api/docs/guides/tools-web-search).

9. **Verify candidates with an evidence ledger.** Store canonical identity, category, address/coordinates with provenance, official website where found, public-source URLs, retrieval time, supported claims, conflicts and unresolved questions. Prefer first-party business and programme pages. A search snippet or model-written URL alone does not establish identity. Each displayed factual claim must map to a retrieved source record. Missing address or conflicting identity excludes a candidate from the verified shortlist. Availability for the proposed event remains unknown unless explicitly supported; normal opening hours do not establish event availability. Treat source content as evidence, never as instructions to the agent.

10. **Make Qloo's contribution traceable.** Resolve the film and candidate entities using returned identifiers and identity metadata. Use Qloo Insights to rank correctly matched eligible candidates under a consistent request context. Save the input identities, candidate mapping, retrieval time, returned rank and relevant score metadata in the evidence record. Qloo documents entity inputs and ranked recommendations; exact place filters and account support must be checked during the live coverage milestone. [Insights API](https://docs.qloo.com/docs/insights-api), [Location Insights](https://docs.qloo.com/docs/insights-with-location).

11. **Handle coverage honestly.** Direct film-to-place matches are the preferred minimum delivery path. Unmatched businesses have no direct Qloo score and cannot inherit one from a same-name brand or category. A future indirect connection through a verified artist, book or programme must be separately labelled and traced; it is not required for this deadline. During a Qloo outage, retain existing results with their timestamp and expose a retryable failure for new live discovery. Do not silently swap in sample content or an LLM-only result labelled as Qloo-backed.

12. **Keep cultural ranking separate from feasibility.** Deterministically enforce identity, radius, selected category and explicit exclusions before final recommendations. Recheck constraints after provider results rather than assuming all upstream filters combine as AND. Among eligible graph-covered candidates, use within-query Qloo ordering to inform the shortlist; the agent explains relevance and proposes activities without inventing numerical scores. A score is not a ticket-sales probability, proof of audience overlap at a specific venue, or confirmation of willingness. Scores are normalized per query and should not be compared across separate runs. [Filters](https://docs.qloo.com/docs/filters), [Interpreting affinity scores](https://docs.qloo.com/docs/interpreting-affinity-scores).

13. **Represent live partners and evidence as durable data.** Replace live-path sample lookups with serializable result snapshots containing stable partner identifiers, identity details, evidence, ranking provenance, proposed activity, unresolved questions and editable introductions. Persist snapshots with the draft and saved plan, together with data mode, schema version, brief revision and research timestamp. Reopening a plan never requires network access. Migrate older ID-only archives by resolving their known sample IDs into explicitly labelled sample snapshots; preserve the original data if migration fails.

14. **Integrate throughout the native journey.** Update film selection, venue entry, discovery progress, filters, result cards, partner detail, evidence sheets, plan review and saved-plan navigation. Replace hard-coded introduction logic tied to sample partner IDs. Show approximate straight-line distance only when coordinates are supported; omit walking time unless backed by a routing service. Use generic category artwork for live businesses unless appropriate image rights and attribution exist. Store allowed categories in the brief rather than deriving them from the sample catalogue.

15. **Support revision without losing user work.** Editing the film, venue, radius, categories or notes creates a new brief revision and marks old recommendations stale. A wider radius or new category triggers new discovery. Preserve existing saved plans and user-written introduction text; do not overwrite edited copy when the agent reruns. Excluded candidates remain excluded for that revision. Selection and save are available only for valid results belonging to the current brief, or when explicitly reviewing an already-saved snapshot.

16. **Preserve sample mode and failure recovery.** Sample mode continues to work without credentials or a backend and stays visibly labelled. Live mode starts with real inputs and never uses fictional venue defaults. Distinguish empty results, missing coverage, invalid input, rate limits, timeout and connectivity errors in user-facing recovery. A local save failure leaves selections, evidence and edits intact. Reset commands are restricted to isolated test storage; the current debug reset implementation must be tightened before further device automation.

17. **Provide a usable hosted demo.** Serve a responsive browser client with the same input, discovery, evidence, selection, draft-editing and local-save capabilities needed for one complete judge journey. Use browser-local persistence with a clear device/browser limitation; cross-device sync is not part of this release. Provide verified starter examples, visible source links, meaningful failure states and a shareable HTTPS entry point. A landing page, API endpoint or prerecorded walkthrough alone does not meet this acceptance criterion. Native distribution is supplementary, not a dependency for judge access.

18. **Bound public-demo operation.** Keep Qloo and OpenAI credentials server-side. Apply input-size limits, session/IP throttling, global concurrency and spend/call caps, and a retryable capacity state. Use short-lived anonymous session scope so one visitor cannot access another's run; do not expose provider keys as client authentication. Log stage timings, provider status, request IDs and aggregate usage without secrets or unnecessary user notes. Document temporary retention, local plan storage and the lack of account sync.

19. **Review all native states after live integration.** Inspect the empty home, film search, cinema/details, research, unselected and selected results, filters, partner details, evidence, plan review, introduction editing, saving, save success, populated home, reopened plan, no matches, search failure, save failure and preferences. Add ambiguous identity, missing coverage, partial results and stale-result states introduced by the integration. Use the connected iPhone when available, rediscovering it rather than assuming connection. Cover light/dark appearance, large accessibility text, VoiceOver flow, Reduce Motion, keyboard/sheet behaviour and optional haptics. Store the review and captures locally.

20. **Publish a focused project package.** Prepare a public source repository containing the native app, backend, browser demo, tests, setup instructions and synthetic fixtures. Use MIT as the proposed license for original project code, keeping third-party notices and artwork provenance distinct. Exclude credentials, device build products, signing identifiers, personal captures and private research outputs. Do not publish raw provider datasets without checking redistribution terms. Prepare the description around the user problem, agent workflow, Qloo inputs and outputs, traceable example, architecture, limitations and live URL. Tracker destination and repository ownership must be established before publication.

## Testing Decisions

1. **Primary testing boundary, confirmed by the user:** exercise the discovery service through its public input/output contract. Good tests assert visible results, supported claims, constraint compliance, terminal outcomes and cancellation behaviour. They do not lock in prompt wording, private helper structure or an exact number/order of internal tool calls.
2. **Backend behaviour:** use controlled Qloo/web/OpenAI responses at external I/O boundaries while running real application validation and orchestration. Cover a supported shortlist, ambiguous film, same-name wrong-location venue, out-of-radius candidate, unsupported category, explicit exclusion, duplicate candidate, missing entity coverage, source conflict, unsupported claim, malformed output, provider timeout and rate limit. Inject hostile webpage instructions and ensure they do not change tool permissions or leak secrets. Add small provider parsing tests only where the service tests cannot diagnose a meaningful contract risk.
3. **Client behaviour:** inject a deterministic implementation of the discovery boundary into ScreeningStore and the browser client. Test actual progress and error rendering, cancellation, older responses arriving after a revision, repeat taps, source links, selection, revision and save/reopen. Provider credentials and live network access are not prerequisites for UI tests.
4. **Existing persistence boundary:** extend LocalPlanRepositoryTests for live result snapshots, evidence and edited introductions surviving reload; older sample archive migration; corrupt-data preservation; failed-save retry without duplicates; and ensuring test resets cannot erase normal app data. Retain the existing temporary-directory isolation and existing user-visible UI flow tests as prior art.
5. **Live smoke tests:** separately run a small documented set against real provider accounts and the deployed backend. Record identity coverage, source traceability, constraint checks, latency and provider usage. Live tests are opt-in rather than a flaky dependency for routine tests. At least one complete native run and one fresh-browser run must reach a reopened saved plan using live data.
6. **Qloo contribution evaluation:** use six labelled screening briefs over supported films/venues, with a frozen candidate pool and factual evidence for each comparison. Compare equally capable Qloo-assisted and no-Qloo runs using the same model, constraints and budgets. Include a mismatched-film signal control. Report identity/constraint errors, unsupported claims, evidence coverage, shortlist changes, latency and qualitative actionability under a written rubric. Qloo's score is not the sole quality metric. Changed output demonstrates influence, not superiority; no ticket-sales or commercial uplift claim follows from this evaluation.
7. **Visual and accessibility review:** use the full state matrix in the implementation decisions, with evidence of inspected states and defects fixed. Existing records of four unit tests and five UI tests passing on 23 October are baseline evidence only; rerun the affected suite after implementation. Confirm normal-mode launch after automation and keep personal device data intact.
8. **Release acceptance:** the public HTTPS demo works in a fresh browser; core tests pass; the native flow passes on an available target; the public repository can be set up from its instructions; a license and asset notices are present; no secret/device artifacts are included; all referenced demo/source links work; the submission description matches observed behaviour. Missing provider credentials, unsupported coverage or an inaccessible demo prevents claiming live delivery complete.

## Out of Scope

- The store/café music-playlist application or a new product pivot.
- Automatic email, social messages, partner outreach, bookings, payments or commitments.
- Ticket attribution, attendance prediction, revenue guarantees, merchant recruitment or field experiments.
- A worldwide coverage promise or indirect cultural-proxy scoring as a required fallback.
- Full CRM functionality, user accounts, team workspaces, cross-device synchronization or a production-scale job platform.
- App Store approval as a prerequisite for the hackathon demo.
- A full redesign, new imagery campaign or feature parity beyond the core browser judge journey.
- Republishing unrelated research archives, device artifacts or provider data dumps.

## Further Notes

### Delivery order and exit criteria

The dates below are working targets in IST, not a claim that implementation or provider access is already verified. The deadline recorded in the project's instructions is **31 October 2026, 09:15 IST**. Recheck the official submission requirements during release preparation. Target a completed submission package by **30 October, 18:00 IST** to leave recovery time.

| Milestone | Target | Deliverable and exit criterion |
| --- | --- | --- |
| 1. Coverage and contract — complete | 26 October | Resolved both films, Nitehawk Williamsburg and eight candidate identities. Three candidates returned scores for both films; order was unchanged. Sourced proposal, executable contract and tests delivered. Public repository and tracker established. See MILESTONE-1.md. |
| 2. First live journey | 27 October | Bounded backend research/ranking/synthesis connected to the iPhone flow; a real proposal can be selected, edited, saved and reopened with its evidence. Deploy a minimal backend smoke endpoint early to expose hosting constraints. |
| 3. Reliability and hosted demo | 28 October | Archive migration, cancellation/revision handling and provider failure recovery pass; the browser journey uses the same service and works at a public HTTPS URL. |
| 4. Evidence and visual review | 29 October | Complete the six-brief comparison, native state review, accessibility checks and fresh-browser smoke test. Fix blocking defects and document limits. |
| 5. Publication and submission package | 30 October, 18:00 IST | Public focused repository, license/notices, reproducible README, working demo, verified links and final project description. Complete the authorized submission process or identify any account-only action explicitly. |
| Recovery buffer | Until 31 October, 09:15 IST | Fix submission-blocking issues and verify final access; add no new product scope. |

If time compresses, reduce supported starter examples and optional presentation polish. Preserve a real Qloo-backed journey, evidence accuracy, saved-plan integrity, accessible judge entry point, license and submission materials. Unsupported extra cities and indirect scoring are the first cuts.

### Definition of done

A judge can open the hosted demo, choose a supported real film and cinema, receive up to three traceable live recommendations, inspect Qloo and public-source evidence, edit an introduction, save a plan and reopen it. The native app can complete the same core journey. Unsupported inputs and provider failures are honest and recoverable. The public source, license, setup guide and submission description are accessible and consistent with that behaviour.

### Current dependencies and publication status

- The user authorized repository creation. The project now uses https://github.com/devesh1011/screening-bridge and its GitHub Issues tracker, with the `ready-for-agent` label configured.
- The user confirmed the discovery-service testing boundary, deterministic UI substitute and extension of the existing local-save tests on 26 October 2026.
- Live Qloo credentials and the tested lookup/ranking endpoints were verified during milestone 1. OpenAI access, account-wide quotas, hosting access and current device connection remain unchecked. No secret values are stored in the public source.
- Existing design and product documents remain the authority for the approved native visual direction. This spec extends the sample-only milestone to live discovery and release delivery.
- Milestone 1 adds the executable contract and bounded Qloo probe. OpenAI orchestration, native live integration, deployment and Devpost submission remain pending.
