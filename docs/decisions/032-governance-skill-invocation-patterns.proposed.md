---
status: "proposed"
date: 2026-04-21
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-21
supersedes: [027-governance-skill-auto-delegation]
---

# Governance skill invocation patterns — foreground + background with deferred-question resumption

## Context and Problem Statement

`ADR-027` (Governance skill auto-delegation) mandated a single execution pattern for every governance skill (`manage-problem`, `create-adr`, `run-retro`, `manage-incident`, `work-problems`): Step 0 delegates to a subagent synchronously; the main agent blocks on the subagent's final report; main agent never executes Steps 1-N in its own context. The model provided strong context isolation and made reviewer subagents the authoritative read-only surface.

In practice the synchronous model conflicts with the user's documented need captured in P014:

> "working on X, notice Y, log Y, keep working on X, don't forget Y"

When an aside-worthy observation surfaces mid-task (a problem noticed in passing, a retro entry, an ADR-worthy decision), the synchronous model forces the user to either (a) invoke the governance skill and consume the current turn on its full intake flow, or (b) accept the friction of remembering to capture the observation later. Both outcomes are the "manually police AI output" pain pattern JTBD-001 is designed against. The user's direction (2026-04-21 interactive): keep the existing foreground skills for full-intake invocations AND add sibling `capture-*` skills that run in background via `Agent(run_in_background: true)`. Supersede ADR-027; don't just layer on top.

Three existing skills get a background-capable sibling or move to a background-oriented default:

- `/wr-itil:capture-problem` — NEW sibling of `manage-problem`; background; captures a problem ticket from aside context.
- `/wr-retrospective:capture-retro` — **DEFERRED pending resolution of the context-marshalling problem (P088, 2026-04-21 user direction)**. Background subagents have isolated context at spawn and cannot see the parent session's tool-call history, which is run-retro's primary input. The other two `capture-*` siblings have self-contained aside payloads (the problem observation; the architectural decision); retro's input is the entire session's tool-call history with no self-contained substitute. The sibling is preserved on this list as a placeholder and re-shipped only once the retro-context-layer taxonomy is defined; until then, foreground `/wr-retrospective:run-retro` and the `claude -p` subprocess invocation (P086) remain the only supported retro surfaces. See P088 for the full settlement.
- `/wr-architect:capture-adr` — NEW sibling of `create-adr`; background; captures an ADR from aside context.

Existing synchronous skills (`manage-problem`, `create-adr`, `run-retro`, `manage-incident`, `work-problems`) remain available as foreground invocations for users who want the full interactive flow. The sibling-naming pattern matches `feedback_skill_subcommand_discoverability.md` — each distinct user intent is its own skill discoverable via `/` autocomplete, not an argument-based subcommand (P071).

Interactive branches within background skills (AskUserQuestion prompts) cannot block the main thread — the main agent has moved on; the user doesn't know the subagent is waiting. This ADR defines a **deferred-question resumption contract** that pauses the subagent, surfaces the question through the main agent at its next natural pause, collects the answer, and resumes the subagent with the answer in its input.

## Decision Drivers

- **JTBD-001** (Enforce Governance Without Slowing Down) — "reviews complete in under 60 seconds so they don't break flow" closes for mid-task captures: the aside goes to a background subagent; the main thread continues.
- **JTBD-003** (Compose Only the Guardrails I Need) — sibling-skill pairs (foreground + background) are independently composable. Projects that want only the heavyweight foreground flow stay on it; projects that want background captures add the `capture-*` skills.
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK orchestrator iterations stay synchronous under this ADR (see Scope). ADR-018 drain-ownership and ADR-019 preflight-ownership untouched.
- **JTBD-101** (Extend the Suite with New Plugins) — the sibling-skill pattern (foreground + `capture-*` background) is the repeatable convention future plugin developers follow when they want to offer both modes. No argumented-subcommand anti-pattern (per P071 and `feedback_skill_subcommand_discoverability.md`).
- **JTBD-201** (Restore Service Fast with an Audit Trail) — foreground edit-gate and commit-gate hooks stay foreground (must block); audit trail integrity preserved.
- **P014** (No lightweight aside invocation for governance skills) — closed at the design level by this ADR.

## Considered Options

1. **Foreground + background with deferred-question resumption (chosen)** — user's pinned direction. Supersedes ADR-027. Sibling `capture-*` skills run in background; existing foreground skills preserved. AskUserQuestion branches inside background skills defer via a pending-questions marker.

2. **Keep ADR-027 synchronous; re-pin P014 to work inside it** — rejected by the user ("happy to supersede previous decisions"). The synchronous model's Step-0 delegation doesn't cleanly support "log Y, keep working on X" because the main agent still blocks on the subagent's final report.

3. **Hybrid: ADR-027 synchronous by default + optional background opt-in pattern** — rejected. Two coexisting patterns multiply the per-skill decision surface; sibling-skill naming is a simpler discoverable alternative.

4. **Fire-and-forget without deferred-question resumption** — rejected on architect review. Background skills that hit AskUserQuestion would silently block the subagent (user doesn't know subagent is waiting), violating ADR-013 Rule 6's fail-safe requirement.

5. **Thin stubs (original P014 framing)** — not what the user wanted. User clarified 2026-04-21: full intake runs in the background; not just a stub that gets fleshed out later.

## Decision Outcome

**Chosen option: Option 1** — foreground preserved; sibling `capture-*` skills run in background; deferred-question resumption contract handles interactive branches.

### Pattern taxonomy

Every governance invocation surface falls into one of these four patterns. Skills pick per invocation, not per skill identity (a single skill can be invoked foreground OR via its `capture-*` sibling).

| Pattern | Main-thread behaviour | Use | Examples |
|---|---|---|---|
| **Foreground synchronous** | Main agent invokes; skill runs; main agent consumes full output and resumes. | Full-intake governance flows; user wants to be in the loop for every step. | `/wr-itil:manage-problem`, `/wr-architect:create-adr`, `/wr-retrospective:run-retro`, `/wr-itil:manage-incident`. |
| **Background capture** | Main agent spawns `Agent(run_in_background: true)`; main agent continues immediately; subagent runs full intake; subagent commits its own work per ADR-014; main agent may notice the completion via file artefacts at its next natural pause. | Mid-task asides; user's cognitive load stays on the main task. | `/wr-itil:capture-problem` (NEW), `/wr-retrospective:capture-retro` (NEW), `/wr-architect:capture-adr` (NEW). |
| **Foreground edit-gate** | PreToolUse hook; blocks the tool call; delegates to a reviewer subagent; permits on PASS. Unchanged by this ADR. | Edit-time governance (architect, jtbd, voice-tone, style-guide review). | `packages/architect/hooks/architect-enforce-edit.sh`, `packages/jtbd/hooks/jtbd-enforce-edit.sh`, etc. |
| **Foreground commit-gate** | PreToolUse hook on git commit; delegates to `wr-risk-scorer:pipeline`. Unchanged by this ADR. | Commit-time risk scoring. | `packages/risk-scorer/hooks/risk-gate.sh` family. |
| **Foreground fresh-context-subagent-as-decision-arbiter** | Main agent invokes a fresh subagent via the Agent tool from inside SKILL.md control flow; subagent reads only the structured inputs (no session-context bias); subagent emits a structured verdict; calling SKILL acts on the verdict deterministically (halt-and-route, proceed, or transform). Added under P346 amendment, 2026-05-31. | Capture-time / lifecycle-time decisions where the main agent's session-context biases the call (pattern-matches existing flows, fails to recognise alternatives). | `wr-itil:hang-off-check` (capture-time inflow discipline — absorb-into-parent vs proceed-as-new); slot for future inflow / lifecycle arbiters. |

### Skill-to-pattern assignments under this ADR

**Preserved foreground (unchanged from ADR-027's in-scope list, minus Step 0)**:
- `/wr-itil:manage-problem` — foreground synchronous. No Step 0 delegation. Main agent runs the skill directly.
- `/wr-architect:create-adr` — foreground synchronous. No Step 0 delegation.
- `/wr-retrospective:run-retro` — foreground synchronous. No Step 0 delegation.
- `/wr-itil:manage-incident` — foreground synchronous. No Step 0 delegation.
- `/wr-itil:work-problems` — **special case**. The orchestrator itself runs in a subagent (per the current ADR-027 framing). Under this ADR the orchestrator is still a subagent but its iteration delegations remain synchronous per ADR-018 / ADR-019; AFK-iteration-spawned governance subagents do not use the background pattern (see AFK carve-out below).

**New background siblings**:
- `/wr-itil:capture-problem` — background. Takes an aside payload (one-line description + trigger context) as its prompt, spawns the full manage-problem intake flow as a background subagent, commits the resulting problem ticket per ADR-014.
- `/wr-retrospective:capture-retro` — **DEFERRED (P088, 2026-04-21).** Background-capture pattern does not fit retro's input shape: the input is the parent session's whole tool-call history, not a self-contained aside payload. A background retro would either run on isolated empty context (useless), require explicit context-marshalling at spawn (rejected by user direction as "shenanigans"), or post-hoc parse `~/.claude/projects/*/sessions/*.jsonl` (out of scope). Foreground `/wr-retrospective:run-retro` and the `claude -p` subprocess invocation (P086 retro-on-exit clause) cover the supported surfaces; the background sibling is re-shipped only when the retro-context-layer taxonomy is defined. The other two `capture-*` siblings are unaffected — their aside payloads are self-contained. See **P088**.
- `/wr-architect:capture-adr` — background. Takes an aside payload (decision context + options-considered sketch), spawns a background ADR-drafting subagent that produces an initial draft at `.proposed.md`; the draft becomes the starting point for a subsequent foreground `create-adr` flesh-out OR (if the draft is complete enough) the subagent commits the ADR directly.

### AFK carve-out (per architect option (a))

Background capture pattern does NOT apply inside AFK orchestrator iterations. `/wr-itil:work-problems` iterations stay synchronous: the iteration subagent delegates to `manage-problem` in its own foreground flow; no `capture-*` invocations fire inside the loop; ADR-018 drain-ownership and ADR-019 preflight-ownership remain in orchestrator main context. Rationale: AFK orchestrators depend on synchronous observability-between-iterations (Step 6.5 drain checks, Step 6.75 inter-iteration verification); fire-and-forget breaks those preconditions.

Background pattern is available for USER-INITIATED (non-AFK) invocations only. A background skill launched from a foreground skill (standard `Agent` semantics) is explicitly allowed — the foreground-skill's main agent launches the background subagent and continues its own flow.

### AFK iteration-isolation wrapper (P077 amendment, 2026-04-21)

The AFK carve-out above says iterations "stay synchronous" and "delegate to `manage-problem` in its own foreground flow". P077 sharpens **how** that delegation happens: the AFK orchestrator's main turn MUST spawn each iteration as a **synchronous `general-purpose` subagent via the Agent tool** — not via the Skill tool (in-process expansion).

This is a first-class sub-pattern under Foreground synchronous. It is distinct from the row-one "main agent invokes; skill runs; main agent consumes full output" case because the iteration subagent's SKILL.md expansion (manage-problem is 500+ lines) happens in the **subagent's** context, not the main agent's. The orchestrator consumes only a short structured return-summary — keeping main-turn context bounded across a long AFK loop.

**Pattern contract:**

- **Mode**: synchronous. The orchestrator awaits the subagent's final message before deciding whether to drain the release queue (Step 6.5), run the inter-iteration verification (Step 6.75), and spawn the next iteration.
- **subagent_type**: `general-purpose`. Typed iteration-workers (Option A in P077) are rejected for now — iteration work is general engineering with no specialised preamble; the typed agent would just re-export manage-problem's content. Promotion path is preserved.
- **Return shape**: structured summary (ticket_id, ticket_title, action, outcome, committed, commit_sha, reason, skip_reason_category, outstanding_questions, remaining_backlog_count, notes). The commit-state fields let Step 6.75's "Dirty for a known reason" branch stay evaluable from the summary alone. The skip-reason category and outstanding-questions fields let Step 2.5 (P053) populate the Outstanding Design Questions table without re-reading ticket files.
- **Orchestration boundary**: release cadence (Step 6.5 / ADR-018), origin preflight (Step 0 / ADR-019), and inter-iteration verification (Step 6.75 / P036) stay in the orchestrator's main turn. The iteration subagent commits its own work per ADR-014 but MUST NOT run `push:watch` / `release:watch`.
- **Not a new pattern**: this is the canonical shape of foreground-synchronous delegation with context-isolation; it slots under the existing taxonomy row rather than adding a fifth row. The AFK carve-out language above covers the "why"; this amendment covers the "how".

Cross-reference: `packages/itil/skills/work-problems/SKILL.md` Step 5 is the implementing document; `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` is the doc-lint assertion set; P077 is the driver ticket.

### AFK iteration-isolation wrapper — subprocess-boundary variant (P084 amendment, 2026-04-21)

The P077 amendment above specified Agent-tool dispatch for the iteration worker. P084 (2026-04-21) surfaced a platform-level blocker: **subagents spawned via the Agent tool do not have the Agent tool in their own surface.** Three-source evidence: (1) ToolSearch `select:Agent,Task` inside a spawned subagent returns "No matching deferred tools found"; (2) Claude Code docs at `code.claude.com/docs/en/subagents.md` state verbatim "Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions"; (3) empirical invocation attempt returns the literal runtime error "No such tool available: Agent. Agent is not available inside subagents."

Consequence: the Agent-tool-dispatched iteration worker cannot satisfy the architect + JTBD PreToolUse edit-gate markers (only settable by the Agent-tool PostToolUse hook), nor the risk-scorer commit gate. Every AFK iteration on a gate-covered path (every iteration on `packages/`, ADRs, SKILL.md edits, hook edits) silently halts with a docs-only diagnosis. P084 confirmed this is "impossible to lift at the platform level" (no custom `subagent_type` or tool-surface declaration changes it).

**The refinement**: the AFK orchestrator's main turn shells out via Bash to a fresh **`claude -p` subprocess** per iteration instead of spawning a subagent via the Agent tool. The subprocess is a full main Claude Code session — it HAS the Agent tool in its own surface (empirically verified via four probes 2026-04-21; probe 2 confirmed `AGENT_AVAILABLE` with sub-subagent dispatch; probe 3 confirmed PostToolUse marker creation matching the subprocess's own SESSION_ID). Governance review runs at full depth via the normal `wr-architect:agent` / `wr-jtbd:agent` / `wr-risk-scorer:pipeline` delegation path inside the subprocess; commit gate unlocks natively; orchestrator consumes the `ITERATION_SUMMARY` return shape from the subprocess's JSON stdout.

This is the same AFK iteration-isolation wrapper intent — same invariants (synchronous, return-summary contract, orchestrator-owned release-cadence / preflight / inter-iteration verification) — with only the spawn mechanism swapped. Parallel structure with the P077 amendment; not a new pattern.

**Pattern contract:**

- **Spawn command**: `claude -p --permission-mode bypassPermissions --output-format json <iteration-prompt>`.
  - `--permission-mode bypassPermissions` handles non-interactive permission prompts (verified by probe 4). Alternative modes (`acceptEdits`, `auto`, `dontAsk`) are acceptable if adopters need narrower permission scopes.
  - `--output-format json` gives deterministic `.result` stdout field for `ITERATION_SUMMARY` parsing.
  - **No per-iteration budget cap** (user direction 2026-04-21). `--max-budget-usd` is deliberately omitted. Rationale: the AFK loop's natural stop condition is quota exhaustion, not an arbitrary per-iteration dollar cap. A cap would halt iterations before quota is actually exhausted, leaving remaining backlog unprocessed and remaining budget unused. Runaway-iteration risk is bounded by quota-exhaust handling below + the orchestrator's Step 6.75 halt on unexpected dirty state. Adopters who genuinely need a per-iteration cap (e.g. multi-tenant environments with per-run billing) can reinstate `--max-budget-usd` in their own fork or set the envvar — not recommended for the default path.
- **Stdout parse shape**: JSON response; the agent's final message is in the `.result` field; the iteration subprocess is prompted to end its final message with the `ITERATION_SUMMARY` block defined in the P077 amendment. Orchestrator extracts `ITERATION_SUMMARY` from `.result` via the same parser it uses for the Agent-tool variant.
- **Exit-code semantics**: non-zero exit from `claude -p` = iteration failed hard (subprocess crash, auth failure, quota exhaustion). Orchestrator reads exit code before parsing stdout; on non-zero, halts the loop and reports per the ADR-018 failure-handling language. Quota-exhaust is the expected natural stop for a long AFK loop; the orchestrator treats it as a clean halt with a "quota exhausted — resume when quota resets" summary.
- **Hook session-id isolation**: each subprocess runs with its own `$CLAUDE_SESSION_ID`. Gate markers at `/tmp/architect-reviewed-<ID>`, `/tmp/jtbd-reviewed-<ID>`, `/tmp/risk-scorer-*-<ID>` etc. are scoped to the subprocess's own hook interactions and never shared with the orchestrator's main-turn SESSION_ID. This is the correct behaviour for isolation — the orchestrator's main turn runs its own separate gate flow if it edits gated paths; the subprocess's gate flow is independent. Contributors MUST NOT wire cross-process marker sharing.
- **Post-subprocess state re-read**: the orchestrator does NOT rely on session-state continuity with the subprocess. After each subprocess returns, the orchestrator reads the working tree via `git status --porcelain` (Step 6.75 / P036) and reads `ITERATION_SUMMARY.commit_sha` from the subprocess stdout to determine whether the subprocess committed. ADR-018 Step 6.5 release-cadence check triggers off the parsed `ITERATION_SUMMARY` fields, not any inherited session state.
- **Orchestration boundary**: unchanged from the P077 amendment. Release cadence (Step 6.5 / ADR-018), origin preflight (Step 0 / ADR-019), and inter-iteration verification (Step 6.75 / P036) stay in the orchestrator's main turn. The iteration subprocess commits its own work per ADR-014 but MUST NOT run `push:watch` / `release:watch`.
- **Quota-exhaust failure mode**: when the Claude Code account's quota is exhausted mid-iteration, `claude -p` exits non-zero with whatever subprocess state the iteration had accumulated still in the working tree. Orchestrator's Step 6.75 then sees either a clean tree (subprocess committed before quota ran out) or a dirty-for-unknown-reason state (subprocess was mid-edit) and halts per P036. The user returns to a stopped loop with a clear quota-exhaustion reason in the halt report and can resume when quota resets. This is the expected natural stop condition for long AFK loops; the alternative of capping per-iteration cost would leave quota under-utilised.
- **Hook composition inside the subprocess**: the subprocess's own `UserPromptSubmit` hooks fire, including `pending-questions-surface.sh` (above). Pending-questions artefacts written by background-capture skills in the orchestrator's session would surface inside the subprocess's first prompt, which is a cross-context leak. AFK carve-out (line 85) means the subprocess must not resume orchestrator-session pending questions — either the hook self-suppresses when invoked with `WR_SUPPRESS_PENDING_QUESTIONS=1` (set by the orchestrator before each subprocess spawn), or the orchestrator drains / parks pending-questions artefacts before spawning iterations. Implementation choice deferred to the follow-up; the explicit contract is that orchestrator-session artefacts do NOT surface inside iteration subprocesses.
- **Retro-on-exit (P086 amendment, 2026-04-21)**: before emitting `ITERATION_SUMMARY`, the iteration subprocess MUST invoke `/wr-retrospective:run-retro`. Retro runs INSIDE the subprocess so its Step 2b pipeline-instability scan has access to the iteration's rich tool-call history — hook TTL expiries, marker-vs-file deadlocks, repeat-workaround patterns, subagent-delegation friction, release-path instability, session-wrap silent drops. Without this clause the subprocess exits and all per-iteration observations evaporate; the orchestrator's `ITERATION_SUMMARY` is ticket-completion-shaped but pipeline-friction-blind, degrading JTBD-006's "clear summary on return" outcome and JTBD-101's "new friction patterns become ticketable" promise. Retro commits its own work per ADR-014 (run-retro delegates ticket creation to `/wr-itil:manage-problem`, which commits per its own contract); tickets created by retro ride into either the iteration's own commit or a retro-owned follow-up commit, and the orchestrator picks them up on the next Step 1 scan naturally — no cross-process marker sharing or inter-subprocess state transport required. Retro is **non-blocking**: if retro fails or surfaces findings, the iteration still emits `ITERATION_SUMMARY` so the AFK loop does not silently halt on a flaky retro run. Rule 6 compatibility: run-retro already has explicit AFK branches (`packages/retrospective/skills/run-retro/SKILL.md`); no new surface introduced by this clause.

**Rule 6 compatibility**: `claude -p` is by definition a non-interactive context (no TTY, no human turn). Every AskUserQuestion branch reachable from inside the subprocess must fail-safe per ADR-013 Rule 6. This is a pre-existing AFK requirement — the P077 Agent-tool variant had the identical requirement — and is NOT a new surface introduced by the subprocess swap. Each skill invoked inside the iteration (manage-problem, architect/jtbd review, risk-scorer) must already be Rule-6-compliant regardless of dispatch mechanism. Ongoing audit tracked as an investigation task on P084; not a gate on this amendment.

**Variant-selection precedence**: the subprocess-boundary variant is the LEAD post-P084. The Agent-tool-dispatched variant from the P077 amendment remains documented as a historical record and a cautionary anchor; adopters writing new AFK orchestrators MUST use the subprocess-boundary variant. Rollback path is trivial: swap the dispatch-mechanism line in the orchestrator's Step 5.

Cross-reference: `packages/itil/skills/work-problems/SKILL.md` Step 5 is the implementing document (updated with the subprocess dispatch 2026-04-21, amended with retro-on-exit 2026-04-21); `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` asserts the subprocess contract including the retro-on-exit clause (P086); P084 is the subprocess-dispatch driver ticket; P077 is the parent amendment; P086 is the retro-on-exit driver ticket.

### AFK iteration-isolation wrapper — backgrounded poll-loop refinement (P121 amendment, 2026-04-26)

The P084 amendment above specified `claude -p` as the dispatch mechanism but described a foreground-synchronous Bash invocation. P121 (2026-04-25) surfaced a recovery gap in that shape: when an iteration subprocess completes its semantic work (commits land, retro runs, `ITERATION_SUMMARY` is emitted into the agent output stream) but does not exit — waiting on a hook timeout, a backgrounded subagent that never resolved, or some other CLI-level idle behaviour — the orchestrator's Bash invocation blocks indefinitely. The JSON file stays 0 bytes (the CLI only flushes on exit). The 2026-04-25 P118 iter 5 evidence: 121 min wall-clock, final commit at ~100 min, manual SIGTERM at 121 min produced a clean 5649-byte JSON response with `is_error: false`, full `## Session Retrospective` section, parseable `ITERATION_SUMMARY` block, and `duration_ms: 2992935` (49.9 min — the real-work portion). Cost burn: ~$8 of the iter's $12.86 was post-commit idle; AFK loops with multiple stuck iters compound the loss.

**The refinement**: the orchestrator backgrounds the `claude -p` subprocess (`claude -p ... > "$ITER_JSON" 2>&1 < /dev/null & ITER_PID=$!`) and runs an explicit poll loop instead of blocking on the foreground invocation. The loop ticks every 60s, computes `LAST_ACTIVITY_MARK = max(DISPATCH_START_EPOCH, git log -1 --format=%at HEAD)`, and sends `SIGTERM` to `$ITER_PID` when `now - LAST_ACTIVITY_MARK > IDLE_TIMEOUT_S` (default 3600s = 60 min, env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S`). The dispatch-start floor handles skip-iterations that produce no commit — they are bounded by `IDLE_TIMEOUT_S` since dispatch start, not by an arbitrarily-stale prior-commit timestamp. After SIGTERM, the loop continues until `kill -0 $ITER_PID` reports the subprocess has exited; the empirical observation is that SIGTERM produces a clean JSON exit-flush within seconds (the orchestrator then `wait`s and reads `$ITER_JSON` as in the foreground variant).

This is the same AFK iteration-isolation wrapper intent — same invariants (synchronous return-summary contract, orchestrator-owned release-cadence / preflight / inter-iteration verification, hook session-id isolation, exit-code semantics, retro-on-exit) — with only the dispatch loop shape refined from foreground-blocking to backgrounded-with-poll-and-SIGTERM. Parallel structure with the P077/P084/P086 amendments; not a new pattern.

**Pattern contract (additions to the P084 amendment):**

- **Dispatch shape**: backgrounded subprocess + 60s poll loop + idle-timeout SIGTERM branch (replacing the foreground-synchronous form). The full Bash block lives in SKILL.md Step 5; this ADR pins the contract.
- **LAST_ACTIVITY signal**: `max(DISPATCH_START_EPOCH, git log -1 --format=%at HEAD)`. Alternatives considered and rejected: `stat -f%m "$ITER_JSON"` (binary — file mtime only changes on subprocess exit, useless during the idle gap); subprocess RSS-change tracking (noisy; spikes during Agent-tool expansions confound the signal). The git-log signal is the cheapest reliable progress indicator the orchestrator already has. Trade-off: skip-iterations bounded by `IDLE_TIMEOUT_S` since dispatch start; raise the threshold in environments with deliberately-long skip-evaluation iters.
- **Default threshold**: `IDLE_TIMEOUT_S=3600` (60 min). Headroom for genuinely long architectural iters; the typical real-work iter from the 2026-04-25 evidence ran 12-49 min. Env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S` for adopters who run very long iters or want a tighter guard.
- **SIGTERM safety**: empirically a clean exit-flush, not a destructive interrupt — the JSON response with `is_error: false` and intact `ITERATION_SUMMARY` arrives within seconds of SIGTERM. Single-source production observation (2026-04-25); behavioural second-source in `test/work-problems-step-5-idle-timeout-sigterm.bats` exercises a fake `claude -p` shim that traps SIGTERM and exits 0 with JSON already flushed.
- **Distinguishable status**: the orchestrator's Step 6 progress line annotates `(SIGTERM_SENT)` when the branch fires so the user can distinguish a SIGTERM-recovered iter from a normal completion. Per JTBD-006 audit-trail expectation: SIGTERM must not masquerade as a normal skip in the post-AFK summary.

**Rule 6 compatibility**: SIGTERM is a non-interactive recovery action; no AskUserQuestion required. The orchestrator's main turn fires SIGTERM autonomously when the threshold is exceeded. This satisfies ADR-013 Rule 6's non-interactive AFK fail-safe — the orchestrator does not block on user input to recover from a stuck subprocess.

**Variant-selection precedence**: the backgrounded-poll-loop refinement is the LEAD post-P121. The foreground-synchronous variant from the P084 amendment is documented as historical record only; adopters writing new AFK orchestrators MUST use the backgrounded poll loop. Rollback path is trivial: replace the poll loop with the prior `claude -p ... < /dev/null` foreground form, accepting that idle-timeout recovery is lost.

Cross-reference: `packages/itil/skills/work-problems/SKILL.md` Step 5 is the implementing document (updated with the backgrounded poll loop 2026-04-26); `packages/itil/skills/work-problems/test/work-problems-step-5-idle-timeout-sigterm.bats` is the behavioural fixture; P121 is the driver ticket; P084 is the parent amendment whose foreground dispatch this refinement replaces; P086 (retro-on-exit) is preserved unchanged.

### AFK iteration-isolation wrapper — is_error:true stream-timeout salvage (P261 amendment, 2026-05-26)

The P121 amendment above handles the SIGTERM idle-timeout class: the orchestrator SIGTERMs a stuck subprocess that completed its work (commits landed, `ITERATION_SUMMARY` emitted) but never exited, and the empirical observation is a clean `is_error: false` JSON exit-flush. P261 (2026-05-18, session-6 iter-4) surfaced a different failure shape: the iter subprocess returned `is_error: true` with `API Error: Stream idle timeout - partial response received` in `.result` AFTER staging substantive coherent work (7 files — a complete SKILL.md amendment + a 290-line bats fixture + ADR amendments) but BEFORE invoking `git commit`. The literal exit-code contract (SKILL.md Step 5 "non-zero exit → halt") would halt and lose ~$13 of intact, salvageable work: the staged content was coherent, the iter's bats passed 39/39, and the work composed cleanly with prior iters. The orchestrator main turn salvaged it by hand; that ad-hoc recovery is now the documented contract.

**The refinement**: when the iter returns `is_error: true` (an API stream timeout, NOT a SIGTERM) AND staged files survive in the working tree AND the iter-authored bats fixtures pass, the orchestrator MAY apply a deterministic 4-step salvage path that commits the staged work from the orchestrator main turn (with iter-attribution) and re-validates it through a fresh commit gate. This is the same AFK iteration-isolation wrapper intent — same invariants (one-commit-per-iteration grain, orchestrator-owned release-cadence / preflight / inter-iteration verification, fresh gate validation) — with a recovery branch added for the stream-timeout-before-commit shape. Parallel structure with the P077/P084/P086/P121 amendments; an ADDITIVE recovery branch, not a new pattern and not a replacement for the existing exit-code halt or the P121 SIGTERM path (both remain in force).

**Pattern contract:**

- **SALVAGE-vs-HALT decision**: deterministic gate. **IF** `is_error: true` AND staged files exist (`git diff --cached --name-only` non-empty) AND any iter-authored bats fixtures pass → SALVAGE via the 4-step path: (1) run the iter's bats as a structural sanity check; (2) inspect the changeset + diffs for quality; (3) commit the staged work from the orchestrator main turn with explicit iter-attribution in the message; (4) the commit gate fires fresh on the salvage commit. **ELSE** (staged work incoherent / bats fail / nothing staged) → halt per the existing exit-code contract. The decision is non-interactive — no `AskUserQuestion` (mirrors the P121 SIGTERM Rule-6 precedent at line 154).
- **Salvage-commit authorship carve-out**: this is the single bounded exception to the orchestration-boundary rule stated twice above — "The iteration subprocess commits its own work per ADR-014 but MUST NOT run `push:watch` / `release:watch`" (lines 102, 127) and SKILL.md line 486 "the orchestrator does NOT commit from its main turn". The subprocess died with `is_error: true` BEFORE it could commit, so commit authorship necessarily moves to the orchestrator main turn for this class only. It is NOT a precedent for arbitrary orchestrator-main-turn commits — it fires exclusively on the SALVAGE branch of the decision gate above.
- **One-commit-per-iteration grain preserved**: amend-based folding (the ADR-041 / ADR-042 / ADR-061 mechanism for reconciling extra commit-bearing work with the one-commit invariant) is INAPPLICABLE here — there is no iter commit to amend (the subprocess died pre-commit; that is the entire problem). The standalone orchestrator-authored salvage commit IS the iteration's one commit, preserving the grain (one logical commit per iteration's worth of work) even though authorship moved to the orchestrator.
- **Distinct from the is_error:false SIGTERM salvage (line 151)**: four distinguishing axes — (a) no SIGTERM involved; (b) the iter exits on its own with `is_error: true`; (c) no `ITERATION_SUMMARY` emitted and no commit landed; (d) the bats are runnable to verify coherence. The line-151 SIGTERM clause relies on the subprocess HAVING committed its own work before going idle (clean `is_error: false` flush); this class did NOT commit, which is why orchestrator-authored salvage is required rather than a simple `.result` parse.
- **Fresh-gate-marker behaviour (ADR-009)**: consistent with ADR-009 line 89 — an `is_error: true` subprocess MUST NOT extend the parent's trust window. The salvage commit fires the commit gate fresh on the orchestrator's OWN SESSION_ID and never reuses the dead subprocess's `/tmp/architect-reviewed-<ID>` / `/tmp/jtbd-reviewed-<ID>` / `/tmp/risk-scorer-*-<ID>` markers. Hook session-id isolation (line 125) is preserved.

**Rule 6 compatibility**: the SALVAGE-vs-HALT decision is deterministic and non-interactive; the orchestrator's main turn applies the salvage path autonomously when the gate conditions hold, and halts otherwise. No `AskUserQuestion` is required — same non-interactive-recovery posture as the P121 SIGTERM branch (line 154).

**Variant-selection precedence**: this is an ADDITIVE recovery branch. It does NOT replace the P121 backgrounded-poll-loop SIGTERM path or the existing exit-code halt — both remain LEAD for their respective classes. The salvage branch fires only on the `is_error: true`-with-coherent-staged-work shape; every other failure shape routes to the prior halt or SIGTERM contracts unchanged.

Cross-reference: `packages/itil/skills/work-problems/SKILL.md` Step 5 exit-code semantics is the implementing document (the `is_error: true` salvage carve-out + the line-486 orchestrator-commit exception); `packages/itil/skills/work-problems/test/work-problems-step-5-stream-timeout-salvage.bats` is the behavioural fixture; P261 is the driver ticket; P121 / P147 / P146 are the sibling iter-failure classes this carve-out is distinguished from; ADR-009 (gate-marker lifecycle) grounds the fresh-gate-marker behaviour; ADR-014 grounds the one-commit-per-iteration grain.

### Deferred-question resumption contract

When a background skill hits an `AskUserQuestion` branch:

1. **Subagent pauses**. Writes a pending-questions artefact at a **persistent** location:
   - `docs/problems/open/<NNN>-pending-background-skill-questions-<short-slug>.md` (ADR-031 per-state-subdir path; graceful fallback to flat `docs/problems/<NNN>-...open.md` until P069's migration lands).
   - The artefact carries a standard problem-ticket header (Status: Open, Reported: <date>, Priority: 3 Low — mirroring the "needs-completion" category) PLUS a structured `## Pending Questions` section with the ADR-013-compliant question set (question text, options, multiSelect, header) PLUS a `## Subagent Resumption Context` section with whatever state the subagent needs to resume (e.g. partial draft, captured prior-step output).
   - This replaces architect's earlier suggestion of a `/tmp` marker: persistent storage survives reboots AND makes each paused subagent a first-class trackable item. Pending-questions artefacts appear in the normal problem backlog and in `manage-problem review` output so the user cannot accidentally lose them.

2. **Subagent exits**. Background invocation completes; no resume loop inside the subagent.

3. **Main agent surfaces the questions**. On the main agent's **next natural pause** (next user prompt), a `UserPromptSubmit` hook (`packages/itil/hooks/pending-questions-surface.sh`, NEW, ships with `@windyroad/itil`) checks for `docs/problems/open/*-pending-background-skill-questions-*.md` files. If any are present, the hook injects a systemMessage listing the pending-questions artefacts by ID+title so the main agent invokes `AskUserQuestion` with each artefact's question set **serially** (one AskUserQuestion call per artefact; matches ADR-013's one-decision-per-interaction grain).

4. **Main agent writes the answers**. For each artefact, main agent appends `## User Answers (<timestamp>)` to the artefact with the user's selection. This is a structured patch the resuming subagent can parse.

5. **Main agent spawns the resume subagent**. New `Agent(run_in_background: true)` invocation with the artefact path as its prompt input. The resume subagent reads the `## Subagent Resumption Context` + `## User Answers`, picks up where the original subagent paused, and completes the work.

6. **Resume subagent completes**. Writes the final artefact (e.g. the completed problem ticket, retro entry, or ADR draft), commits per ADR-014, and `git mv`s the pending-questions artefact to `docs/problems/closed/<NNN>-pending-background-skill-questions-<short-slug>.md` with a `## Resolved` section citing the resume commit SHA.

7. **TTL expiry**. If the pending-questions artefact sits unanswered for more than `PENDING_QUESTIONS_TTL` (default 7 days; overridable via envvar), `manage-problem review` surfaces it as a stale-pending-question. The user decides whether to answer (resume), cancel (rename to `docs/problems/parked/<NNN>-...md` with a `## Parked` section citing "background skill abandoned"), or escalate to a foreground `manage-problem` / `run-retro` / `create-adr` invocation that takes the resumption context + any partial work as its starting point.

**Concurrency**: multiple simultaneous pending-questions artefacts are handled serially. The `UserPromptSubmit` hook lists all detected artefacts; main agent invokes `AskUserQuestion` once per artefact. Order: artefact creation date ascending (FIFO). No batching — each artefact's question set is independent and the user reviews them one at a time.

**Precedent**: the TTL+marker primitive reuses ADR-009's gate-marker-lifecycle pattern. This ADR extends the primitive to a new semantic class — pending-subagent-state tokens. ADR-009 markers are clearance tokens (the gate was passed); ADR-032 pending-questions artefacts are paused-subagent-state tokens.

### ADR-013 Rule 6 audit requirement

Before any existing skill moves to (or gains) a background sibling, every AskUserQuestion branch in the skill must pass a Rule 6 audit:

- **(a) Policy-authorise** (ADR-013 Rule 5 variant) — if the branch's options are safely-defaultable in the background context, convert the branch to automatic selection with a policy citation. Background-preferred default matches foreground-interactive default.
- **(b) Defer via pending-questions artefact** — if the branch genuinely needs user input, apply the deferred-question contract above.
- **(c) Reclassify as foreground-only** — if the branch's input is time-sensitive, high-stakes, or depends on context the subagent cannot snapshot, the skill's background variant skips this branch path entirely (`capture-problem` takes only aside-captureable inputs; anything requiring full interactive flow routes to foreground `manage-problem`).

Each skill's SKILL.md under this ADR's model MUST include a "Rule 6 audit" section enumerating each AskUserQuestion branch and its resolution path.

### Observable-output contract

Background skills produce observable artefacts that bats tests + manual audit can assert. The artefact types:

- **Completed artefact** — problem ticket at `docs/problems/open/NNN-<slug>.md` (or the intended post-ADR-031-migration path); retro entry appended to BRIEFING.md; ADR at `docs/decisions/NNN-<slug>.proposed.md`. Standard ADR-014 commit carries the artefact.
- **Pending-questions artefact** — persistent problem ticket per the deferred-question contract above.
- **Background-skill receipt** — short structured file at `docs/problems/open/<NNN>-background-skill-receipt-<short-slug>.md` (or equivalent) naming which background skill fired, when, and what its completed or pending state is. Optional; main agent decides whether to emit based on whether the caller wanted an explicit receipt. Primary use case: AFK orchestrators that want to track "which background captures fired this session" (not relevant under AFK carve-out but reserved for future).

### Foreground-lightweight-capture variant (P155 amendment, 2026-05-03)

The pattern taxonomy above (line 62) defines `capture-problem` as a **background-capture** skill — `Agent(run_in_background: true)` spawning the heavyweight `manage-problem` flow as a subagent. P088 (settled 2026-04-21, see line 26) deferred `capture-retro` because retro's whole-session-history input does not fit the background-capture self-contained-aside-payload shape. P155 (2026-05-03) surfaces the same friction one layer deeper for `capture-problem`: the **lightweight aside-invocation** use case the parent ticket P014 names ("working on X, notice Y, log Y, keep working on X, don't forget Y") is served better by a foreground skill that **does less work** than `manage-problem` than by a background skill that does the same heavyweight work asynchronously.

The two are not equivalent. Background-capture pattern's promise is "main agent doesn't block on the subagent's run"; the subagent still runs the full ~10-turn intake (Step 0 reconciliation preflight, wide-net duplicate-grep, AskUserQuestion branches, Step 4b multi-concern split, P094 README refresh, Step 11 commit gate). Foreground-lightweight-capture's promise is "main agent runs a stripped-down intake (~3-4 turns) inline" — minimal title-only duplicate-grep, deferred-placeholder priority/effort, no multi-concern split, no inline README refresh, single commit. The user's session keeps the in-flow capture cost bounded by the work the skill **omits**, not by an asynchronous wrapper around the same heavyweight work.

**The amendment**: ship `/wr-itil:capture-problem` as a **foreground-lightweight-capture** skill first. The deferred background-capture variant from line 79 remains deferred per P088 settlement (and ADR-032's original taxonomy preserves the slot for it if future requirements re-establish demand). Sibling skill `/wr-architect:capture-adr` (line 81) follows the same precedent — ship lightweight foreground first; revisit background-capture when the deferred-question resumption contract has live in-tree usage to validate against.

This is parallel to the P077 / P084 / P086 / P121 amendments above — same ADR-032 architectural intent, same invariants (one skill per distinct user intent per P071, ADR-014 commit ownership, framework-mediated mechanical-stage decisions per ADR-044), with only the **dispatch-cost shape** refined: lightweight foreground replaces the never-shipped background variant for the immediate slice. Not a new pattern — a new row under the foreground-synchronous taxonomy distinguishing **full-intake** from **lightweight-capture** sub-variants.

**Pattern contract:**

- **Mode**: foreground synchronous. Main agent invokes; skill runs in main-agent context; no background subagent spawn.
- **Cost shape**: ~3-4 turns total. Step 0 reconciliation preflight (shared with manage-problem), Step 1 description parse, Step 2 minimal-grep + create-gate marker, Step 3 next-ID, Step 4 skeleton-fill template (deferred-placeholder pattern), Step 5 single Write, Step 6 single commit, Step 7 trailing-pointer report.
- **AskUserQuestion**: zero branches by design. Each potentially-interactive decision is framework-mediated per ADR-044 (duplicate-check = false-positives-cheaper-than-false-negatives mechanical rule; priority/effort = framework-policy default flagged for re-rate; multi-concern split = out of scope, route to manage-problem; empty `$ARGUMENTS` = halt-with-stderr-directive). Rule 6 audit section in SKILL.md enumerates the resolution path for each.
- **Composition with manage-problem create-gate (P119)**: capture-problem's Step 2 calls `mark_step2_complete` via the existing `packages/itil/hooks/lib/create-gate.sh` helper, sharing the per-session marker `/tmp/manage-problem-grep-${SESSION_ID}`. Cross-skill ordering (manage-problem first, then capture-problem; or vice versa) is idempotent. The PreToolUse hook `manage-problem-enforce-create.sh` permits Writes from either skill once the marker is set.
- **Deferred-README-refresh contract**: capture-problem does NOT regenerate `docs/problems/README.md` inline (the P094 block from `manage-problem` Step 5 is intentionally omitted). The README ranking lags new captures until the next `/wr-itil:review-problems` invocation, which folds captured-but-not-rated tickets into the WSJF table (its Step 9b auto-transition pass keys off the literal deferred-placeholder string `(deferred — re-rate at next /wr-itil:review-problems)`). Trade-off: capture-time speed vs. README authoritativeness; the on-disk ticket inventory is always the source of truth, README is a derived view, and `/wr-itil:list-problems` cache-stale fallback re-derives directly from the ticket files. Trailing-pointer in capture-problem Step 7 is the user-visible signal that the README is transiently stale and how to reconcile.
- **Multi-concern**: out of scope. One ticket per invocation. Multi-concern observations route to `/wr-itil:manage-problem` (its Step 4b owns the split decision via AskUserQuestion).
- **AFK orchestrator compatibility**: capture-problem is invokable from inside AFK iter subprocesses. The AFK carve-out at line 85 excludes the **background-capture** variant from AFK contexts (synchronous observability requirements); the **foreground-lightweight-capture** variant has no `Agent(run_in_background: true)` invocation and runs as a normal foreground-synchronous skill, so it is compatible with iter subprocesses. Use case: mid-iter sibling-finding capture without breaking iter cadence; observation-to-ticket conversion rate climbs from current ~50% (buried in `notes` field) toward ~100%.
- **Commit grain (ADR-014)**: one commit per capture. Commit message convention `docs(problems): capture P<NNN> <title>`. The `capture` verb is the audit signal that this ticket landed via the lightweight aside path (vs. `open` for manage-problem's full intake).

**Rule 6 compatibility**: trivially satisfied — capture-problem has zero AskUserQuestion branches. Empty-`$ARGUMENTS` halt-with-stderr-directive is non-interactive and AFK-safe.

**Variant-selection precedence**: foreground-lightweight-capture is the LEAD post-P155 for `/wr-itil:capture-problem`. The background-capture variant from line 79 remains deferred (sibling slot to P088's `capture-retro` deferral). If background-capture demand re-emerges with concrete use cases the lightweight variant cannot serve, the variant ships under a sibling skill name (e.g. `/wr-itil:queue-problem-capture` or similar) — not by mutating the existing capture-problem contract.

Cross-reference: `packages/itil/skills/capture-problem/SKILL.md` is the implementing document; `packages/itil/skills/capture-problem/REFERENCE.md` hosts rationale + edge cases per ADR-038 progressive-disclosure pattern; `packages/itil/skills/capture-problem/test/capture-problem.bats` is the behavioural fixture per ADR-052; P155 is the driver ticket; P014 is the parent / master tracker.

### Foreground-lightweight-capture variant — capture-adr (P156 amendment, 2026-05-03)

P156 ships the sibling skill named at line 81 — `/wr-architect:capture-adr` — under the same foreground-lightweight-capture pattern the P155 amendment above introduced for `/wr-itil:capture-problem`. The amendment is a row under the foreground-synchronous taxonomy distinguishing **full-intake** (`/wr-architect:create-adr`, ~10-15 turns) from **lightweight-capture** sub-variants (~3-4 turns) on the architect plugin namespace, symmetric with the ITIL plugin precedent.

The two are not equivalent. The heavyweight `/wr-architect:create-adr` walks Considered Options ≥2 (with pros/cons), Decision Drivers, Decision Outcome, full Consequences (Good/Neutral/Bad), Confirmation criteria (testable), Pros/Cons of Options, Reassessment Criteria, decision-makers/consulted/informed, plus a Step 5 confirm-with-user AskUserQuestion review pass. Foreground-lightweight-capture's promise is "main agent runs a stripped-down skeleton-fill (~3-4 turns) inline" — single-option chosen with a deferred-flagged sibling, deferred-flagged Drivers / Consequences / Confirmation / Pros-Cons / Reassessment-criteria, sentinel `decision-makers: [unspecified — fill at canonical review]`, default `reassessment-date` 3 months from today, status `proposed`, no inline architect-agent review handoff (deferred to canonical expansion). The user's session keeps the in-flow capture cost bounded by the work the skill **omits**, not by an asynchronous wrapper around the same heavyweight work.

**The amendment**: ship `/wr-architect:capture-adr` as a **foreground-lightweight-capture** skill alongside `/wr-itil:capture-problem`. The deferred background-capture variant from line 79 remains deferred per P088 settlement.

**Pattern contract:**

- **Mode**: foreground synchronous. Main agent invokes; skill runs in main-agent context; no background subagent spawn.
- **Cost shape**: ~3-4 turns total. Step 1 parse Title + Context + Decision from `$ARGUMENTS` (graceful-degradation on partial payload); Step 2 next-ID via P056-safe `local_max + origin_max + 1` formula reused from `create-adr` Step 3; Step 3 skeleton-fill MADR template (deferred-placeholder pattern + numbered-options placeholder `1. Option A (chosen) — <one-line>` + `2. (deferred — see /wr-architect:create-adr canonical review)` to preserve MADR ≥2-options surface for any doc-lint); Step 4 single Write to `docs/decisions/<NNN>-<kebab-title>.proposed.md`; Step 5 single commit; Step 6 trailing-pointer report.
- **AskUserQuestion**: zero branches by design. Each potentially-interactive decision is framework-mediated per ADR-044 (Considered Options ≥2 = mechanical skeleton placeholder; Drivers / Consequences / Confirmation / Reassessment-criteria = framework-policy deferred flag; Reassessment-date = framework-policy default 3 months from today; decision-makers/consulted/informed = sentinel `[unspecified — fill at canonical review]`; multi-decision split = out of scope, route to create-adr's Step 2b; empty `$ARGUMENTS` = halt-with-stderr-directive). Rule 6 audit section in SKILL.md enumerates the resolution path for each.
- **MADR conformance at skeleton time**: status `proposed` covers the not-yet-accepted state. The architect-agent enforces MADR ≥2-options at acceptance review, not at skeleton time. The numbered-options placeholder preserves the surface for any structural lint that asserts numbered-option presence. Each deferred section carries the literal pointer string `(deferred to /wr-architect:create-adr canonical review)` so canonical-expansion tooling (or an auto-detect-and-expand path in a follow-up ticket) can detect and expand mechanically.
- **Deferred-canonical-expansion contract**: capture-adr does NOT invoke the `wr-architect:agent` review inline (the create-adr Step 5 confirm-with-user AskUserQuestion pass is intentionally omitted). Architect review fires when canonical expansion runs (`/wr-architect:create-adr <NNN>` or direct architect-agent delegation). The architect-agent reviewing a `.proposed.md` skeleton sees `status: proposed` + deferred-flag literals and treats it as a not-yet-accepted ADR; reviews focus on whether the captured Decision conflicts with existing accepted ADRs.
- **Composition with capture-problem**: an iter that surfaces both a problem AND a related decision can fire `/wr-itil:capture-problem` + `/wr-architect:capture-adr` in sequence (~6-8 turns total) instead of ~20-30 through the heavyweight pair.
- **AFK orchestrator compatibility**: capture-adr is invokable from inside AFK iter subprocesses. Same rationale as capture-problem — foreground-synchronous, no `Agent(run_in_background: true)`, no AskUserQuestion. Use case: mid-iter design-decision capture without breaking iter cadence; architect-review verdict capture (PASS-WITH-NOTES / ISSUES-FOUND with substantive rationale) preserved as ADR-shaped record instead of rotting in commit-message bodies.
- **Commit grain (ADR-014)**: one commit per capture. Commit message convention `docs(decisions): capture ADR-<NNN> <title>`. The `capture` verb is the audit signal that this ADR landed via the lightweight aside path (vs. `add` / `accept` for canonical create-adr's full intake). Status remains `proposed` until canonical review accepts it.

**Rule 6 compatibility**: trivially satisfied — capture-adr has zero AskUserQuestion branches. Empty-`$ARGUMENTS` halt-with-stderr-directive is non-interactive and AFK-safe.

**Variant-selection precedence**: foreground-lightweight-capture is the LEAD post-P156 for `/wr-architect:capture-adr`. The background-capture variant from line 79 remains deferred (sibling slot to P088's `capture-retro` deferral). If background-capture demand re-emerges with concrete use cases the lightweight variant cannot serve, the variant ships under a sibling skill name — not by mutating the existing capture-adr contract.

**Auto-detect-and-expand path (out of scope for P156)**: when `/wr-architect:create-adr` is later invoked on a captured `<NNN>`, it could detect the existing skeleton (via deferred-flag literal pointer string match) and expand the deferred sections rather than write a new ADR. P156 does not ship this; the manual workflow is `/wr-architect:create-adr` invoked with the captured ID + body context, or direct Edit. Filed as follow-up scope under P014.

Cross-reference: `packages/architect/skills/capture-adr/SKILL.md` is the implementing document; `packages/architect/skills/capture-adr/REFERENCE.md` hosts rationale + edge cases per ADR-038 progressive-disclosure pattern; `packages/architect/skills/capture-adr/test/capture-adr.bats` is the behavioural fixture per ADR-052; P156 is the driver ticket; P014 is the parent / master tracker.

### Pending-questions-surface variant — JSONL queue at SessionStart (P157 amendment, 2026-05-03)

The Deferred-question resumption contract above (lines 158-181) defines a `pending-questions-surface.sh` hook (line 169) that reads **markdown-ticket** pending-questions artefacts (`docs/problems/open/*-pending-background-skill-questions-*.md`) — paused-subagent-state tokens written by background-capture skills hitting an `AskUserQuestion` branch, surfaced at the main agent's next natural pause via `UserPromptSubmit`. P157 (2026-05-03) ships a **second** pending-questions surface, scoped to a different artefact class: the **JSONL queue** at `.afk-run-state/outstanding-questions.jsonl` accumulated by `/wr-itil:work-problems` iter subprocesses' Step 5 / Step 2.5 / Step 2.5b per the P135 Phase 3 schema + ADR-044 6-class taxonomy. Two artefact classes, two hooks; the file naming makes the distinction clean (the markdown variant retains its existing `pending-questions-surface.sh` design; the new JSONL variant ships as `itil-pending-questions-surface.sh`).

The two are not equivalent. The markdown variant is per-artefact serial surfacing at prompt-time (per-paused-subagent-state granularity, FIFO creation date, no batching); the JSONL variant is batched-at-session-start surfacing of accumulator entries that survived an AFK loop's Step 2.5 / Step 2.5b emit-or-not gate. The empirical evidence in P157's body: 16-hour AFK loop, 2 entries accumulated by iter 12, user manually stopped the loop, queue file persisted to next session, only surfaced because the user explicitly asked. Without P157's hook, accumulated direction-questions silently drift the agent's behaviour from user intent across session boundaries.

**The amendment**: ship `itil-pending-questions-surface.sh` as a `SessionStart` hook with matcher `"startup"` per ADR-040 Option A precedent (the `wr-retrospective` `session-start-briefing.sh` precedent); silent-on-no-content per ADR-040 Mechanism step 1; ranked emission per ADR-044 6-class taxonomy precedence; AFK-iter cross-context-leak prevention via the orchestrator-set `WR_SUPPRESS_PENDING_QUESTIONS=1` env var per the existing line 127 contract (architect-confirmed implementation choice (a) in the P157 review pass).

**Pattern contract:**

- **Hook event**: `SessionStart` with matcher `"startup"`. Fires once per session boot per the Claude Code hook contract; semantically correct for "you returned to a session, here are accumulated artefacts" surfaces (ADR-040 Option A precedent — Option B's `UserPromptSubmit` + once-per-session marker rejected on the same reasoning).
- **Plugin home**: `@windyroad/itil`. Co-located with the AFK orchestrator (`/wr-itil:work-problems`) that writes the queue and with the queue's host directory (`.afk-run-state/`). Sibling to existing UserPromptSubmit hooks `itil-correction-detect.sh` and `itil-assistant-output-gate.sh`.
- **Hook script**: `packages/itil/hooks/itil-pending-questions-surface.sh`. Naming consistent with the `itil-*.sh` sibling convention.
- **Silent-on-no-content**: missing file, empty file, whitespace-only file, all-malformed JSONL → exit 0 with zero stdout per ADR-040 Mechanism step 1. Defensive — SessionStart hook failures cascade into "session won't start" UX which is far worse than missing one surfacing pass.
- **Parsing + ranking**: each line parsed via `jq -e .` (malformed lines silently skipped); category extracted; entries deduped on `(rank, category, ticket_id, question)` tuple; stable-sorted by ADR-044 precedence rank ascending (deviation-approval = 1, direction = 2, one-time-override = 3, silent-framework = 4, taste = 5, correction-followup = 6). Category strings byte-for-byte match the JSONL schema in `work-problems` SKILL.md Step 5 (`deviation-approval`, `direction`, `one-time-override`, `silent-framework`, `taste`, `correction-followup`).
- **Output shape**: plain-stdout markdown directive per ADR-040 precedent. Includes (a) one-paragraph context naming the source file + entry count + ranking precedence; (b) explicit cleanup directive instructing the agent to rewrite the queue file removing resolved entries after each `AskUserQuestion` batch; (c) ranked entries table with columns `# | Category | Ticket | Question`; (d) batching note when entry count > 4 citing the ADR-013 Rule 1 `<=4 per call` cap.
- **AFK-iter cross-context-leak prevention** (ADR-032 line 127 contract): hook self-suppresses on `WR_SUPPRESS_PENDING_QUESTIONS=1`. The `/wr-itil:work-problems` Step 5 dispatch block sets the env var via `export WR_SUPPRESS_PENDING_QUESTIONS=1` immediately before each `claude -p` subprocess spawn (implementation choice (a) of the two ADR-032 line 127 enumerations — simpler than orchestrator-side queue drain/restore, idempotent, no state to restore on crash). Without the env var the orchestrator's accumulated session-level queue would surface inside every iter subprocess's first turn as a cross-context leak.
- **Cleanup-on-resolve**: out of scope for the hook — the agent rewrites the queue file removing resolved entries on its first interactive turn after surfacing. Empty queue → next session no-op. Mirrors the work-problems Step 2.5 cleanup contract at SKILL.md line 163 (truncate after batch resolution).
- **Queue file lifecycle**: `.afk-run-state/` is gitignored at `.gitignore` line 18 (per ADR-032 subprocess-boundary AFK runtime state). No commit involved; agent rewrites the file in-session as entries resolve.

**Rule 6 compatibility**: trivially satisfied — the hook itself is non-interactive (it can only inject context via stdout). The `AskUserQuestion` invocation that resolves the surfaced entries fires from the main agent's first interactive turn, where the user is presumed present by construction (SessionStart fires when the user opens a session). The AFK carve-out at line 85 + the env-var self-suppress ensure the hook does not fire inside iter subprocess contexts where `AskUserQuestion` would violate Rule 6.

**Variant-selection precedence**: the SessionStart-JSONL variant is the LEAD post-P157 for surfacing accumulated AFK-loop direction-questions across session boundaries. The markdown-ticket-pending-questions UserPromptSubmit variant from line 169 remains the LEAD for paused-background-subagent-state tokens — the two variants serve different artefact classes and ship as two separate hooks, both under `@windyroad/itil`. If a future use case emerges that needs prompt-time JSONL surfacing (e.g. mid-session queue updates while a foreground capture flow runs in parallel), the variant ships under a sibling hook name, not by mutating the SessionStart contract.

**Consequence on AFK orchestrator main turn**: the orchestrator main turn (the session that spawns iter subprocesses and emits the final AFK summary) sees accumulated questions surface on its OWN session start when it boots up post-AFK-loop. This complements the existing Step 2.5 / Step 2.5b loop-end emit shape — Step 2.5 fires when the loop reaches its natural emit point; the SessionStart hook fires when the user (or orchestrator) returns to a session that did NOT reach Step 2.5 (manual stop, quota exhaustion, network failure). Together they close the queue-file lifecycle gap end-to-end. The orchestrator iter subprocesses themselves never see the surface (env-var self-suppress).

Cross-reference: `packages/itil/hooks/itil-pending-questions-surface.sh` is the implementing hook script; `packages/itil/hooks/test/itil-pending-questions-surface.bats` is the behavioural fixture per ADR-052 (19 cases — silent-on-no-content, single + multi-entry surface, full 6-class precedence, dedup, batching directive, cleanup directive, env-var self-suppress, hooks.json wiring, work-problems Step 5 export, malformed-JSON skip); `packages/itil/hooks/hooks.json` registers the hook as a second SessionStart entry with matcher `"startup"`; `packages/itil/skills/work-problems/SKILL.md` Step 5 hosts the orchestrator-side `export WR_SUPPRESS_PENDING_QUESTIONS=1` insertion before `claude -p`; ADR-040 is the SessionStart-hook precedent (Option A choice + silent-on-no-content shape); ADR-044 is the 6-class taxonomy precedence source-of-truth; P135 Phase 3 is the JSONL schema source-of-truth in `work-problems` SKILL.md Step 5; P157 is the driver ticket; P014 is the parent / master tracker; P155 + P156 are the sibling capture-* amendments shipped earlier in the same loop.

### Foreground fresh-context-subagent-as-decision-arbiter variant (P346 amendment, 2026-05-31)

The pattern taxonomy above (line 62) defines four invocation surfaces — foreground synchronous, background capture, foreground edit-gate, foreground commit-gate. P346 Phase 3 (2026-05-31) surfaced a fifth shape: a fresh subagent spawned via the Agent tool from **inside** a SKILL's control flow (not from a PreToolUse hook), whose job is to **arbitrate a decision** the calling SKILL would otherwise resolve under the main agent's biased session context. The verdict is structured (e.g. `HANG_OFF: P<NNN>` / `PROCEED_NEW`), and the SKILL acts on it deterministically.

The driver is the wrongly-captured P347 sibling-ticket of P346 on 2026-05-31 — the main agent, mid-work on P346 Phase 2, pattern-matched the existing capture flow and failed to recognise that the new Phase 3 spec belonged in P346 as Phase 3, not as a sibling. User correction (verbatim): *"we need to have the ticket creation process do more effort in finding existing ticket to add to"* + *"maybe use a subagent to avoid bias from existing context, then you probably can make it much simpler"*. Both pinned the substance: subagent, bias-free, simpler-than-defensive-in-SKILL-checks.

This is distinct from the four existing patterns on four axes:

- **vs Foreground synchronous (row 1)**: a foreground-synchronous SKILL runs in main-agent context; this variant punts a specific decision inside the SKILL to a fresh subagent. The SKILL itself is still foreground-synchronous; the variant lives one layer down, at a specific decision point.
- **vs Background capture (row 2)**: not background. The main agent BLOCKS on the subagent's verdict before continuing the SKILL — the verdict is load-bearing for the next branch.
- **vs Foreground edit-gate (row 3)**: not a PreToolUse hook. There is no Bash/Write tool intercept; the dispatch is from inside SKILL.md control flow.
- **vs Foreground commit-gate (row 4)**: not a PreToolUse-on-`git commit` hook either; same distinction.

The new shape composes existing primitives (the Agent tool, structured agent verdicts, the same context-isolation pattern that powers `wr-architect:agent` / `wr-jtbd:agent` / `tdd:review-test` / `wr-risk-scorer:pipeline`) — but applies them at a NEW surface: capture-time / lifecycle-time inflow-discipline rather than edit-time or commit-time review. Recording it as a fifth row in the taxonomy preserves taxonomy unity (the alternative — leaving it implicit — invites future inflow-class decisions to pattern-match this one with no governing principle and a later disavowal would force P314-class rework across all of them per ADR-074).

**Pattern contract:**

- **Mode**: foreground synchronous AT THE SKILL LEVEL; the SKILL blocks on the subagent verdict at the dispatch point.
- **Dispatch site**: inside SKILL.md control flow at a specific decision step (e.g. `/wr-itil:capture-problem` Step 2 hang-off-check, after the mechanical pre-filter returns a non-empty candidate set). Not a PreToolUse hook; no Bash/Write tool intercept.
- **Subagent invocation**: `Agent` tool with `subagent_type: "wr-itil:hang-off-check"` (or the future inflow-arbiter subagent name). Fresh context — the subagent reads only its structured inputs (the new capture's description + the filtered candidate ticket list) and ADR files via its limited tool surface; no session-context bias.
- **Verdict shape**: structured, terminal, deterministic. The verdict MUST resolve to a single value the SKILL acts on (e.g. `HANG_OFF: P<NNN>` with rationale, `PROCEED_NEW` with rationale, or `INSUFFICIENT_SIGNAL → PROCEED_NEW` as the safe-default collapse). Never a free-text recommendation the SKILL has to re-interpret.
- **Latency bound**: the dispatch site MUST short-circuit when the mechanical pre-filter returns a wide candidate set (default cap: 5 candidates; configurable per SKILL). Wide-set dispatches blow the SKILL's lightweight-capture latency contract (`/wr-itil:capture-problem`'s under-60s flow budget per JTBD-001); the safe default is "skip the dispatch + record the candidate list in the captured ticket body for review-time re-evaluation."
- **AFK safe-default**: under `--no-prompt` or AFK propagation, ambiguous-multi-parent collapses to `PROCEED_NEW` (the conservative safe default — false-negative is cheaper than wrongly-folding into the wrong parent, mirroring `/wr-itil:capture-problem` Step 2's existing "false-positives are cheaper than false-negatives" framing). The verdict is non-interactive by construction; no `AskUserQuestion` fallback.
- **Audit trail**: the subagent emits its rationale alongside the verdict; the SKILL writes the rationale into the receiving artefact (Investigation Tasks bullet on the parent ticket for `HANG_OFF`; the captured ticket body's `## Related` section for `PROCEED_NEW` so the next reviewer sees what was considered).
- **Maintainer-side firewall**: the dispatch fires on maintainer-side capture surfaces only. Plugin-user-side intake (`.github/ISSUE_TEMPLATE/problem-report.yml`) MUST NOT carry an equivalent dispatch — plugin-user descriptions do not carry the same authorial intent as maintainer-internal captures (a plugin-user describing their friction in maintainer-vocabulary terms could plausibly trigger a wrong-parent HANG_OFF). Triage during `/wr-itil:manage-problem` ingestion stays user-judgement per JTBD-301. This matches the established firewall pattern at line 116 of `packages/itil/skills/capture-problem/SKILL.md`.
- **Commit grain (ADR-014)**: the dispatch decision does NOT itself create a commit. The SKILL's normal commit (the captured ticket OR the parent-ticket amendment, depending on verdict) carries the verdict outcome.

**Rule 6 compatibility**: trivially satisfied — the verdict shape is deterministic; the SKILL's branch on the verdict is non-interactive. No `AskUserQuestion` invoked by the subagent or by the SKILL on the verdict; the safe-default collapse handles ambiguous cases mechanically.

**Variant-selection precedence**: this is an additive surface. It does NOT replace any of the four existing patterns. SKILLs adopting this variant pick a specific decision-point inside their flow; they remain foreground-synchronous overall. The trigger for adopting the variant is the SAME class of friction P346 surfaced — a SKILL's decision is structurally biased by the main agent's session context and the bias drives wrong-class outcomes.

**Worked example (P346 Phase 3 — the canonical regression)**: `/wr-itil:capture-problem` Step 2 runs a 3-keyword title-only grep (existing). Phase 3 adds: a mechanical pre-filter scanning candidate ticket bodies for shared ADR-NNN refs / SKILL paths / file paths cited in the new capture's description; if the filtered set is non-empty AND ≤5 candidates, dispatch `wr-itil:hang-off-check` subagent with the description + filtered candidate list as inputs; the subagent returns `HANG_OFF: P<NNN>` (halt-and-route to amend the named parent) or `PROCEED_NEW` (continue to Step 3 of capture-problem). The bats fixture exercises the canonical regression: P347's description + candidate set containing P346 MUST return `HANG_OFF: P346`. `/wr-itil:manage-problem` Step 2 carries the same dispatch.

Cross-reference: `packages/itil/agents/hang-off-check.md` is the implementing agent; `packages/itil/agents/test/hang-off-check.bats` is the behavioural fixture per ADR-052 (3 fixtures: P347-vs-P346 regression, genuinely-new, subtle-sibling); `packages/itil/skills/capture-problem/SKILL.md` Step 2 hosts the dispatch; `packages/itil/skills/manage-problem/SKILL.md` Step 2 hosts the same dispatch; P346 is the driver ticket (master; Phase 3 is this amendment's substance; Phases 1+2 shipped under prior iters); RFC-013 traces the full P346 multi-phase work per ADR-071.

## Scope

### In scope (this ADR)

- Pattern taxonomy (foreground synchronous, background capture, foreground edit-gate, foreground commit-gate).
- Three new `capture-*` skills (`/wr-itil:capture-problem`, `/wr-retrospective:capture-retro`, `/wr-architect:capture-adr`) — ADR-level decision. SKILL.md authoring is the implementation step tracked under P014.
- Deferred-question resumption contract (persistent `docs/problems/open/` pending-questions artefact + UserPromptSubmit surfacing hook + serial AskUserQuestion + resume subagent spawn + Resolved-section commit).
- AFK carve-out: background capture does not apply inside AFK orchestrator iterations.
- Rule 6 audit requirement for each skill's SKILL.md under this ADR's model.
- Removal of ADR-027's Step-0 delegation language from `manage-problem`, `create-adr`, `run-retro`, `manage-incident` SKILL.md files. Those skills go back to executing Steps 1-N in main-agent context (foreground synchronous pattern).
- Supersession administration: rename `027-governance-skill-auto-delegation.proposed.md` → `.superseded.md`; update ADR-027 frontmatter status + superseded-by; add "Superseded by" section to ADR-027 body.
- New UserPromptSubmit hook `packages/itil/hooks/pending-questions-surface.sh` that injects a systemMessage when pending-questions artefacts exist.
- Bats doc-lint coverage for the three new SKILL.md files, the Rule 6 audit section presence, the pending-questions-surface hook's detection logic.

### Out of scope (follow-up tickets)

- Direct-invocation Agent tool changes (e.g. a hypothetical "background by default" flag on the Agent tool itself). This ADR picks the model that fits existing Agent tool semantics; any upstream Claude Code changes are separate.
- Background variants of edit-gate / commit-gate hooks. Those must stay foreground (they MUST block).
- Cross-session pending-questions resume (agent session exits before user answers). The TTL expiry path + foreground-escalation recovery covers it; no need for a cross-session transport layer.
- Background variants for `manage-incident`. Incidents are time-pressure interactive; background doesn't fit the JTBD-201 audit-trail model. Revisit if the pattern emerges.
- Background variants for `work-problems` iterations. AFK carve-out is explicit.

## Consequences

### Good

- P014 closes at design level. User's "log Y, keep working on X" promise delivered via the sibling-skill pattern.
- Existing foreground skills unchanged for users who want full interactive flow.
- Sibling-skill naming matches `feedback_skill_subcommand_discoverability.md` and P071's deprecation of argument-based subcommands.
- Deferred-question contract has an explicit observable artefact (not a `/tmp` file) — pending-questions are first-class items in the problem backlog; auditable, timeout-able, recoverable.
- ADR-009 TTL+marker primitive reused and extended; no new filesystem pattern invented.
- ADR-018 / ADR-019 AFK ownership boundaries preserved via explicit carve-out.
- ADR-014 commit ownership preserved; background subagents still commit their own work.
- Rule 6 audit forces each skill's branch points to be explicitly classified before the background variant ships.

### Neutral

- Three new skill identities in the manifest. `claude plugin list` output grows by three lines per adopter.
- New UserPromptSubmit hook fires on every user prompt (checks for pending-questions artefacts). Hook cost is a single `ls docs/problems/open/*-pending-background-skill-questions-*.md 2>/dev/null` per prompt — sub-millisecond; bounded to problem-ticket directory.
- Foreground skills lose their Step-0 delegation. Main agent executes Steps 1-N directly. This removes an isolation layer but reclaims a main-turn that ADR-027 had consumed for every invocation. Net: the user's "synchronous but don't waste a turn on delegation" observation was already part of P014's pain pattern; this ADR resolves it.

### Bad

- **First-run unfamiliarity**: users accustomed to ADR-027's Step-0 delegation (subagent-first, no-main-context-execution) will see a behavior change in existing skills. Documentation + CHANGELOG entries mitigate; the supersede note in ADR-027's body points forward.
- **Pending-questions backlog growth**: if users frequently abandon background captures mid-resumption, the `docs/problems/open/` directory accumulates stale `*-pending-background-skill-questions-*.md` files. Mitigation: TTL expiry path + `manage-problem review` surfacing + escalation recovery to foreground skills.
- **Sibling-skill discoverability load**: users must know both `/wr-itil:manage-problem` and `/wr-itil:capture-problem` exist. Mitigation: `/wr-itil:` autocomplete surfaces both; the `capture-*` verb is consistent across three skills; one mental model spans all three.
- **Existing AFK orchestrator invariants rely on ADR-027 language**: the `work-problems` SKILL.md currently references "Step 0 subagent" framing inherited from ADR-027. Under this ADR that language is stale. Work-problems's Step 0 (preflight) IS still a thing — but it's main-agent preflight, not subagent delegation. Remove ADR-027 references; keep AFK carve-out text.
- **ADR-031 auto-migration's Step-0 question dissolves**: the P069 execution-time question "where does auto-migration sit given ADR-027's Step 0?" (ADR-031 line 130) no longer applies under this ADR. Migration runs in foreground main-agent context, policy-authorised per ADR-013 Rule 6 + ADR-019 precedent. ADR-031 should be cross-updated when that migration executes.

## Confirmation

A set of structural doc-lint bats assertions validates the ADR's implementation:

### Source review (at implementation time)

- `027-governance-skill-auto-delegation.proposed.md` renamed to `.superseded.md`; `status: superseded`; `superseded-by: [032-governance-skill-invocation-patterns]` in frontmatter; "Superseded by" section at top of body.
- `manage-problem` / `create-adr` / `run-retro` / `manage-incident` SKILL.md files have their Step-0 subagent-delegation language removed; main-agent Step-1-onwards execution flow documented.
- Three new SKILL.md files at `packages/itil/skills/capture-problem/SKILL.md`, `packages/retrospective/skills/capture-retro/SKILL.md`, `packages/architect/skills/capture-adr/SKILL.md`. Each:
  - Names the background pattern in its Context section.
  - Enumerates its AskUserQuestion branches with Rule 6 audit resolution (policy / defer / foreground-only).
  - Cites the deferred-question resumption contract from this ADR.
  - Writes completed artefact via standard foreground-skill commit path (ADR-014).
- `packages/itil/hooks/pending-questions-surface.sh` UserPromptSubmit hook exists; detects `docs/problems/open/*-pending-background-skill-questions-*.md` (or ADR-031-post-migration equivalent path); injects systemMessage with detected artefact IDs + titles in ascending creation-date order.
- `.claude-plugin/plugin.json` entries for `@windyroad/itil`, `@windyroad/retrospective`, `@windyroad/architect` list the new skills.

### Foreground-spawns-N-background fanout (P075 amendment)

`run-retro` Step 4b Stage 1 (ticket every codify-worthy observation) is a **foreground-spawns-N-background-fanout** case: the foreground `run-retro` turn spawns one background capture invocation (`/wr-itil:capture-problem`) per codifiable observation. This is a legitimate extension of the foreground-spawns-single-background pattern already named in this ADR — no semantic change, only arity. The FIFO concurrency paragraph already covers the resulting deferred-question ordering: N Stage-2 pending-question artefacts (one per Stage 1 ticket) queue in serial creation-date order and surface FIFO via the UserPromptSubmit hook. When `/wr-itil:capture-problem` does not yet exist in the suite, `run-retro` Step 4b Stage 1 falls back to synchronous `/wr-itil:manage-problem` invocations; the fanout semantics remain the same, only the background/foreground mode changes. P075 tracks the `run-retro` execution; the ADR-032 contract itself covers the case via this amendment.

### Bats structural tests

- `packages/itil/skills/capture-problem/test/capture-problem-contract.bats`, `packages/retrospective/skills/capture-retro/test/capture-retro-contract.bats`, `packages/architect/skills/capture-adr/test/capture-adr-contract.bats` — each asserts: SKILL.md present; Context section cites the background pattern; Rule 6 audit section present; deferred-question-resumption contract cited; ADR-032 referenced.
- `packages/itil/hooks/test/pending-questions-surface.bats` — asserts: hook fires on UserPromptSubmit; detects pending-questions artefacts via glob; produces systemMessage with correct artefact list (FIFO by creation date); no-ops when no artefacts exist.
- `packages/shared/test/adr-027-superseded.bats` — asserts: ADR-027 file is at `.superseded.md` path; frontmatter status is `superseded`; `superseded-by` names ADR-032; body contains "Superseded by" forward pointer.

### Behavioural replay (at implementation time, for the human tester)

1. Fresh session. Invoke `/wr-itil:capture-problem hook TTL expiry mid-iteration`. Verify: main thread receives a short confirmation ("captured as P-NNN in background"); background subagent writes the problem ticket; main agent continues original task.
2. Invoke `/wr-architect:capture-adr decision about X`. Verify: ADR draft appears at `docs/decisions/NNN-<slug>.proposed.md`; if the capture's payload is thin, the background subagent hits AskUserQuestion on Title/Options; pending-questions artefact appears at `docs/problems/open/`; next user prompt surfaces the questions via UserPromptSubmit hook's systemMessage + AskUserQuestion invocation by the main agent.
3. Interrupt a background capture (kill the subagent before it completes). Verify: the original capture's partial commit (if any) is on disk; no pending-questions artefact written (nothing to resume); user can re-invoke `/wr-itil:capture-problem` to retry from scratch.
4. AFK invocation: run `/wr-itil:work-problems`. Verify: iterations stay synchronous per AFK carve-out; no `capture-*` invocations fire inside the loop; drain + preflight remain in orchestrator main context.
5. Let a pending-questions artefact sit past TTL. Run `/wr-itil:manage-problem review`. Verify: artefact surfaces as stale-pending-question with options to answer, cancel (park), or escalate to foreground.

## Reassessment Criteria

Revisit this decision if:

- Pending-questions backlog grows faster than users can answer (signal: `docs/problems/open/*-pending-background-skill-questions-*.md` count exceeds 20 for any adopter). Consider reducing AskUserQuestion branches (convert more to policy-authorised) or lowering TTL.
- Users consistently prefer foreground over `capture-*` (signal: `capture-problem` invocation count stays near-zero for 3+ months post-release). Consider deprecating a `capture-*` skill whose background model doesn't match user behaviour.
- A governance skill emerges whose background variant cannot cleanly resolve any AskUserQuestion branch via Rule 6 audit (signal: architect review blocks the background sibling's design). That skill stays foreground-only; no sibling ships.
- Pending-questions artefact shape proves insufficient (e.g. subagent state too large to persist in a markdown file; users can't read the Resumption Context). Revisit the persistence format; JSON-in-a-YAML-frontmatter-section is the fallback.
- UserPromptSubmit hook latency becomes noticeable (signal: user reports the prompt-submit feeling slower). Measure; optimise the glob or move to a dedicated daemon.
- Cross-session resumption becomes a real need (users resume a background skill in a new session after a gap longer than TTL). Current TTL + foreground-escalation covers it; if it doesn't, a cross-session resume transport layer becomes the next ADR.
- ADR-031's migration lands and the pending-questions artefact path moves from flat `docs/problems/` to `docs/problems/open/` — update this ADR's Confirmation paths in the same commit.

## Related

- **ADR-027** (Governance skill auto-delegation) — superseded by this ADR. Its synchronous-Step-0 mandate is replaced by the pattern taxonomy above.
- **ADR-009** (Gate marker lifecycle) — TTL+marker primitive precedent; this ADR extends it to pending-subagent-state.
- **ADR-013** (Structured user interaction for governance decisions) — Rule 5 (policy-authorised) + Rule 6 (non-interactive fail-safe) both usable under the Rule 6 audit in this ADR. Rule 1 (AskUserQuestion for mutually-exclusive options) preserved via the deferred-question contract's serial surfacing.
- **ADR-014** (Governance skills commit their own work) — preserved under both foreground and background patterns.
- **ADR-018** (Inter-iteration release cadence for AFK loops) — AFK carve-out explicitly preserves.
- **ADR-019** (AFK orchestrator preflight) — same AFK carve-out.
- **ADR-020** (Governance auto-release for non-AFK flows) — auto-release triggers on foreground-skill commits; background-skill commits trigger the same auto-release path per ADR-014 commit ownership.
- **ADR-024** (Cross-project problem-reporting contract) — `report-upstream` is a foreground-synchronous skill; unchanged.
- **ADR-026** (Agent output grounding) — the observable-output contract satisfies the persist clause.
- **ADR-028** (amended External-comms gate) — reviewer agents (voice-tone, risk-external-comms) remain foreground-blocking via their edit-gate hooks; unaffected.
- **ADR-031** (Problem-ticket directory layout) — pending-questions artefacts live under the per-state-subdir layout (`docs/problems/open/`) post-migration; ADR-031's auto-migration Step-0 open question at lines 128-138 dissolves under this ADR (migration runs in foreground main-agent context per ADR-019 precedent).
- **P014** (No lightweight aside invocation for governance skills) — closed at decision level by this ADR.
- **P071** (Argument-based skill subcommands not discoverable) — reinforced: sibling-skill naming (`capture-*` alongside `manage-*` / `create-*` / `run-*`) is the explicit alternative to argument-based subcommands.
- **P077** (work-problems Step 5 does not delegate to subagent) — driver for the AFK iteration-isolation wrapper amendment above.
- **P086** (AFK iteration subprocess does not run retro before returning) — driver for the retro-on-exit clause under the subprocess-boundary variant; extends the P084 amendment with a closing-retro contract so per-iteration friction reaches the backlog via run-retro's Step 2b pipeline-instability scan.
- **P121** (AFK orchestrator should SIGTERM stuck `claude -p` subprocesses after idle-timeout) — driver for the backgrounded-poll-loop refinement under the subprocess-boundary variant; replaces the P084 amendment's foreground-synchronous dispatch with a backgrounded subprocess + 60s poll loop + idle-timeout SIGTERM branch (default 3600s, env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S`). Behavioural second-source in `test/work-problems-step-5-idle-timeout-sigterm.bats`.
- **P088** (run-retro cannot see the full session context when invoked as a subagent, subprocess, or non-parent surface) — driver for the `capture-retro` deferral noted at lines 26 and 80 above. Retro's whole-session-history input does not fit the background-capture pattern's self-contained-aside-payload shape; the sibling is preserved on this list as a placeholder and re-shipped only once the retro-context-layer taxonomy is defined. Anti-pattern clause in `packages/retrospective/skills/run-retro/SKILL.md` preamble pins the only-foreground-or-`claude -p` invocation surfaces.
- `feedback_skill_subcommand_discoverability.md` — memory note confirms the user's preference for separate skills over arg-subcommands.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary beneficiary.
- **JTBD-003** (Compose Only the Guardrails I Need) — independent foreground / background skill composability.
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK carve-out preserves the job's invariants.
- **JTBD-101** (Extend the Suite with New Plugins) — sibling-skill pattern as repeatable convention.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — pending-questions as first-class problem tickets keep the audit trail complete.
