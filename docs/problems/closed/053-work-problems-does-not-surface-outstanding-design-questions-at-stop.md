# Problem 053: work-problems does not surface outstanding design questions at stop-condition #2

**Status**: Closed
**Reported**: 2026-04-19
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: 8.0 — (8 × 2.0) / 2

## Fix Released

Shipped 2026-04-19 (AFK iter 4) — `packages/itil/skills/work-problems/SKILL.md` extended to surface outstanding design questions at stop-condition #2 before emitting `ALL_DONE`:

- **Step 2**: stop-condition #2 now routes to a new Step 2.5 before `ALL_DONE`. Stop-conditions #1 and #3 keep the direct-emit behaviour.
- **Step 2.5 (new)**: extracts user-answerable questions from skipped tickets, branches on interactivity per ADR-013. Interactive → single `AskUserQuestion` call (cap 4 per Anthropic tool docs). Non-interactive / AFK → emit `### Outstanding Design Questions` table in post-stop summary (Rule 6 fail-safe).
- **Step 4 classifier**: skip-reason taxonomy (`user-answerable` / `architect-design` / `upstream-blocked`) added as a dedicated column; classifier rows now tag each Skip action with a category so Step 2.5 can deterministically select the user-answerable subset. Added two new classifier rows for "outstanding user-answerable design question" (surface at stop) and "needs architect design judgment" (pre-triggerable in `--deep-stop` mode).
- **Output Format**: the Final Summary template gains an `### Outstanding Design Questions` section (Ticket / Question / Context columns), emitted only when stop-condition #2 fires AND at least one skipped ticket has a user-answerable skip-reason. Table is omitted otherwise.
- **Non-Interactive Decision Making table**: new row documents the stop-condition #2 default (emit table, do not call AskUserQuestion) per JTBD-006 persona constraint.

Tests — `packages/itil/skills/work-problems/test/work-problems-stop-condition-questions.bats` (new, 7 assertions, RED→GREEN this iteration):

- SKILL.md exists (P053 precondition).
- Stop-condition #2 has a pre-terminal question-surfacing step.
- 4-question `AskUserQuestion` cap cited (per Anthropic tool docs + ADR-013).
- Classifier records the user-answerable / architect-design / upstream-blocked skip-reason taxonomy.
- Non-interactive fallback emits Outstanding Design Questions table (Rule 6).
- ADR-013 Rule 6 cited in the stop-condition block.
- Output Format template includes the Outstanding Design Questions section.

Full project test surface: 253 tests, 0 failures (was 246/0; +7 from this iteration).

Architecture + JTBD reviews: both PASS. No new ADR required — within-skill extension that layers on ADR-013 Rules 1 (interactive batching) + 6 (non-interactive table fallback) and does not conflict with ADR-018 (release cadence, distinct Step 6.5 surface). Architect recommendation on the mode branch followed: AskUserQuestion when interactive, Outstanding Design Questions table when AFK. JTBD-006 alignment: the table path is the default for this skill since the persona is AFK by definition. JTBD-001: no 60-second-norm violation (stop-summary is per-loop, not per-edit). ADR-005 Permitted Exception covers the structural bats assertions, mirroring work-problems-preflight.bats and work-problems-release-cadence.bats.

Awaiting user verification: next stop-condition #2 event in an AFK loop should emit an `### Outstanding Design Questions` table in the summary listing user-answerable skipped tickets with their questions + context.

### Exercise evidence (post-release, same session)

- **2026-04-19 AFK loop iter 4 `ALL_DONE` summary**: Step 2.5 fired end-to-end on its own invocation. The loop hit stop-condition #2 after completing P051 / P053 / P049+migration / P048 and finding that all remaining Open tickets (P015, P018, P022, P046, P014, P019, P045, P012, P034) needed architect-design or user-answerable input. The final summary emitted the `### Outstanding Design Questions` table listing 5 user-answerable questions (P048 candidates 2/3/5, P019 direction, P015 vague-Gherkin spec, P022 grounded-estimate policy, P046 high-traffic predicate) with Ticket / Question / Context columns in the exact format specified by the fix. Non-interactive path per ADR-013 Rule 6 (JTBD-006 persona default) — no AskUserQuestion fired; the table is the record the user reads on return. The Skipped table's new `Skip-reason category` column populated correctly (`architect-design` for the XL tickets; `user-answerable (direction)` for P019). End-to-end verification of the P053 fix on its own invocation.

## Description

`wr-itil:work-problems` stop condition #2 fires when "all remaining problems require interactive input". The skill today emits `ALL_DONE` with a summary table of what was worked, skipped, and remaining — but does NOT surface the specific design questions that caused each remaining ticket to be skipped.

Concrete session observation (2026-04-19 AFK loop, iter 3 that never happened):

After shipping P047 (iter 1) and P050 (iter 2), the loop stopped with `ALL_DONE` at stop-condition #2. The WSJF-4.0 Open tier was P048 / P049 / P051, each with a different outstanding design question:

- P048: observation annotation format (new-ADR-level vs within-skill pattern?)
- P049: status name + file suffix for the new Verification-Pending state
- P019: direction on ADR-008 amendment (remove fallback vs keep as advisory)
- P051: pacing — rewrite Step 2/4b/5 again immediately or let P050 settle?

The loop's final report listed these tickets with one-line reasons ("needs architect design judgment", "new ADR required") but did not **ask the specific questions** of the user before stopping. The user had to prompt: "if you need interactive design decisions, you should be taking the opportunity to ask, not saying 'nothing needed'."

Once prompted, I surfaced four AskUserQuestion calls covering P028 close / P051 pace / P049 naming / P019 direction. The user answered all four in one interaction. Next AFK loop can now implement against those decisions without re-asking.

This is the gap: work-problems' stop flow treats "needs interactive input" as a terminal state rather than an opportunity to batch the outstanding questions through `AskUserQuestion` before the terminal state. The information the user needs to decide is fully known at stop time — there is no cost to asking.

## Symptoms

- AFK loops that stop at condition #2 leave the user's attention cycle dependent on them reading the loop's summary, translating each skipped ticket's blocker into a concrete question, and then deciding case-by-case. Cognitive load that belongs to the orchestrator is pushed to the user.
- When the user doesn't know to prompt for the questions, design decisions stay outstanding across sessions. Next AFK loop re-hits the same stop condition with the same blockers.
- Problem tickets retain their "waiting on architect design judgment" notes indefinitely without the architect review actually happening — the loop silently re-skipped them each iteration.
- The pattern is AFK-specific: the very reason the user is AFK is so they don't have to babysit the loop. But the loop's current stop behaviour requires them to babysit the summary to notice which questions need answering.
- Observed 2026-04-19: loop emitted `ALL_DONE` with 11 remaining items; user had to read the table and prompt, at which point 4 concrete questions could be batched.

## Workaround

- User reads the post-loop summary carefully and spots which skipped tickets have user-answerable blockers vs which are blocked on external (architect / ADR-heavy) work.
- User prompts the assistant to "ask me the design questions you need before I go AFK" (this session's exact prompt was the workaround).
- The assistant manually extracts up to 4 questions from the skipped-tickets list and batches them via `AskUserQuestion`.

None of these are systemic. All rely on the user noticing the gap in the post-stop summary.

## Impact Assessment

- **Who is affected**: solo-developer persona (JTBD-006 Progress the Backlog While I'm Away). JTBD-006's explicit desired outcome includes "surfaces questions that need my input before I return" — currently unmet at stop-condition #2.
- **Frequency**: every AFK loop that hits stop-condition #2 with ≥1 skipped ticket whose blocker is user-answerable. Empirically: this session (2/2 AFK loops run in recent memory) hit this condition.
- **Severity**: Minor — no functional breakage, no data loss. The cost is decision latency (design choices sit unanswered for additional sessions) and the user-cognitive-load shift.
- **Analytics**: 2026-04-19 session — 4 user-answerable design questions sat in skipped-tickets list; all 4 answered in one batch once prompted. Next-loop implementation unblocked for P019, P049, P051 and P028 closed.

## Root Cause Analysis

### Structural: stop-condition #2 is terminal, not interrogative

`packages/itil/skills/work-problems/SKILL.md` Step 2 stop conditions list:

1. No actionable problems
2. All remaining problems require interactive input
3. All remaining problems are blocked

Condition #2 is worded as a terminal state. The skill's current behaviour on hitting it is to emit `ALL_DONE`. There is no step between "detect the condition" and "emit the terminal marker" where the skill is instructed to extract the batchable questions and ask them.

### Structural: the classifier's skip reasons are prose, not structured

Step 4's classifier table has a "Skip" action but does not require the skill to categorise the skip reason into a question shape. The skip reasons observed in practice partition cleanly:
- **User-answerable design question** (naming, direction, pacing, scope): should be surfaced.
- **Architect design judgment needed** (new ADR required, cross-plugin coordination): could be pre-triggered by spawning the architect agent for a review that produces a concrete question for the user.
- **Upstream-blocked** (external dependency, Claude Code capability gap): genuinely terminal — no user question possible until the dependency lands.

The first two shapes are interrogative; the third is truly terminal. Today all three collapse into one `ALL_DONE` emit.

### Candidate fixes

1. **Extend stop-condition #2 with a pre-terminal AskUserQuestion step**: between detecting the condition and emitting `ALL_DONE`, the skill enumerates skipped tickets with user-answerable blockers and batches them into one `AskUserQuestion` call (cap at 4 questions per call — `AskUserQuestion`'s documented limit). Questions answered in the same session update the respective problem files so the next loop picks them up without re-asking. Low-cost SKILL.md edit.

2. **Classify skip reasons structurally**: when classifying a problem as "Skip — user-answerable" vs "Skip — architect-design" vs "Skip — upstream-blocked", record the category alongside the skip in the iteration report. The stop-flow then reads the categories and only prompts for the user-answerable skips.

3. **For architect-design skips, pre-trigger the architect agent** at stop time to produce a concrete question (e.g. "does this need a new ADR?" → architect answers "yes — name, location, scope"). The architect's answer becomes a user-answerable question batched with the others. Adds cost per skipped architect-design ticket; could be gated behind an explicit user preference (`--deep-stop` or similar).

4. **Non-interactive fallback**: when `AskUserQuestion` is unavailable (e.g. running inside a sub-loop or with --channels that disables AskUserQuestion), the skill records the question list in the post-stop summary as a structured "Outstanding Design Questions" table so the user can answer them on return without the assistant re-deriving which ones to ask.

Candidates 1 + 2 are the minimum viable fix. Candidate 3 is a nice-to-have that closes the architect-design half-gap. Candidate 4 is the ADR-013 Rule 6 pattern applied to this surface.

### Investigation Tasks

- [ ] Architect review: does "surface batched questions at stop" need an ADR? Expected verdict: additive to ADR-013 Rule 1 (AskUserQuestion for governance decisions) and ADR-018 (release cadence in AFK loops). Within-skill extension, no new ADR. Could layer naturally on P048's detection pattern.
- [ ] Draft SKILL.md edits: add a Step 2.5 (pre-terminal question batch) between the stop detection and the `ALL_DONE` emit. Specify the cap (4 questions per `AskUserQuestion` call per tool docs), the question selection rule (user-answerable skips only), and the follow-up (update each problem file with the user's decision so next loop doesn't re-ask).
- [ ] Define the skip-reason classification (Candidate 2): update the classifier table in `work-problems` SKILL.md to name the three skip categories explicitly.
- [ ] Add bats test: assert SKILL.md's stop-condition #2 path includes an AskUserQuestion step BEFORE `ALL_DONE`, and that the question-selection rule references the user-answerable skip category.
- [ ] Consider interaction with P048 (detection of verification candidates): the same stop-flow should also surface Fix-Released tickets whose fix path was exercised in-session AND the user has evidence to close (session's P028 close-prompt was the worked example). P048 + P053 likely share the detection surface; land together or P048 first.
- [ ] Consider interaction with JTBD-006: the "surfaces questions that need my input before I return" outcome needs either this ticket's fix or an alternative path. Document which outcome this fix serves.

## Related

- `packages/itil/skills/work-problems/SKILL.md` — primary fix target (Step 2 stop conditions, Step 4 classifier, final report format).
- P048: `docs/problems/048-manage-problem-does-not-detect-verification-candidates.open.md` — sibling; P048 detects verification candidates, P053 detects outstanding design questions. Same "surface at stop" pattern, different input.
- P014: `docs/problems/014-aside-invocation-for-governance-skills.open.md` — related capture pattern but fires mid-session, not at AFK stop.
- ADR-013: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — Rule 1 (AskUserQuestion for branch decisions) and Rule 6 (non-interactive fallback) both apply.
- ADR-018: `docs/decisions/018-lean-release-cadence.proposed.md` — stop-condition #2 fires in the same loop ADR-018 governs release cadence for.
- JTBD-006: `docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md` — "surfaces questions that need my input before I return" desired outcome currently unmet.
- Session evidence 2026-04-19: AFK loop hit stop-condition #2 with P028 verification + P049 naming + P019 direction + P051 pacing outstanding. User prompted; 4 AskUserQuestion calls resolved all in one interaction.
