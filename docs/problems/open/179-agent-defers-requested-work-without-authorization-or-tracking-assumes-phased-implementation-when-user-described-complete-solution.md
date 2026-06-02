# Problem 179: Agent defers requested work into untracked phases — phases are fine, but unticketed phases never get implemented

**Status**: Open
**Reported**: 2026-05-10
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

**Phases are NOT the problem.** Incremental implementation across phases is a legitimate engineering technique and the user explicitly endorses it. The problem is **untracked phases** — when the agent defers work to "Phase 2 / Phase 3 / out-of-scope / follow-up iter" without creating a tracking artefact (problem ticket, RFC, or other backlog entry) that surfaces the deferred work in WSJF rankings, work-problems backlog, or any actionable queue.

Concretely: when the user describes a problem and discusses how to solve it, the agent silently splits the described solution into "ship now" (current iter / current scope) vs "defer to future phase" (Phase 2 / Phase 3 / "future work" / "follow-up iter") without:

1. **Explicit user authorisation** for the split. The agent decides the boundary between "in scope" and "deferred" based on its own scope-narrowing inference (cost / complexity / "phased implementation feels safer" / "let's not blow scope"), not on user direction.
2. **Sibling-ticket tracking** for the deferred work. Deferrals are recorded only in ADR text ("Phase 2 — deferred"), in iter prompt notes ("T6 deferred to follow-up"), or in the ticket's Implementation Tasks section. None of these surface in WSJF rankings, the work-problems backlog, or any actionable queue. The deferred work disappears from view until either (a) the user notices it's missing weeks/months later or (b) it's re-derived from scratch on the next session.

User direction 2026-05-10 (verbatim, 2-message correction):

> *"You have a habit of deferring work that has been requested. … When you defer the work, 1) it surprises me (not good), 2) unless we do something to track it, it never gets implemented until I notice that it's missing."*
>
> *"I don't mind phases, but I do mind if those phases never happen."*

The fix shape per user direction: phases are LEGITIMATE if every phase is tracked as its own backlog entry that surfaces in the queue. The framework already has the right primitive — problem tickets and RFCs ARE the "tracked phase" mechanism. The agent must use them on every deferral, not invent ad-hoc "Phase 2" inline-text that lives only inside ADRs.

Concrete evidence — this session 2026-05-06 to 2026-05-10:

1. **Story-map design** — user described P170 with explicit reference to user story maps, JTBD trace, multi-RFC composition. ADR-060 deferred the story-map design to "Phase 2"; agent treated this as authoritative deferral. User had to explicitly ask "what is the design for how we maintain the user story maps?" 4 days into implementation work to surface the gap.
2. **ADR-022 / ADR-016 / ADR-024 amendments** — iter 8's ITERATION_SUMMARY explicitly named these as "deferred to T5b follow-up iter" without user direction. Still deferred at the time of P179 capture.
3. **T6 dual-pattern drop** — agent named "drop dual-pattern compatibility post-T5 verification" as a follow-up T-task without surfacing what "T5 verification" means or who decides when it's been verified enough.
4. **T7-T11 adopter auto-migration** — substantial work (multi-skill, multi-package; capture-problem + work-problems must both detect flat-layout and auto-migrate per ADR-031 § "Backward compatibility — adopter repos auto-migrate on first-run"). Agent placed entire block in "Slice 6" without surfacing whether user expected it as in-scope for P170 or as separate work.
5. **WSJF integration for story maps (Phase 2.5)** — agent silently created a "Phase 2.5" tier in the just-landed amendment to defer story-level WSJF design without user direction.
6. **INVEST extraction (Phase 2.5)** — same pattern; agent named a new phase tier to defer scope.

The pattern composes with:

- **P175** (agent over-narrows scope-pin words "just" / "only" / "first" into count constraints — halts loop on agent-inferred scope rather than framework-prescribed stop conditions). Same root-cause class: agent inferring framework-resolved decisions from non-framework signals. P175 was loop-control; P179 is scope-control.
- **P178** (agent skips ITIL state-machine gates on architecture-driven problems — treats architect-PASS as RCA substitute). Same root-cause class. P178 was lifecycle-state inference; P179 is scope-boundary inference.

The three together form a class-of-failure: **agent infers framework-resolved boundaries from non-framework signals (natural-language modifiers, ADR text, design verdict-class signals) when the framework actually requires explicit user direction for those boundaries**. ADR-044's framework-resolution boundary names the inverse failure (lazy AskUserQuestion deferral); P175 / P178 / P179 are the OUTBOUND failures (agent decides what the framework didn't actually resolve).

## Symptoms

- The agent says "deferred to Phase N" or "deferred to follow-up iter" or "Phase 2.5 / Phase 4 / out-of-scope" without a corresponding user authorisation in the recent session transcript.
- Deferred work is recorded only in ADR text or iter prompt notes; no problem ticket is created to track it; no entry appears in `docs/problems/README.md` WSJF rankings.
- User reaction signal: "you have a habit of deferring" / "I expected this to be implemented" / "where did X go" / "what about Y" — strong-affect class-of-behaviour correction triggering P078.
- ADRs accumulate "Phase 2" / "Phase 3" / "Phase 4" / "out-of-scope deferred" sections that never get implemented until user surfaces the gap.
- The user's mental model after a session: "we discussed solution X with components A, B, C, D, E"; the actual ship: "agent shipped A and B; C, D, E silently in 'Phase 2'".

## Workaround

Currently — user manually surfaces the deferral mid-session ("what about X?") which fires P078 capture-on-correction. Each correction costs a re-prompt round-trip the framework should not require.

A defensive workaround at iter dispatch / orchestrator main turn time: every time the agent uses the words "defer", "Phase N (next/later/future)", "out of scope", "follow-up iter", "deferred-to-Phase-N", surface explicitly via AskUserQuestion: "I'm about to defer X. Options: (1) implement now (2) capture as P-ticket and defer (3) document in ADR as scope-boundary-decision (4) cancel the deferral and complete now". Inelegant but breaks the silent-deferral pattern.

A SKILL-side fix: introduce a **deferral discipline** — every "out of scope" / "deferred to" line in any agent-authored artefact (ADR, RFC, problem ticket, iter summary) MUST cite either (a) a problem ticket ID tracking the deferral OR (b) a documented user direction authorising the deferral. Behavioural test (per ADR-052) asserts no agent-authored artefact contains uncited deferrals.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: user (loses visibility of described-but-deferred work); secondary: future maintainers reading ADRs see "Phase 2" sections with no implementation timeline; tertiary: AFK orchestrator's WSJF backlog under-represents true work pipeline because deferred work isn't ticketed.
- **Frequency**: (deferred to investigation) — likely Likely; surfaced 6+ instances in single session 2026-05-06 to 2026-05-10. Recurs on every multi-phase ADR + every multi-iter feature.
- **Severity**: (deferred to investigation) — likely Moderate; doesn't block ship but creates a hidden backlog that surprises the user and erodes the framework's "what you describe is what gets built" property.
- **Analytics**: (deferred to investigation) — count of "Phase N (deferred)" / "Out of Scope" entries in `docs/decisions/*.md`; count of "deferred-to-follow-up" mentions in `.afk-run-state/iter*.json` ITERATION_SUMMARY notes; ratio of described-but-deferred work to ticketed-and-tracked deferrals.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause: is this a SKILL.md gap (no skill explicitly forbids unauthorised deferral or requires deferral citation), an ADR-template gap (ADR templates have an "Out of Scope" section that invites unauthorised scope-narrowing), an agent-prior gap (training-data conditioning to "phased implementation = safer"), or all three? Likely all three; fix at all three surfaces per ADR-051 load-bearing-from-the-start.
- [ ] Survey existing ADRs for unauthorised "Phase N (deferred)" / "Out of Scope" entries that lack sibling-ticket citations. Suggested grep: `grep -lE 'Phase [0-9]+ \(deferred|Out of Scope|deferred to' docs/decisions/`. Cross-reference each "deferred" mention against `docs/problems/` for a tracking ticket. Expected high false-positive rate; manual triage.
- [ ] Decide framework position on deferral discipline:
  - **Option A** — Hard rule: every deferral MUST cite a tracking ticket (existing or newly-captured). Behavioural test enforces.
  - **Option B** — Soft rule: every deferral SHOULD cite a tracking ticket; SKILL.md authoring guidance + retro Step N audit catches gaps.
  - **Option C** — Process rule: every "out-of-scope" / "deferred" agent decision triggers AskUserQuestion mid-flow asking whether to ticket or proceed.
  - **Option D** — Cultural rule: documented in CLAUDE.md as MANDATORY; no test enforcement; relies on agent-prior + retro hygiene.
- [ ] Sweep ADR-044 framework-resolution boundary worked examples — does P179 belong in the inverse-P132 lazy-deferral worked-example list (currently P130 transient-user is the sole entry; P175 + P178 + P179 form the outbound-failure cluster)? If so, surface in `run-retro` Step 1.5 silent classification + Step 2d Ask Hygiene Pass criteria.
- [ ] Behavioural test: a bats fixture asserting that ADR / RFC / problem-ticket / iter-prompt artefacts authored by skills do NOT contain `(deferred|Out of Scope|Phase [0-9]+ \(deferred)` patterns without an adjacent ticket-ID citation. Fixture exercises the manage-problem / capture-problem / capture-rfc / manage-rfc / create-adr / amendment paths.
- [ ] Reverse-engineer the 6 in-session deferral instances (story-map design, ADR-022/016/024 amendments, T6, T7-T11, Phase 2.5 WSJF, Phase 2.5 INVEST) — for each, identify where in the agent's reasoning chain the deferral decision fired and whether the user had explicit input. Calibrates whether the fix targets the agent-prior layer or the SKILL.md layer.

## Dependencies

- **Blocks**: (none directly — but the longer this is deferred, the more accumulated unauthorised deferrals pile up across the framework's ADRs)
- **Blocked by**: (none — investigation can proceed independently)
- **Composes with**:
  - **P175** (agent over-narrows scope-pin words into count constraints) — sibling root-cause class: agent inferring framework-resolved decisions from non-framework signals. P175 was loop-control; P179 is scope-control. Both stem from same root.
  - **P178** (agent skips ITIL state-machine gates on architecture-driven problems — treats architect-PASS as RCA substitute) — sibling root-cause class: agent inferring framework-resolved boundaries from verdict-class signals. P178 was lifecycle-state; P179 is scope-boundary.
  - **P078** (capture-on-correction OFFER pattern) — this very ticket was captured under P078 discipline after the user's class-of-behaviour correction.
  - **ADR-044** (decision-delegation contract — framework-resolution boundary) — scope-boundary decisions ARE framework-resolved when the user has described the solution; agent must not sub-contract back via "phased implementation" inference. Composes with the inverse-P132 lazy-deferral worked examples.
  - **ADR-051** (load-bearing-from-the-start) — applies to this ticket's own fix; whatever discipline emerges should ship with its enforcement test, not as advisory-then-escalate.
  - **ADR-052** (behavioural-tests-default) — the deferral-citation test is a behavioural surface; bats fixture exercises agent-authored artefacts.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-022 — problem lifecycle conventions
- ADR-044 — framework-resolution boundary
- ADR-051 — load-bearing-from-the-start
- ADR-052 — behavioural-tests-default
- ADR-060 — RFC framework (drove the unauthorised "Phase 2 deferral" of story-map design that surfaced this pattern)
- P078 — capture-on-correction OFFER pattern
- P175 — sibling inferential failure class (loop-control)
- P178 — sibling inferential failure class (state-machine)
- P170 — the empirical surface where the pattern accumulated 6+ instances in single session
- /wr-itil:work-problems SKILL.md — Step 5 iter prompt template (deferral-discipline gap)
- /wr-itil:manage-problem SKILL.md — Step 9 work-the-fix (deferral-discipline gap)
- /wr-architect:create-adr SKILL.md — ADR template's "Out of Scope" section invites unauthorised deferral
- Session evidence — 2026-05-10 user correction "you have a habit of deferring work that has been requested … 1) it surprises me (not good), 2) unless we do something to track it, it never gets implemented until I notice that it's missing".
