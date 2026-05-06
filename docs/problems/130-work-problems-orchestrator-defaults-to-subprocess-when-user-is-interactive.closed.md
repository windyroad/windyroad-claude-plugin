# Problem 130: `/wr-itil:work-problems` orchestrator defaults to subprocess dispatch even when the user is observably interactive — loses real-time presence advantage

**Status**: Closed
**Reported**: 2026-04-27
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M — `packages/itil/skills/work-problems/SKILL.md` prose-discipline amendment per the user-reframed Fix Strategy (lines 95-123 below). Adds the **Mid-loop ask discipline (orchestrator main turn)** subsection inside Non-Interactive Decision Making, augments Step 5's iteration-prompt body with transient-user framing, adds a Decision Table row, plus matching contract bats per ADR-037 + P081 (`work-problems-no-mid-loop-asking.bats`). The original-effort estimate (dual-mode dispatch + presence-signal detector + ADR-032 amendment) was superseded by the user reframe — actual effort is materially smaller (prose discipline, no new helper, no ADR amendment).
**WSJF**: (9 × 2.0) / 2 = **9.0**
**Type**: technical

> Surfaced 2026-04-27 by direct user correction during an interactive session of `/wr-itil:work-problems`: "I'm not sure why you did that as a background non-interactive run. We could of just done it here. create a problem for that". P078 contradiction-signal pattern. Triggering iter: iter 9 = P081, dispatched as `claude -p` subprocess immediately after the user answered an `AskUserQuestion` next-step decision at the orchestrator's main turn — the user-presence signal had flipped from absent to present, but the orchestrator's Step 5 dispatch shape did not adapt.

## Description

`/wr-itil:work-problems` Step 5 mandates `claude -p --permission-mode bypassPermissions --output-format json` subprocess dispatch for every iteration. The contract evolved from inline Skill-tool invocation (P077 — context-bloat failure mode) to Agent-tool dispatch (P077's amendment) to `claude -p` subprocess dispatch (P084 — Agent-tool subagents lack Agent themselves, breaking governance gate markers). The subprocess-boundary variant under ADR-032 is the canonical AFK iter shape; it correctly serves JTBD-006 (progress the backlog while I'm away).

But the dispatch decision is **monomodal** — every iter is dispatched as a subprocess regardless of whether the user is observably present. When the user shifts from AFK back to interactive mid-loop (e.g. answers an `AskUserQuestion` at the orchestrator's main turn, sends a new directive message, or responds to a task notification), the orchestrator's Step 5 still dispatches the next iter as an isolated subprocess. The user can no longer:

- Watch architect / JTBD / risk-scorer verdicts unfold in real-time
- Intervene on design surface in-flight (e.g. when the architect asks for ADR-shape input)
- See partial commits as they land
- Course-correct mid-iter without waiting ~15-30 min for the subprocess to complete

The orchestrator's main turn IS interactive by construction — Agent tool is natively available, gates fire at full depth, governance reviews land directly in the visible turn. The subprocess dispatch was added (P084) to make AFK iters feasible, not because main-turn iters are wrong. The current SKILL.md defaults to subprocess unconditionally; the absent-presence assumption is baked in as the only dispatch path.

## Symptoms

- During an interactive session where the user has answered an `AskUserQuestion` and is still at the keyboard, the next iter dispatches as a subprocess. The user sees only the periodic background-task notifications — they can't watch the iter's architect verdict, can't intervene when the iter hits a design ambiguity, and have to wait for the iter's `ITERATION_SUMMARY` block before they can react.
- The user explicitly observed (2026-04-27): "I'm not sure why you did that as a background non-interactive run. We could of just done it here."
- Subprocess overhead — each `claude -p` invocation pays ~$5-15 cost + 12-45 min wall (cumulative session totals at iter 9 dispatch: ~$63 / ~3.7 hrs across 8 prior iters). Main-turn iters would amortise the orchestrator's already-loaded SKILL.md context and the existing architect / JTBD markers, reducing per-iter cost.
- The dispatch decision is invisible to the user — they don't see "I am about to subprocess this iter; the next visible signal will be the completion notification in ~20 min." There's no opt-out at decision time.
- Composes-with adjacent gaps: P122 (now closed) fixed the inverse class — orchestrator was defaulting to AFK fallback table at stop-condition #2 even when `AskUserQuestion` was available. P130 is the same shape on a different surface — orchestrator is defaulting to AFK subprocess at Step 5 even when main-turn skill invocation is available.

## Workaround

The user explicitly tells the orchestrator to NOT subprocess (e.g. "just do it here"). Without that signal the orchestrator subprocesses by SKILL contract.

## Impact Assessment

- **Who is affected**: every user of `/wr-itil:work-problems` who shifts from AFK to interactive mid-loop. The AFK-to-interactive transition is the common case — users start a loop before stepping away, then return mid-loop to check progress and stay engaged. Solo-developer persona (JTBD-001) and especially the AFK-orchestration persona (JTBD-006) which the skill primarily serves.
- **Frequency**: every interactive AFK loop session where the user returns mid-loop and the orchestrator dispatches another iter. Observed every session this week.
- **Severity**: Moderate — degrades user experience without losing correctness. The work still completes and commits correctly; the user just can't watch / intervene. Higher than Minor because the inability-to-intervene cuts off in-flight design corrections that would otherwise save iters.
- **Likelihood**: Possible — depends on whether the user is engaged at iter dispatch time. For a fully-AFK session it doesn't fire; for any interactive session it does.
- **Analytics**: 2026-04-27 session — iter 9 dispatch was the trigger event. The user answered an `AskUserQuestion` immediately before iter 9 dispatch; orchestrator subprocess-dispatched iter 9 anyway; user corrected within ~30 seconds.

## Root Cause Analysis

### Investigation Tasks

- [x] Audit work-problems SKILL.md Step 5 — confirmed monomodal subprocess dispatch (lines 201-378). No branch for presence-detection. The Bash invocation shape is fixed: backgrounded `claude -p ... > "$ITER_JSON" 2>&1 < /dev/null & ITER_PID=$!` followed by 60s poll loop and idle-timeout SIGTERM (P121 refinement). No conditional path for "if user is present, run inline via Skill tool".
- [x] Cross-reference ADR-032 — confirmed the proposed ADR carries 4 variants (P077 Agent-tool dispatch, P084 subprocess-boundary, P086 retro-on-exit clause, P121 backgrounded poll-loop). All four assume AFK-by-construction at the iter layer. None specifies a presence-aware dispatch branch.
- [x] Cross-reference P122 (closed) — established the Cross-skill principle at the orchestrator's stop/halt surfaces: "orchestrator main turns default to AskUserQuestion when available; the AFK persona is served by the subprocess-boundary contract under ADR-032 (iteration subprocess workers are AFK by construction via `claude -p`), NOT by suppressing AskUserQuestion at the orchestrator layer." P130 is the SAME shape on a different surface (Step 5 dispatch instead of Step 2 stop conditions).
- [ ] Define the presence-signal detector. Candidates with trade-off analysis:
  - **`UserPromptSubmit-since-loop-start` marker** — clean signal but asymmetric (the loop-invocation prompt itself fires it). Needs a "since iter N completion" qualifier to be useful.
  - **`AskUserQuestion-answered-within-last-N-minutes` marker** — a tool result from `AskUserQuestion` is observable evidence the user is at the keyboard. Requires AQ-result-hook to touch a marker file. Misses the case where the user is watching but not yet asked anything.
  - **`Wall-clock idle threshold`** (e.g. 5 min since last user activity) — heuristic, requires a `last-user-activity-epoch` marker touched by both UserPromptSubmit hooks AND AskUserQuestion result handlers. Most robust signal but most complex implementation.
  - **Composed (best-of-N)** — combine all three. Safest fail-mode (default-to-AFK if any signal indicates absence; default-to-presence only if ALL signals are positive).
  - **Recommended**: `last-user-activity-epoch` marker (idle-threshold heuristic) — touched on UserPromptSubmit AND on AskUserQuestion answer notifications. Threshold default: 5 min. Composes with ADR-038's once-per-session marker pattern at `.afk-run-state/last-user-activity-epoch`. **This is an architect-design call** — the cross-skill helper boundary belongs in ADR-032's amended taxonomy, not in this ticket alone.
- [ ] Decide the dual-mode contract shape — **architect-design call**. Two viable shapes:
  - **Subprocess-by-default + main-turn-on-presence-positive** (recommended): preserves AFK as the safe default; switches to main-turn only when presence is actively signalled. Minimal disruption to existing JTBD-006 invariants. Risk: re-introduces context-bloat (P077's killer) when main-turn fires.
  - **Main-turn-by-default + subprocess-on-presence-absence**: aligns with ADR-013 Rule 1's interactive-default. Higher risk: every iter pays main-turn context cost; AFK loops degrade to main-turn for 1+ iters before idle-threshold flips them to subprocess.
  - Default-branch decision composes with ADR-044 (proposed) framework-resolved-decisions taxonomy: once the heuristic is settled, the routing IS framework-resolved (no per-iter user prompt needed). Until settled, it's a user-design decision.
- [ ] Evaluate whether the orchestrator should ANNOUNCE its dispatch decision to the user before dispatching, with an opt-out window. e.g. "About to subprocess iter 10 (AFK mode). Reply within 30s to switch to main-turn." This trades latency for visibility. **Architect-design**: the announce surface introduces a new interaction primitive that must compose with ADR-013 Rule 1 / Rule 6. Probably out-of-scope for the initial fix; the detector + dual-mode contract delivers most of the value without it.
- [ ] ADR-032 amendment to formalise the dual-mode contract. Likely a new sibling subsection ("AFK iteration-isolation wrapper — interactive-presence variant") parallel to the existing P077 / P084 / P086 / P121 amendment subsections. The amendment must specify (a) the presence-signal detector mechanism, (b) the dispatch-branch contract (when subprocess vs main-turn fires), (c) how main-turn-iter handles context-isolation (likely by spawning a `general-purpose` subagent via Agent tool — re-using the P077-rejected variant for the presence-positive branch since gates are NOT required when running in main-turn-context-with-Agent-available), (d) gate-marker session-id semantics for main-turn iters (markers shared with orchestrator's session — different from subprocess isolation contract).
- [ ] Behavioural bats for the detector (when the signal fires) and for the dispatch branch (subprocess vs main-turn). Per ADR-037 / `feedback_behavioural_tests.md`: structural-only greps are not real tests; the bats must exercise the detector with synthetic markers and the dispatch with mock surfaces.

### Findings (2026-04-28 investigation)

**Root cause confirmed.** `packages/itil/skills/work-problems/SKILL.md` Step 5 is a single Bash dispatch shape. Lines 211-255 show the canonical invocation: `claude -p --permission-mode bypassPermissions --output-format json "$ITERATION_PROMPT" > "$ITER_JSON" 2>&1 &` — no conditional path. There is no presence-signal detector anywhere in the orchestrator's main-turn execution; the dispatch is **mechanically uniform** across every iter regardless of the user's observable presence state.

**Historical context.** The dispatch shape evolved across three amendments:
- **P077 (2026-04-21)**: Skill-tool inline invocation → Agent-tool dispatch to `general-purpose` subagent. Closed context-bloat (manage-problem SKILL.md = 800+ lines accumulating in main turn).
- **P084 (2026-04-21)**: Agent-tool dispatch → `claude -p` subprocess. Closed gate-marker gap (subagents lack the Agent tool, breaking architect/JTBD/risk-scorer gates).
- **P121 (2026-04-26)**: Foreground subprocess → backgrounded subprocess + idle-timeout SIGTERM. Closed stuck-iter recovery gap.

Each amendment **assumed AFK as the operating mode** (the persona JTBD-006 explicitly serves). None evaluated the case where the user is interactively present at iter dispatch time. The current monomodal contract is the cumulative artefact of three amendments that each correctly solved an AFK-mode gap without considering the interactive-mode surface.

**Why P130 is non-trivial.** A naive "switch to main-turn dispatch when user is present" amendment re-introduces every gap the prior amendments closed:
- **Context bloat** (P077): main-turn iter via Skill tool expands manage-problem's 800-line SKILL.md into the orchestrator's main turn. Across 8-10 iters this saturates context. Mitigation candidates: (a) main-turn iter via Agent-tool dispatch (re-introduces P084's gate-marker gap), (b) main-turn iter via inline execution but with explicit context-isolation directives in the iter prompt (untested), (c) main-turn iter for ONLY the iters where the user is observed to be present (presumed rare — degenerates to subprocess in practice).
- **Gate-marker isolation** (P084): main-turn iter via Agent tool means the iter subagent inherits the orchestrator's session ID; gate markers at `/tmp/architect-reviewed-<ID>` apply across the orchestrator's main turn AND the iter, blurring audit boundaries.
- **Stuck-iter recovery** (P121): main-turn iter has no SIGTERM-able PID; recovery requires Ctrl-C, losing the iter's partial work.

The fix therefore needs a **context-isolation strategy** for the main-turn variant that doesn't regress the prior amendments. Likely answer: **subprocess-boundary preserved at the dispatch layer; the ONLY thing that changes is whether the orchestrator BLOCKS on the subprocess wait or surfaces a stream of intermediate observations**. This reframes P130: the dispatch shape stays subprocess; what changes is the orchestrator's wait-shape (silent block → live tail of subprocess output to the orchestrator's progress line). That avoids context-bloat, gate-marker bleed, and SIGTERM regression — all the iter's tool calls still happen in the subprocess; only the orchestrator's main-turn observation surface changes.

**Alternative reframing**: rather than a dual-mode dispatch, change the dispatch's **observation surface**. The subprocess's `--output-format stream-json` (instead of `json`) emits intermediate JSON events as they happen; the orchestrator can `tail -f` the stream and surface a live progress line in its own main turn. Real-time observation achieved without re-introducing any P077/P084/P121 gap. **This may be the actual fix shape** — not a dual-mode dispatch, but a richer observation contract under the existing subprocess boundary.

**Workaround confirmed.** User-side opt-out: the user explicitly tells the orchestrator to NOT subprocess (`"just do it here"`). This is a manual signal that must currently be issued before EVERY iter dispatch — there's no session-level toggle. Workaround is documented and routinely used; root cause is not blocking.

**Architect-design dimension.** The four open investigation tasks (detector design, dual-mode contract default branch, announce-window UX, ADR-032 amendment shape) all require architect judgment. The "stream-json observation surface" alternative reframing also needs architect review — it changes the dispatch contract less invasively than the dual-mode option but introduces a new failure mode (partial JSON parsing if the stream is interrupted mid-event). Implementation effort stays at M once the design is settled; the design itself is an architect-design ticket. This iter intentionally stops at root-cause documentation + Known Error transition; implementation routes to a separate iter once the design is settled.

### Preliminary hypothesis (superseded by Findings above)

The dispatch monomodality is a **historical artefact** of P084's adoption of subprocess dispatch. P084 closed a real gap (Agent-tool subagents can't satisfy gates) by requiring `claude -p` subprocess. P077's prior amendment addressed Skill-tool inline invocation (context bloat). Neither P077 nor P084 considered the case where the user is present and main-turn invocation would work fine — both assumed AFK as the operating mode.

The fix is to **make presence-awareness explicit at Step 5** rather than baking AFK assumption into the dispatch contract. **Refined**: the fix may instead be to **enrich the orchestrator's observation contract** under the existing subprocess boundary (stream-json + live tail), avoiding a dual-mode dispatch entirely. See Findings above for the full design space.

## Fix Strategy

**Updated 2026-04-28 — direction reframed by user**. The original two-path fix-shape question (dual-mode dispatch vs observation-surface enrichment) was rejected by the user as missing the underlying purpose. The user's direction verbatim: *"you can't tell when I'm AFK or not. I might come in, respond to a question and disappear again. I'm not saying use subprocess unnecessarily, I'm saying don't assume I will be here for follow-up questions for quite some time. Instead follow the main purpose of `work-problems` which is to progress the problem tickets and accumulate questions. When you can no longer make any progress, surface the questions for me to answer (with sufficient context that I can make an informed and educated decision and without doing BUFD, and without asking me questions that would be better determined through research, exploration and experimentation)."*

The reframe:

1. **Presence-detection is unreliable and is not the goal**. Even at the keyboard, the user may answer one question and then disappear for hours. Don't try to detect presence; treat the user as transient.
2. **The loop's purpose is progress + accumulation, not interactive-vs-AFK routing**. Progress every ticket the agent can advance autonomously. Accumulate user-answerable questions as a side-effect of progress. When stuck (cannot progress further without user input), surface the accumulated questions in one batch.
3. **Question discipline at surface time**:
   - Each question must carry enough context for an informed decision (the architect's recommended option, the alternatives considered, the trade-offs, the concrete consequence of each path).
   - **No BUFD** — don't pre-judge architectural decisions before there's evidence; small actionable questions, not galaxy-brain ones.
   - **Don't ask questions that research / exploration / experimentation could answer**. The agent should prototype, read code, run experiments to answer those itself. The user is the source for direction-setting decisions only.

**Implementation shape (replaces the original dual-mode approach)**:

The fix is mostly SKILL.md prose discipline, not a new dispatch mode:

- `packages/itil/skills/work-problems/SKILL.md` — tighten the AskUserQuestion-in-orchestrator-main-turn discipline. Step 5/6.5/6.75 should NOT ask the user mid-loop unless the framework explicitly prescribes it (Step 6.5 above-appetite halt, Step 6.75 dirty-for-unknown-reason halt, Step 0 session-continuity). Continue iterating through the backlog until quota exhausts or stop-condition #1/#2/#3 fires.
- Reinforce Step 2.5b's central role — the halt-with-batched-questions surface IS the framework's prescribed user-interaction point. Don't dilute it by asking mid-loop.
- Add explicit guidance on what KIND of accumulated questions are acceptable to batch-surface: direction-setting decisions only; no BUFD; no questions answerable by research/experimentation.
- `packages/itil/skills/work-problems/test/work-problems-no-mid-loop-asking.bats` — behavioural assertions: orchestrator does not fire `AskUserQuestion` between iters when the framework's stop-conditions don't fire.
- ADR-032 amendment: NOT needed. The subprocess-boundary contract is unchanged. The change is at the orchestrator's main-turn discipline layer.

**Out of scope (per the reframing)**:
- Presence-detection helper (`packages/itil/hooks/lib/presence-signal.sh`) — removed from scope. Presence is unreliable and is not the goal.
- Dual-mode dispatch (subprocess vs main-turn) — removed from scope. The dispatch shape stays subprocess-by-default; the change is in WHEN to ask, not HOW to dispatch.
- Observation-surface enrichment (`--output-format stream-json` live tail) — defer. Could be a P130-follow-up if real-world friction surfaces; today's evidence (this session) is that the friction is "asking too often" not "iter progress is invisible".

**Compose with**: P132 (over-ask in interactive sessions — same family of agent-discipline gaps; P132's Phase 4 enforcement hook directly serves P130's reframed direction), P135 (decision-delegation contract — ADR-044 codifies the framework-resolution boundary that P130 now operationalises in the orchestrator's main turn).

## Dependencies

- **Blocks**: (none — P130 is a UX improvement; nothing strictly waits on it)
- **Blocked by**: (none — implementation can proceed standalone)
- **Composes with**: P122, P084, P077, P078, P083, P081, P124

## Related

- **P122** (`docs/problems/122-...closed.md`) — orchestrator main-turn defaults at stop-condition #2. P130 is the same shape on a different surface (Step 5 dispatch).
- **P084** (`docs/problems/084-...closed.md`) — established `claude -p` subprocess as the canonical iter dispatch. P130 builds on P084 by adding presence-awareness.
- **P077** (`docs/problems/077-...closed.md`) — established Agent-tool dispatch (later superseded by P084). P130 continues the dispatch-shape evolution.
- **P078** (`docs/problems/078-...verifying.md`) — capture-on-correction. P130's own creation was triggered by P078's pattern (user direct contradiction → ticket capture).
- **P083** (`docs/problems/083-...verifying.md`) — iter prompt forbids ScheduleWakeup. P130's main-turn variant inherits the same forbidden-primitives list (no self-rescheduling whether subprocess or main-turn).
- **P124** (`docs/problems/124-...verifying.md`) — `session-id.sh` `shopt-under-zsh` regression. P130's presence-signal detector likely reads session-scoped markers via the same helper, so P124 fix is a soft prerequisite. Observed in this very capture: `get_current_session_id:33: command not found: shopt` on zsh; helper still returned a valid SID via fallback scrape — but the SID it returned was STALE, not the orchestrator's actual SID. The marker had to be re-written by brute-forcing every recent SID before the create-gate hook would unlock. This is fresh evidence of the P124 regression's user-facing impact and confirms iter 4's flag.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — taxonomy parent. P130 amendment adds the interactive-presence variant alongside the existing subprocess-boundary variant.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 (interactive default) and Rule 6 (non-interactive fail-safe). P130's dual-mode dispatch directly serves both rules.
- **ADR-038** (`docs/decisions/038-progressive-disclosure-for-governance-tooling-context.proposed.md`) — once-per-session marker pattern. P130's presence-signal detector reuses the same marker conventions.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — primary persona served. P130 doesn't break the AFK contract — it adds an opt-in interactive-presence path.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — composes; main-turn dispatch reduces "slowdown" perception when the user is present.
- 2026-04-27 session evidence: iter 9 dispatch immediately after user answered `AskUserQuestion` next-step decision; user corrected within ~30 seconds: "I'm not sure why you did that as a background non-interactive run. We could of just done it here. create a problem for that". This ticket is the captured response.

## Fix Released

**Released 2026-04-28** (commit pending — `/wr-itil:work-problems` AFK iter, this commit). Awaiting user verification.

**One-line fix summary**: SKILL.md prose discipline for `/wr-itil:work-problems` — added the **Mid-loop ask discipline (orchestrator main turn)** subsection enumerating the framework-prescribed halt points, the no-mid-iter-asks invariant, and the accumulated-question discipline; augmented Step 5's iteration-prompt body with the transient-user framing; added a Decision Table row; landed `work-problems-no-mid-loop-asking.bats` (20 contract assertions) per ADR-037 + P081.

**Fix shape (per the 2026-04-28 user reframe — Fix Strategy section above)**:

- The original "dual-mode dispatch + presence-signal detector + ADR-032 amendment" approach was superseded by the user reframe. Presence-detection is unreliable and is not the goal — treat the user as transient. The fix is orchestrator-main-turn ask discipline, not a new dispatch mode.
- The orchestrator MUST NOT call `AskUserQuestion` between iters except at the framework-prescribed halt points (Step 0 session-continuity / fetch-failure halt; Step 2.5 / 2.5b loop-end emit; Step 6.5 above-appetite Rule 5 halt + CI-failure / release:watch halt; Step 6.75 dirty-for-unknown-reason halt).
- Accumulated-question discipline at surface time: direction-setting only; no BUFD; no questions answerable by research / exploration / experimentation.
- Out-of-scope per the reframe: presence-signal helper, dual-mode dispatch, observation-surface enrichment, ADR-032 amendment.

**Exercise evidence** (in-iter):

- 175 / 175 work-problems bats pass with the new fixture landed (full suite green; this iter ran the suite via `npx bats packages/itil/skills/work-problems/test/` before commit).
- The 20 new assertions in `work-problems-no-mid-loop-asking.bats` exercise the heading presence, the no-mid-iter-asks invariant, halt-point enumeration, accumulated-question discipline, ADR citations (ADR-044, ADR-013 Rule 1 / Rule 6, ADR-032 unchanged), and the Decision Table row consistency.
- Architect review (`wr-architect:agent`) approved shape, placement (Non-Interactive Decision Making section), and ADR citations. JTBD review (`wr-jtbd:agent`) confirmed JTBD-006 + JTBD-001 alignment.

**Verification requested from user**: on next interactive `/wr-itil:work-problems` invocation, confirm the orchestrator does NOT call `AskUserQuestion` between iters; confirm the loop-end Step 2.5 / 2.5b batched-question surface still functions when `outstanding_questions` are accumulated; confirm halt paths still surface batched questions per the Step 2.5b cross-reference. Close the ticket via `/wr-itil:transition-problem` when verified.
