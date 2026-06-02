# Problem 260: P119 create-gate marker race between concurrent Claude sessions via shared runtime-sid file

**Status**: Verifying
**Reported**: 2026-05-18
**Priority**: 6 (Medium) — Impact: 2 (Minor — capture-problem Write is blocked until workaround applies; not destructive) x Likelihood: 3 (Likely — fires whenever orchestrator main turn captures a ticket while an iter subprocess is also active, which is the standard /wr-itil:work-problems shape)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; per-PID/per-session runtime-sid file naming)

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-007 | verifying | P260 — concurrent-session create-gate marker race fix (ADR-050 Option C) |

## Fix Released

Released in **`@windyroad/itil@0.35.14`** (release commit `bf1ebdd`, 2026-05-26) — the Option-C bounded multi-UUID create-gate marker-write shipped to adopters. Brought under the RFC framework as **RFC-007** (retro-fit per ADR-071 — every fix goes through an RFC) so the held changeset could release under the new unconditional gate. Transitioned `Known Error → Verifying` on release per ADR-022.

**User verification gate**: the concurrent-session create-gate deny no longer fires during `/wr-itil:work-problems` AFK loops (the behavioural bats negative control already reproduces the pre-fix deny vs the fixed candidate-set path). Verifying → Closed on user confirmation.

## Description

Surfaced 2026-05-18 during session 6's foreground captures (P254, P255) while iter 1 subprocess was running concurrently. The P119 PreToolUse:Write hook reads `session_id` from its stdin JSON payload to identify the marker `/tmp/manage-problem-grep-${SESSION_ID}`. The agent-side `get_current_session_id` helper at `packages/itil/hooks/lib/session-id.sh` reads from `/tmp/itil-runtime-sid-tomhoward-3038058228.current` (per-machine file written by `itil-runtime-sid-marker.sh` on every PreToolUse:Bash/Write/Edit/Read).

**The runtime-sid file is per-MACHINE, not per-PROCESS.** When the orchestrator main turn (session A) and an iter subprocess (session B with different SESSION_ID) BOTH fire PreToolUse hooks, both write to the SAME runtime-sid file. Last writer wins.

So when the orchestrator main turn ran:
1. `Bash get_current_session_id` returned session A's SID (runtime-sid file was last written by session A's PreToolUse:Bash)
2. `Bash mark_step2_complete "<session-A-SID>"` set the marker
3. (iter subprocess ran several tool calls, overwriting runtime-sid to session B's SID)
4. `Write docs/problems/open/254-...md` — PreToolUse:Write hook read stdin SESSION_ID = session A (orchestrator's real SID, not affected by runtime-sid clobber); checked marker at `/tmp/manage-problem-grep-<session-A>` — FOUND, but actually NO — the agent's earlier mark may have been under a DIFFERENT SID because get_current_session_id fell through to announce-marker fallback (no runtime-sid present at that moment)

The race produces a marker-vs-Write mismatch: marker exists under SID X, but Write's stdin SESSION_ID is SID Y. Hook denies.

Workaround used: spam-write the marker under ALL recent UUIDs found in `/tmp/<system>-announced-*` markers + the current runtime-sid value. Whichever SID the Write's stdin actually carries, the marker exists.

## Symptoms

- `claude plugin install` and other tool calls from concurrent sessions interleave their runtime-sid writes; the per-machine file's last-writer-wins shape causes agent-side `get_current_session_id` to return the wrong session's SID.
- P119 create-gate marker mismatch causes PreToolUse:Write deny with `BLOCKED: Cannot Write '<file>' under docs/problems/ without running /wr-itil:manage-problem Step 2 (duplicate-check) first.`
- Workaround spam-writes the marker under 10+ UUIDs to ensure coverage.

## Workaround

Spam-write `/tmp/manage-problem-grep-<sid>` under EVERY recent announce-marker UUID (from `/tmp/<system>-announced-*` filenames) + the current runtime-sid value. Documented in the orchestrator's main-turn capture flow.

## Impact Assessment

- **Who is affected**: Any orchestrator main turn that creates a ticket while an iter subprocess is active. Standard `/wr-itil:work-problems` AFK loop shape.
- **Frequency**: Likely (3) — fires on every foreground capture during AFK loop runs.
- **Severity**: Minor — workaround works; no data loss; just an extra Bash invocation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [x] Architect verdict on the fix shape — **resolved 2026-05-26** (see "Architect verdict" below). Option C (bounded multi-UUID marker-write) is the only structurally sound option; A and B are disqualified. The fix AMENDS ADR-050 (Phase 5, not a new ADR) but the amendment re-opens an accepted-limitation posture on a human-oversight-confirmed ADR ⇒ ADR-044 category-2 deviation-approval ⇒ escalated to the user (queued at this iteration's `outstanding_questions`), NOT force-implemented in-AFK.
  - **Option A**: Per-PID runtime-sid file (e.g. `/tmp/itil-runtime-sid-tomhoward-<pid>.current`) — each process writes its own file; agent-side helper reads `$PPID` or similar.
  - **Option B**: Stop using runtime-sid at all in `get_current_session_id`; rely on announce-marker most-recent-mtime fallback exclusively (the existing fallback path).
  - **Option C**: Make the spam-write workaround the documented contract — agent always marks under all recent UUIDs.
- [x] Update P124 (agent-side SID discovery helper) Change Log to document this race — **done 2026-05-26** (P124 `## Related` + post-Phase-4 note cross-reference P260).
- [x] **ADR-050-posture direction RESOLVED 2026-05-26 (user, P283 prong-2 drain): amend ADR-050 in place** (not supersede). DONE: ADR-050 frontmatter `amended: 2026-05-26` + oversight re-confirmed (`oversight-date: 2026-05-26`); Race-mitigation section's "orchestrator + own subprocess: not a race" claim struck-through + corrected via an "Amendment 2026-05-26" subsection recording the falsification + Option C as the chosen mitigation + the line-191 reassessment-trigger-met note. Architect + JTBD PASS. The deviation-approval is now discharged — Option C may be implemented.
- [x] **Implement Option C** — **done 2026-05-26** (see "Implementation 2026-05-26" below). Bounded multi-UUID create-gate marker-write shipped in `packages/itil/hooks/lib/session-id.sh` (`get_candidate_session_ids`) + `create-gate.sh` (`mark_step2_complete_candidates`); both `manage-problem` Step 2 substep 7 and `capture-problem` Step 2 switched to the candidate-set write; `@windyroad/itil` patch changeset queued. **Transition to Verifying is release-gated** — deferred to the orchestrator's Step 6.5 release cadence (this iteration commits but does NOT release per the AFK constraint; ticket stays Known Error until the fix ships).
- [x] Behavioural bats coverage for concurrent-session scenario — **done 2026-05-26** (see below).

### Architect verdict (2026-05-26)

Investigated this iteration via `wr-architect:agent` delegation (decision-discipline step 1). Verdict: **NEEDS DIRECTION** — structurally one sound fix, but it changes a human-oversight-confirmed ADR's posture, so it escalates rather than force-implements.

**Fix-shape ranking (framework-resolvable on structural grounds):**

- **Option A — per-PID runtime-sid file: REJECTED (structurally unsound).** The marker is *written* by the Claude Code PreToolUse hook process (`itil-runtime-sid-marker.sh`) and *read* by the agent-side Bash-tool subshell (`get_current_session_id` sourced into a Bash call). These are different short-lived processes spawned per-tool-call; the hook's PID changes every call. Per-PID scoping needs a *stable shared* identifier (a common ancestor, e.g. the Claude Code session process PID), but whether `$PPID` from each resolves to that common ancestor is unspecified by the Claude Code hook contract and platform-dependent (Claude Code may spawn hooks and Bash tools as siblings under a shell wrapper, not as children of one stable session process). Trades a known, observable, recoverable failure (visible Write deny) for an unverified process-topology assumption.
- **Option B — drop runtime-sid; rely on announce-marker mtime fallback: REJECTED (confirmed P142 regression).** This is exactly the Phase 3 mechanism ADR-050 §Context documents as broken. `session-id.sh` line 146 selects `ls -t … | head -1` (newest mtime within a system); ADR-038 establishes announce markers as write-once on first UserPromptSubmit, so their mtime IS the session's first-prompt timestamp. In an orchestrator-main-turn-after-dispatch, the subprocess announced *later* ⇒ newer mtime ⇒ `head -1` returns the subprocess SID while the orchestrator's Write stdin carries the orchestrator SID ⇒ mismatch ⇒ deny. ADR-050 line 31 already proved no pure-helper filesystem algorithm can disambiguate orchestrator-vs-subprocess context.
- **Option C — make bounded multi-UUID marker-write the documented contract: CHOSEN (structurally sound).** Only option that survives scrutiny. It **inverts the binding direction**: A and B both try to *predict* which single SID the Write's stdin will carry — the thing that cannot be done reliably from agent-side state under concurrency. C stops predicting and writes the create-gate marker under *every* candidate SID (recent `/tmp/<system>-announced-*` UUIDs + the runtime-sid value), so whichever SID the hook reads from its own stdin at Write-time, a matching marker provably exists. The P119 audit-trail invariant is preserved (the marker still proves the duplicate-check grep ran *this session* — the candidate set is bounded to recent same-machine announce markers, not a global fail-open). No process-topology dependency; degrades gracefully. **Refinement to codify:** bound the candidate set explicitly (announce-marker UUIDs within an mtime window + current runtime-sid value), so the contract is deterministic and bats-testable — not "all UUIDs ever seen in /tmp".
- **Lock-file / per-process-tree (ADR-050 line 191's other named candidates): do not help.** A `flock` lock-file does not solve P260 — the problem is not a torn write, it is *legitimately-concurrent writers each correctly recording their own different SID*; serialising still leaves last-writer-wins. Per-process-tree scoping reduces to Option A and inherits the same `$PPID`-ancestry uncertainty.

**Routing — AMENDS ADR-050 (Phase 5); does NOT need a new ADR; but ESCALATES as category-2 deviation-approval:**

The fix stays entirely within ADR-050's mechanism surface (runtime-SID marker + `get_current_session_id` consumption + create-gate marker write); it adds no new semantic marker class (Option C reuses the *existing* announce markers + runtime-sid value). ADR-050's Reassessment Criteria (line 191) **pre-authorises** exactly this revisit: *"A pattern of same-project parallel-session races emerges → revisit race-mitigation (per-process-tree marker scoping, lock-file protocol, etc.)."* P260 is that pattern.

**Falsified-claim correction (load-bearing).** ADR-050 §Race-mitigation lines 116-117 assert orchestrator+own-subprocess is *"not a race … orchestrator-side tool calls do not fire during subprocess execution."* This is **false**: `packages/itil/skills/work-problems/SKILL.md` Step 5 (~lines 333-339) **backgrounds** the iter dispatch (`claude -p … &`) and runs a `kill -0 … sleep` idle-timeout poll loop (P121) in the orchestrator's own turn — so the orchestrator main turn demonstrably fires PreToolUse hooks concurrently with the running subprocess (the foreground P254/P255 captures that surfaced this ticket). ADR-050's accepted-limitation (lines 113-115, 160) scoped the same-project race to *two separate developer sessions* and explicitly excluded the orchestrator+subprocess case — that exclusion is wrong.

Changing the accepted-limitation posture of an ADR that carries `human-oversight: confirmed, oversight-date: 2026-05-25` (confirmed the day before this verdict) is an ADR-044 **category-2 (deviation approval)** decision — not mechanical, and not something an AFK iter may silently rewrite (cf. `feedback_lift_auto_decisions_to_human`). The **fix-shape pick (Option C)** is framework-resolvable; only the **ADR-050 posture amendment** needs user sign-off. They are inseparable here (codifying Option C *is* the posture change), so both queue together. The architect's advisory lean: Phase-5 amend ADR-050 in place (correct lines 116-117, move orchestrator+own-subprocess into the accepted-and-now-mitigated section, record Option C as the mitigation, re-confirm `oversight-date`) over superseding it with a new ADR. See this iteration's `outstanding_questions` (deviation-approval entry).

### Implementation 2026-05-26 (Option C shipped, pending release)

Implemented via `/wr-itil:manage-problem` AFK iteration. Architect + JTBD gates PASS (Option C was already architect-resolved + human-confirmed; this was an implementation-compliance review). Surfaces landed:

- **`packages/itil/hooks/lib/session-id.sh`** — new `get_candidate_session_ids()`. Echoes one candidate SID per line, deduplicated: the `get_current_session_id` pick (env-var > runtime-sid > announce-marker priority — guaranteed superset of prior single-SID behaviour) PLUS every recent `/tmp/<system>-announced-<UUID>` UUID across all systems within an mtime window (`find -maxdepth 1 -name '*-announced-*' -mmin -${window}`). Window default 1440 min (24h), overridable via `SESSION_CANDIDATE_WINDOW_MINS`; marker dir overridable via `SESSION_MARKER_DIR`. Bounded set (not a global fail-open): 24h covers any realistic AFK loop while excluding the P124 stale-marker pathology (103 accumulated UUIDs). Extra markers under recently-stale UUIDs are harmless empty files; the hook only matches the marker equal to the Write's stdin SID. `get_current_session_id` and the announce-marker priority logic are UNCHANGED.
- **`packages/itil/hooks/lib/create-gate.sh`** — new `mark_step2_complete_candidates()`. Reads candidate SIDs from stdin, calls the unchanged single-SID `mark_step2_complete` for each (same `/tmp/manage-problem-grep-${SID}` marker class — no new convention). Returns 0 if ≥1 marker written, 1 if none (fail-closed parity).
- **`manage-problem` Step 2 substep 7 + `capture-problem` Step 2** — both switched from `sid=$(get_current_session_id) && mark_step2_complete "$sid"` to `get_candidate_session_ids | mark_step2_complete_candidates`. manage-problem gained a "Phase 5 (P260 / ADR-050 Option C)" note correcting the Phase-4 "structurally impossible" claim for the concurrent case.
- **Behavioural bats** — `session-id.bats` gained 6 candidate-enumeration tests (both-SIDs, runtime-sid inclusion, dedupe, mtime-window exclusion, empty, env-var inclusion); `manage-problem-enforce-create.bats` gained 2 end-to-end concurrent-session tests including a **negative control** that reproduces the pre-Option-C deny under the same fixture. All 57 tests across the three affected hook test files pass (bash + zsh verified). Behavioural-only per ADR-052 / P081.
- **`.changeset/wr-itil-p260-option-c-multi-uuid-create-gate.md`** — `@windyroad/itil` patch.
- **ADR-050** — already amended in place 2026-05-26 (frontmatter `amended:`, struck-through false claim, "Amendment 2026-05-26" Option-C subsection); no further ADR change required to ship.

**Verifying transition deferred**: this iteration committed the fix but did NOT release (AFK constraint — the `/wr-itil:work-problems` orchestrator Step 6.5 owns release cadence). The ticket stays Known Error until the fix ships; transition to `.verifying.md` per ADR-022 fires on release.

## Dependencies

- **Blocks**: (none — workaround keeps captures functional)
- **Blocked by**: (none)
- **Composes with**: P124 (P119 create-gate hook contract), P142 / ADR-050 (runtime-SID instrumentation introduction)

## Related

- `packages/itil/hooks/lib/session-id.sh` `get_current_session_id` — the helper that reads the racy file.
- `packages/itil/hooks/itil-runtime-sid-marker.sh` — the PreToolUse hook that WRITES the racy file.
- `packages/itil/hooks/manage-problem-enforce-create.sh` — the P119 create-gate hook that reads stdin SESSION_ID (not affected by runtime-sid clobber, but its marker may be missing under the right SID).
- P124 — agent-side SID discovery helper history.
- P142 / ADR-050 — runtime-SID introduction.

(captured via /wr-retrospective:run-retro Step 4b Stage 1; expand at next investigation)
