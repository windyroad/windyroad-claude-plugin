---
status: proposed
rfc-id: confirm-substance-before-build-enforcement
reported: 2026-05-27
decision-makers: [Tom Howard]
problems: [P315]
adrs: [ADR-074, ADR-064, ADR-066, ADR-044, ADR-060]
jtbd: []
stories: []
---

# RFC-008: Confirm-substance-before-build enforcement (ADR-074 mechanical layer)

**Status**: proposed
**Reported**: 2026-05-27
**Problems**: P315
**ADRs**: ADR-074 (parent contract), ADR-064 + ADR-066 (amended), ADR-044 (lazy-count exclusion), ADR-060 I13 (the surface)
**JTBD**: (none)

## Summary

Build the mechanical enforcement for the ADR-074 "confirm-substance-before-build" contract. The design/contract layer is recorded and committed (ADR-074 + ADR-064 amend + ADR-066 carve-out, commit `fdb9eb9`); this RFC implements the runtime guard and the supporting test/metric surfaces so the contract is enforced, not merely documented.

## Driving problem trace

- **P315** — agent implements dependent work on a genuine ≥2-option decision before its substance is human-confirmed (surfaces only the meta/grain question), so load-bearing content rides unconfirmed until a post-hoc drain. ADR-074 records the fix contract; this RFC builds the enforcement P315's fix strategy names as the remaining implementation layer.

## Scope

Mechanical enforcement of ADR-074 across the surfaces the architect named and the user confirmed (Option A). Explicitly **NOT** a PreToolUse hook — the "is this dependent work on an unconfirmed decision?" judgment is semantic and a hook would over-fire (inverse-P078 / P132 guard).

In scope:
1. Sharpen the `wr-architect:agent` Needs-Direction verdict prompt to require naming the **substantive** choice, not a meta/grain framing question.
2. Add a propose-fix process guard at the ADR-060 I13 surface in `/wr-itil:manage-problem` (and the `/wr-itil:work-problems` orchestrator path): detect when fix work would build on a born-`proposed` decision whose substance is unconfirmed (no `human-oversight: confirmed` marker) and surface its substance via `AskUserQuestion` (interactive) or queue to `outstanding_questions` (AFK) before dependent work lands.
3. Add the ADR-044 lazy-AskUserQuestion-count **exclusion** for substance-confirm-before-build asks in `packages/retrospective/scripts/check-ask-hygiene.sh` (the ask is cat-1 direction-setting, not lazy).
4. Behavioural tests per ADR-052 for the testable surfaces (architect verdict prompt; hygiene-count exclusion). Skill-flow assertions for the guard are blocked on the P176 skill-invocation harness — recorded as deferred follow-up, structural-permitted per ADR-052 Surface 2 citing P176.

Out of scope: re-litigating the ADR-074 contract (decided); the P316 `rejected` drain-state (separate ticket).

## Tasks

- [x] **T5** — `packages/architect/scripts/is-decision-unconfirmed.sh` + bin shim `wr-architect-is-decision-unconfirmed` (ADR-049 PATH pattern — adopter-safe per P317; NOT repo-relative sourcing). Single-ADR predicate: exit 0 = unconfirmed (lacks `human-oversight: confirmed`, not superseded), 1 = confirmed/superseded, 2 = not found. Mirrors `detect-unoversighted.sh` frontmatter logic with an in-sync cross-check. **10 behavioural bats GREEN** (`test/is-decision-unconfirmed.bats`, incl. the detect-unoversighted sync guard). Sibling-script grain confirmed by architect (keeps the detector's always-exit-0 contract intact).
- [x] **T1** — `packages/architect/agents/agent.md` Needs-Direction verdict now requires naming the **substantive** choice, not a meta/grain framing question (ADR-064 amendment behaviour / ADR-074 surface 1). Structural-permitted bats added (`architect-needs-direction-verdict.bats`, P176 harness gap per ADR-052 Surface 2) — GREEN.
- [x] **T3** — `packages/itil/skills/manage-problem/SKILL.md` propose-fix guard at the ADR-060 I13 surface: collect decisions the fix builds on (Fix Strategy `ADR-NNN` + referenced RFC `adrs:`), run `wr-architect-is-decision-unconfirmed`, and on any unconfirmed decision surface its substance via `AskUserQuestion` (interactive) / queue to `outstanding_questions` (AFK) before building. Skill-flow behavioural test deferred (P176).
- [x] **T4** — `packages/itil/skills/work-problems/SKILL.md` orchestrator iter constraints: the inherited guard queues a `category: "direction"` entry + routes to `action: skipped` (`skip_reason_category: user-answerable`) rather than blocking/guessing; excluded from the lazy count. Skill-flow behavioural test deferred (P176).
- [x] **T2** — run-retro Step 2d rubric + `check-ask-hygiene.sh` header: substance-confirm-before-build asks are ADR-044 cat-1 (`direction`), excluded from the lazy count. Behavioural regression guard added to `check-ask-hygiene.bats` — GREEN.

**Implementation status (2026-05-27):** all five tasks landed; testable surfaces (T1/T2/T5) GREEN; T3/T4 skill-flow behavioural assertions deferred to the P176 skill-invocation harness (structural-permitted per ADR-052 Surface 2). Remaining: formal RFC lifecycle transition (proposed → in-progress → verifying) + release of the held changeset via `/wr-itil:manage-rfc`.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

- **P315** — driving problem.
- **ADR-074** — parent contract (confirm-substance-before-build); this RFC is its mechanical layer.
- **ADR-064 / ADR-066** — amended by the design layer; T1 implements the ADR-064 amendment's verdict-surface behaviour.
- **ADR-044** — T2 implements the lazy-count exclusion.
- **ADR-060 I13** — the propose-fix surface T3/T4 ride.
- **ADR-070/071** — every-fix-via-RFC; this RFC is the mandated vehicle for the P315 implementation.
- **P176** — skill-invocation harness limitation blocking the T3/T4 skill-flow behavioural tests.

(captured via /wr-itil:capture-rfc; Scope + Tasks populated at capture because the build proceeds immediately this session. Advance to accepted/in-progress + refresh docs/rfcs/README.md via /wr-itil:manage-rfc.)
