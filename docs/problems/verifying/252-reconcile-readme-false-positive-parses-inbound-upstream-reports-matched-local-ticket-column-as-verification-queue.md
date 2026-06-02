# Problem 252: reconcile-readme false-positive parses Inbound Upstream Reports `Matched local ticket` column as Verification Queue

**Status**: Verification Pending
**Reported**: 2026-05-17
**Fix Released**: @windyroad/itil@0.35.3 — fix landed 2026-05-17 commit `52a50e9` "fix(itil): scope reconcile-readme VQ slice to terminate at Inbound Upstream Reports (closes P252)"; consumed in version-packages commit `55dde23` 2026-05-18; merged via PR #148 (`d450683`); cache now at `@windyroad/itil@0.35.3` (released session 7 loop-end Step 6.5 drain 2026-05-18). The fix added `INBOUND_START` to the section-boundary scan and updated `VQ_END` / `WSJF_END` sentinel cascade so VQ extraction terminates at the Inbound Upstream Reports section per ADR-062 / RFC-004. Transition Open → Verification Pending per ADR-022 P143 fold-fix amendment (changeset removal in `55dde23` IS the canonical fix-shipped signal). Sibling P264 captured 2026-05-18 was a duplicate (the cached 0.32.1 script still had the bug at session 7 start); closed in this iter referencing P252 as authoritative.
**Priority**: 9 (Med-High) — Impact: 3 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**RFCs**: []

## Description

`wr-itil-reconcile-readme docs/problems` produces 31 false-positive `STALE verification-queue: actual=open` entries for tickets P198-P228 every time it runs. The script's parser interprets the `Matched local ticket` column of the Inbound Upstream Reports table (`## Inbound Upstream Reports` section) as if it were a Verification Queue row. The cited P-IDs are actually Open dev-work tickets manually-curated as upstream-report mirrors per ADR-062 — they are NOT in `docs/problems/verifying/` and never claim Verifying status anywhere in the README.

Observed friction this session (2026-05-17 work-problems orchestrator main turn):

- **P082 narrative-only short-circuit broken**: P230 short-circuit requires `reconcile-readme.sh` exit 0 to fire; the false-positives produce exit 1, blocking the otherwise-clean narrative-only edit from committing.
- **P251 commit attempt blocked**: same false-positives + the classifier's HALT_ROUTE_RECONCILE verdict suggested running `/wr-itil:reconcile-readme` to "fix" non-drift, which would have destructively rewritten the README.
- **Forced workaround**: capture-problem deferred-README-refresh contract had to be manually overridden — P251 + P082 + README + README-history bundled into one commit (instead of two clean commits per contract) so the README staging satisfied P165.

The script's reverse-trace logic appears to scan `| P<NNN> |` patterns across the README without section-anchor awareness, so the Inbound Upstream Reports `Matched local ticket` column rows (which have shape `| #NN | ... | P<NNN> |`) are picked up as Verification Queue candidates.

## Symptoms

(deferred to investigation)

Observed signal:

- `wr-itil-reconcile-readme docs/problems` exit 1 with 31 `STALE verification-queue: actual=open` entries for P198-P228 immediately after a clean `5553cc4` preflight commit that populated the Inbound Upstream Reports table.
- The cited IDs are at lines 79-109 of docs/problems/README.md (WSJF Rankings table) AND at lines 196-230 (Inbound Upstream Reports table as `Matched local ticket` cross-refs) — the script appears to mis-attribute the second set to the Verification Queue section.
- `wr-itil-classify-readme-drift` returns HALT_ROUTE_RECONCILE because the cited IDs are not staged renames — but the cited IDs are NOT drift at all.

## Workaround

(deferred to investigation)

Possible interim workarounds (to validate):

- When orchestrating commits that include problem-ticket changes, manually verify whether reconcile-readme drift output cites IDs that appear in the Inbound Upstream Reports section; if so, the drift is false-positive and can be safely ignored.
- Disable Step 0 README reconciliation preflight in `/wr-itil:work-problems` SKILL.md until this bug is fixed (too aggressive — masks real drift).
- Use BYPASS_README_REFRESH_GATE=1 in `.claude/settings.json` for the duration of the workaround (too broad — affects all gate firings).

## Impact Assessment

- **Who is affected**: any session that runs `/wr-itil:work-problems`, `/wr-itil:manage-problem`, `/wr-itil:capture-problem`, `/wr-itil:review-problems` Step 0 preflight after a session that populated the Inbound Upstream Reports table (this is now most sessions since RFC-004 / P079 inbound-discovery shipped).
- **Frequency**: very high — the Inbound Upstream Reports table is populated by the inbound-discovery pipeline; once populated, this false-positive fires on every reconcile-readme invocation until the script is fixed.
- **Severity**: Med-High. Blocks the P230 narrative-only short-circuit (P165 hook depends on it) AND triggers Step 0 HALT_ROUTE_RECONCILE recovery routing — both are load-bearing for routine doc commits.
- **Analytics**: this session — 3 friction events directly attributable to the false-positive (P082 commit blocked, P251 commit blocked, P251+P082 bundling workaround applied).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Read `packages/itil/scripts/reconcile-readme.sh` to identify the parser logic. Likely candidates: the verification-queue parser regex matches `| P<NNN> |` patterns without scoping to the `## Verification Queue` section header.
- [ ] Fix the parser to anchor on section headers (`## Verification Queue`, `## Inbound Upstream Reports`, etc.) so each section's rows are categorised correctly.
- [ ] Update `packages/itil/scripts/test/reconcile-readme.bats` fixture to include an Inbound Upstream Reports table with `Matched local ticket` cross-refs; assert reconcile-readme correctly ignores those rows.
- [ ] Re-run reconcile-readme against the current `docs/problems/README.md` post-fix and confirm exit 0 with no drift.
- [ ] Investigate whether the classifier `wr-itil-classify-readme-drift` needs a sibling fix to recognise Inbound-table rows.

## Dependencies

- **Blocks**: (none directly — but composes with workflow surfaces above; impacts every commit that includes problem-ticket changes)
- **Blocked by**: (none)
- **Composes with**: [[P118]] (README reconciliation contract parent), [[P149]] (drift classification carve-out — orthogonal classifier), [[P165]] (README-refresh discipline hook — depends on reconcile-readme exit 0 for narrative-only short-circuit)

## Related

- **P118** (`docs/problems/closed/118-readme-reconciliation-contract.md` or similar) — parent README reconciliation contract that this script implements.
- **P165** (`docs/problems/verifying/165-...md`) — README-refresh discipline hook that depends on reconcile-readme exit 0 for its P230 narrative-only short-circuit.
- **ADR-062** (`docs/decisions/062-...accepted.md`) — Inbound Upstream Reports pipeline that populates the `Matched local ticket` column the script mis-parses.
- **RFC-004** (`docs/rfcs/RFC-004-...verifying.md`) — P079 inbound-upstream-report discovery + assessment pipeline; introduces the Inbound Upstream Reports table the script doesn't account for.
- (captured via /wr-retrospective:run-retro Step 4b Stage 1; expand at next investigation)

## Fix Strategy

**Kind**: improve
**Shape**: script
**Target file**: `packages/itil/scripts/reconcile-readme.sh` + sibling `classify-readme-drift.sh`
**Observed flaw**: Verification-queue parser regex matches `| P<NNN> |` patterns without scoping to the `## Verification Queue` section header; mis-attributes Inbound Upstream Reports `Matched local ticket` column rows as Verification Queue rows.
**Edit summary**: Add section-header awareness to the parser — only count rows that follow a `## Verification Queue` header until the next `##` header. Sibling fix in `classify-readme-drift.sh` if the classifier shares the same logic.
**Evidence**:
1. 2026-05-17 work-problems session — 3 friction events documented in this ticket's Description (P082 commit blocked, P251 commit blocked, P251+P082 bundling workaround applied).
2. `wr-itil-reconcile-readme docs/problems` output at session position post-`5553cc4` commit: 31 STALE entries on P198-P228, all of which are actually Open tickets with rows in WSJF Rankings + cross-refs in Inbound Upstream Reports.
3. `wr-itil-classify-readme-drift` HALT_ROUTE_RECONCILE verdict on the false-positive output — running the recommended `/wr-itil:reconcile-readme` recovery would have destructively rewritten the README.
