# Problem 157: Ship pending-questions-surface hook — auto-surface accumulated `outstanding_questions` from `.afk-run-state/outstanding-questions.jsonl` at session start when user returns interactive

**Status**: Verification Pending
**Reported**: 2026-05-03
**Priority**: 12 (High) — Impact: Significant (3) x Likelihood: Almost certain (4)
**Effort**: M — new SessionStart hook + parser for `outstanding-questions.jsonl` + ranking per ADR-044 6-class taxonomy + AskUserQuestion batch construction (≤4 per call) + cleanup-on-resolve. Hook fires on session-start when `outstanding-questions.jsonl` is non-empty and `AskUserQuestion` is available.

**WSJF**: (12 × 1.0) / 2 = **6.0**
**Type**: technical

> Surfaced 2026-05-03 by user direction post-AFK-loop-restart: split P014 (ADR-032 master tracker) into its three planned children. P157 is the third and final child — the pending-questions-surface hook that auto-fires the Step 2.5 / 2.5b loop-end emit shape when the user returns to an interactive session with accumulated outstanding_questions. Sibling to P155 (capture-problem) and P156 (capture-adr).

## Description

Per P135 Phase 3 + ADR-044 framework-resolution boundary, AFK iters accumulate `outstanding_questions` entries to `.afk-run-state/outstanding-questions.jsonl` between iters. Loop-end Step 2.5 (and halt-path Step 2.5b) read the queue + present batched via `AskUserQuestion`. This works correctly when the orchestrator main turn reaches Step 2.5 — but the queue file persists across session boundaries, and if a session ends BEFORE Step 2.5 fires (e.g. user manually stops the loop, quota exhausts mid-iter, network failure halts the orchestrator), the accumulated questions linger unread.

This very session is the empirical evidence:

- iter 12 accumulated 2 outstanding direction questions (P014 child-split + briefing Tier 3 MUST_SPLIT).
- Loop ran for ~16 hours wall-clock; 9 more iters accumulated more findings.
- User stopped the loop manually post-restart, asked for the questions to be surfaced via "you should ask me the questions now, while I'm here".
- The questions were sitting in `.afk-run-state/outstanding-questions.jsonl` waiting; only fired because the user explicitly asked.

**Without P157**, the `outstanding-questions.jsonl` queue file accumulates indefinitely across sessions and either:
1. Loses content when overwritten by the next loop without surfacing
2. Stays unread until the user manually inspects it (which they almost never do)
3. Gets re-asked redundantly when the next loop hits Step 2.5 (queue file isn't cleared between sessions)

**With P157**, a SessionStart hook reads the queue file on session start, ranks accumulated entries per ADR-044 taxonomy (deviation-approval > direction > one-time-override > silent-framework > taste > correction-followup), and auto-fires `AskUserQuestion` (batched ≤4 per call) so the user resolves on their next interactive turn before they begin foreground work.

Composes with: P155 (capture-problem — captured tickets aren't outstanding_questions; the two surfaces are distinct); P156 (capture-adr — same separation); P135 (master ticket — P157 closes the loop on the queue-file lifecycle); P130 (transient-user discipline — P157 makes presence-detection a no-op since the hook fires deterministically on session start).

## Symptoms

- Queue file `.afk-run-state/outstanding-questions.jsonl` persists across session boundaries with accumulated entries no one has resolved.
- User restarts session post-AFK-loop and expects the queue to surface but has to manually ask.
- Multiple sessions over multiple days could accumulate redundant entries (the same direction-question asked across N iters because the user never actually resolved it).
- AFK loops that halt before Step 2.5 fire (e.g. quota exhaust, user manual stop, network failure) leave queue entries dangling.

## Workaround

Currently: user manually checks `.afk-run-state/outstanding-questions.jsonl` and asks the agent to surface. Brittle.

Sub-workarounds:
- Loop's Step 2.5 / 2.5b at-loop-end emits, but only when the loop reaches that step. Many halt paths don't reach it.
- Orchestrator main-turn manual surface (this session — agent fired AskUserQuestion when user said "ask me the questions now"). Manual; depends on agent recalling the queue exists.

## Impact Assessment

- **Who is affected**: Solo-developer (queue-file accumulation across sessions) + AFK orchestrator (halt-path loss). Plugin-user persona unaffected.
- **Frequency**: Every AFK loop session. Continuous risk class.
- **Severity**: Significant — accumulated direction-questions that don't surface drift the agent's behaviour from user's intent silently.
- **Likelihood**: Almost certain — known gap.
- **Analytics**: This session — 2 entries accumulated for ~16 hours; only surfaced because user explicitly asked. Without P157, those 2 entries plus any from future loops would accumulate indefinitely.

## Root Cause Analysis

### Preliminary Hypothesis

The fix shape:

1. **New SessionStart hook** at `packages/itil/hooks/itil-pending-questions-surface.sh` (or sibling plugin if more appropriate per architect review).
2. **Hook contract**:
   - Read `.afk-run-state/outstanding-questions.jsonl` (path resolved relative to `${CLAUDE_PROJECT_DIR}` if available, else `pwd`).
   - If file missing or empty: silent-on-pass per ADR-045 Pattern 1; return.
   - If file non-empty: parse JSONL, dedupe identical entries (same category + question + ticket_id), rank per ADR-044 6-class taxonomy.
   - If `AskUserQuestion` is available: emit a structured directive (via JSON output mode) that the agent fires AskUserQuestion on first turn (batched ≤4 per call, sequential when >4).
   - If `AskUserQuestion` is unavailable (restricted permission mode): emit a structured-summary directive listing entries as a fallback table.
   - On user resolution (entry's question answered): rewrite the queue file removing the resolved entries.
3. **Cleanup-on-resolve** — the hook OR the agent's first-turn handler removes resolved entries from the queue file. Empty queue → next session-start no-op.
4. **Composes with P135 master schema** — uses the same ADR-044 6-class taxonomy + the deviation-candidate shape; doesn't fork the schema.

### Investigation Tasks

- [x] Architect review — `@windyroad/itil` plugin home + SessionStart hook + ADR-040 Option A precedent. Verdict PASS-WITH-NOTES (8 actionable items folded in; ADR-040 cited over ADR-045 for SessionStart-specific silent-on-no-content shape; env-var self-suppress per ADR-032 line 127 implementation choice (a)).
- [x] JTBD review — PASS. Primary JTBD-006 (Progress backlog AFK), secondary JTBD-001 + JTBD-101.
- [x] Implement: hook script `packages/itil/hooks/itil-pending-questions-surface.sh` + JSONL parser via `jq -e` + ADR-044 6-class precedence ranking + dedup on `(rank, category, ticket_id, question)` + cleanup-on-resolve directive + behavioural bats `packages/itil/hooks/test/itil-pending-questions-surface.bats` (19/19 green).
- [x] Wire into `packages/itil/hooks/hooks.json` SessionStart array as second entry with matcher `"startup"`.
- [x] Insert `export WR_SUPPRESS_PENDING_QUESTIONS=1` in `packages/itil/skills/work-problems/SKILL.md` Step 5 dispatch block before `claude -p` to prevent cross-context leak per ADR-032 line 127.
- [x] Amend ADR-032 with the P157 SessionStart-JSONL-variant section paralleling P155 + P156 amendments.

## Fix Released

Hook + ADR amendment + work-problems Step 5 export shipped 2026-05-03 in iter4 of the AFK loop alongside siblings P155 + P156 (the three ADR-032 child tickets). Awaiting user verification:
- Hook surfaces accumulated queue on SessionStart (dogfood: ran end-to-end against 9-entry real queue, ranked deviation-approval > direction > silent-framework correctly).
- 19/19 behavioural bats green (silent-on-no-content × 3, surfacing × 2, ranking × 2, dedup × 2, batching × 2, cleanup × 1, env-var suppress × 2, hooks.json wiring × 1, work-problems Step 5 export × 1, malformed-JSON skip × 2, exists × 1).
- Verification: next AFK loop end-to-end. The orchestrator's iter subprocesses must NOT see the queue (env-var suppresses); the orchestrator's main turn on session resume must see it via SessionStart hook.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — P135 schema landed; ADR-044 + ADR-038 + ADR-045 patterns shipped)
- **Composes with**: P155 (sibling — capture-problem); P156 (sibling — capture-adr); P014 (parent — ADR-032 master); P135 (master schema for outstanding_questions); P130 (transient-user discipline — P157 is the structural form of "treat user as transient — surface on return")

## Related

- P014 — parent / master tracker.
- P155 / P156 — siblings.
- P135 (`docs/problems/135-...verifying.md`) — outstanding_questions schema this hook reads.
- P130 (`docs/problems/130-...verifying.md`) — transient-user discipline this hook structurally implements.
- ADR-044 (decision-delegation contract) — 6-class taxonomy for ranking entries.
- ADR-045 (silent-on-pass hook pattern) — empty-queue silence.
- `.afk-run-state/outstanding-questions.jsonl` — queue file shape per P135 Phase 3.
