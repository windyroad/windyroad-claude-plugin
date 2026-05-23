# Problem 271: `/wr-itil:review-problems` not auto-fired when needed — user has to remember to run it

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 8 (Medium) — Impact: 2 × Likelihood: 4
**Effort**: M (re-estimated 2026-05-18 — trigger condition + auto-dispatch wiring across work-problems/manage-problem/capture-problem surfaces + bats fixture)
**Type**: technical

## Description

> I'm finding that I have to remember to run review-problems. I'm expecting it to run automatically when needed

`/wr-itil:review-problems` is a heavyweight skill that re-rates Priority + Effort for deferred-placeholder tickets, refreshes WSJF Rankings + Verification Queue ordering, and updates `docs/problems/README.md`. Every `/wr-itil:capture-problem` invocation creates tickets with `(deferred — re-rate at next /wr-itil:review-problems)` placeholders that accumulate until the user manually invokes review-problems. The skill never auto-fires.

Worked example evident this session: 7 captures (P266, P267, P268, P269, P270, P271 — this one, plus pre-session P252/P264) all share the deferred-placeholder pattern, all wait for the user to remember to invoke review-problems. The user explicitly highlighted at this iteration mid-loop: "I'm finding that I have to remember to run review-problems. I'm expecting it to run automatically when needed."

**Auto-fire trigger candidates** (any of which could individually justify a review-problems auto-dispatch):

1. **N captures since last review** — e.g. after 3+ tickets accumulate with deferred-placeholder text since the last review, auto-fire at next safe point (loop-end Step 2.5, manage-problem Step 0 preflight, etc.).
2. **README.md `Last reviewed:` annotation older than X days** — e.g. >7 days since last full review (where "full review" means all open + known-error tickets re-rated, not just per-operation refresh).
3. **AFK orchestrator preflight detects stale rankings** — P187 captures this specific surface (orchestrator halts with "recommended next step" instead of auto-dispatching). P271 is the broader umbrella: P187's surface is one example of a class.
4. **Pre-iter dispatch when WSJF scores are deferred-placeholder** — if the top-ranked ticket has placeholder WSJF (just-captured), the orchestrator should re-rate before dispatching the iter (otherwise iter risks working an under-/over-rated ticket).
5. **Pre-release-cadence drain when capture batch ≥ N** — if Step 6.5's classifier would drain N captures whose Priority is uncalibrated, review-problems should fire first to ensure release decisions are well-grounded.

**Recommended fix shape**: trigger-and-route at the orchestrator + manage-problem Step 0 surfaces.

- Trigger condition: count deferred-placeholder tickets via `grep -cl 'deferred — re-rate at next' docs/problems/open/*.md docs/problems/known-error/*.md`. When count ≥ 3 AND last-reviewed annotation older than 7 days, auto-dispatch /wr-itil:review-problems before the next iter.
- Route: in AFK orchestrator main turn, the trigger fires at Step 0a (after auto-migrate, before backlog scan). In manage-problem Step 0 (interactive), the trigger fires before backlog scan. In capture-problem Step 0, the trigger fires AFTER capture (the capture itself shouldn't be gated; the auto-fire is for the NEXT user-action).
- Authorisation: per ADR-013 Rule 5 + ADR-044 framework-resolution boundary — review-problems is policy-authorised silent proceed when accumulated-placeholder threshold met. Same shape as Step 0a auto-migrate (P170 RFC-002 T5a precedent).

## Symptoms

(deferred to investigation)

**Evidence (2026-05-24, work-problems session)**: the deferred-placeholder count reached **83** (`grep -rl 'deferred — re-rate at next' docs/problems/open/ docs/problems/known-error/`). At work-problems loop end the user was asked how to handle the accumulated bulk re-rate and directed: **apply the re-rate in small batches** (preserving the incremental git-visible cadence; auto-decisions have drifted poor) **AND capture a problem ticket for getting into this state** — that meta-ticket is THIS ticket (P271). The ~76→83 accumulation is the concrete witness of the exact gap P271 describes: review-problems never auto-fired, so 83 placeholders piled up across many sessions. The user's "small batches" cadence directive REFINES P271's recommended fix shape — the auto-fire trigger should re-rate incrementally (a bounded batch per fire), NOT bulk-re-rate all 83 at once. Add that constraint to the fix design.

Initial observations:
- 5 pre-existing entries in `.afk-run-state/outstanding-questions.jsonl` queued from session 7 + 3 from session 8 iter 2 = 8 total queued at this point in session 8.
- 8 capture-problem tickets created in last 2 sessions (P252/P264/P266/P267/P268/P269/P270/P271) all carrying `(deferred — re-rate at next /wr-itil:review-problems)` placeholders.
- The user invoked review-problems 0 times across both sessions; the agent invoked it 0 times.
- Top WSJF rankings in README.md may be stale by N% (the 8 deferred-placeholder captures are interleaved at WSJF=9.0/6.0/3.0/1.0 based on framework defaults; real WSJF after review may move them up or down significantly).

## Workaround

User manually invokes `/wr-itil:review-problems` periodically. Friction: user has to know when to invoke (no signal surface), walk through the heavyweight review, then return to whatever they were doing. The signal "deferred placeholders accumulated" is currently invisible to the user.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — likely both maintainers (deferred-placeholder accumulation invisible) and AFK orchestrator (iters dispatch against potentially-stale WSJF rankings).
- **Frequency**: (deferred to investigation) — every session that creates ≥ 3 captures without invoking review-problems.
- **Severity**: (deferred to investigation) — initial: moderate. Compounds with capture-problem usage growth.
- **Analytics**: (deferred to investigation) — count of `(deferred — re-rate at next /wr-itil:review-problems)` substrings in `docs/problems/open/*.md` + `docs/problems/known-error/*.md`.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems (meta-recursive ✓)
- [ ] Investigate root cause — review-problems was designed as user-invoked; no auto-trigger surface exists. The deferred-placeholder pattern presupposes a NEXT review invocation that never happens autonomously.
- [ ] Survey existing trigger surfaces in `packages/itil/skills/work-problems/SKILL.md` Step 0 / Step 0a / Step 0b (preflight stage); `packages/itil/skills/manage-problem/SKILL.md` Step 0; `packages/itil/skills/capture-problem/SKILL.md` Step 0 — identify where to wire the deferred-placeholder-count trigger.
- [ ] Sibling P187 is one specific surface (orchestrator preflight unblock) — verify P271's fix shape composes with P187 rather than duplicating; consider folding P187 into P271 or vice versa at next review.
- [ ] Sibling P110 (risk register has no passive trigger) is analogous pattern at risk-register surface — same fix class, different artefact; document the pattern at meta level.
- [ ] Create reproduction test (bats fixture: 3 deferred-placeholder tickets exist; orchestrator preflight detects + auto-dispatches review-problems; bats asserts the dispatch fired and the placeholders were re-rated).

## Dependencies

- **Blocks**: any reliable WSJF-driven prioritisation when captures accumulate — orchestrator may dispatch iters against stale rankings.
- **Blocked by**: (none observed yet)
- **Composes with**:
  - P187 — orchestrator detects review-problems unblock, halts with "recommended next step" instead of auto-dispatching (specific surface of the same class P271 captures)
  - P110 — risk-register has no passive trigger (analogous pattern at different artefact)
  - P246 — agent waits on calendar trigger for held-cohort graduation (analogous defer-anti-pattern; user direction: "evidence-based not time-based")
  - P247 — run-retro Step 3 Tier 3 Branch B "leave-as-is" encodes fictional defer (analogous; same calendar-defer class)
  - P190 — agent designs schemas with user-asked classification fields when framework should derive silently (deeper generalisation — review-problems auto-fire is the framework-derive shape)
  - ADR-013 Rule 5 — policy-authorised silent proceed (the trigger-and-route IS Rule 5 behaviour)
  - ADR-044 — framework-resolution boundary (when to auto-fire IS framework-resolved, not user-asked)
  - JTBD-006 — Progress the Backlog While I'm Away (auto-fire ensures the backlog rankings stay live during AFK loops)

## Related

(captured via /wr-itil:capture-problem mid-loop — orchestrator main turn while iter 3 P268 was running in background subprocess; user-initiated capture per CLAUDE.md MANDATORY capture-on-correction rule; description shape matches user explicit direction "I'm expecting it to run automatically when needed" — class-of-behaviour signal for framework auto-trigger)

- P187 — sibling at orchestrator preflight surface
- P110, P246, P247, P190 — sibling pattern cluster (defer / auto-fire / framework-resolution)
- ADR-013, ADR-044 — authorisation framework
- JTBD-006 — AFK persona constraint
- `packages/itil/skills/review-problems/SKILL.md` — target skill that needs an auto-fire trigger surface
- `packages/itil/skills/work-problems/SKILL.md` Step 0/0a/0b — candidate trigger sites for the orchestrator surface
- `packages/itil/skills/manage-problem/SKILL.md` Step 0 — candidate trigger site for interactive surface
- `packages/itil/skills/capture-problem/SKILL.md` Step 7 trailing-pointer — current placeholder mechanism (the "Run /wr-itil:review-problems next" trailing pointer signals stale README but does NOT auto-dispatch; P271 closes the gap between signal and action)
