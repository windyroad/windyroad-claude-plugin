# Problem 149: `/wr-itil:manage-problem` Step 0 reconcile halt-on-drift directive doesn't distinguish uncommitted-rename-rooted drift (same-session pending) from committed cross-session drift — should refresh inline rather than halt for the former case

**Status**: Closed (verified 2026-05-05)
**Reported**: 2026-05-02
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Possible (2)
**Effort**: S — bounded SKILL.md amendment in two files (`manage-problem` Step 0, `work-problems` Step 0) + new `classify-readme-drift.sh` helper + bin shim (ADR-049) + behavioural bats covering both routing branches. Effort confirmed S on landing — `work-problem` (singular) has no Step 0 reconcile preflight (relies on cache freshness via review-problems), so the third file in the original estimate was not edited.
**WSJF**: (4 × 1.0) / 1 = **4.0**
**Type**: technical

## Description

`/wr-itil:manage-problem` Step 0 (and the symmetric Step 0 / Step 1 in `work-problems` and `work-problem`) runs `bash packages/itil/scripts/reconcile-readme.sh docs/problems` as a preflight; on exit 1 (drift detected) the SKILL.md contract halts the invocation and routes to `/wr-itil:reconcile-readme`. P118 introduced this preflight as a robustness layer ON TOP of the per-operation P094 (refresh-on-create) and P062 (refresh-on-transition) contracts to catch cross-session drift that those per-operation contracts cannot retroactively see.

The halt directive is correct for **committed cross-session drift** — a past session committed a ticket change while skipping the README staging step, leaving the next session reading a stale README. Halt + route to reconcile-readme is the only safe path because proceeding would re-encode the drift into the post-operation refresh and propagate the lie.

The halt directive is **wrong for uncommitted-rename-rooted drift** — when the current working tree carries an uncommitted ticket rename (or content edit) that hasn't yet had its README refresh applied. In this case:

- The drift is the EXPECTED intermediate state of the user's current session — a `git mv` happened, content edits happened, but the SKILL flow has not yet reached its commit step where P094 / P062 would refresh README.
- Halting and routing to `/wr-itil:reconcile-readme` produces a separate commit refreshing README, then the user resumes the original work, which then makes its own commit. Two commits for what should be one — directly violating ADR-014 single-commit grain ("the ticket change and its README refresh land in the same commit").
- The right action is "continue the flow inline; the standard P094 refresh at Step 5 / P062 refresh at Step 7 will pick up the README refresh in the same commit as the ticket work."

## Symptoms

- 2026-05-02 invoking `/wr-itil:work-problem P148`: Step 0 reconcile detected `DRIFT P148 wsjf-rankings: claims=open actual=verifying` + `MISSING P148 verification-queue: actual=verifying` exit 1.
- The drift was caused by an uncommitted prior-session AFK iter rename (`docs/problems/148-...open.md` → `.verifying.md` was on the working tree, ticket Status edits done, README untouched).
- Per the Step 0 contract literal reading, the agent should have halted and invoked `/wr-itil:reconcile-readme`. That would have committed the README refresh in a separate commit, then the agent would have proceeded to commit the rest of the P148 fix work — splitting one logical change across two commits.
- The agent interpreted Step 0 contextually (recognised the drift as uncommitted-rename-rooted) and proceeded with inline refresh — landing the README refresh in the same commit as the rename + content edit + new scripts + bats per ADR-014.
- The interpretation worked but is **not codified** — a more strict-following agent (or a future maintainer reading the contract) would split the commit.

## Workaround

Agent-side contextual interpretation of Step 0's halt directive: detect that drift is rooted in current-session uncommitted state via `git status --porcelain` showing a staged rename for the drifting ticket, and proceed inline rather than halting. This is fragile — it depends on the agent recognising the pattern, and contradicts the literal SKILL.md contract.

## Impact Assessment

- **Who is affected**: agents and users invoking `/wr-itil:manage-problem`, `/wr-itil:work-problems`, or `/wr-itil:work-problem` on a session where uncommitted prior-session work exists (e.g. AFK iter pending commit; user resumed session days later; cross-session work-in-progress).
- **Frequency**: edge case — most fix work commits in the same session. Hits when AFK iters defer commits or when session continuity gaps leave pending state. Today (P148) was the first observed instance; expect to recur.
- **Severity**: Low — both paths produce correct end state (no data loss, no audit-trail corruption). The halt path produces an extra commit and a worse audit trail (split commit). The inline path produces the correct ADR-014 single-commit grain.
- **Likelihood**: Possible — depends on AFK iter cadence and session continuity gaps.
- **Analytics**: 1 observation (today's P148 release).

## Root Cause Analysis

### Investigation Tasks

- [ ] Confirm the SKILL.md Step 0 halt directive doesn't have an existing carve-out for uncommitted state (it doesn't — verified by reading the contract today).
- [ ] Decide on the detection mechanism: `git status --porcelain | grep '^R' | grep docs/problems/` is one approach; alternatives include reading `git diff --cached --name-status` to spot staged renames vs unstaged renames.
- [ ] Decide whether the same carve-out applies to `/wr-itil:work-problems` Step 0 and `/wr-itil:work-problem` Step 1 (likely yes — symmetric path).
- [ ] Determine whether `/wr-itil:reconcile-readme` itself should detect uncommitted state and refuse to commit (defensive layer, optional).

### Preliminary hypothesis

The Step 0 halt directive was designed for the cross-session committed-drift case (P118's originating evidence). Uncommitted-rename-rooted drift wasn't named as a separate case because the per-operation refresh paths (P094 / P062) were assumed to fire BEFORE Step 0's preflight could detect a delta. But Step 0 fires at the START of the SKILL flow; P094 / P062 fire during/after Step 5 / Step 7. So Step 0 can legitimately observe drift that the in-progress flow will resolve.

The fix is a 2-3 line carve-out in the Step 0 routing logic: detect "drift caused by uncommitted ticket renames in current working tree" and treat as inline-refresh rather than halt.

## Fix Strategy

**Kind**: improve

**Shape**: skill (`packages/itil/skills/manage-problem/SKILL.md` + `packages/itil/skills/work-problems/SKILL.md` + `packages/itil/skills/work-problem/SKILL.md`)

**Target file**: `packages/itil/skills/manage-problem/SKILL.md` Step 0 (primary); symmetric carve-outs in work-problems Step 0 and work-problem Step 1.

**Observed flaw**: Step 0's halt-on-drift directive doesn't distinguish uncommitted-rename-rooted drift (current-session pending, will be resolved by P094 / P062 in the upcoming commit) from committed cross-session drift (must halt and reconcile separately).

**Edit summary**: amend Step 0's exit-1 routing to add a carve-out — when `git status --porcelain | awk '/^R/ && /docs\/problems\//'` matches AND the matched ticket appears in the reconcile-readme drift output, treat as inline-refresh case (continue the flow; standard P062 refresh at Step 7 / P094 at Step 5 will pick up the README in the same commit per ADR-014). Only halt-and-route to `/wr-itil:reconcile-readme` when drift is committed (no matching working-tree rename). Add a behavioural bats fixture covering both branches.

**Evidence**:
- 2026-05-02 P148 release session: working tree showed `RM docs/problems/148-...open.md -> docs/problems/148-...verifying.md` plus the renamed file's content edit; reconcile-readme.sh detected drift; agent contextually interpreted the situation and refreshed inline rather than halting; ADR-014 single-commit grain preserved.
- ADR-014 (Single-commit governance): "the ticket change and its README refresh land in the same commit"; halting + separate reconcile-readme commit violates this.
- P094 (refresh-on-create) + P062 (refresh-on-transition): the per-operation contracts already handle the inline-refresh case; the carve-out makes Step 0's preflight aware of them.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — fix is independent)
- **Composes with**: P145 (run-retro Tier 3 rotation defers recurringly — same class of "SKILL contract overreach gets papered over by agent-side judgement"), P148 (retro Stage 1 mechanical-ticketing — same composition pattern: agent detects framework-resolvable case but doesn't bypass the halt directive), ADR-014 (single-commit grain — the load-bearing principle the carve-out preserves).

## Fix Released

Deployed in v0.24.0 (next release of `@windyroad/itil`). The fix carves out an **uncommitted-rename detection branch** from the Step 0 Exit-1 routing in two SKILL.md files (`manage-problem` Step 0 + `work-problems` Step 0) and ships a new `packages/itil/scripts/classify-readme-drift.sh` helper + `wr-itil-classify-readme-drift` `$PATH` shim per ADR-049. The classifier reads the captured stdout of `reconcile-readme.sh` plus `git status --porcelain docs/problems/` filtered for staged renames (`R` / `RM`), cross-references drifting IDs against the destination paths of working-tree renames, and emits one of two classifications:

- `INLINE_REFRESH covered=<N>` (exit 0) — every drift ID is the destination of a staged rename; defer to in-flow P094 / P062 refresh per ADR-014 single-commit grain. The SKILL.md Step 0 logs a one-line note and continues to Step 1 inline.
- `HALT_ROUTE_RECONCILE uncovered=<N>` (exit 1) — at least one drift ID is committed-only or mixed; halt and route to `/wr-itil:reconcile-readme` as today.

Behavioural bats coverage at `packages/itil/scripts/test/classify-readme-drift.bats` (13 tests; INLINE / HALT / mixed / RM / parse-error / no-git-repo / default-arg branches). Shim-existence + smoke parity tests added to `packages/shared/test/no-repo-relative-script-paths-in-skills.bats`.

**Architect verdict**: PASS — no new ADR required. The carve-out aligns with ADR-014 line 136 ("the new ticket file + the refreshed README ride the same commit"); the inline-classify branch IS the ADR-013 Rule 6 fail-safe (deterministic mechanical resolution, no human input deferred). Detection heuristic is appropriately scoped: `R` and `RM` both prefix-match; destination path is parsed for the post-rename status. Bounded as a SKILL.md refinement under ADR-014's existing reassessment window (2026-10-16); P145's MUST_SPLIT precedent (Tier 3 rotation refinement landed inline as SKILL-amendment-without-ADR) is the directly analogous pattern.

**JTBD verdict**: PASS — change serves JTBD-006 (AFK loop continuity), JTBD-001 (governance without slowing down), JTBD-201 (audit trail). The inline path produces a single ADR-014-grain commit; the halt path remains intact for committed cross-session drift, so the cross-session safety net P118 was designed for is preserved. No persona regresses.

**Verification criteria** (close on confirmation):
1. Next AFK iter that lands on a manage-problem invocation with a same-session staged rename in the working tree continues inline through Step 0 without firing the halt-and-route to `/wr-itil:reconcile-readme`.
2. The iter's commit captures the README refresh in the same commit as the ticket rename + content edit (single-commit grain per ADR-014).
3. A future committed cross-session drift case still halts and routes correctly (no regression on the P118 originating scenario).

## Related

- **P118** (`docs/problems/118-readme-drifts-from-filesystem-truth-despite-refresh-contracts-closed.closed.md`) — originating ticket for the Step 0 reconcile preflight contract. P149 refines it by distinguishing uncommitted vs committed drift.
- **P094** (`docs/problems/094-manage-problem-does-not-refresh-readme-on-ticket-creation.closed.md`) — per-operation refresh on creation; the inline path the carve-out preserves.
- **P062** (`docs/problems/062-manage-problem-readme-not-refreshed-on-single-ticket-iterations.closed.md`) — per-operation refresh on transition; the inline path the carve-out preserves.
- **ADR-014** (`docs/decisions/014-single-commit-governance.proposed.md`) — single-commit grain principle; the load-bearing rationale.
- **`packages/itil/scripts/reconcile-readme.sh`** — the diagnostic script Step 0 invokes; unchanged by this fix (advisory output remains correct; the fix is in how SKILL.md routes the exit-1 signal).
- **`packages/itil/skills/manage-problem/SKILL.md` Step 0** — primary edit target.
- **`packages/itil/skills/work-problems/SKILL.md` Step 0** — symmetric edit target.
- **`packages/itil/skills/work-problem/SKILL.md` Step 1** — symmetric edit target (P148 release session: this skill called Step 0 indirectly via manage-problem delegation).
- **2026-05-02 P148 release session evidence**: agent contextually interpreted Step 0 as inline-refresh; outcome correct (single commit per ADR-014) but pattern not codified.
- **`/wr-retrospective:run-retro` 2026-05-02 retro Step 2b detection**: this ticket originated from the pipeline-instability scan during today's retro; category = Skill-contract violations (contract overreach where halt directive is too broad).
