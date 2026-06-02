# Problem 237: Phase 3a — `wr-itil-plugin-maturity-populate` writes `plugin.json` `maturity:` field from Phase 2 NDJSON

**Status**: Verification Pending
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Phase 3a population script for P087 plugin maturity rollout. `wr-itil-plugin-maturity-populate` writes the `plugin.json` `maturity:` field per surface and per plugin root from Phase 2 NDJSON output (`wr-itil-skill-invocations` + `wr-itil-plugin-exercise-index`). Applies ADR-053 §promotion criteria + §Bootstrapping clause to map NDJSON evidence → band designation. Idempotent — re-running with unchanged signals produces no diff.

ADR-044 silent-framework carve-out applies (Cat 4): no `AskUserQuestion` per band recompute. Carve-out is scope-limited per ADR-063 — does NOT cover author-declared Deprecated band assignment, `supersededBy:` pointer authoring, or Phase 4+ threshold tuning (those remain AskUserQuestion-eligible per ADR-013 Rule 1).

ADR-049 shim grammar: ships as `packages/itil/bin/wr-itil-plugin-maturity-populate` → `packages/itil/scripts/plugin-maturity-populate.sh` (canonical body). ADR-052 behavioural bats coverage: synthetic NDJSON + synthetic `plugin.json` fixture → assert resulting `maturity:` field shape matches the ADR-063 schema (rich record per-surface + string rollup; `schema_version: "1.0"`); idempotency fixture asserts re-run produces no diff.

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
- [ ] Author `packages/itil/scripts/plugin-maturity-populate.sh` canonical body — reads two Phase 2 NDJSON streams; applies ADR-053 §promotion criteria + §Bootstrapping clause; writes `plugin.json` `maturity:` field per surface + per plugin root.
- [ ] Author `packages/itil/bin/wr-itil-plugin-maturity-populate` shim per ADR-049 grammar.
- [ ] Author bats fixtures per ADR-052: synthetic NDJSON + synthetic `plugin.json`; idempotency fixture; bootstrapping-window vs steady-state fixture (test date past 2026-06-06 sunset); negative-presence behavioural assertion that script does NOT invoke `AskUserQuestion` per band recompute (ADR-044 carve-out).
- [ ] Verify ordering invariant: Phase 3a MUST land before Phase 3b (P238) — 3b renderer + drift detector requires populated canonical fields.

## Dependencies

- **Blocks**: P238 (Phase 3b renderer + drift detector — needs canonical fields to render against)
- **Blocked by**: (none — Phase 2a/b scripts already shipped)
- **Composes with**: P087 (parent), ADR-053 (taxonomy contract), ADR-058 (Phase 2 NDJSON source), ADR-063 (Phase 3 presentation-layer contract)

## Related

- P087 — parent: no maturity / battle-hardening signal on plugins, skills, agents, or hooks
- ADR-053 — Phase 1 taxonomy + Bootstrapping clause (applied by this script)
- ADR-058 — Phase 2 measurement scripts (NDJSON source for this script)
- ADR-063 — Phase 3 presentation-layer contract (this script's contract)
- ADR-044 — silent-framework carve-out scope (band recomputation only)
- ADR-049 — bin shim grammar
- ADR-052 — behavioural bats
- P238 — Phase 3b renderer + drift detector (blocked by this ticket)
- P239 — Phase 3c bats doc-lint per plugin
- P240 — Phase 3d JTBD outcome amendments

## Fix Released

Phase 3a population script shipped 2026-05-17 in `/wr-itil:work-problems` AFK orchestrator iter 9 (session 4), commit `b840a7a feat(itil): ship Phase 3a plugin maturity populate script (P087, P237)`. Released across `@windyroad/itil@0.31.x` cohort (Phase 2a + 2b + 3a atomic-cohort graduation per user direction, commit `287e4c6`).

Fold-fix Open → Verification Pending per ADR-022 P143 amendment — the script's contract is documented inline (canonical body, ADR-049 shim, 17 behavioural bats covering ADR-063 §Confirmation criteria 1-3 plus schema-shape / rollup worst-case / hook null-sentinel / Deprecated-overlay preservation / fail-safe missing-input / no-network-primitive). Smoke test against live monorepo confirmed 11 plugins × 121 surfaces written; idempotency confirmed via pinned `--now`; populated values reverted from commit per strict architect §E scope (retroactive mechanical rollout composes with Phase 3b per P087 line 133).

Awaiting user verification — next adopter session that runs `wr-itil-plugin-maturity-populate` from a marketplace-installed cache against a Phase 2 NDJSON pair confirms script behaves per ADR-063 contract. P237 was tracked separately from P087's Phase 3a `[x]` Investigation Task to surface the script-deliverable as a discrete WSJF-ranked entity; both representations stay in sync per ADR-014 governance.

Recovery path: `/wr-itil:transition-problem 237 known-error` after reverting the script commits.
