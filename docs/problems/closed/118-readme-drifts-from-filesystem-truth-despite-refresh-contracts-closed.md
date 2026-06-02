# Problem 118: `docs/problems/README.md` drifts from filesystem truth across sessions despite P094 (refresh-on-create) and P062 (refresh-on-transition) both Closed

**Status**: Closed
**Reported**: 2026-04-24
**Fix Released**: 2026-04-25 (`@windyroad/itil` patch — pending release; commit `9c50d03`)
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M
**WSJF**: (9 × 1.0) / 2 = **4.5**

## Fix Released

**Released**: 2026-04-25 (AFK iter 5 of `/wr-itil:work-problems`; `@windyroad/itil` patch via `.changeset/wr-itil-p118-reconcile-readme.md`; contract-landing commit `9c50d03`).

**Fix shape**: Shape A + minimal Shape C per architect verdict. New diagnose-only script `packages/itil/scripts/reconcile-readme.sh` reads `docs/problems/<NNN>-*.<status>.md` files, parses the README's WSJF Rankings + Verification Queue + Closed tables, and emits one structured row per drift entry to stdout (≤150 bytes per ADR-038 progressive-disclosure budget). Exit codes: 0 = clean, 1 = drift, 2 = parse error.

New skill `/wr-itil:reconcile-readme` wraps the script with an agent-applied-edits pattern that preserves narrative content (the "Last reviewed" prose paragraph at the top, the per-row closure-via free text in the Closed section). Full README regeneration is forbidden — narrative is human-curated session memory.

Step 0 preflight invocations:
- `/wr-itil:manage-problem` Step 0 — invoke the script before parsing the request; halt-with-directive on drift; do NOT auto-apply.
- `/wr-itil:work-problems` Step 0 — invoke after the session-continuity pass; auto-apply via `/wr-itil:reconcile-readme` in AFK mode (per ADR-013 Rule 6) so the orchestrator's Step 3 ranking reads ground truth.
- `/wr-itil:transition-problem` deliberately does NOT invoke the script — P062 already covers transition-time refresh inside the same commit; redundant preflight there would pay the cost on every transition.

ADR-014 amended with "Reconciliation as preflight robustness layer" sub-rule (within existing 2026-10-16 reassessment window — no new ADR). ADR-022 Confirmation criterion 3 extended with the reconciliation invariant.

Tests: 16 behavioural script bats + 18 contract assertion bats for the skill. Full suite 969/969 green (was 935; +34 = +16 script + 18 contract). `package.json` test glob extended to include `packages/*/scripts/test/`.

**Self-bootstrap demonstration (this commit)**: ran the new script on the live `docs/problems/README.md`; detected 12 standing drift entries; applied the corrections in this commit:
- REMOVED from WSJF Rankings: P074 (closed on disk), P110 (verifying on disk).
- ADDED to WSJF Rankings: P073 (WSJF 1.5), P079 (WSJF 6.0), P080 (WSJF 6.0), P081 (WSJF 3.0), P082 (WSJF 6.0), P087 (WSJF 3.0), P088 (WSJF 3.0).
- ADDED to Verification Queue: P110 (released 2026-04-25 per linked ticket).
- REMOVED from Verification Queue: P056 (closed on disk), P075 (closed on disk).

Post-edit re-run of the script reports exit 0 (clean). Contract self-validates.

**Architect verdict**: APPROVED WITH CHANGES (Shape A + minimal Shape C; skill+script split; diagnose-only script + agent-applied-edits skill; manage-problem/work-problems Step 0 preflight + transition-problem excluded; ADR-014 amendment + ADR-022 small Confirmation extension; bats per ADR-005 + ADR-037).

**JTBD verdict**: PASS — JTBD-006 (Progress the Backlog While I'm Away) primary; JTBD-001 (Enforce Governance Without Slowing Down) secondary.

**Awaiting user verification**. Verification path: in any subsequent session, run `bash packages/itil/scripts/reconcile-readme.sh docs/problems` against the live README and confirm exit 0 (clean). If drift accumulates again, the cause is either (a) the new Step 0 preflight didn't fire, (b) the agent skipped the auto-apply branch in AFK mode, or (c) a new drift class outside the WSJF Rankings / Verification Queue / Closed scope — investigate and reopen if any of these hold.

## Description

`docs/problems/README.md` has accumulated significant drift from on-disk ticket state across multiple sessions, despite both P094 (manage-problem does not refresh README.md on ticket creation — Closed 2026-04-24) and P062 (manage-problem README refresh on transitions — Closed 2026-04-22) being in force. During the P108 AFK iteration on 2026-04-24 the README showed:

- **10 open tickets missing from the WSJF Rankings table**: P073, P079, P080, P081, P082, P083, P085, P087, P088, P089, P090. All have current `.open.md` files on disk with `**WSJF**:` lines populated.
- **2 tickets listed as Open in the WSJF Rankings table that are actually `.verifying.md` on disk**: P105 (WSJF 8.0) and P102 (WSJF 7.5). P062's refresh-on-transition contract should have moved them to the Verification Queue at release time.
- **Stale WSJF value for P108**: README showed 5.0, ticket showed 15.0 (moot on close, but indicative of re-rate-without-render).
- **Stale entries in the Verification Queue**: P056 and P075 appear but are not in `docs/problems/*.verifying.md` on disk — they were closed in prior sessions without removing their VQ rows.

The orchestrator of this iteration observed only a subset of these (P105, P108 stale WSJF, P110 missing) and handed the iteration a scope-cap escape hatch: "If the README-reconcile scope feels larger than expected, keep the P108 close minimal and open a follow-up ticket for the systemic stale-README class." That escape hatch fired — this ticket captures the systemic class.

## Symptoms

- New `.open.md` tickets are created (per P094 Closed contract) but do NOT always appear in the WSJF Rankings table of `docs/problems/README.md`.
- Status transitions to `.verifying.md` (per P062 Closed contract) do NOT always remove the ticket from the WSJF Rankings table.
- Status transitions to `.closed.md` do NOT always remove the ticket from the Verification Queue section.
- Drift accumulates silently across sessions — each session sees an already-drifted README and does not systematically reconcile it.
- The P094 / P062 closure rationales ("every manage-problem-class commit this session kept docs/problems/README.md in-sync", "refresh-on-transition contract held") were evidenced on a per-session basis but the README on-disk across sessions tells a different aggregate story.

## Impact Assessment

- **Who is affected**: every AFK orchestrator invocation (WSJF ranking is read from the README and drives ticket selection); every user who reads the backlog; every retro that consumes the README's Last-reviewed annotation.
- **Frequency**: accumulates on every session where a refresh is skipped. Observed on 2026-04-24 with ≥ 12 drift entries against ~70 lifecycle tickets.
- **Severity**: Moderate. WSJF ranking silently lies about what the top of the queue is. An AFK orchestrator selecting "highest WSJF actionable ticket" from the stale README may pick a ticket that has already been moved to `.verifying.md` — burning an iteration on a no-op.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit recent `docs(problems):` and `fix(...)` commits for manage-problem-class operations and check whether each also updated `docs/problems/README.md` — identify the commits where the refresh was skipped.
- [ ] Identify whether the skipped refreshes correlate with a specific invocation surface (direct `/wr-itil:manage-problem <NNN> <status>` vs the split `/wr-itil:transition-problem` vs folded-fix commits vs /wr-itil:work-problems subprocess iterations).
- [ ] Check whether Step 11 of manage-problem's "single-commit transaction — include refreshed README.md in stage list" is consistently executed across invocation surfaces, or whether the split-skill transition path (P093 fix; `/wr-itil:transition-problem` Step 7 inline block) has an inconsistent README-refresh step.
- [ ] Determine whether a periodic reconciliation step — e.g. every manage-problem invocation runs a quick `ls docs/problems/*.open.md | wc -l` vs README WSJF-row-count sanity check — would be a better robustness layer than per-operation refresh enforcement.
- [ ] Create a reproduction test (bats or similar) that creates N .open.md files, transitions M of them, closes K, and asserts the README reflects the exact filesystem state.

## Dependencies

- **Blocks**: (none — no downstream ticket hard-blocks on this robustness layer)
- **Blocked by**: (none)
- **Composes with**: P094 (refresh-on-create — Closed), P062 (refresh-on-transition — Closed). This ticket is a robustness / reconciliation layer on top of both rather than a supersession.

## Related

- **P094** (`docs/problems/094-manage-problem-does-not-refresh-readme-on-ticket-creation.verifying.md`) — Closed 2026-04-24. Refresh-on-create contract. Closure rationale cited "every manage-problem-class commit this session" — per-session evidence holds, but the aggregate multi-session state does not.
- **P062** (`docs/problems/062-manage-problem-readme-refresh-on-transitions.verifying.md`) — Closed. Refresh-on-transition contract.
- **P117** (`docs/problems/117-no-batch-transition-for-multiple-problem-tickets.open.md`) — composes: a batch-transition surface would reduce the number of opportunities for individual transition refreshes to be skipped.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — single-commit-transaction contract that pairs ticket edits with README refresh.
- **P074** (`docs/problems/074-run-retro-does-not-notice-pipeline-instability-and-record-problems.open.md`) — this ticket exists because P074's Step 2b pipeline-instability scan fired during the retro-on-exit of the P108 AFK iteration and detected the drift class (category 2: Skill-contract violations).
- Discovered 2026-04-24 during `/wr-itil:work-problems` AFK iteration closing P108; reconcile effort capped to the orchestrator-observed subset per escape hatch.
