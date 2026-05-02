---
"@windyroad/itil": patch
---

fix(itil): work-problems Step 5 iteration prompt forbids `bats`-output regex-poll antipattern (closes P146)

The 2026-04-29 AFK iter 1 (PID 23580 child PID 16408) deadlocked in a `bash until`-loop polling backgrounded `bats --tap` output with regex `^[0-9]+ tests?,` — bats's *default* (non-TAP) console-summary line. `bats --tap` never emits that line, so the until-loop spun forever after bats completed. 68m34s wall-clock burn; manual SIGTERM produced exit 143 + 0-byte JSON (metadata loss per the P147 stuck-before-emit subclass).

Repo audit confirmed the polling idiom is NOT taught by any SKILL.md (`grep -rn "until.*grep" packages/` returned no matches outside the P146 ticket itself). The idiom is agent-learned from training data — a generic bash + bats Bourne idiom. Fix shape per the ticket's "agent-learned, no source-of-truth" branch: prompt-discipline rule + behavioural assertion.

Concretely, the work-problems iteration prompt body's Constraints list now:

- explicitly forbids polling `bats` output with the bats-console-summary regex against TAP-format output;
- names `wait $bg_pid` (Unix idiom) or Bash-tool `run_in_background=true` + `BashOutput` exit-state polling as the safe substitute;
- explains the TAP-vs-console-summary divergence so future contributors don't "fix" the rule incorrectly (e.g. the TAP plan line `^[0-9]+\.\.[0-9]+` is the format-stable sentinel if regex-polling is genuinely required);
- cites P146 inline.

Behavioural second-source: `packages/itil/skills/work-problems/test/work-problems-step-5-bats-polling-discipline.bats` — 5 contract assertions per ADR-037's permitted exception (doc-lint contract assertion against the contract document itself; same shape as the P083 / P089 fixtures already in the suite).

Architect APPROVED at risk 1/25 (Low — SKILL.md prose addition + 1 bats fixture; no executable code change; no commit-gate path touched). JTBD PASS — primary fit JTBD-006 ("progress while I'm away" reliability outcome explicitly mentions extended unattended runs). Scope narrowed to work-problems Step 5 only (per architect): the polling-loop antipattern surface IS AFK-iteration-shaped, not manage-problem-shaped, and mirrors precedent from P083 (ScheduleWakeup ban) and P135 (AskUserQuestion ban) which also live in work-problems Step 5 only.
