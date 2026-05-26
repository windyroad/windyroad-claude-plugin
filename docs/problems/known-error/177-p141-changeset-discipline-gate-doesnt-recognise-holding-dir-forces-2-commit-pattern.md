# Problem 177: P141 changeset-discipline gate doesn't recognise `docs/changesets-holding/` — forces 2-commit pattern when work belongs to a held window

**Status**: Known Error
**Reported**: 2026-05-07
**Priority**: 6 (Medium) — Impact: 2 (Minor — forces a 2-commit pattern on held-window work; dev-tooling friction, not published-distribution) x Likelihood: 3 (Possible — fires on every held-window iter)
**Effort**: M
**WSJF**: 6.0 — (6 × 2.0) / 2 (Known Error multiplier 2.0) — auto-transitioned Open → Known Error 2026-05-26 (confirmed root cause + documented workaround); Likelihood un-deferred from placeholder 1 → 3
**Type**: technical

## Description

P141's changeset-discipline gate (`packages/itil/hooks/itil-changeset-discipline.sh`) requires `.changeset/*.md` to exist when `packages/itil/` source is staged for commit. The gate does NOT recognise `docs/changesets-holding/*.md` — the held-window directory blessed by ADR-042 Rule 7 for changesets that are intentionally not yet ready to ship (multi-slice WIP per Case 1 OR auto-applied by the orchestrator under ADR-042 Rule 2 to bring release risk within appetite).

Net effect when work belongs to a held window: the work commit fails the P141 gate because no `.changeset/*.md` file exists. Workaround is the **2-commit pattern**:

1. **Work commit** — author the changeset directly in `.changeset/`, stage with the source code, satisfy the gate, commit.
2. **Move-to-holding chore commit** — `git mv .changeset/<name>.md docs/changesets-holding/<name>.md`, append "Currently held" entry to the holding README, commit as `chore(changeset): move <name> to holding per ADR-060 atomicity contract (ADR-042 Rule 2)`.

**Concrete evidence — N=2 this session 2026-05-06**:

- Iter 2 recovery move at commit `08cbf1e` — orchestrator's main turn after Step 6.5 scored cumulative residual at 20/25 (above appetite — Slice 4 B7 changeset would have graduated ahead of held Phase 1 framework code, breaching ADR-060 § Confirmation criterion 6 atomicity contract).
- Iter 3 move at commit `9a5deff` — iter subprocess applied the same pattern after committing the Slice 4 B7.T3 capture-problem type-prompt work.

Both follow the same `chore(changeset): move <name> to holding per ADR-060 atomicity contract (ADR-042 Rule 2)` shape and add a sibling line to `docs/changesets-holding/README.md` "Currently held" section. The pattern recurs for the duration of the held-window slice — Slices 2-5 of P170 RFC framework, which on current pacing is weeks of duration.

User direction 2026-05-06 (from interactive session-end review): "capture as a P-ticket and defer" — preserve evidence for next-review-pass triage; do not amend P141 inline this session.

## Symptoms

- Work commits on `packages/itil/` source fail the P141 gate when no active `.changeset/*.md` exists, even though a sibling held entry in `docs/changesets-holding/` documents the intent.
- AFK iter subprocesses (and orchestrator main turn) emit a 2-commit pattern (`feat(itil): ... + chore(changeset): move ... to holding`) per held-window-bound bounded sub-task.
- Architect finding 8 ADR-014 grain composition is satisfied (work is one task, move-to-holding is another), but the audit trail for held-window iteration accumulates twice as many commits as the underlying work would otherwise warrant.
- Held-window slices (P170 Slices 2-5) under ADR-060 § Confirmation criterion 6 carry the friction-toll for ~weeks of session-pacing duration.

## Workaround

The 2-commit pattern itself IS the workaround. It works correctly today; the question is whether to make it implicit (gate-recognised) or document-it-as-policy (iter-prompt template).

Three resolution shapes for next-review-pass triage:

- **(a) Amend P141 hook to recognise held-window directory**: modify `packages/itil/hooks/itil-changeset-discipline.sh` to satisfy the gate when a same-PR `docs/changesets-holding/<name>.md` exists for the staged `packages/<plugin>/` change. Closes the recurring 2-commit pattern at gate level. Requires its own ADR-014 grain commit + behavioural bats per ADR-052. Composes with ADR-042 Rule 7 (held-window blessing) — the gate gains a held-window awareness branch.
- **(b) Document the 2-commit pattern in iter prompt template**: bake `commit work, then chore(changeset): move to holding` into `/wr-itil:work-problems` Step 5 iteration-prompt body so iter subprocesses don't have to re-derive the pattern. Lowest-effort beyond capture; preserves audit-trail granularity (work commit + chore commit independently revertable).
- **(c) Skip — N stays low until Slice 6 graduation**: option (c) accepts the friction-toll until the held window empties at Slice 6 graduate-to-adopters. ADR-014 grain composition is structurally consistent (one bounded sub-task per commit, held-window move is its own bounded sub-task); audit-trail granularity is a feature, not a defect.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: solo-developer running AFK orchestrator on P170 Slices 2-5 work; secondary: future maintainers running held-window slices on any plugin (the gate behaviour is plugin-agnostic).
- **Frequency**: (deferred to investigation) — N=2 in 2026-05-06 single session; expected to grow per held-changeset entry until Slice 6 graduation.
- **Severity**: (deferred to investigation) — likely Minor; doubles commit count for held-window-bound work but does not block progress.
- **Analytics**: (deferred to investigation) — count of `chore(changeset): move .* to holding` commits across held-window slices; held-window duration measured in commits-per-slice + days-per-slice.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause: P141 gate scope was authored before ADR-042 Rule 7 blessed `docs/changesets-holding/`; the gate's `.changeset/*.md` check predates the held-window directory's establishment. Check whether P141's original Confirmation criteria 1-3 named gate-blocking-with-held-fallback as out of scope or simply pre-dated it.
- [x] Pick resolution shape (a/b/c) per the deferred review pass — **DECIDED 2026-05-26 (user, P283 prong-2 drain surfacing): option (a) — amend the hook.** Rationale: recurrence N=12 move-to-holding commits all-time, well past the ticket's own "≤4 → just accept" escalation threshold; the held window is still active. **Fix strategy**: amend `packages/itil/hooks/itil-changeset-discipline.sh` to satisfy the gate when a same-commit `docs/changesets-holding/<name>.md` entry exists for the staged `packages/<plugin>/` source (gains a held-window-awareness branch composing with ADR-042 Rule 7), with a behavioural bats test per ADR-052 covering BOTH routes (gate satisfies on `.changeset/*.md` OR same-commit `docs/changesets-holding/*.md`; non-holding source-without-either still denies). Ready to implement (this ticket now carries a settled fix strategy).
- [x] Implement option (a) — **DONE 2026-05-26** (this commit, held-window AFK iter). Amended the delegated detection helper `packages/itil/hooks/lib/changeset-detect.sh` to set `has_changeset=1` on a staged `docs/changesets-holding/<name>.md` entry (excluding `README.md`), mirroring the existing `.changeset/*.md` branch + its README meta-doc exclusion. **File-name reconciliation** (JTBD review 2026-05-26): the fix-strategy line above named the wrapper hook `packages/itil/hooks/itil-changeset-discipline.sh`, but the wrapper delegates all detection to the helper per its line-8 contract (`Detection delegates to lib/changeset-detect.sh::detect_changeset_required`) — the helper is the correct edit surface; the wrapper is unchanged. Added 4 behavioural bats tests to `packages/itil/hooks/test/itil-changeset-discipline.bats` (both holding-route allow cases + a README-meta-doc-excluded deny + a neither-`.changeset`-nor-holding deny regression guard); full file 36/36 green. Authored `@windyroad/itil` patch changeset (`.changeset/wr-itil-p177-changeset-gate-holding-dir.md`). Architect APPROVE + JTBD PASS recorded 2026-05-26 (no new ADR; composes with ADR-042 Rule 7; release/drain semantics unchanged). Transition to Verifying deferred to release per ADR-018 (orchestrator owns release cadence) — ticket stays Known Error this iteration.
- [ ] Confirm pattern recurrence — measure N across ongoing P170 Slices 2-5 work; if N stays ≤ 4 by Slice 6 graduation, option (c) is the right call. If N exceeds 4 before graduation, option (a) escalates priority.
- [ ] Cross-reference with P162 (held-changeset graduation criteria) — does P162's resolution naturally close P177 by emptying the held window? If so, P177 can be marked as composed-with-blocked-by-P162 and parked-pending-P162-resolution.

## Dependencies

- **Blocks**: (none — work proceeds via the 2-commit pattern; this ticket is friction-reduction, not blocking)
- **Blocked by**: (none — investigation can proceed independently)
- **Composes with**:
  - **P141** (`docs/problems/141-afk-iter-changeset-discipline-enforcement-hook.verifying.md`) — parent ticket for the gate this captures friction against. Resolution shape (a) is a P141 amendment.
  - **P162** (`docs/problems/162-codify-dogfood-graduation-criteria-with-counterfactual-risk-assessment-for-held-changesets.open.md`) — held-changeset graduation criteria. P162's resolution naturally closes P177 by emptying the held window; until P162 lands, P177 friction-toll continues per held-changeset entry.
  - **P170** + **ADR-060** § Confirmation criterion 6 — atomicity contract that creates the held-window slice this friction surfaces in. Slice 6 graduate-to-adopters closes the immediate window for P170; but the gate-vs-held-window mismatch persists for any future held-window slice on any plugin.
  - **ADR-042** Rule 2 + Rule 7 — auto-apply + held-window blessing. Rule 7 is the load-bearing context that makes `docs/changesets-holding/` a legitimate alternative to `.changeset/`, which P141's gate doesn't yet acknowledge.
  - **ADR-014** Architect finding 8 (grain composition) — the 2-commit pattern is structurally consistent with one-commit-per-bounded-sub-task; this is "feature, not defect" framing for option (c).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-014 (commit grain — work commit + move-to-holding commit are independent bounded sub-tasks)
- ADR-042 Rule 7 (held-window blessing — `docs/changesets-holding/` is the authoritative mechanism)
- ADR-052 (behavioural-tests-default — option (a) requires a bats fixture)
- ADR-060 § Confirmation criterion 6 (atomicity contract — creates the held-window slice this friction surfaces in)
- P141 — parent gate ticket (verifying)
- P162 — held-changeset graduation criteria (closes P177 indirectly via Slice 6)
- P170 — driver multi-slice ticket exposing the recurrence
- Session evidence — 2026-05-06 commits `08cbf1e` (iter 2 recovery), `9a5deff` (iter 3); user direction at session-end "capture as a P-ticket and defer".
