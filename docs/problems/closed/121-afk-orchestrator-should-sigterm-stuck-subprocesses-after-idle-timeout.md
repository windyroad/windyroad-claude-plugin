# Problem 121: AFK orchestrator should SIGTERM stuck `claude -p` subprocesses after idle-timeout — and SIGTERM appears to flush a clean JSON

**Status**: Closed
**Reported**: 2026-04-25
**Fix Released**: 2026-04-26 (AFK iter 2; `@windyroad/itil` patch — `packages/itil/skills/work-problems/SKILL.md` Step 5 dispatch shape changed from foreground-synchronous to backgrounded + 60s poll loop with idle-timeout SIGTERM branch (default 3600s, env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S`); `LAST_ACTIVITY_MARK = max(DISPATCH_START_EPOCH, git log -1 --format=%at HEAD)` to avoid skip-iteration false-positive; orchestrator's Step 6 progress line annotates `(SIGTERM_SENT)` for distinguishable status per JTBD-006 audit-trail; ADR-032 amended 2026-04-26 with the backgrounded-poll-loop refinement under the subprocess-boundary variant; new `test/work-problems-step-5-idle-timeout-sigterm.bats` (10 tests — 4 behavioural with fake `claude -p` shim covering SIGTERM-fires/JSON-clean-flush/env-override/no-fire-within-threshold + 6 doc-lint contract assertions; 10/10 green; full project bats 993/994 with the 1 failure pre-existing in P120's `.claude/skills/install-updates/` work, unrelated to P121); `docs/briefing/afk-subprocess.md` P121 entry updated to cite the new bats coverage. Awaiting genuine in-the-wild verification: a future AFK iter that genuinely stalls past `WORK_PROBLEMS_IDLE_TIMEOUT_S` should observe SIGTERM fire, clean JSON arrive, and orchestrator continue normally.
**Priority**: 8 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3) — re-rated 2026-04-25 from initial S 9 lean toward 8 to reflect the once-per-multi-iter-loop frequency rather than per-iter
**Effort**: S — orchestrator poll loop already has the stuck-detection signals (PID alive + JSON 0 bytes + no new commits + duration since last activity); add a `LAST_ACTIVITY_MARK` tracker + idle-timeout SIGTERM branch in the existing poll loop
**WSJF**: (8 × 1.0) / 1 = **8.0**

> Surfaced 2026-04-25 in `/wr-itil:work-problems` AFK iter 5 (P118): the iteration's 3 commits (`9c50d03`, `257ea5c`, `c8a87fa`) all landed at the ~100-min wall-clock mark; the subprocess then sat for ~70 min with no further commits, no new JSON output (file stayed 0 bytes), and RSS oscillating 88-99 MB before SIGTERM at the 121-min mark produced a clean 5649-byte response: `is_error: false`, full `## Session Retrospective` section, complete `ITERATION_SUMMARY` block, `duration_ms: 2992935` (49.9 min — matches the "real work" portion). The subprocess had completed its semantic work but was waiting on something (perhaps a hook timeout, perhaps a backgrounded subagent that never resolved) before its natural exit. **This evades the retro-on-exit guarantee (P086): retro IS the hang, so it cannot self-surface.**

## Description

The `/wr-itil:work-problems` orchestrator's poll loop (Step 5) waits for the iteration subprocess to exit and produce a JSON response, then parses `ITERATION_SUMMARY`. The wait pattern is: `kill -0 $PID` until the process exits. There is no idle-timeout — the orchestrator polls indefinitely.

When a subprocess completes its semantic work (commits land, retro runs, ITERATION_SUMMARY is emitted in agent output) but does not exit (waiting on a hook timeout, a backgrounded Agent invocation that never resolves, a subagent task that hangs, etc.), the orchestrator polls forever. The subprocess RSS oscillates around 90 MB with no API turns. The JSON file stays 0 bytes because `claude -p --output-format json` only writes to stdout on exit.

SIGTERM at this point appears to trigger a clean exit-flush: the JSON lands with valid `is_error: false`, the `## Session Retrospective` section is intact, and `ITERATION_SUMMARY` is parseable. This 2026-04-25 evidence suggests SIGTERM is a *safe* recovery primitive for this stuck-state class — not a destructive interrupt.

The orchestrator should detect the stuck-state and SIGTERM rather than wait indefinitely. The detection signals are already present in the poll loop:
- PID still alive (`kill -0 $PID`)
- JSON file 0 bytes (`stat -f%z`)
- No new commits since some marker (`git log` since timestamp)
- Wall-clock duration past a configurable idle threshold (e.g. 30-90 min since last activity)

## Symptoms

- AFK iter 5 (2026-04-25 P118): wall-clock 2h 1min, but `duration_ms` reported 49.9 min. The 70-min gap was post-commit idle wait.
- RSS oscillation 88-99 MB during the idle window with no new commits and no JSON output. Brief spike to 127 MB mid-idle (likely an Agent tool delegation expanding+closing).
- 0-byte JSON file throughout the idle period; final flush only on SIGTERM.
- Cost burn: ~$8 of the iter's $12.86 was during this idle period (extrapolating from the linear cost-per-min pattern of iters 1-4 which all completed without idling).
- Retro-on-exit (P086) cannot surface the hang because retro itself is part of the hang region — the subprocess emitted retro content into agent output, but did not exit, so no JSON was produced and no ITERATION_SUMMARY landed.
- Pattern is consistent with prior AFK iters that had unusually-long wall-clock (P084 closure work mentioned 4-iter probes with cost variance; P089 cost-metadata authority hierarchy diagnosed final-turn-ack-vs-cumulative — adjacent symptom, different root cause).

## Workaround

Manual SIGTERM after polling timeout (the 2026-04-25 evidence). The orchestrator's main turn detects "no progress for ~70 min" and runs `kill -TERM $ITER_PID`; the JSON arrives within seconds. Fragile — relies on the operator noticing and intervening; defeats AFK if the user is genuinely AFK.

## Impact Assessment

- **Who is affected**: Every AFK iter long enough to hit the stuck state. Empirically: ~1 in 5 iters (this 2026-04-25 session: iter 5 stuck; iters 1-4 completed normally). Frequency probably correlates with subprocess duration — longer iters more likely to stall.
- **Frequency**: Once per multi-iter AFK loop on average. Not every iter; this isn't a guaranteed failure mode.
- **Severity**: Moderate. The cost is real (~$8 burn observed) and the failure mode evades retro detection. Worse for AFK orchestrators that release-drain after every iter — the orchestrator stays in foreground waiting for a subprocess that already finished its work.
- **Severity if no fix**: pattern compounds with iter count — a 10-iter AFK loop with 1-in-5 stuck rate burns ~$16 of idle subprocess wall-clock per loop on top of the real iter cost.
- **Analytics**: Direct evidence from 2026-04-25 AFK iter 5 (P118). Prior loops likely hit it too but the orchestrator just kept polling and the wall-clock divergence wasn't surfaced.

## Root Cause Analysis

### Preliminary Hypothesis

The subprocess emits its ITERATION_SUMMARY block in the agent's output stream, then waits for some terminating event before exiting. Candidates for the terminating event:

1. **Hook PostToolUse processing**: a PostToolUse hook (architect-mark-reviewed.sh, jtbd-mark-reviewed.sh, risk-mark-reviewed.sh) backgrounded via `&` in its dispatch; the subprocess waits for the backgrounded job before exit. If the hook is genuinely stuck (timeout, deadlock), the subprocess never exits.
2. **Agent-tool delegation that didn't return**: the iter ran an Agent invocation (e.g. for retro Step 4a verification scan or Step 4b Stage 1 ticketing); the subagent finished but somehow didn't return cleanly to the parent subprocess. The 127-MB RSS spike mid-idle in iter 5's evidence is consistent with this — Agent-tool expansion peaks RSS, then collapses.
3. **Backgrounded bats run from inside retro**: if retro spawned bats via `npm test &` or similar, the subprocess might wait on the background job at exit. Plausible but the iter 5 retro shows no test invocations.
4. **CLI-level idle behaviour**: `claude -p` may have its own idle-wait before exit. Anthropic CLI behaviour we don't yet have visibility on.

The 2026-04-25 evidence does NOT distinguish these. The fix proposed below is mechanism-agnostic — orchestrator-side timeout — so it works regardless of which root-cause subset applies.

### Investigation Tasks

- [ ] Verify SIGTERM safety: re-run iter 5's flow on a future iter that hits the stuck state. Does SIGTERM always produce a clean JSON, or was 2026-04-25 a lucky case?
- [ ] If SIGTERM is safe: add idle-timeout detection to `packages/itil/skills/work-problems/SKILL.md` Step 5 poll loop. Default: 30 min since last activity (last commit timestamp OR last RSS-change marker).
- [ ] If SIGTERM is unsafe: investigate the stuck-state root cause (option 1-4 in the hypothesis section). May require querying Anthropic CLI behaviour or instrumenting the subprocess to log what it's waiting on.
- [ ] Decide the LAST_ACTIVITY signal: (a) last `git log` commit timestamp from within the subprocess's session — needs polling git history; (b) last JSON-file modification — JSON only modifies on exit, so signal is binary; (c) last RSS-change — noisy. Lean: (a), polling git log every 60s during the existing poll loop.
- [ ] Decide the timeout value. 30 min covers most "real work" iter durations (iters 1-4 of 2026-04-25 ran 12-44 min); 60 min is more conservative; both leave headroom for genuinely long architectural iters before triggering. Lean: 60 min for safety, with the option to override per-iter via env var.
- [ ] Add a behavioural bats test that simulates a stuck subprocess (e.g. a fake `claude -p` script that sleeps 10s after final output) and verifies the orchestrator SIGTERMs it after the configured idle threshold.
- [ ] Update afk-subprocess.md briefing entry (already added 2026-04-25 retro) to cite the bats coverage once it lands.

### Fix Strategy

**Shape**: Skill — improvement stub on `packages/itil/skills/work-problems/SKILL.md` Step 5 poll loop.

**Target file**: `packages/itil/skills/work-problems/SKILL.md` Step 5 (the orchestrator's wait-for-subprocess pattern). The skill already polls in 60s ticks; add an idle-timeout branch that fires SIGTERM when "last activity" is older than a configured threshold. New behavioural bats under `packages/itil/skills/work-problems/test/` covering the SIGTERM-on-idle path.

**Observed flaw**: Step 5's poll loop has no upper bound — it polls until the subprocess exits naturally. When the subprocess is stuck post-commit, it never exits, and the orchestrator burns wall-clock waiting.

**Edit summary**: extend the poll loop to track `LAST_ACTIVITY_MARK` (set to the last new commit's timestamp via `git log -1 --format=%at`); when `now - LAST_ACTIVITY_MARK > IDLE_TIMEOUT_S` (default 3600s = 60 min, env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S`), send SIGTERM to the subprocess PID and continue the poll loop until the JSON arrives.

**Evidence** (1-3 session observations):

1. 2026-04-25 AFK iter 5 (P118): 121 min wall-clock; final commit at ~100 min; SIGTERM at 121 min produced clean JSON in seconds; cost ~$8 of $12.86 was the post-commit idle burn.
2. The orchestrator's existing poll loop (per `packages/itil/skills/work-problems/SKILL.md` Step 5 + 6.75) already has the necessary signals: `kill -0 $ITER_PID`, `stat -f%z` on the JSON file, `git status --porcelain`. Adding a `git log -1 --format=%at` poll is structurally trivial.
3. SIGTERM-flushes-JSON evidence is single-source (one observation). Investigation Task 1 confirms before relying on the behaviour for the auto-SIGTERM branch.

**Out of scope**: Investigating the root-cause Anthropic CLI behaviour (defer to upstream if Investigation Task 3 unblocks it). Changing the dispatch surface to `claude -p --max-budget-usd` or similar (rejected per user direction 2026-04-21 — quota is the natural stop). Forced-kill SIGKILL escalation (out of scope until SIGTERM reliability is established).

## Dependencies

- **Blocks**: (none directly — fix is independent)
- **Blocked by**: (none — fix is bounded to the orchestrator's poll loop)
- **Composes with**: P086 (subprocess retro-on-exit — retro can't self-surface this hang since retro IS the hang region; this ticket fixes the orchestrator side); P089 (dispatch robustness — stdin redirect + cost metadata authority — same Step 5 surface, complementary fix); P083 (iteration-worker prompt forbids ScheduleWakeup — different time-deferring primitive, similar effect on subprocess exit timing); P084 (subprocess-boundary dispatch — closed; this ticket extends Step 5's poll loop, not its dispatch).

## Related

- **P086** (`docs/problems/086-afk-iteration-subprocess-does-not-run-retro-before-returning.closed.md`) — closed. Retro-on-exit landed but the retro contract presumes the subprocess will exit; this ticket addresses the case where it doesn't.
- **P089** (`docs/problems/089-work-problems-step-5-dispatch-robustness-stdin-warning-and-cost-metadata-edge-case.verifying.md`) — same Step 5 surface; the stdin-warning fix landed in 0.19.4. This ticket adds an idle-timeout branch on the poll loop that consumes the JSON.
- **P084** (`docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.closed.md`) — closed. Subprocess-boundary dispatch pattern this ticket extends.
- **P083** (`docs/problems/083-work-problems-iteration-worker-prompt-does-not-forbid-schedulewakeup.verifying.md`) — adjacent: forbids time-deferring primitives in the iter prompt. P121 is the orchestrator-side guard for the same class of "subprocess won't exit" gap.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — subprocess-boundary iteration pattern this ticket's poll loop guards.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — target file for the fix.
- `docs/briefing/afk-subprocess.md` — briefing entry added 2026-04-25 retro citing this ticket. Once the fix ships, the entry can stay as a "what to watch for if the orchestrator regresses" note — the proximate cause (no idle-timeout) is fixed, but the ultimate cause (whatever the subprocess waits for at exit) remains unsolved.
- **JTBD-006** (Progress the Backlog While I'm Away) — primary fit. AFK loops that burn wall-clock waiting for stuck subprocesses lose the "while I'm away" property the persona depends on.
- **JTBD-001** (Enforce Governance Without Slowing Down) — secondary. The orchestrator's per-iter cost surfaces include a wall-clock metric; idle burn pollutes the cost-vs-real-work analysis.
- 2026-04-25 session evidence: this retro's `/wr-retrospective:run-retro` pipeline-instability scan (Step 2b) detected the iter-5 hang and routed it through ticket creation per Stage 1.

## Fix Strategy

**Kind**: improve

**Shape**: skill (improvement stub)

**Target file**: `packages/itil/skills/work-problems/SKILL.md` (Step 5 poll loop)

**Observed flaw**: Step 5's poll loop has no upper bound — when an iteration subprocess goes idle post-commit (no new turns, no new commits, JSON file 0 bytes) the orchestrator polls indefinitely, burning wall-clock. SIGTERM appears to trigger a clean exit-flush per the 2026-04-25 P118 iter 5 evidence.

**Edit summary**: Step 5's poll loop adds a `LAST_ACTIVITY_MARK` tracker (sourced from `git log -1 --format=%at` polled every 60s) plus an idle-timeout branch (default 3600s = 60 min, env-overridable via `WORK_PROBLEMS_IDLE_TIMEOUT_S`). When `now - LAST_ACTIVITY_MARK > IDLE_TIMEOUT_S`, send SIGTERM to the subprocess PID and continue polling until the JSON arrives. Add behavioural bats covering the SIGTERM-on-idle path and the env-var override. Update `docs/briefing/afk-subprocess.md` entry to cite the new bats coverage.

**Evidence**:

1. 2026-04-25 AFK iter 5 (P118): subprocess PID 73267 wall-clock 2h 1min; final commit `c8a87fa` at ~100 min; SIGTERM at 121 min produced clean 5649-byte JSON (`is_error: false`, full retro section, valid ITERATION_SUMMARY) within seconds; `duration_ms: 2992935` (49.9 min) confirmed the 70-min idle gap was post-real-work.
2. Orchestrator poll loop already iterates in 60s ticks and tracks the subprocess PID; adding a `git log -1 --format=%at` poll is structurally trivial — no new infrastructure needed.
