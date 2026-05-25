# Problem 260: P119 create-gate marker race between concurrent Claude sessions via shared runtime-sid file

**Status**: Known Error
**Reported**: 2026-05-18
**Priority**: 6 (Medium) — Impact: 2 (Minor — capture-problem Write is blocked until workaround applies; not destructive) x Likelihood: 3 (Likely — fires whenever orchestrator main turn captures a ticket while an iter subprocess is also active, which is the standard /wr-itil:work-problems shape)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; per-PID/per-session runtime-sid file naming)
**Type**: technical

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
- [ ] Behavioural bats coverage for concurrent-session scenario — deferred to implementation (blocked on the escalated ADR-050-posture direction below).

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
