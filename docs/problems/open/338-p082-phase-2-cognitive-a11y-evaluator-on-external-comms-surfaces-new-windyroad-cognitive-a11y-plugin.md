# Problem 338: P082 Phase 2 — cognitive-accessibility evaluator on the 4 external-comms surfaces (gh / npm / changeset / git commit), shipped as a NEW `@windyroad/cognitive-a11y` plugin

**Status**: Open
**Reported**: 2026-05-30
**Priority**: 4 (Low) — Impact: 2 (Minor — sibling-cohort follow-on; new plugin scaffold; doesn't break existing surfaces) × Likelihood: 2 (Unlikely — speculative integration risk; absence is currently a documented gap, not an active fault)
**Origin**: internal
**Effort**: L (suite-wide cognitive-a11y plugin scaffold + ADR-028 amendment + 4 surface integrations + per-surface bats coverage)
**WSJF**: 1.0 (re-rated 2026-05-31; was placeholder I=3×L=1; honest grounding is below appetite per acceptance-deferred sibling-cohort framing)

## Description

Sibling-cohort follow-on to P082 (voice-tone + risk-scorer evaluators on external-comms surfaces). Surfaced by P082 RCA (iter 4) and re-confirmed by P082 iter 5 JTBD agent flag-C. Direction decided during session 9 Step 2.5b wrap (user-answered AskUserQuestion 2026-05-30):

**User direction: Ship as a new `@windyroad/cognitive-a11y` plugin** (chosen over the alternative of extending voice-tone as a third evaluator). Clean separation of concerns; new plugin scaffold pays once; existing voice-tone gate stays focused on tone/voice.

Scope: a cognitive-accessibility evaluator that fires on the SAME 4 external-comms surfaces voice-tone and risk-scorer already cover:
1. `gh` issue/PR bodies
2. npm publish content (CHANGELOG, README in published package)
3. `.changeset/*.md` summaries
4. `git commit*` messages (the Phase 1 P082 extension surface — when P082 Phase 1 lands, the surface is wired and cognitive-a11y joins as a third evaluator on it)

ADR-028 amendment required: declare cognitive-a11y as the third evaluator class (currently the ADR caps at voice-tone + risk-scorer per the 2026-05-14/05-16/05-25 amendments). Each surface's existing PostToolUse hook gains a third evaluator round.

## Symptoms

- External-comms surfaces today (`.changeset/`, gh issue/PR, npm publish, git commit when P082 Phase 1 ships) gate on voice/tone and confidentiality-risk only.
- Cognitive load / readability / plain-language signals are not checked — published external prose may violate cognitive-a11y guidelines (long sentences, jargon density, passive voice, complex clause nesting) without any gate signal.
- The voice-tone gate covers brand voice; the risk-scorer covers confidentiality. Cognitive-a11y is the third orthogonal concern with no current evaluator.

## Workaround

(deferred to investigation — manual review during external-comms author flow; no automated gate)

## Impact Assessment

- **Who is affected**: adopters reading shipped external-comms (issue bodies, README, CHANGELOG); the accessibility-first JTBD persona; downstream users with cognitive-accessibility needs
- **Frequency**: every external-comms surface fire (every gh issue, every release publish, every changeset, every commit when P082 Phase 1 ships)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems (likely L when scoping the per-surface bats coverage)
- [ ] Scaffold new `@windyroad/cognitive-a11y` plugin per ADR-002 (plugin.json, package.json, hooks/, agents/, scripts/test/, ADR-049 shims)
- [ ] Author cognitive-a11y evaluator agent (claude-prose verdict; same shape as `wr-voice-tone:external-comms` and `wr-risk-scorer:external-comms`)
- [ ] Author per-surface integration hooks (or extend the shared external-comms-gate.sh dispatch to route to a third evaluator)
- [ ] Amend ADR-028 to declare cognitive-a11y as third evaluator class (single ADR amendment — same amendment cadence as the 2026-05-14/05-16/05-25 prior amendments)
- [ ] Behavioural bats per surface: assert cognitive-a11y verdict fires correctly on long-sentence / jargon-dense / passive-voice drafts; passes on plain-language drafts
- [ ] Verify P082 Phase 1's `git commit*` surface accepts the third evaluator wire-up (when P082 Phase 1 lands)
- [ ] Consider whether cognitive-a11y should also have a session-mark hook on the same pattern as the voice-tone / risk-scorer marks

## Dependencies

- **Blocks**: cognitive-accessibility coverage on shipped external-comms — a JTBD-301-ish concern for downstream readers
- **Blocked by**: P082 Phase 1 (the `git commit*` surface integration — once shipped, cognitive-a11y joins as third evaluator on it); ADR-028 amendment authority (the ADR is currently `proposed` per the architect oversight drain — verify acceptance/amendment is in scope)
- **Composes with**: P082 (Phase 1 wires the surface), ADR-028 (the governing decision), `@windyroad/voice-tone` + `@windyroad/risk-scorer` (sibling evaluator plugins — shape precedent)

## Related

(captured via /wr-itil:capture-problem 2026-05-30 during session 9 work-problems Step 2.5b wrap; user-directed design choice = new plugin)

- **P082** — Phase 1 driver; this is Phase 2.
- **ADR-028** — external-comms gate ADR; needs amendment to declare cognitive-a11y as third evaluator class.
- **JTBD-101** (Extend the Suite with New Plugins) — primary persona alignment (this IS a new plugin).
- `@windyroad/voice-tone` + `@windyroad/risk-scorer` — sibling evaluator plugins; shape precedent for the new plugin.
- `packages/shared/hooks/external-comms-gate.sh` (canonical) — the shared dispatch the new plugin would wire into.
