# Problem 290: Harden ADR-052 to behavioural-only — remove the structural-test escape hatch entirely

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 9 (Med High) — Impact: 3 (Moderate — the documented-justification escape hatch lets wasteful structural tests keep shipping; the user's standing position is that structural tests are "not real tests"; removing the hatch raises the whole suite's test quality and stops the `structural-justified` verdict being a permanent parking spot) × Likelihood: 3 (Likely — every test-author decision + the 14 existing escape-hatch-reliant test files)
**Effort**: L — ADR-052 redesign (remove the escape hatches + the `structural-justified` verdict) + supersede ADR-005's Permitted Exception + P011 + convert/remove ~14 existing structural test files + resolve the not-yet-behaviourally-expressible-test tension (Layer B harness primitives)
**WSJF**: 9/4 = **2.25** (Open multiplier 1.0)

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (`/wr-architect:review-decisions` flow, 2026-05-25). When ADR-052 (Behavioural-tests-default for skill testing) was presented for human-oversight confirmation, the user declined to confirm it as-recorded and directed a hardening:

> User direction 2026-05-25 (drain): *"structural tests not permitted at all."*

ADR-052 currently chose **"Option 1 — behavioural-default with documented-justification escape hatches"**: structural tests are permitted when (a) the behavioural assertion isn't yet expressible under the framework AND (b) the author documents the harness gap with a linked ticket. The `review-test` agent emits a permitted `structural-justified` verdict, and two escape hatches exist (`WR_TDD_REVIEW_TEST=skip`; an in-file `tdd-review: structural-permitted (justification: …)` comment). The user wants the escape hatch **removed entirely** — behavioural is the ONLY permitted kind; structural tests are not allowed, period. This makes absolute the standing position behind P081 (structural tests are "wasteful and not real tests").

This is a **material amendment** to an extensively-built ADR (the whole `review-test` agent design is organised around the `structural-justified` classification + escape hatches), so it is its own unit of work. **ADR-052 is left unoversighted** (P283/ADR-066 marker withheld) until this rework lands and the hardened decision is re-confirmed — mirroring P287 (ADR-060) and P289 (solo-developer).

## Symptoms

(deferred to investigation)

- ADR-052 lines 51/63/69/125/142/184-185/201/220/227/257-259 all encode the escape-hatch / `structural-justified` / `structural-permitted` mechanism.
- **~14 existing test files** rely on the structural-permitted exception (`grep -rl structural-justified|Permitted Exception` across `packages/*/test/`).
- **ADR-005** carries a structural-test "Permitted Exception" (P011) that the hardened ADR-052 supersedes — note: ADR-005 was human-confirmed in the same drain batch, but its Permitted Exception sub-clause is now superseded by this hardening.
- The `review-test` agent (`packages/tdd/agents/review-test.md`) emits `structural-justified` as a permitted verdict — would need to become a non-permitted (failing/advisory-negative) verdict.

## Workaround

None — the escape hatch is the current policy; this ticket changes the policy.

## Root Cause Analysis

### Investigation Tasks

- [ ] **Resolve the load-bearing design tension**: ADR-052 defers "Layer B harness primitives" (Skill-tool interceptor, AskUserQuestion stub, filesystem sandbox, subagent-return stub) and uses `structural-justified` as the *interim* for skill-tests not yet behaviourally expressible. If structural is banned outright, those tests can't ship until Layer B exists. Decide: (a) block such tests until Layer B lands (prioritise Layer B), or (b) define a narrower carve-out that isn't "structural" (e.g. the hook-safety-construct bats targeting executable bash, which ADR-052 line 227 already treats as a different class). The user's directive is the end-state (no structural tests); the path needs design.
- [ ] Amend ADR-052: remove the documented-justification escape hatches + the `structural-justified` permitted verdict; behavioural-only.
- [ ] Supersede ADR-005's structural Permitted Exception + P011 (record the supersession).
- [ ] Update the `review-test` agent verdict vocabulary (drop `structural-justified` as permitted).
- [ ] Convert or remove the ~14 existing structural test files (behavioural rewrite where Layer B allows; otherwise gate on the Layer B decision above).
- [ ] Re-confirm hardened ADR-052 via `/wr-architect:review-decisions` → write `human-oversight: confirmed`.

## Dependencies

- **Blocks**: ADR-052 human-oversight confirmation (held until this rework lands).
- **Blocked by**: the Layer B harness-primitive question may gate the existing-test conversion (but the ADR amendment itself can proceed).
- **Composes with**: P081 (structural-tests-are-wasteful master), P012 (skill-testing-harness / Layer B primitives), ADR-052 (amendment target), ADR-005 + P011 (superseded Permitted Exception), `packages/tdd/agents/review-test.md` (verdict surface), P283/ADR-066 (the drain that surfaced this).

## Related

(captured during the P283/ADR-066 ADR-oversight drain, 2026-05-25)

- **P283** / **ADR-066** — the oversight-drain mechanism that surfaced this.
- **P287** (ADR-060 type-tag) + **P289** (solo-developer rename) — sibling drain-surfaced material amendments; same "withhold marker + capture rework" pattern.
- **P081** — structural-tests-are-wasteful master ticket (this hardens it into policy).
- **ADR-052** (`docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`) — amendment target.
- **ADR-005** + **P011** — the structural Permitted Exception this supersedes.
- `packages/tdd/agents/review-test.md` — the `review-test` verdict surface.
