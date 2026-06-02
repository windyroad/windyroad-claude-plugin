# Problem 165: P094 README-refresh enforcement gap — iter subprocess commits can land a `.verifying.md` rename without staging the corresponding Verification Queue row in `docs/problems/README.md`

**Status**: Verification Pending — fix released awaiting user verification (per ADR-022)
**Reported**: 2026-05-04
**Released**: 2026-05-12 (this commit; pending `@windyroad/itil` patch — ships `itil-readme-refresh-discipline.sh` PreToolUse:Bash commit-gate hook + `lib/readme-refresh-detect.sh` helper + 22-test ADR-052 behavioural bats fixture)
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

**WSJF**: (9 × 1.0) / 2 = **4.5**

> Captured 2026-05-04 by `/wr-itil:work-problems` AFK loop iter 7 surfacing pass per user direction "capture all four now". Sibling finding from iter 4 P157 commit.

## Description

Per `manage-problem` SKILL.md Step 5 P094 + Step 7 P062, every ticket creation, ranking-bearing update, and status transition MUST stage the refreshed `docs/problems/README.md` in the same commit as the ticket change (ADR-014 single-commit grain). The contract is well-documented; bats fixtures cover the happy path.

Observed iter 4 P157: iter 3's commit `d28bd51` (P156 capture-adr) shipped without the P094 README refresh — the P156 row was missing from the WSJF Rankings table → Verification Queue. Iter 4 backfilled inline (extra P094 work added on top of P157's own scope) to recover the audit trail.

This is an **enforcement gap**: the manage-problem skill's contract says "MUST stage README", but iter subprocesses can ship a commit without it and nothing observable rejects the commit. The git log carries the violation forward; only the next iter (or a `/wr-itil:reconcile-readme` invocation) detects it.

## Symptoms

- Iter 3 commit `d28bd51` (P156 capture-adr) — staged the rename to `.verifying.md` and the ticket-body update, but not `docs/problems/README.md` refresh.
- Iter 4 P157 commit had to backfill the P156 VQ row to recover.
- General class: any iter subprocess can violate the contract; only the orchestrator's Step 0 P118 reconcile-check (or the next ticket-creator's Step 0) catches it.

## Workaround

Inline backfill on next iter (iter 4 did this for iter 3's gap). Cost: ~1-2 extra agent turns per backfill + the unused iter context that the violation cost.

## Impact Assessment

- **Who is affected**: Every iter subprocess that creates / updates / transitions a ticket. AFK loops accumulate violations across iters until the next reconcile.
- **Frequency**: Per-iter risk; observed once this AFK loop (iter 3 → iter 4 backfill).
- **Severity**: Moderate — README staleness misleads next reader (orchestrator's Step 1 backlog scan, user manual review). Recoverable; not catastrophic.
- **Likelihood**: Likely — observed once across this loop's 6 iters; iter dispatch shape (`claude -p` subprocess with isolated context) means each iter independently follows the contract; one slip-up per loop is plausible.

## Root Cause Analysis

The current manage-problem SKILL.md Step 5 P094 / Step 7 P062 contracts are declarative ("MUST stage README"). No structural enforcement detects the violation.

Possible enforcement shapes:

1. **PostCommit hook** scanning the just-landed commit's diff for a ticket file rename / Status edit without a corresponding `docs/problems/README.md` change. Emits a deny-style message after-the-fact (commit already landed; needs re-do).

2. **PreToolUse:Bash hook** on `git commit` that grep's the staged set for ticket file changes without README change. Halts the commit. Lower-friction for forward-fixing; same shape as P125 staging-trap detector + P141 changeset-discipline.

3. **manage-problem Step 5 hard-fail** — after writing the new file, the skill itself validates the README contains the new ticket's row before allowing the commit. Internal to the skill; doesn't help if the skill is bypassed.

4. **Step 7 hard-fail** — same as #3 for transitions. The skill validates `grep -q "<ticket-id>" docs/problems/README.md` matches the new state suffix before allowing the commit.

Option 2 (PreToolUse hook) is the strongest enforcement and matches the existing pattern (P125, P141). Option 4 (skill-internal hard-fail) is cheaper to implement but only catches good-faith errors.

### Investigation Tasks

- [x] Confirm scope: only manage-problem Step 5 / Step 7 paths affected, or also transition-problem / transition-problems / capture-problem / review-problems? — **All paths**. Hook gates `git commit` at the commit boundary regardless of authoring skill, covering manage-problem Step 5/7 + transition-problem + transition-problems + capture-problem + review-problems + raw `git mv`+`git commit` shapes.
- [x] Decide enforcement shape — Option 1 / 2 / 3 / 4 above. Architect review. — **Shape #2 (PreToolUse:Bash)** approved by architect 2026-05-12 verdict PASS. Direct sibling of P125 + P141 architectural precedent. No new ADR needed; ADR-009 (no-marker per-invocation), ADR-013 Rule 1 (deny+recovery), ADR-014 (single-commit grain), ADR-022 (`.verifying.md` lifecycle), ADR-038 (terseness), ADR-045 (Pattern 1 + ≤300-byte deny band) all apply unchanged.
- [x] Implement chosen shape + behavioural bats per ADR-052. — `packages/itil/hooks/itil-readme-refresh-discipline.sh` + `packages/itil/hooks/lib/readme-refresh-detect.sh` ship in this commit; 22-test ADR-052 behavioural bats fixture at `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` (8 deny cases / 7 allow cases / 2 Pattern 1 silence cases / 2 tool-name + command-shape filter cases / 2 mixed-set cases / 2 parse + fail-open cases; 22/22 green; full itil hook suite 231/231 green confirming no regression). Hook registered in `packages/itil/hooks/hooks.json` PreToolUse:Bash array alongside P125 + P141 siblings.
- [x] Apply to existing iter subprocess violations (would have caught iter 3 d28bd51). — Hook fires on `git commit` regardless of authoring path; iter 3 d28bd51 shape (staged `.verifying.md` rename without README) would emit deny + recovery directive.

## Fix Strategy

Architect-approved Shape #2: PreToolUse:Bash hook (`itil-readme-refresh-discipline.sh`) gates `git commit` invocations. Detection delegates to `lib/readme-refresh-detect.sh::detect_readme_refresh_required` which:

1. Bypass via `BYPASS_README_REFRESH_GATE=1` env var.
2. Fail-open if not inside a git work tree.
3. Run `git diff --staged --name-only`.
4. Categorise each path:
   - `docs/problems/README.md` → counts as README refresh.
   - `docs/problems/README-history.md` → ignored (rotated history per P134).
   - `docs/problems/(open|verifying|closed|known-error|parked)/NNN-*.md` → ticket-state-transition surface; records first offending path.
   - Legacy flat `docs/problems/NNN-*.md` → also recorded.
   - Anything else → ignored.
5. If ticket recorded AND README not staged → return 1 + echo offending path.

Hook emits deny JSON with the offending ticket ID (`P<NNN>` extracted from leading digits — full ticket slugs would exceed ADR-045 deny-band), the literal recovery command `git add docs/problems/README.md`, and the `BYPASS_README_REFRESH_GATE=1` escape. Silent-on-pass per ADR-045 Pattern 1. ≤300 bytes per ADR-045 deny band.

JTBD-001 (Enforce Governance Without Slowing Down) primary fit — strengthens the existing commit-time gate band (P125 + P141 siblings) by closing the README-index drift surface. JTBD-302 (Trust That the README Describes the Plugin) composes — load-bearing-from-the-start drift detection at the closest surface to the failure (matches the 2026-05-04 P159 amendment direction).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P094 (parent — README refresh on creation), P062 (parent — README refresh on transition), P125 (sibling — PreToolUse:Bash gate pattern), P141 (sibling — changeset-discipline gate), ADR-014 (single-commit grain), P118 (`/wr-itil:reconcile-readme` — recovery path)

## Related

- ADR-014 — single-commit grain.
- P094 — README refresh on creation contract (manage-problem Step 5).
- P062 — README refresh on transition contract (manage-problem Step 7).
- P125 — staging-trap detector PreToolUse:Bash hook (precedent shape).
- P141 — changeset-discipline PreToolUse:Bash hook (precedent shape).
- P118 — reconcile-readme recovery path.
- iter 4 P157 retro — `docs/retros/2026-05-04-p159-iter.md` (incident location).

## Change Log

- **2026-05-04** — Opened by orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 per user direction "capture all four now". Sibling finding from iter 4 P157 backfill. Skeleton ticket; investigation deferred.
- **2026-05-12** — Open → Verification Pending. AFK iter `/wr-itil:work-problems`. Architect verdict PASS on Shape #2 (PreToolUse:Bash, sibling to P125 + P141 — no new ADR). JTBD-lead verdict PASS (JTBD-001 primary + JTBD-302 composes; in-scope, no doc update). Ships `@windyroad/itil` patch: new `packages/itil/hooks/itil-readme-refresh-discipline.sh` PreToolUse:Bash commit-gate hook + new `packages/itil/hooks/lib/readme-refresh-detect.sh` shared helper + new 22-test ADR-052 behavioural bats fixture at `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` (22/22 green; full itil hook suite 231/231 green; pre-fix suite 209). Hook registered in `packages/itil/hooks/hooks.json` PreToolUse:Bash array. Deny message ≤300 bytes per ADR-045; uses extracted ticket ID `P<NNN>` (not full slug) to fit budget across all ticket-name lengths. User verifies on next `git commit` in this monorepo: staged ticket without README → deny with redirect; staged ticket+README → commit allowed. Recovery if rollback needed: `BYPASS_README_REFRESH_GATE=1 git commit ...` for one-time bypass, or remove the hooks.json entry for full rollback.
