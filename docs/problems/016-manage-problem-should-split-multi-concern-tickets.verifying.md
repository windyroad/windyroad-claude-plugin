# Problem 016: `manage-problem` skill does not flag or split multi-concern tickets

**Status**: Verification Pending
**Reported**: 2026-04-16
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M
**WSJF**: 4.5 — (9 × 2.0) / 4 → now known-error
**Type**: technical

## Description

When the user asks `/wr-itil:manage-problem` to capture a problem that actually contains multiple distinct concerns, the skill creates a single conflated ticket instead of splitting it or flagging the issue. The skill's intake does no concern-boundary analysis.

Observed this session: the user asked to create a problem covering (a) `.feature` file classifier gap and (b) vague Gherkin detection. The skill filed them as a single P013 even though:
- The two concerns have different root causes (file-extension match vs no test-content review mechanism at all)
- The architect explicitly flagged that (b) warrants its own ADR, which only makes sense if (b) is its own ticket
- Fix effort, priority, and the owning plugin could all differ

The user had to ask for the split after the fact ("the problem skill should of created this as two problems"). Rework.

## Symptoms

- Tickets filed by the skill conflate multiple concerns without warning.
- The architect's "needs its own ADR" guidance is silently swallowed into a single ticket's Related section.
- WSJF scoring becomes meaningless for conflated tickets — Impact/Likelihood/Effort can't be estimated for two different things at once.
- Rework: the user notices the conflation later and has to request a split, which requires rewriting two files and creating a third.
- The skill's duplicate-search step (intended to prevent two tickets from describing the same thing) has no mirror step for preventing one ticket from describing two things.

## Workaround

Rely on the user to notice and request a split after the fact. Expensive — the user is the one whose flow we're trying to preserve, and this is exactly the kind of housekeeping that should be automatable.

## Impact Assessment

- **Who is affected**:
  - Plugin-developer persona (JTBD-101 Extend the Suite) — the "clear patterns, not reverse-engineering" outcome is weakened when tickets in `docs/problems/` are inconsistently scoped
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — governance primitives (problem tickets) become less reliable when they don't respect concern boundaries
- **Frequency**: Any session where the user describes a problem in a paragraph covering multiple concerns. Common when retro-driven capture happens mid-task.
- **Severity**: Medium. The skill still works; the artefacts are just wrong-shaped and require rework.
- **Analytics**: Observed this session — P013 filed conflated, user asked for split, rework produced P013 + P015 + this P016.

## Root Cause Analysis

The `manage-problem` skill (`packages/itil/skills/manage-problem/SKILL.md`) has a duplicate-search step (step 2) but no concern-boundary-analysis step. After gathering the description in step 4, it proceeds straight to writing a single file in step 5.

Contributing factors:
1. **No concern-boundary heuristic.** The skill has no prompt asking "does this description contain multiple distinct root causes / fix paths / owning components?"
2. **No architect-signal channel.** When the skill delegates to the architect and the architect says "this needs its own ADR", there's no explicit rule that says "if the architect flags a standalone decision, that's a split signal."
3. **Single-file output assumption.** Step 5 writes exactly one file. The skill does not contemplate emitting `<NNN>a` and `<NNN>b` or consecutive IDs.

### Investigation Tasks

- [x] Design a concern-boundary-analysis step — chose Option (a): LLM self-check before step 5 counting distinct root causes; single concern proceeds, multi-concern triggers AskUserQuestion split prompt (per ADR-013)
- [x] Decide whether the split is automatic or gated by AskUserQuestion — gated by AskUserQuestion (per ADR-013 Rule 1) with auto-split fallback for non-interactive mode (per ADR-013 Rule 6)
- [x] Update `packages/itil/skills/manage-problem/SKILL.md` with the new step — added as step 4b between gather-info and write-file; scoped to new problem creation only
- [x] Add a test case exercising the split behaviour — `packages/itil/skills/manage-problem/test/manage-problem-concern-boundary.bats` (4 structural tests, all GREEN)
- [ ] Consider whether the same rule applies to `manage-incident` (probably yes — incidents can also conflate)

### Fix Strategy

LLM self-check after Step 4 (gather info), before Step 5 (write file). Self-check counts distinct root causes. Single concern → proceed to step 5. Multiple concerns → `AskUserQuestion` with options: "Split into separate problems" or "Keep as single problem." Non-interactive fallback: auto-split with consecutive IDs and cross-reference in Related sections.

## Fix Released

Implemented in `packages/itil/skills/manage-problem/SKILL.md` (2026-04-17):
- Added Step 4b (concern-boundary analysis) between gather-info and write-file
- LLM self-check counting distinct root causes; AskUserQuestion for split decision per ADR-013
- Auto-split fallback for non-interactive mode per ADR-013 Rule 6
- Structural test `manage-problem-concern-boundary.bats` (4 tests, all GREEN)

Awaiting user verification that new problem creation offers a split when multi-concern descriptions are provided.

## Related

- Trigger: conflated original P013, split this session into P013 + P015
- Sibling: P013 `docs/problems/013-tdd-feature-file-classifier.open.md`
- Sibling: P015 `docs/problems/015-tdd-vague-gherkin-detection.open.md`
- Related concern: P014 `docs/problems/014-aside-capture-for-problems.open.md` — tension between split-friction and capture-friction; both must be weighed together
- `packages/itil/skills/manage-problem/SKILL.md` — target for the fix
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
