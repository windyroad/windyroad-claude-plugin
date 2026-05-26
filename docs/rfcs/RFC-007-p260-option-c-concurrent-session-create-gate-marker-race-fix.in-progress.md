---
status: in-progress
rfc-id: p260-option-c-concurrent-session-create-gate-marker-race-fix
reported: 2026-05-26
decision-makers: [Tom Howard]
problems: [P260]
adrs: [ADR-071, ADR-050]
jtbd: [JTBD-006]
stories: []
---

# RFC-007: P260 — concurrent-session create-gate marker race fix (ADR-050 Option C)

**Status**: in-progress
**Reported**: 2026-05-26
**Problems**: P260
**ADRs**: ADR-071 (every fix goes through an RFC — why this retro-fit exists), ADR-050 (runtime-SID marker; amended in place for Option C)
**JTBD**: JTBD-006 (Progress the Backlog While I'm Away — the race fires during `/wr-itil:work-problems` AFK loops)

> **Retro-fit RFC (ADR-071 backfill).** The P260 Option-C fix was implemented and committed before ADR-071 ("every fix goes through an RFC, unconditionally") landed. This RFC brings that already-shipped fix under the RFC framework — the same RFC any fix gets — so its held `@windyroad/itil` changeset can release under the new unconditional gate. It carries **no independent decisions** (per ADR-070): the Option-C-vs-A/B choice was architect-resolved and user-confirmed, and recorded by amending **ADR-050** (referenced below, not re-argued here). Status is `in-progress` because the fix commits have landed and the changeset is queued; on release it advances to `verifying` alongside P260's `Known Error → Verifying` transition.

## Summary

P260: during a `/wr-itil:work-problems` AFK loop, the orchestrator main turn fires PreToolUse hooks concurrently with its backgrounded iter subprocess; both write the same per-machine runtime-sid marker (last-writer-wins), so the single-SID create-gate marker-write could land the marker under the wrong session ID — a mismatch that denied legitimate problem-ticket creation and forced a manual multi-UUID spam-write workaround.

The Option-C fix stops trying to predict which single session ID the Write's stdin will carry (impossible from agent-side state under concurrency) and instead writes the create-gate marker under every recent candidate session ID, so whichever SID the hook reads, a matching marker provably exists. The candidate set is bounded to recent same-machine markers (not a global fail-open), preserving the P119 audit invariant.

## Driving problem trace

- **P260** (`docs/problems/known-error/260-p119-create-gate-marker-race-between-concurrent-claude-sessions-via-shared-runtime-sid-file.md`) — P119 create-gate marker race between concurrent Claude sessions via the shared runtime-sid file. Status: Known Error (transition to Verifying release-gated). The fix is implemented; this RFC is the ADR-071 trace that lets the held changeset release.

## Scope

Ships the bounded multi-UUID create-gate marker-write (already implemented + committed):

- `packages/itil/hooks/lib/session-id.sh` — new `get_candidate_session_ids()` (enumerates the `get_current_session_id` pick plus every recent `/tmp/<system>-announced-<UUID>` announce-marker UUID within a 24h mtime window, deduplicated; bounded, not fail-open).
- `packages/itil/hooks/lib/create-gate.sh` — new `mark_step2_complete_candidates()` (writes the marker under each candidate SID via the unchanged single-SID `mark_step2_complete`).
- `/wr-itil:manage-problem` Step 2 + `/wr-itil:capture-problem` Step 2 — switched to the candidate-set marker-write.
- Behavioural bats (`session-id.bats` + `manage-problem-enforce-create.bats`) covering the concurrent orchestrator+subprocess scenario, including a negative control reproducing the pre-fix deny.

This RFC holds no decisions. The Option-C-vs-A/B fix-shape choice (Option A per-PID file rejected as structurally unsound; Option B announce-marker-mtime rejected as a confirmed P142 regression) was architect-resolved and user-confirmed, then recorded by **amending ADR-050 in place** (the falsified "orchestrator + own-subprocess: not a race" claim struck; Option C recorded as the chosen mitigation; `oversight-date` re-confirmed). See P260's ticket body + the ADR-050 "Amendment 2026-05-26" subsection.

## Tasks

All complete (retro — the commits landed before this RFC was captured):

- [x] `get_candidate_session_ids()` in `lib/session-id.sh`.
- [x] `mark_step2_complete_candidates()` in `lib/create-gate.sh`.
- [x] `/wr-itil:manage-problem` Step 2 + `/wr-itil:capture-problem` Step 2 switched to candidate-set write.
- [x] Behavioural bats (concurrent-session scenario + negative control); all green (bash + zsh).
- [x] ADR-050 amended in place (Option C recorded; falsified claim corrected; oversight re-confirmed).
- [x] `@windyroad/itil` patch changeset queued (`wr-itil-p260-option-c-multi-uuid-create-gate.md`).
- [ ] Release the held changeset → then P260 `Known Error → Verifying` + this RFC `in-progress → verifying`.

## Commits

(maintained automatically — the Option-C implementation commits predate this RFC's `Refs: RFC-007` trailer; this retro-fit documents them. The trailer convention applies to commits authored after capture.)

## Verification

The held `@windyroad/itil` changeset `wr-itil-p260-option-c-multi-uuid-create-gate.md` is the release marker. On release, P260 transitions `Known Error → Verifying` (per ADR-022) and this RFC transitions `in-progress → verifying`. User-side verification: the concurrent-session create-gate deny no longer fires during `/wr-itil:work-problems` AFK loops (the behavioural bats negative control already exercises the pre-fix deny vs the fixed path).

## Related

- **P260** — driving problem ticket (Known Error).
- **ADR-050** — runtime-SID marker introduction; amended in place 2026-05-26 to record Option C as the concurrent-session race mitigation.
- **ADR-071** — every fix goes through an RFC; this retro-fit is the backfill that brings the pre-ADR-071 P260 fix under the RFC framework.
- **RFC-006** — the ADR-070/071 implementation RFC; this retro-fit is its slice 7.
- **P124 / P142 / P119** — agent-side SID discovery helper history, runtime-SID introduction, and the create-gate hook contract the fix composes with.
