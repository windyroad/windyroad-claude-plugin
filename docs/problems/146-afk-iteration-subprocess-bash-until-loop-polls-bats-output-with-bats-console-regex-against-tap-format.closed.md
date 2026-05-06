# Problem 146: AFK iteration subprocess `bash until`-loop polls bats-output file with bats-console regex against TAP-format output — deadlocks indefinitely, manual SIGTERM required, JSON metadata lost

**Status**: Closed
**Reported**: 2026-04-29
**Priority**: 8 (High) — Impact: Moderate (4) x Likelihood: Possible (2) — fires every AFK iteration whose `manage-problem` Step 11 commit-gate runs the full bats suite via the polling pattern; observed today end-to-end with concrete cost (68m34s wall-clock + lost ITERATION_SUMMARY).
**Effort**: M — investigate which SKILL.md / agent-prompt / bash-idiom reference taught the iteration agent the bats-console-summary regex shape; correct the source so iteration subprocesses use a TAP-compatible terminator pattern (or switch off the polling-regex pattern entirely in favour of `wait` on the backgrounded PID). Plus matching behavioural bats per ADR-037 + P081.
**WSJF**: (8 × 1.0) / 2 = **4.0**
**Type**: technical

## Description

During AFK iteration 1 (P143 `release-watch.sh` race-condition fix) on 2026-04-29, the iteration subprocess (`claude -p`, PID 23580) deadlocked in a `bash until`-loop polling for a backgrounded-task output file. The polling regex was `^[0-9]+ tests?,` — bats console-summary format — but the polled file (`/private/tmp/claude-501/.../tasks/bt4cgdx0v.output`) contained TAP-format output (`ok 1 ... ok 1455 install-updates: REFERENCE.md ...`). TAP output never emits a line matching `^[0-9]+ tests?,`, so the until-loop spun forever after the bats run completed at ~08:11.

The subprocess had completed its semantic work — commits `e56de11` (fix) and `e7e471c` (retro) landed at ~08:32 — but never reached `ITERATION_SUMMARY` emission. The orchestrator polled via ScheduleWakeup four times (~50 min wall-clock) before discovering the deadlock via `ps -ef` child-process inspection. Manual SIGTERM at 08:51 (68m34s wall-clock) recovered the orchestrator. JSON metadata was lost (P147 — distinct ticket).

## Symptoms

- Iter 1 PID 23580 child PID 16408 ran a Bash invocation: `until [ -f /private/tmp/claude-501/.../tasks/bt4cgdx0v.output ] && grep -qE '^[0-9]+ tests?,' /private/tmp/claude-501/.../tasks/bt4cgdx0v.output 2>/dev/null; do sleep 5; done; tail -25 ...`
- Polled file existed (last modified 08:11) with content shape `ok 1 <test name>` ... `ok 1455 install-updates: REFERENCE.md does not claim uninstall refuses project-scope (P106)`. TAP-format only — no bats console-summary line.
- `bats --tap` (which is what the iteration was using per the visible command line) does NOT emit a console summary line of shape `1455 tests, 0 failures` — that line is bats's *default* (non-TAP) formatter output.
- Subprocess kept polling every 5s after final commit at 08:32; manual SIGTERM at 08:51 produced exit 143 + 0-byte JSON file.
- Cost: 68m34s subprocess wall-clock burn for ~30+ min of zero-API-work polling time. Lost cost metadata (per P147).

## Workaround

Manual orchestrator-side SIGTERM after observing the deadlock via `ps -ef` child-process inspection. Today: orchestrator's 4th ScheduleWakeup wakeup did the inspection that found the until-loop; SIGTERM cleaned up. Higher-friction recovery than the SKILL.md's documented "subprocess auto-exits after JSON emit" expected path.

## Impact Assessment

- **Who is affected**: every `/wr-itil:work-problems` AFK iteration whose iteration agent uses the same polling pattern. Today's incident was iter 1; pattern recurrence depends on whether the polling-regex shape is taught by a SKILL.md / agent prompt that fires across iterations.
- **Frequency**: TBD — pending audit. If the pattern is taught by `manage-problem` Step 11's bats-suite invocation guidance, every Step 11 invocation that uses bats's TAP formatter would deadlock. If it's taught only by an agent-side learned bash idiom, it's variable.
- **Severity**: High (4) on a per-incident basis — JSON metadata loss, ~30 min wall-clock cost per incident, requires manual SIGTERM recovery, defeats the AFK loop's "progress without me being present" persona (JTBD-006).
- **Likelihood**: Possible (2) — depends on the pattern's source. Pending Investigation Task #1.
- **Analytics**: 1 observed incident today (iter 1 PID 23580); root-cause source unknown until audit.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit `packages/itil/skills/manage-problem/SKILL.md` Step 11 commit-gate guidance for any polling-loop pattern that uses `^[0-9]+ tests?,` or similar bats-console-summary regex. Search for `until.*grep.*tests?,` and `^[0-9]+.tests?,` patterns.
- [ ] Audit `packages/itil/skills/work-problems/SKILL.md` Step 5 dispatch + iteration-prompt body for any pattern that teaches the iteration agent to wait on bats output via grep-poll.
- [ ] Audit any `subagent`-defined prompts (architect, jtbd, risk-scorer, style-guide, voice-tone) for similar patterns.
- [ ] Search the `claude-in-chrome` / `claude-code-guide` / Anthropic SDK docs / Bash-idiom literature the iteration agent would have learned this pattern from.
- [ ] Determine: is the regex shape the bug, OR is the polling-vs-wait pattern itself the bug? Two distinct root causes.
- [ ] Decide fix: regex correction (replace `^[0-9]+ tests?,` with TAP-terminator like `^# bats:end` or `^[0-9]+\.\.[0-9]+`) vs pattern replacement (use `wait $bg_pid` or signal-based completion). The latter is more robust but a deeper rewrite.
- [ ] Behavioural bats per ADR-037 + P081 covering the chosen fix.

### Preliminary hypothesis

The iteration agent (or the SKILL.md it follows) learned a Bash idiom for polling bats output that assumed bats's default formatter (which emits `<N> tests, <M> failures` summary line). When the iteration runs `bats --tap` to integrate with another consumer, the regex never matches. The deadlock is silent — no error, no exit, just forever-poll.

If the pattern is in a SKILL.md (versioned, distributed), the fix is a SKILL.md amendment + behavioural bats. If the pattern is agent-learned (no source-of-truth), the fix is harder — needs prompt-discipline rule.

## Fix Strategy

**Kind**: improve

**Shape**: skill (likely `packages/itil/skills/manage-problem/SKILL.md` Step 11 OR `packages/itil/skills/work-problems/SKILL.md` Step 5 — pending Investigation Task #1) + behavioural bats

**Target file**: TBD pending audit

**Observed flaw**: the polling regex `^[0-9]+ tests?,` (bats console-summary format) doesn't match `bats --tap` output. The until-loop spins forever after bats completes successfully, deadlocking the subprocess.

**Edit summary** — two candidate fix shapes:

1. **Regex correction** (smaller fix, narrower coverage). Replace `^[0-9]+ tests?,` with a TAP-compatible terminator. Three TAP-shape options: `^[0-9]+\.\.[0-9]+` (TAP plan line, e.g. `1..1455`); `^# bats:end` (bats's TAP-mode end marker); `^(ok|not ok) [0-9]+ -- last-test-name` (sentinel anchored on a known-final test). Keep the polling pattern; just fix the regex.

2. **Pattern replacement** (deeper fix, broader coverage). Replace polling-via-grep with backgrounded-PID-wait: `bats ... &; bg_pid=$!; wait $bg_pid; exit_status=$?`. This is the standard Unix idiom for "spawn and wait" — no regex required, completion is signaled by process exit. Eliminates both the regex-mismatch class AND the silent-spin-forever class. Heavier rewrite.

**Architect review will pick** between (1), (2), or both at different surfaces. If the pattern lives in SKILL.md, the fix is a versioned amendment. If it lives in an agent-learned idiom, the fix is a prompt-discipline rule + behavioural test on the bats invocation surface.

**Evidence**:
- 2026-04-29 iter 1 PID 23580 / child PID 16408 — concrete deadlock with citable command line and polled file content.
- 68m34s wall-clock burn vs ~38min real work = 30min wasted.
- JSON metadata loss (per P147).

## Dependencies

- **Blocks**: P147 (SIGTERM-clean-flush caveat) is partially-mitigable here — if the polling-regex bug is fixed, the stuck-before-emit subclass that caused today's metadata loss disappears. Doesn't block P147 entirely (other stuck-before-emit failure modes may exist) but reduces the surface.
- **Blocked by**: (none — fix is independent)
- **Composes with**: P121 (verifying — orchestrator-side idle-timeout SIGTERM that already ships), P086 (verifying — retro-on-exit clause), P084 (verifying — subprocess-boundary dispatch), P130 (verifying — transient user / no-mid-loop-asks discipline). All verifying — this ticket fills a gap NOT covered by their fixes.

## Related

- **P121** (`docs/problems/121-afk-orchestrator-should-sigterm-stuck-subprocesses-after-idle-timeout.verifying.md`) — orchestrator-side SIGTERM at 60-min idle threshold. Today the dispatch script's SIGTERM threshold had not yet fired when manual SIGTERM was sent (idle timer reset by recent commits, threshold was at 09:32, manual SIGTERM at 08:51).
- **P086** (`docs/problems/086-afk-iteration-subprocess-does-not-run-retro-before-returning.verifying.md`) — retro-on-exit clause. Today retro DID run inside the subprocess and committed (`e7e471c`); it was the polling-loop that fired AFTER retro that deadlocked. So P086's fix held; P146's bug is downstream of retro completion.
- **P084** (`docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.open.md`) — subprocess-boundary dispatch. Iter 1 used the correct dispatch shape.
- **P147** — sibling ticket (this same retro). The metadata-loss outcome from P146 is the contract gap P147 captures on the SIGTERM-flush side.
- **P083** (`docs/problems/083-work-problems-iteration-worker-prompt-does-not-forbid-schedulewakeup.verifying.md`) — distinct iteration-worker-prompt-discipline gap. Same skill surface; different rule.
- **`packages/itil/skills/manage-problem/SKILL.md`** Step 11 — primary audit target.
- **`packages/itil/skills/work-problems/SKILL.md`** Step 5 — secondary audit target.
- 2026-04-29 retro evidence: orchestrator main turn observed PID 23580's child PID 16408 running the until-loop at 08:24 wakeup; SIGTERM at 08:51 confirmed exit 143 + 0-byte JSON.

## Fix Released

**Date**: 2026-05-03 (AFK iter 10).

**Fix shape** — prompt-discipline rule + behavioural assertion (the "agent-learned, no source-of-truth" branch the ticket flagged in its Fix Strategy). Audit confirmed the polling idiom is NOT taught by any SKILL.md or agent prompt in the repo (`grep -rn "until.*grep" packages/` and `grep -rn "^[0-9]+ tests?,"` returned no matches outside this ticket itself). The idiom is generic bash + bats Bourne literature — agent-learned from training data.

**Edits landed**:

- `packages/itil/skills/work-problems/SKILL.md` — Step 5 iteration prompt body Constraints list extended with a P146 clause that (1) explicitly forbids polling `bats` output with the bats-console-summary regex against TAP-format output, (2) names `wait $bg_pid` (Unix idiom — completion signaled by process exit, no regex required) or Bash-tool `run_in_background=true` + `BashOutput` exit-state polling as the safe substitute, (3) explains the TAP-vs-console-summary divergence so future contributors don't "fix" the rule incorrectly (the TAP plan line `^[0-9]+\.\.[0-9]+` is the format-stable sentinel if regex-polling is genuinely required), and (4) cites P146 inline. Related-section P146 cite added with full incident summary + cross-reference to the behavioural fixture.

- `packages/itil/skills/work-problems/test/work-problems-step-5-bats-polling-discipline.bats` — new fixture, 5 contract assertions per ADR-037's permitted exception (doc-lint contract assertion against the contract document itself; same shape as the existing P083 ScheduleWakeup-ban fixture and P089 stdin-redirect fixture). Asserts: prohibition phrase present, safe-substitute pointer present, P146 cite present, TAP/console-summary divergence explanation present, Related-section P146 cite present.

**Architect verdict**: APPROVED, risk 1/25 (Low) — SKILL.md prose addition + 1 bats fixture; no executable code change; no commit-gate path touched. Architect narrowed scope from the ticket's "two SKILL.md surfaces" suggestion (work-problems Step 5 + manage-problem Step 10/11) to **work-problems Step 5 only**, on grounds that (a) the polling-loop antipattern surface IS AFK-iteration-shaped (bats fork-and-poll inside `claude -p` subprocess), not manage-problem-shaped (manage-problem Step 11 commit-gate delegates to risk-scorer, doesn't fork bats); (b) precedent — P083 (ScheduleWakeup ban) and P135 (AskUserQuestion ban) are both AFK-iteration-worker discipline rules that live in work-problems Step 5 only; and (c) DRY — mirroring would require a shared snippet to prevent wording drift, and the manage-problem surface doesn't currently exhibit the failure mode.

**JTBD verdict**: PASS. Primary fit JTBD-006 ("Progress the Backlog While I'm Away") — explicit "loop should be safe to run for extended periods" + "may be away for minutes or hours" outcomes. Secondary fits JTBD-001 (governance speed) and JTBD-101 (contributor pattern preventing future plugin authors copying the bad idiom).

**Release vehicle**: `@windyroad/itil@0.23.5` (changeset `.changeset/p146-bats-polling-discipline.md`, patch bump). The orchestrator's Step 6.5 release-cadence drain owns the actual `push:watch` + `release:watch` invocation.

**Verification on next AFK loop**: any future iteration that needs to wait on a backgrounded bats run reads the iteration prompt body's new clause, reaches for `wait $bg_pid` or `BashOutput` exit-state instead of the regex-poll antipattern, and exits cleanly with `ITERATION_SUMMARY` populated. The empirical regression signal is the absence of stuck-before-emit deadlocks in subsequent retros (compare against the 2026-04-29 incident rate). The behavioural bats fixture protects against accidental clause removal.

**Closure criterion**: one full AFK loop runs to completion without a stuck-before-emit deadlock recurring on this specific antipattern shape (regex-poll on bats output). If the empirical signal holds, transition Verifying → Closed in the next retrospective.
