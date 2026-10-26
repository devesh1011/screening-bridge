# Milestone 2 review

Review base: `cd901aa` (preserved native sample app and milestone-1 backend). Initial implementation commit: `39ed8e1`. Separate read-only reviewers assessed standards and spec coverage, then rechecked the corrections in the working tree.

## Standards

- **Full snapshot retention — resolved.** The native draft now retains the original completed wire JSON, including coordinates, address, claim/source associations and omitted IDs, alongside its presentation model. Reload tests check these fields.
- **Identity recovery — resolved.** Missing or ambiguous selected film/venue matches produce nonretryable `needs_input`; native recovery returns to the appropriate input screen.
- **Selections after widening filters — resolved.** Live selections remain until refreshed results arrive, then intersect with returned eligible IDs. The flow test covers this.
- **Duplicated category mapping — resolved (maintainability judgment).** `PartnerCategory` centralizes API identifiers, labels and symbols.

Three material standards/correctness findings and one maintainability finding were raised; all four were rechecked as resolved. No unresolved finding remains within this review's scope.

## Spec

- **Unsupported claims in generated prose — resolved.** A regression test first demonstrated that a structurally valid model response could invent confirmed availability. Model output now permits only a partner ID and enumerated activity/focus; server-rendered wording is tentative and factual fields come from verified data. Official research citations are retained separately. The unsupported-claim test passes.
- **Incomplete evidence persistence — resolved.** The full wire payload is preserved and checked after reload, rather than relying only on flattened display strings.

Two material spec findings were raised and rechecked as resolved. Public browser/session/storage work remains explicitly milestone 3; it was not treated as a milestone-2 omission. No scope creep was found in the reviewed implementation.

## Runtime findings

- A saved-plan card failed to open when its blank label area was tapped. An explicit rectangular content shape fixed the hit target, and reopening was added to the sample end-to-end regression test.
- Direct phone-to-Mac LAN access failed despite confirmed settings. The phone's full live journey passed through ngrok using the existing SSE API. No Cloudflare dependency or buffered transport remains.

## Visual scope

The bounded review inspected actual iPhone screenshots of the live shortlist, evidence sheet and reopened plan. Evidence and reopened-plan states passed. A settled shortlist recapture resolved the footer overlap/blur concern. The disabled Build Plan action remains visually absent at zero selection, recorded as a nonblocking visibility observation for milestone 4; repeated physical tests confirmed selection and progression work. The reviewer disposition was **ship milestone 2** within this limited scope. The original native design contract remains the authority; no design-system rewrite is warranted. Broad all-screen, dark-mode and accessibility review remains milestone 4.
