# Problem 094: `/wr-itil:manage-problem` does not refresh `docs/problems/README.md` on ticket creation

**Status**: Closed
**Reported**: 2026-04-22
**Closed**: 2026-04-24 — verified in-session via run-retro Step 4a. Every manage-problem invocation this session rode the README-refresh contract correctly: commit 2be1bfa (P113 open) included the ticket + docs/problems/README.md; commit e14040b (P115 open + P113 RCA update) included both; commits 245e09c (P113 closure), 25e06e5 (P114 closure), and 539e952 (P113 upstream back-write) all kept README in-sync with the ticket file set. ADR-014 single-commit-transaction rule held across 5 manage-problem-class commits.
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost certain (5)
**Effort**: S
**WSJF**: (10 × 1.0) / 1 = **10.0**

## Description

`/wr-itil:manage-problem` Step 7 has a P062 "README.md refresh on every transition" block that regenerates `docs/problems/README.md` whenever a ticket's Status changes (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed, any → Parked). This keeps the ranked table, Verification Queue, and Parked section current across transitions.

There is NO equivalent refresh on Step 5 (new-ticket creation) or Step 6 (in-place updates). When a new `.open.md` file lands, README.md is not updated. The ticket is absent from the WSJF Rankings until the next `/wr-itil:review-problems` invocation runs a full re-scan, or until the new ticket transitions and Step 7 triggers a refresh.

`/wr-itil:review-problems` is not run on any automatic cadence — it's invoked manually. So README.md accumulates staleness on every creation-only session.

Observed 2026-04-22 this session: before my session started, README.md's WSJF Rankings table listed open tickets up to P078. The filesystem had 13 newer open tickets (P073, P079-P090) that had never made it into the ranked table. The Verification Queue similarly lagged. During this session's run-retro, I had to surgically edit the table to insert P091 and P092 rather than regenerate the whole thing, because the rest of the table was stale baseline I couldn't trust or refresh without running the full WSJF re-rank myself.

## Symptoms

- New tickets are absent from `docs/problems/README.md` WSJF Rankings until either a transition or a manual `/wr-itil:review-problems`.
- Cross-session sessions see stale rankings even after the current session created several new open tickets.
- The README's "Last reviewed" parenthetical drifts from the on-disk reality — says "13 open tickets ranked" when there are actually 20+.
- Surgical edits (inserting a single new row) are the only feasible session-end refresh from within run-retro or manage-problem creation paths, because a full regeneration requires re-reading every ticket's WSJF value and handling tickets that don't have a stored WSJF field.
- The fast-path freshness check in `/wr-itil:manage-problem` Step 9 correctly detects the staleness (`git log --oneline` shows commits modifying problem files since the README commit) but the detection just triggers the slow-path re-scan — it does not fix the creation-path gap.

## Workaround

End each session with `/wr-itil:review-problems` to force a full regeneration. Not applied consistently; session-wrap usually skips this step because the user is done and the regeneration is relatively expensive (every ticket re-read, WSJF re-rated).

## Impact Assessment

- **Who is affected**: Every user who creates new tickets without also running `/wr-itil:review-problems`. In practice, that's essentially every session that creates tickets.
- **Frequency**: Every ticket creation that doesn't also trigger a transition.
- **Severity**: Minor — README staleness doesn't break any executable path, but it does mislead any reader (human or agent) who uses the README as the ranking source of truth. That's the README's stated purpose.
- **Analytics**: The README's "13 open tickets ranked" parenthetical vs `ls docs/problems/*.open.md | wc -l` is a direct drift indicator.

## Root Cause Analysis

### Root cause — confirmed

`/wr-itil:manage-problem` Step 5 (new-problem file creation) and Step 6 (bare-update edit) do not invoke the P062 README-refresh mechanism. P062's contract is scoped to Step 7 transitions only. This matches the original P062 design intent (transitions are the pre-existing refresh trigger), but the gap left by creation + update paths has now accumulated enough drift to be ticketed.

### Fix strategy

Add a P062-style README refresh to Step 5 and Step 6 in `packages/itil/skills/manage-problem/SKILL.md`:

- **Step 5 (creation)**: after writing the new `.open.md` file, regenerate `docs/problems/README.md` to insert the new ticket's row into the WSJF Rankings. The insertion uses the ticket's own stored WSJF value (trusted per P062's "render not re-rank" rule). Stage the README in the same commit as the new ticket.
- **Step 6 (update)**: if the update changed the ticket's Priority, Effort, or WSJF line, regenerate README.md to reflect the new ranking. If the update was to other sections (Root Cause Analysis, Related, etc.), skip the refresh — it's not load-bearing. Stage the README in the same commit as the update.

The refresh is a render, not a re-rank — existing WSJF values on other ticket files are trusted. This matches P062's existing discipline. The two new insertion points share the same underlying render function with Step 7's refresh.

A lighter alternative: run `/wr-itil:review-problems` automatically at the end of every `/wr-itil:manage-problem` creation or update commit. This guarantees full re-rank freshness but adds the full re-scan cost to every ticket creation. The P062-style surgical refresh is cheaper and matches P062's existing discipline.

### Investigation tasks

- [x] Investigate root cause (confirmed — P062 contract is scoped to Step 7 only; creation and update paths have no refresh).
- [ ] Decide between surgical refresh (P062-style) or full re-rank (review-problems invocation) for the creation + update paths. The surgical refresh is the likely pick for consistency with P062.
- [ ] Implement the Step 5 surgical refresh in manage-problem SKILL.md.
- [ ] Implement the Step 6 conditional refresh (only when Priority / Effort / WSJF line changed).
- [ ] Add a contract-assertion bats fixture: `manage-problem-step5-refreshes-readme.bats` asserting a new ticket creation commit contains `docs/problems/README.md` in its file list.
- [ ] Verify by creating a test ticket and confirming README.md ranking updates in the same commit.

## Fix Strategy

- **Kind**: improve
- **Shape**: skill
- **Target file**: `packages/itil/skills/manage-problem/SKILL.md` Step 5 + Step 6.
- **Observed flaw**: P062's README-refresh mechanism is scoped to Step 7 transitions only; new-ticket creation and in-place updates leave the README stale. Staleness accumulates silently across sessions.
- **Edit summary**: Add a P062-style surgical README refresh to Step 5 (creation) and a conditional refresh to Step 6 (update, only when Priority / Effort / WSJF changed). Stage the refreshed README in the same commit as the new ticket / updated ticket.
- **Evidence**:
  1. Before this session, README.md's WSJF Rankings table listed open tickets up to P078 only; filesystem had 13 newer open tickets (P073, P079-P090).
  2. run-retro Step 4a this session surgically inserted P091 + P092 rows into the table rather than regenerating — the rest was stale baseline I couldn't trust without a full re-rank.
  3. README.md's "13 open tickets ranked" parenthetical was stale vs. the on-disk count of 20+.

Chosen per run-retro Step 4b Stage 2 Option 2 (`Skill — improvement stub`). The fix is a bounded edit to an existing SKILL.md — no new concept, no new ADR required.

## Related

- **P062** (manage-problem README refresh on transitions — closed 2026-04-20 commit 7e19eab) — directly adjacent. P062 solved the transition-path refresh; this ticket extends the same mechanism to creation + update paths.
- **P048** (manage-problem verification-candidate detection — Verification Pending fast-path + `Likely verified?` column) — depends on an up-to-date README Verification Queue. Staleness in the creation path indirectly degrades P048's fast-path.
- **P076** (WSJF transitive dependencies — methodology update) — if creation-path refresh lands after P076, the rendering must also respect transitive effort re-rating.
- **P093** — sibling ticket this session about circular delegation between transition-problem and manage-problem. Distinct failure mode.
- **ADR-014** — governance skills commit their own work; any creation / update commit that now includes a README refresh must stay a single-commit transaction per ADR-014.

## Fix Released

Deployed in the next `@windyroad/itil` patch release (commit to follow). `packages/itil/skills/manage-problem/SKILL.md` Step 5 now unconditionally refreshes `docs/problems/README.md` after writing a new `.open.md`; Step 6 conditionally refreshes when Priority / Effort / WSJF lines change; Step 11's `git add` language now mandates the refreshed README is staged in the same commit as the ticket creation / ranking-changing update (ADR-014 single-commit transaction preserved).

Awaiting user verification: next ticket creation via `/wr-itil:manage-problem` should land `docs/problems/README.md` in the same commit as the new `.open.md` file, with the new ticket's row present in the WSJF Rankings table.
