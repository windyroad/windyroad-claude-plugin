# Problem 043: Next-ID collision guard missing in ticket-creator skills

**Status**: Closed
**Reported**: 2026-04-18
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M (one or two SKILL.md changes + bats test + small commit)
**WSJF**: 9.0 (9 × 2.0 / 2)

## Fix Released

Released in `@windyroad/itil@0.4.3` and `@windyroad/architect@0.3.2`
(commit `359ec7c`, release tag merged 2026-04-18). Both `manage-problem`
step 3 and `create-adr` step 3 now compute `max(local, origin) + 1` with
`git ls-tree origin/main` lookup.

Awaiting user verification: create a problem ticket or ADR while origin
has advanced (parallel session, CI commit, etc.) and confirm the
ticket-creator skill renumbers to avoid the collision and logs the
renumber decision.

## Description

ADR-019 (AFK orchestrator preflight) defines two confirmation criteria.
The first — orchestrator-level `git fetch origin` + divergence handling —
shipped in `@windyroad/itil@0.4.2` via P040. The second is a **next-ID
collision guard** at ticket-creation time: before any skill creates a new
problem, ADR, or JTBD ticket, it MUST re-check the next-ID assignment
against `git ls-tree origin/<base>` so the local choice does not collide
with a ticket created on origin since the last fetch.

The guard does not belong in `work-problems` (which does not create
tickets). The architect (P040 implementation review, 2026-04-18)
confirmed it belongs in the ticket-creator skills:

- `packages/itil/skills/manage-problem/SKILL.md` — step 3 ("Assign the
  next ID") currently scans local `docs/problems/` only.
- `packages/architect/skills/create-adr/SKILL.md` — step 3 ("Determine
  sequence number and filename") currently scans local `docs/decisions/`
  only.
- (Likely also `packages/jtbd/skills/*/SKILL.md` if any of those skills
  create JTBD files with sequential IDs — needs scoping during
  investigation.)

## Symptoms

- New problem ticket created locally with `P0NN` while a parallel session
  has already used `P0NN` on origin for a different problem
- New ADR created locally with `0NN` while origin has used `0NN`
- Push fails with non-fast-forward; manual rebase drops the local ticket
  or the origin ticket because both number to the same file path
- The 2026-04-18 incident (P040 source incident) is the canonical example:
  14 local problem tickets had to be dropped during a surgical rebase
  because of P0NN collisions

## Workaround

The ADR-019 Step 0 preflight (shipped via P040) catches divergence at the
loop start and pauses for the user. So if the user has run the latest
work-problems version, divergence is surfaced before tickets are created.
This is a partial workaround — it covers the AFK loop case but not the
case where the user creates a ticket directly via `/wr-itil:manage-problem`
or `/wr-architect:create-adr` without running the orchestrator preflight
first.

## Impact Assessment

- **Who is affected**: Solo-developer running `/wr-itil:manage-problem`
  or `/wr-architect:create-adr` while a parallel session (CI, another
  Claude instance, another machine) has advanced origin
- **Frequency**: Every ticket creation on a branch where origin has
  advanced since the last local fetch
- **Severity**: Moderate — recovery cost is a surgical rebase that can
  drop content; mitigated partially by the orchestrator preflight, but
  the gap exists for direct ticket creation outside the AFK loop
- **Analytics**: One observed incident (2026-04-18) that motivated P040
  and ADR-019

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

Source code from `packages/itil/skills/manage-problem/SKILL.md` step 3:

> **For new problems: Assign the next ID**
> Scan `docs/problems/` for existing files. Extract the highest numeric
> ID and increment by 1. Zero-pad to 3 digits.
> ```bash
> ls docs/problems/*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^[0-9]+' | sort -n | tail -1
> ```

The scan operates on the local working tree only. There is no comparison
against `origin/<base>`. Same gap in `create-adr` step 3 (scans local
`docs/decisions/`).

### Fix Strategy

1. **Add `git ls-tree origin/<base>` collision check** to step 3 of each
   ticket-creator skill. After computing the local-max ID, also compute
   the origin-max ID via:
   ```bash
   git ls-tree origin/<base> docs/problems/ | grep -oE '[0-9]+' | sort -n | tail -1
   ```
   Take the max of the two and increment.
2. **Renumber on collision**: if the local choice collides with an origin
   ticket since the last fetch, renumber to the next free ID and log the
   renumber in the AFK iteration summary.
3. **Add bats test** asserting each ticket-creator SKILL.md references
   `git ls-tree origin/` (mirroring the work-problems-preflight.bats
   pattern).
4. **Document in cross-cutting place** — possibly a shared pattern file
   that both manage-problem and create-adr cite, to avoid drift if a
   third ticket-creator skill is added later.

### Investigation Tasks

- [x] Confirm the gap in ticket-creator skills (manage-problem step 3,
      create-adr step 3) — both scan local-only
- [x] Architect approval to split from P040 (confirmed 2026-04-18,
      after P040 implementation review)
- [ ] Audit all skills under `packages/*/skills/` that create
      sequentially-numbered files in `docs/` — confirm the full list of
      ticket-creators that need the guard
- [ ] Decide whether to centralise the guard logic (shared script) or
      duplicate per-skill
- [ ] Implement the SKILL.md changes (one PR per skill, or a single PR
      depending on the centralisation decision)
- [ ] Add bats test(s)
- [ ] Update P040 to mark this guard sub-task complete

## Related

- ADR-019: `docs/decisions/019-afk-orchestrator-preflight.proposed.md`
  — establishes both the orchestrator preflight (shipped via P040) and
  the next-ID collision guard (this ticket)
- P040: `docs/problems/040-work-problems-does-not-fetch-origin-before-starting.known-error.md`
  — sibling concern; the orchestrator-side fix is shipped, this is the
  ticket-creator-side fix that ADR-019 also requires
- `packages/itil/skills/manage-problem/SKILL.md` step 3 — first
  ticket-creator that needs the guard
- `packages/architect/skills/create-adr/SKILL.md` step 3 — second
  ticket-creator that needs the guard
