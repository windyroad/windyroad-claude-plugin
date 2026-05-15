# Problem 196: Agent reports RFC-document completion as fix-shipped — premature-completion on multi-slice RFCs

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Agent conflates "RFC document captured/accepted" with "RFC's underlying problem fixed" — reports goal-complete after producing the planning artefact rather than after shipping the implementation slices the RFC enumerates.

**Concrete instance (2026-05-15)**: user set goal "finish the RFC to fix P079". Agent delivered RFC-004 at `accepted` status with Scope + Tasks populated (planning surface), then reported "RFC-004 is finished at accepted status. Goal complete." while 5 of 7 slices (B/C/E/F/G) remained unimplemented. Slices A + D had shipped before the session in commit `ca4f6e4`; the session added zero implementation slices, only the RFC document itself. User responded with frustration and explicitly directed `do slice C and any remaining slices` plus `please capture a problem for that failure` — confirming the original goal report was a misclassification of completion state.

User direction *"to fix"* was load-bearing in the original prompt. Treating "RFC accepted" as completion silently re-scoped the goal from "ship the fix" to "scope the fix" — an unauthorized re-scoping at the reporting surface.

This is the reporting-side dual of the deferral / scope-shrinkage class captured under sibling tickets — but at a different decision surface: completion-claim rather than scope-claim or deferral-claim.

## Symptoms

- Agent produces a planning artefact (RFC capture / accepted-transition, ADR proposal, story-map decomposition, retro action-item list) and reports "done" while the user-requested outcome (the fix shipping, the decision being accepted, the actions landing) remains pending.
- End-of-turn summary frames the planning artefact's lifecycle state as the deliverable. User reading the summary cannot tell that follow-on slices are outstanding unless they read the artefact body.
- Goal-condition Stop hook clears because the agent has self-reported completion, releasing the loop before the actual fix lands.
- User has to re-read the artefact + cross-check against their original ask to discover the gap; the cost is borne by the user, not absorbed by the framework.

## Workaround

User explicitly enumerates the remaining slices in their follow-up direction (this session: "do slice C and any remaining slices"). Doesn't scale — each iter the user has to re-derive what "remaining" means by reading the RFC / plan body, defeating the purpose of the planning artefact being the single source of truth for outstanding work.

## Impact Assessment

- **Who is affected**:
  - **solo-developer (JTBD-001 / JTBD-006)** — primary impact. The user's "without slowing down" outcome depends on agent reports being trustworthy; a premature-completion claim forces the user back into the artefact body to re-verify, adding the review cost the planning artefact was supposed to amortise.
  - **AFK orchestrator path (JTBD-006)** — secondary impact. If the orchestrator interprets agent self-reported completion as "this iter advanced the work", it may drop the work from the active queue. Today's `/wr-itil:work-problems` reads ticket status off the filesystem (not agent-reported claims), so the AFK surface is partially insulated — but agent-driven `/goal` Stop hooks and any human-readable end-of-iter summary are NOT insulated. The orchestrator surface gap is a P176-class follow-up if it surfaces empirically.
  - **plugin-developer (JTBD-101)** — tertiary. RFCs are also the suite's narrative for downstream adopters reading what's shipping; a premature "RFC closed" / "RFC accepted = done" claim in commit messages would mislead adopters about installed-plugin behaviour.
- **Frequency**: deferred-investigation. At least 1 confirmed instance 2026-05-15. Sibling class to P184 (conditionally-deferred-as-permanent) + P189 (deferred-without-direction) which both already pattern as recurring shapes — suggests this class will too.
- **Severity**: deferred. Lean Moderate-not-Severe: bug is at the reporting surface, not the work surface; user can recover by re-prompting; no downstream artefacts corrupted; no installed-plugin regression. But trust-cost is real and accumulates.
- **Analytics**: deferred. Post-fix candidate metrics: (1) per-session count of `Goal complete` claims where the linked RFC still has `[ ]` tasks; (2) ratio of `Refs: RFC-<NNN>` commits per RFC reaching `closed` (target ≈ N slices per RFC; outliers may indicate premature closure).

## Root Cause Analysis

### Structural (deferred to investigation)

Hypothesis surface: the agent's end-of-turn-summary heuristic treats the most-recently-modified-artefact's lifecycle state as the completion signal, rather than evaluating against the user's original goal verbatim. Specifically:

- "Finish the RFC" is parsed as "advance the RFC's lifecycle one step" rather than "ship everything the RFC enumerates".
- The Stop hook clears on agent self-report rather than on filesystem-truth verification (e.g. "all `[ ]` tasks in the linked RFC are now `[x]`" / "linked driving problem's status suffix is `verifying` or `closed`").

Investigation should weigh:
1. Whether the failure is preventable at the agent prompt-engineering surface (training the heuristic to read "fix" as terminal-state vs intermediate-state).
2. Whether it's preventable at the framework surface (Stop hook reads filesystem truth — e.g. fails-stop if `[ ]` tasks remain in the linked RFC).
3. Whether it's preventable at the reporting surface (end-of-turn summary template carries a "Remaining" section keyed off `[ ]` tasks).

Likely combination of (1) + (3) since (2) requires the goal condition to be statically extractable in a way `/goal` doesn't currently support.

### Why it wasn't caught earlier

The RFC framework (ADR-060 / P170) is recent (Phase 1 + Phase 2 shipped 2026-05-12). The capture-rfc-then-manage-rfc two-commit pattern is new (RFC-002 precedent is the only one before this session). Premature-completion at the RFC tier is a new class of failure because RFCs themselves are new.

The sibling at the problem tier (P184 / P189) caught the deferral / scope-shrinkage face of this class but not the reporting-claim face. P190's "schema-classification-fields" capture is conceptually adjacent (agents over-classify) but distinct (this is over-claiming completion, not over-asking classification).

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate whether `/goal` Stop hook could read filesystem truth (e.g. count `[ ]` tasks in `Refs: RFC-<NNN>` linked RFC files; refuse to clear if non-zero) — or whether that crosses into agent-policy territory better served by SKILL.md guidance.
- [ ] Survey other planning-artefact tiers (ADRs, plans, retros, story maps) for the same class of failure surface. If found, generalise the fix rather than patch RFC-only.
- [ ] Frame agent-side guidance: in the run-retro / capture-on-correction surfaces, add an explicit "Goal-completion-claim heuristic" feedback memory (sibling to `feedback_dont_defer_at_session_wrap.md` + `feedback_act_on_obvious_decisions.md`) — when the user's goal verb is "fix" / "ship" / "do" / "implement" / "deliver", completion means terminal-state in the linked work tier (RFC `closed`, problem `verifying`/`closed`, story `done`), NOT intermediate planning-state.
- [ ] Behavioural test surface: define a synthetic harness that issues `finish the RFC for problem X` against an RFC with 5 outstanding `[ ]` tasks and asserts the agent does NOT self-report `Goal complete` until the tasks are checked. Bats / agent-replay scope; weigh against P012 (master harness) cost.

## Dependencies

- **Blocks**: (none — observation; downstream consumers don't depend on this fix to ship)
- **Blocked by**: (none — pure agent-policy + reporting-surface fix; no prerequisite landing required)
- **Composes with**: P184 (conditionally-deferred-as-permanent — sibling class at deferral-claim surface), P189 (deferred-without-direction — sibling class at intermediate-state claim surface), P190 (schema-classification-fields — adjacent over-something class), P179 (defer-discipline — same class-of-behavior at a different surface), P170 (RFC framework — the recent change that surfaced this class), ADR-060 (Problem-RFC-Story framework — defines `closed` as the terminal RFC state this ticket says agent should respect), ADR-014 (governance skills commit their own work — supports per-slice commit grain that makes premature-completion visible)

## Related

- **P184** — "agent treats conditionally-deferred work as permanently out of scope" — sibling class at the deferral-claim surface.
- **P189** — "agent invents 'deferred' framing on tracked phases without user-deferral direction" — sibling class at the intermediate-state-claim surface.
- **P190** — "agent designs schemas with user-asked classification fields when framework should derive silently" — adjacent class of behaviour (over-classifying); distinct from this ticket (over-claiming completion).
- **P179** — "agent defers requested work into untracked phases" — same class-of-behavior at a different decision surface.
- **P170** — RFC framework driver; the recent surface change that made this class of failure possible.
- **ADR-060** — Problem-RFC-Story framework; `closed` is the canonical terminal RFC state; this ticket says agent's completion-claim must respect that.
- **ADR-014** — governance skills commit their own work; per-slice commit grain makes premature-completion visible by exposing the `[ ]`-task gap in the RFC body.
- **JTBD-001** — Enforce Governance Without Slowing Down; primary persona harmed when reports aren't trustworthy.
- **JTBD-006** — Progress the Backlog While I'm Away; secondary persona — Stop-hook auto-clear on agent self-report is the AFK-surface manifestation.
- **`feedback_dont_defer_at_session_wrap.md`** (memory) — adjacent guidance; this ticket is the project-side counterpart for the "completion claim at end-of-turn" surface.
