# Problem 017: `create-adr` skill does not flag or split multi-decision inputs

**Status**: Verification Pending
**Reported**: 2026-04-16
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M
**WSJF**: 4.5 — (9 × 2.0) / 2 → now known-error
**Type**: technical

## Description

When the user asks `/wr-architect:create-adr` to record an architectural decision whose description actually contains multiple distinct decisions, the skill produces a single conflated ADR instead of splitting it or flagging the issue. The skill's intake does no decision-boundary analysis.

This is the same failure mode as P016 (`manage-problem` conflating multi-concern tickets) — different skill, identical pattern. ADRs are a core governance artefact; a single ADR covering two unrelated decisions damages auditability, defeats status transitions (one decision may land while the other is still proposed), and makes it hard to reference the decision from downstream artefacts.

## Symptoms

- ADRs in `docs/decisions/` that weave together two or more unrelated decisions under one ID.
- Status transitions stall when one half of the ADR is accepted and the other is not — the file cannot move from `.proposed.md` to `.accepted.md` cleanly.
- Cross-references from problems, JTBDs, and code comments become ambiguous ("see ADR-009" — which part?).
- The "Consequences" and "Alternatives" sections bloat trying to cover two decision spaces at once.
- No prompt in the skill asks "does this description contain multiple distinct decisions?"

## Workaround

Rely on the user to spot the conflation and request a split after the fact. Same expensive rework pattern as P016.

## Impact Assessment

- **Who is affected**:
  - Tech-lead persona (governance + auditability) — ADRs are the primary audit artefact; conflation weakens the trail.
  - Plugin-developer persona (JTBD-101 Extend the Suite) — inconsistent ADR scoping makes the "clear patterns, not reverse-engineering" outcome harder to meet.
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — downstream skills that reference ADRs get garbled signals.
- **Frequency**: Any session where the user describes an architectural question in a paragraph spanning more than one decision surface. Common during retros or when capturing multiple learnings at once.
- **Severity**: Medium. The skill still works; the artefacts are just wrong-shaped and require rework.
- **Analytics**: Observed anecdotally this session. User reported: "the create-adr has a similar issue where it groups multiple decisions that should be separate ADRs."

## Root Cause Analysis

`create-adr` (`packages/architect/skills/create-adr/SKILL.md`) gathers context and writes a single file. It has no decision-boundary-analysis step. Contributing factors mirror P016:

1. **No boundary heuristic.** No prompt asks "list the distinct decisions; if >1, propose a split."
2. **Single-file output assumption.** The skill writes exactly one `.proposed.md`. Emitting `NNN` + `NNN+1` is not contemplated.
3. **No cross-skill pattern.** P016 identifies the same gap in `manage-problem`. Fixing them independently would duplicate logic; a shared "concern-splitting" pattern would be better but is not yet designed.

### Investigation Tasks

- [x] Decide whether the fix is a per-skill step or a shared helper — chose per-skill (same as P016); shared abstraction deferred until a second data point confirms the pattern
- [x] Design the decision-boundary heuristic — chose Option (a): LLM self-check counting distinct decisions; if each could be independently accepted/rejected/superseded, they are distinct
- [x] Decide automatic vs AskUserQuestion-gated split — gated by AskUserQuestion per ADR-013 Rule 1, with auto-split fallback for non-interactive mode per ADR-013 Rule 6
- [x] Update `packages/architect/skills/create-adr/SKILL.md` with the new step — added as step 2b between gather-context and determine-sequence; scoped to new ADR creation only, not supersession
- [x] Add a test case — `packages/architect/skills/create-adr/test/create-adr-decision-boundary.bats` (4 structural tests, all GREEN)

### Fix Strategy

LLM self-check after Step 2 (gather context), before Step 3 (determine sequence/filename). Self-check counts distinct decisions. Single decision → proceed to step 3. Multiple decisions → `AskUserQuestion` with options: "Split into separate ADRs" or "Keep as single ADR." Non-interactive fallback: auto-split with consecutive IDs.

## Fix Released

Implemented in `packages/architect/skills/create-adr/SKILL.md` (2026-04-17):
- Added Step 2b (decision-boundary analysis) between gather-context and determine-sequence
- LLM self-check counting distinct decisions; AskUserQuestion for split decision per ADR-013
- Auto-split fallback for non-interactive mode per ADR-013 Rule 6
- Scoped to new ADR creation only (not supersession handling)
- Structural test `create-adr-decision-boundary.bats` (4 tests, all GREEN)

Awaiting user verification that new ADR creation offers a split when multi-decision inputs are provided.

## Related

- Sibling: `docs/problems/016-manage-problem-should-split-multi-concern-tickets.open.md` — same failure mode in a different skill
- Related tension: `docs/problems/014-aside-capture-for-problems.open.md` — split friction vs capture friction
- `packages/architect/skills/create-adr/SKILL.md` — target for the fix
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
- Tech-lead persona: `docs/jtbd/tech-lead/persona.md`
