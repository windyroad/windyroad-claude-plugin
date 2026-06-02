# Problem 040: work-problems does not fetch origin before starting

**Status**: Closed
**Reported**: 2026-04-18
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: L (architect requires ADR-019 prerequisite before SKILL.md change ships)
**WSJF**: 6.0 (12 × 2.0 / 4)

## Fix Released

Released in `@windyroad/itil@0.4.2` (commit `9c6019e`, release tag merged
2026-04-18). Step 0 (Preflight) now appears in
`packages/itil/skills/work-problems/SKILL.md`.

The next-ID collision guard (ADR-019 confirmation criterion 2) is split
into a separate problem ticket targeting `manage-problem` per architect
guidance — `work-problems` does not create tickets, so the guard does not
belong there. See P043.

Awaiting user verification: run an AFK loop with `origin/main` advanced
by another session and confirm the orchestrator either pulls (trivial
case) or stops with a divergence report (non-fast-forward case).

## Description

The `wr-itil:work-problems` AFK orchestrator does not run `git fetch origin` or
compare local state against `origin/main` before beginning its work loop. When a
parallel Claude session has advanced `origin/main` — creating new problem
tickets, closing others, or shipping related fixes — the local orchestrator
continues oblivious, reviewing a stale backlog and potentially creating new
problem tickets with IDs that will collide with the remote's numbering on push.

Observed 2026-04-18: a parallel session advanced `origin/main` by 20+ commits,
creating P031-P039 with completely different semantics than the P031-P042 I had
created locally. The work-problems loop reviewed, ranked, transitioned, and
worked 4 problems across 5 commits before the user intervened. The push then
failed with a non-fast-forward error, requiring a surgical rebase that dropped
14 of my problem tickets because of numbering collisions.

## Symptoms

- `work-problems` runs against a stale local backlog without warning
- New problem tickets created with IDs that duplicate existing IDs on remote
- Push fails with non-fast-forward after substantial local work
- Surgical rebase required; problem-ticket content often has to be dropped due
  to same-number-different-semantics collisions
- Fix commits closing "P<NNN>" reference ticket IDs that mean different things
  locally vs upstream

## Workaround

Manually run `git fetch origin && git log --oneline HEAD..origin/main` before
invoking `/wr-itil:work-problems`. If the command shows any commits, pull or
investigate before starting the loop.

## Impact Assessment

- **Who is affected**: Anyone running the AFK work-problems loop on a branch
  also being edited by a parallel session (manually, via CI, or via another
  Claude instance)
- **Frequency**: Every AFK loop where a parallel session has committed to
  `origin/main` since the last local fetch
- **Severity**: Significant — wasted surgical-rebase effort, lost problem
  tickets, and eroded user trust in the orchestrator
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

Source-code evidence from `packages/itil/skills/work-problems/SKILL.md`:

- **Step 1 — Scan the backlog (lines 17–24)** reads `docs/problems/README.md`
  with a git-history-based cache-freshness check (P031 fix). The check is
  scoped entirely to the local working tree — `git log` of the local
  README.md vs local problem files. There is no `git fetch origin` and no
  `HEAD vs origin/main` divergence comparison.
- **Step 3 — Pick the highest-WSJF problem (lines 42–47)** ranks from local
  files only.
- **No preflight section exists.** The skill assumes the local branch is the
  canonical backlog state at invocation time.

The preliminary hypothesis is confirmed. The cache-freshness mechanism added
for P031 solved a local-staleness class of bug; this ticket covers the
distinct remote-divergence class of bug.

### Architect Verdict (2026-04-18)

The fix as scoped requires a new ADR before the SKILL.md change can ship:

> ADR-019: AFK orchestrator preflight — fetch-origin and divergence handling.
> AFK orchestrators MUST run `git fetch origin` and compare local HEAD with
> `origin/<base>` before opening their work loop. If origin has advanced,
> the orchestrator MUST surface the divergence (and, in fully autonomous
> mode, attempt a trivial pull/rebase before continuing). The orchestrator
> MUST also re-check next-ID assignment against `origin/<base>` before
> creating any new problem ticket, to avoid numbering collisions like the
> 2026-04-18 incident.
>
> Distinct from ADR-018 (release cadence) — that decision covers WHEN to
> push/release; this one covers WHEN to start. Conflating them risks an
> overly broad ADR. Cross-link both ADRs as siblings.

This raises the effort from M to L. WSJF = (12 × 2.0) / 4 = **6.0**
(unchanged numerically because the status multiplier rises 1.0 → 2.0 in the
same review that effort drops M → L).

### Fix Strategy (post-architect-review)

Ship in this order:

1. **ADR-019 — AFK orchestrator preflight: fetch-origin and divergence
   handling** (prerequisite)
   - Path: `docs/decisions/019-afk-orchestrator-preflight.proposed.md`
   - Rule: AFK orchestrators MUST run `git fetch origin` and compare HEAD
     with `origin/<base>` before opening their work loop. On divergence:
     attempt trivial pull/rebase non-interactively (per ADR-013 Rule 6); on
     non-trivial divergence, stop and report.
   - Numbering-collision guard: before creating any new problem ticket,
     check the next-ID scan against `git ls-tree origin/<base>
     docs/problems/`. Renumber if the local choice would collide.
   - Cross-link ADR-018 as sibling (preflight vs cadence — both are AFK
     orchestrator lifecycle rules).

2. **Update `packages/itil/skills/work-problems/SKILL.md`** (after ADR-019)
   - Insert a new "Step 0 — Preflight" before Step 1 (Scan the backlog):
     run `git fetch origin`; compare HEAD with `origin/main`; if origin has
     advanced, attempt `git pull --ff-only`; if non-fast-forward, stop with
     a clear divergence report and abort the loop.
   - Insert a numbering-collision guard before any ticket creation step in
     the manage-problem skill (cross-cutting concern — may belong in
     manage-problem rather than work-problems).
   - Add a row to the Non-Interactive Decision Making table:
     `Origin diverged before start | Pull --ff-only if trivial; stop with
     report if non-fast-forward`.

3. **Atomic push per iteration** (already partially observed — work-problems
   commits per iteration; the ADR should formalise that push happens in
   the same iteration as commit, not deferred to end-of-loop).

4. **Reproduction test (deferred)**
   - Simulated bats test: stage a diverged origin via a temp git repo and
     assert the SKILL.md preflight refuses to start (or auto-rebases).
   - Defer until ADR-019 lands.

### Workaround (non-permanent)

The user (or this skill operator) manually applies the rule via the
feedback memory entry `feedback_release_cadence.md`: fetch origin before
starting. Operator vigilance is the workaround until the fix ships.

### Investigation Tasks

- [x] Audit `work-problems` skill opening steps for any existing origin
      awareness — confirmed none (cache-freshness check is local-only,
      lines 17–24)
- [x] Architect review (ALIGNMENT — ADR-019 required as prerequisite,
      distinct from ADR-018)
- [x] Author ADR-019 (2026-04-18, commit a530912)
- [x] Decide whether the numbering-collision guard belongs in
      `work-problems` or `manage-problem` — decided: manage-problem
      (architect confirmed; split into separate ticket)
- [x] Create reproduction test
      (`packages/itil/skills/work-problems/test/work-problems-preflight.bats`,
      7 assertions covering ADR-019 confirmation criteria)
- [x] Implement the SKILL.md change (Step 0 added before Step 1;
      Non-Interactive Decision Making table updated with origin-divergence
      row)
- [ ] User verification: run an AFK loop with origin diverged and confirm
      the preflight either pulls (trivial) or stops (non-fast-forward)
- [ ] Create INVEST story for permanent fix (covers ADR + SKILL + tests)

## Related

- P041: work-problems does not enforce release cadence — companion issue
  from the same incident; same session, different root cause
- P035: manage-problem commit gate no subagent delegation fallback
  (known-error, fix released) — related commit-gate/subagent context
- P036: work-problems orchestrator does not verify commit-landing between
  iterations — adjacent orchestrator-hygiene concern
- `/Users/tomhoward/.claude/projects/-Users-tomhoward-Projects-windyroad-claude-plugin/memory/feedback_release_cadence.md`
  — personal feedback memo capturing the release-timing half of the lesson
