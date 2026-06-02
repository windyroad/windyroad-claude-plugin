# Problem 075: run-retro's codification-candidate prompt asks "X or Y or create a problem ticket" — the answer is always "create a problem ticket first"

**Status**: Closed — verified in post-AFK-iter-7 retrospective 2026-04-21 (Step 4b two-stage flow fires: Stage 1 mechanical ticket creation for codification candidates, Stage 2 per-ticket fix-strategy AskUserQuestion)
**Reported**: 2026-04-21
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M — `packages/retrospective/skills/run-retro/SKILL.md` Step 4b rework. Collapse the 19-option AskUserQuestion into a two-stage flow: (1) **every** observation first becomes a problem ticket via `/wr-itil:manage-problem`; (2) the codification decision (skill / agent / hook / settings / script / CI / ADR / JTBD / guide / test fixture / memory) is recorded as the **proposed fix strategy** on the problem ticket, not as an alternative to ticketing. Removes the ticket-this-or-pick-another-shape option from the creation axis; preserves the improvement-axis routing. Bats doc-lint updates; P044 / P050 / P051 existing coverage retuned.

## Fix Released

Shipped in `@windyroad/retrospective` (next minor bump — changeset `.changeset/p075-run-retro-ticket-first-codification.md`; pending release). `packages/retrospective/skills/run-retro/SKILL.md` Step 4b rewritten as a two-stage flow per the architect-approved plan:

- Stage 1 mechanically tickets every codify-worthy observation (delegates to `/wr-itil:manage-problem` — or `/wr-itil:capture-problem` once the ADR-032 background sibling ships). Applies P016 concern-boundary split before ticketing. Fires regardless of interactive/AFK mode.
- Stage 2 per-ticket `AskUserQuestion` with `header: "Proposed fix"` and four options: `Skill — create stub` / `Skill — improvement stub` / `Other codification shape` (free-text Fix Strategy capture per architect Q4 lean (b) — not cascading AskUserQuestion batches) / `Self-contained work — no codification stub` (with the Rule 6 audit note that protects P044's recommend-skills intent from leaking). Records a `## Fix Strategy` section on the ticket.
- AFK branch defers Stage 2 via the ADR-032 deferred-question artefact; Stage 1 ticketing still fires.

14 new structural doc-lint assertions at `packages/retrospective/skills/run-retro/test/run-retro-ticket-first-flow.bats` enforce the two-stage contract (Stage 1 / Stage 2 headings, Stage 1 delegation, no ticketing AskUserQuestion in Stage 1, Proposed-fix header, 4-option cap, Option 4 rename + Rule 6 audit note, Option 3 free-text capture, `## Fix Strategy` section, ADR-032 citation, deferred-question contract, P016 concern-boundary split, Rule 6 fallback, legacy 19-option regression guard). Existing `run-retro-skill-candidates.bats` test updated to accept either the P044 / P050 legacy strings or the P075 reframed equivalents so the P044 regression guard survives the reframing. ADR-032 Confirmation amended with the foreground-spawns-N-background-fanout case.

Full bats suite green (454/454). Awaiting user verification.

## Description

`packages/retrospective/skills/run-retro/SKILL.md` Step 4b presents codification candidates to the user via a single `AskUserQuestion` with 19 options:

- 12 **creation-axis** options (Skill / Agent / Hook / Settings / Script / CI / ADR / JTBD / Guide / **Problem** / Test fixture / Memory — each as "create stub" or "invoke dedicated skill").
- 6 **improvement-axis** options (Skill / Agent / Hook / ADR / Guide / Problem — each as "improvement stub" or "edit existing").
- 1 **Skip** option.

The `Problem — invoke manage-problem` option is presented as **one alternative among twelve** for the creation axis. In practice the user always picks it: every retro observation that is codify-worthy is also problem-worthy. The observation is a concrete instance of something going wrong or needing improvement; that IS the triggering definition of a problem ticket. The codification shape (is this a new skill? a hook? a script?) is the **fix strategy** for the problem, not an alternative to filing the problem in the first place.

User feedback (this session, 2026-04-21, verbatim): *"run-retro has a habit of asking 'should I do X or Y or create a problem ticket'. The answer should always be 'create a problem ticket' so the question is redundant."*

Flipping the flow: every codify-worthy observation gets a problem ticket first (via `/wr-itil:manage-problem` OR the new `/wr-itil:capture-problem` background skill once ADR-032 lands). The codification shape — skill / agent / hook / ADR / JTBD / whatever — is recorded on the problem ticket as the proposed fix strategy. Routing skills like `/wr-architect:create-adr` or `/wr-jtbd:update-guide` consume the problem ticket's fix strategy when the user is ready to actually DO the codification; they don't act as a ticketing alternative at retro-time.

## Symptoms

- run-retro Step 4b's 19-option `AskUserQuestion` burns cognitive load on a decision that has a foregone conclusion for the ticketing axis. The user picks "Problem — invoke manage-problem" every time.
- Codification candidates recorded with `Decision = skipped` or `flagged — not actioned (non-interactive)` are orphans: they exist in the retro summary but have no home in the problem backlog. Risk: codify-worthy observations silently evaporate between retro runs.
- Candidates recorded with `Decision = created stub` (skill/agent/hook stubs) live in the retro summary text, not as problem tickets. Later sessions have to re-derive the context when someone tries to build the stub.
- P074 (run-retro doesn't notice pipeline instability) surfaces the same structural issue from a different angle: run-retro's current flow drops observations at many points because it treats problem-ticketing as one option among many instead of the common funnel.

## Workaround

User manually invokes `/wr-itil:manage-problem` for each codify-worthy observation after run-retro finishes. That's the "manually police AI output" pattern JTBD-001 is designed against; run-retro is the natural enforcement point for this.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — every retro with ≥ 1 codification candidate forces the user through a 19-option AskUserQuestion where the ticketing decision has a foregone answer. Friction compounds across sessions.
  - **Tech-lead persona (JTBD-201)** — audit trail of codify-worthy observations is incomplete when stubs live only in retro summaries. Observations recorded without a ticket don't appear in the WSJF queue.
  - **Plugin-developer persona (JTBD-101)** — "clear patterns, not reverse-engineering" fails when the codification flow has two parallel tracks (retro-summary stubs vs problem tickets) instead of one canonical track (problem tickets always; codification is the fix-strategy axis).
- **Frequency**: every retro run that surfaces ≥ 1 codifiable pattern. 2026-04-21 session would have seen this fire on P074 itself if run-retro had fired — the ticket IS the codification.
- **Severity**: Moderate. Not a correctness defect — tickets eventually get filed, retros eventually run, the ecosystem keeps working. But the friction is cumulative and the audit-trail leak is real.
- **Analytics**: N/A until the retro pattern is exercised on this session's observations.

## Root Cause Analysis

### Structural

run-retro's Step 4b was designed (P044 → P050 → P051 progression) to enumerate every codification shape the user might reach for, and to ask the user which one fits. The enumeration is correct; the framing is wrong. Step 4b treats "problem ticket" as ONE shape alongside "skill", "agent", "hook", etc. — but problem ticket is a different axis:

- **Ticketing axis** (mandatory): every observation that merits codification is ALREADY a problem (something needs a fix). The observation becomes a problem ticket; no user decision required.
- **Codification-shape axis** (proposed fix strategy): once the problem exists, the user can record HOW the fix will land — skill / agent / hook / ADR / JTBD / guide / test fixture / memory / script / CI / settings / internal code change. This axis IS user-decidable.

Collapsing these two axes into one AskUserQuestion forces the user to re-decide the ticketing axis on every observation. The correct flow separates them: ticket first (mechanical), fix-strategy second (user-interactive).

### Candidate fix

Rewrite Step 4b as a two-stage flow:

**Stage 1: Ticket every codify-worthy observation** (mechanical, no user decision):

- For every observation from Step 2 that meets the codifiability criteria (recurring pattern OR bounded targeted edit OR reproducible defect), invoke `/wr-itil:manage-problem` (or `/wr-itil:capture-problem` background per ADR-032) to create a problem ticket.
- The problem's Description captures the observation. The problem's Root Cause Analysis is populated from the retro narrative.
- Multiple observations merging into a single ticket per the concern-boundary rule (P016) — run-retro's Step 4b already hosts the split logic; preserve it.

**Stage 2: Record the proposed fix strategy on each ticket** (user-interactive, per ticket):

- `AskUserQuestion` per ticket: "What's the proposed fix shape for this problem?"
  - `header: "Proposed fix"`
  - Options per ADR-013 Rule 1 4-option cap: batch intelligently. Default options for most observations: (a) `Skill — create stub` / (b) `Skill — improvement stub` / (c) `Other codification shape (agent, hook, ADR, JTBD, guide, script, CI, test, memory, internal change)` / (d) `No codification needed — problem is self-contained work` .
  - On (c), fire a follow-up AskUserQuestion narrowing the shape (4 options per batch).
  - On (d), the problem ticket is filed without a codification hint; fix strategy populated later.
- Record the decision as a `## Fix Strategy` section on the problem ticket, naming the shape and any stub candidate (e.g. suggested skill name `wr-<plugin>:<verb>-<object>` per ADR-010 amended).

**AFK non-interactive branch**: ticketing (Stage 1) still fires — it's mechanical. Fix-strategy prompts (Stage 2) defer via the ADR-032 deferred-question contract for the new `capture-*` background pattern: each ticket gets a pending-questions artefact asking for the fix strategy; main agent surfaces on next interactive session.

### Interaction with P044 / P050 / P051 / P068 / P074

- **P044** (recommend new skills): becomes Stage 2 option `Skill — create stub`. Unchanged semantics; new placement.
- **P050** (recommend other codifiables): becomes Stage 2 shape-narrowing follow-up. Unchanged semantics; new placement.
- **P051** (improvement axis): becomes Stage 2 option `Skill — improvement stub` or `Other — edit existing`. Unchanged semantics; new placement.
- **P068** (verification-close housekeeping): independent of Step 4b flow; unaffected.
- **P074** (pipeline-instability scan): feeds Stage 1 as another ticket source. Pipeline signals become problem tickets first, then the fix-strategy prompt decides codification shape.

### Investigation Tasks

- [ ] Rewrite `packages/retrospective/skills/run-retro/SKILL.md` Step 4b per the two-stage flow. Preserve the codifiability criteria from Step 2; move the stub-recording into the new "Fix Strategy" structure on the ticket.
- [ ] Update the existing `packages/retrospective/skills/run-retro/test/*.bats` tests (P044 + P050 + P051 coverage) to assert the new flow shape. Each test either becomes a Stage 2 option-presence test OR migrates to a ticket-body `## Fix Strategy` section test.
- [ ] Add bats doc-lint asserting Stage 1 is always mechanical (no ticketing `AskUserQuestion`) AND Stage 2 is always per-ticket.
- [ ] Cross-reference from P044 / P050 / P051 Related sections — this ticket reframes their shared flow.
- [ ] Verify interaction with ADR-032 deferred-question artefact for AFK Stage 2.
- [ ] Verify interaction with P074's pipeline-instability scan — signals should feed Stage 1 naturally.
- [ ] Confirm `feedback_verify_from_own_observation.md` memory direction is preserved: in-session observations ticket themselves.

## Related

- **P044** — run-retro does not recommend new skills. Becomes Stage 2 option under this ticket's reframing.
- **P050** — run-retro does not recommend other codifiables. Becomes Stage 2 shape-narrowing follow-up.
- **P051** — run-retro improvement axis. Becomes Stage 2 improvement-axis options.
- **P068** — run-retro verification-close housekeeping (shipped `@windyroad/retrospective@0.4.0`). Independent; unaffected.
- **P074** — run-retro pipeline-instability scan. Feeds Stage 1 as another ticket source.
- **P016** — multi-concern split. Preserved in Stage 1 ticketing logic.
- **ADR-032** (Governance skill invocation patterns) — capture-problem background skill is the Stage 1 invocation target when run-retro itself runs in background mode.
- **ADR-013** (Structured user interaction) — Rule 1 governs the Stage 2 AskUserQuestion; Rule 6 governs the AFK fix-strategy defer.
- **ADR-026** (Agent output grounding) — ticket Description section is a grounded persist-surface for the observation; fix strategy inherits the same grounding rules.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary beneficiary. Removes the redundant ticketing-axis question.
- **JTBD-101** (Extend the Suite with New Plugins) — clearer single-track codification flow.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — no more orphan observations; every codify-worthy thing lands in the problem backlog.
- `packages/retrospective/skills/run-retro/SKILL.md` — target of the Step 4b rewrite.
- `feedback_verify_from_own_observation.md` — user memory confirming observations become tickets via the agent's own observation, not deferred to the user.
