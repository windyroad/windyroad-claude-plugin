# Problem 239: Phase 3c — bats doc-lint per plugin asserts `maturity:` field shape, rollup invariant, rendered badge currency

**Status**: Verification Pending
**Reported**: 2026-05-17
**Verifying since**: 2026-05-18 (session 7 iter-5 — fix shipped this iter)
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)


## Description

Phase 3c of the P087 plugin maturity rollout per ADR-063 §Phase 3 sub-iter shape. For each `packages/<plugin>/`, ship a bats fixture asserting:

1. `plugin.json` carries a `maturity:` field on every top-level entry (skill / agent / hook / command / sub-skill) whose value matches the ADR-063 schema (`{schema_version: "1.0", band, computed_at, evidence: {invocations_30d, days_shipped, closed_tickets_window, breaking_change_age_days}}`).
2. The plugin root entry carries a rollup `maturity:` field whose shape is `{schema_version: "1.0", band}` (rollup omits the evidence record per ADR-063 §Decision Outcome).
3. The rollup band equals the worst-case among constituent surfaces per ADR-053 §granularity contract (Experimental ≻ Alpha ≻ Beta ≻ Stable; Deprecated as overlay axis).
4. The README contains the prose-woven rollup badge matching the canonical `plugin.json` field (during Bootstrapping window: compound form with invocations + window; post-sunset: band-only).
5. **Anti-pattern checks (negative-presence assertions)**: README does NOT contain a standalone `## Maturity` section heading; README does NOT contain a shields.io URL pattern (`img\.shields\.io/badge/maturity`); per-skill table cells do NOT contain the compound bootstrapping rendering (compound is rollup-only).

ADR-052 behavioural — tests read `plugin.json` and assert field shape behaviourally, NOT by structural-grep on README content for the badge text (which would be brittle to plugin-author restructuring of the value-framing prose). The README presence assertion is structural on the badge marker but not on the full prose context — the marker is a stable string the renderer always emits.

May ship alongside Phase 3b (P238) in a single commit, or as a follow-on commit per ADR-014 commit grain. Recommend alongside for fixture-coverage-and-implementation co-location.

Child of P087. Driver: ADR-063 Phase 3 sub-iter contract.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Author per-plugin bats fixture; ship as `packages/itil/scripts/test/plugin-maturity-doc-lint.bats` (single fixture with dynamic discovery, NOT one fixture per plugin — sidesteps the 11× duplication anti-pattern that would make future plugin additions require copy-paste edits). 11 tests covering A1 schema shape / A2 rollup shape / A3 worst-case invariant (live + synthetic) / A4 README badge marker / A5 anti-patterns + iter-10 P0 hotfix regression fence. (Shipped 2026-05-18 session 7 iter-5.)
- [x] Author anti-pattern negative-presence assertions (no standalone `## Maturity` section; no shields.io URL; no compound rendering in per-skill table cells). (Shipped 2026-05-18 session 7 iter-5 — tests 9 / 10 / 11.)
- [x] Verify rollup-equals-worst-case invariant assertion logic against a multi-band fixture (synthetic plugin with one Experimental skill + one Beta skill → rollup must be Experimental). (Shipped 2026-05-18 session 7 iter-5 — test 6 multi-band, test 7 all-Deprecated.)
- [x] Ensure bats fixtures discover plugins dynamically (no hard-coded list) so future plugin additions auto-inherit the doc-lint. (Shipped 2026-05-18 session 7 iter-5 — `plugins_with_maturity` helper walks `packages/*/.claude-plugin/plugin.json` at test runtime.)

## Dependencies

- **Blocks**: P087 closure path
- **Blocked by**: P237 (Phase 3a — needs canonical fields to assert against) AND P238 (Phase 3b — needs rendered badges to assert against)
- **Composes with**: ADR-063 (Phase 3 presentation contract), ADR-052 (behavioural test default), ADR-053 (granularity + rollup-worst-case contract)

## Related

- P087 — parent
- ADR-063 — Phase 3 presentation-layer contract (schema being asserted)
- ADR-053 — granularity contract (rollup-worst-case invariant)
- ADR-052 — behavioural bats default
- P237 — Phase 3a population script (blocks)
- P238 — Phase 3b renderer + drift detector (blocks)
- P240 — Phase 3d JTBD outcome amendments

## Fix Released

Phase 3c bats doc-lint shipped 2026-05-18 in `/wr-itil:work-problems` AFK orchestrator iter 5 (session 7). One changeset:

- `@windyroad/itil` patch — bats doc-lint fixture `packages/itil/scripts/test/plugin-maturity-doc-lint.bats` (11 tests covering ADR-063 §Phase 3c contract). Single fixture with dynamic discovery — no per-plugin duplication. Anchored regex on `*Maturity: <band>` followed by `.` or `(` (architect adjustment A2 tightening). Includes synthetic-fixture tests for the rollup-equals-worst-case invariant on a multi-band shape AND an all-Deprecated shape. Includes a regression fence for the iter-10 P0 hotfix incident class (top-level `skills:` / `agents:` / `hooks:` / `commands:` keys carrying maturity-shaped records — the Claude Code manifest validator rejection pattern).

Architect verdict YELLOW-with-4-adjustments (P087 iter-11 architect review 2026-05-18); all four folded in:

- **A1** Negative-presence regression fence for the iter-10 P0 hotfix incident class (test 4).
- **A2** Anchored regex `*Maturity: <band>[.(]` over raw substring (test 8).
- **A3** Header-comment scope-limit on compound-vs-bare form (in fixture preamble).
- **A4** Closed-enum `schema_version` ∈ `{"1.0", "2.0"}` per ADR-058 §Confirmation #8 precedent + iter-10 Amendment (tests 2 / 3).

JTBD verdict PASS (P087 iter-11 JTBD review 2026-05-18) — no new persona surface; contract-test infrastructure protects existing Phase 3d outcome amendments (JTBD-101 / JTBD-302 / JTBD-007 / JTBD-003) without new outcome bullets needed.

Bats coverage: 11/11 green against the live monorepo (`npx bats packages/itil/scripts/test/plugin-maturity-doc-lint.bats`). All 11 plugins (`architect` / `c4` / `connect` / `itil` / `jtbd` / `retrospective` / `risk-scorer` / `style-guide` / `tdd` / `voice-tone` / `wardley`) pass every assertion.

Awaiting user verification — verification ships when the doc-lint sits cleanly across the next two release cycles without firing on rendered-vs-canonical drift OR when a contributor introduces a fixture-driven regression (e.g. hand-edited `plugin.json` shape mismatch) and the lint catches it. Per ADR-022 the user may also signal verification by acknowledging this iter's bats green output.

Recovery path: `/wr-itil:transition-problem 239 known-error` after reverting the iter commit.
