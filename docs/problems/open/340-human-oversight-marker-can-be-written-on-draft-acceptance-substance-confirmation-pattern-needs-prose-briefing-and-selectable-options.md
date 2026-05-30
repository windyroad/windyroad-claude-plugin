# Problem 340: Human-oversight marker can be written on draft-acceptance without verifying substance-confirmation — the substance-confirmation interaction pattern needs prose briefing + each option as a selectable option + no ID-as-explainer + informed-decision-without-external-doc-lookup

**Status**: Open
**Reported**: 2026-05-31
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems; HIGH in practice — ratification claims may stamp ADRs whose substance was never user-authorised, and the architect agent reads the marker as proof of ratification per ADR-066, so the entire governance chain downstream operates on a foundation that didn't actually exist)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; SKILL.md amendments on `/wr-architect:create-adr` Step 5 + `/wr-architect:capture-adr` if applicable + architect agent's review-decisions flow + behavioural bats coverage of the new substance-confirm pattern)
**Type**: technical

## Description

Surfaced 2026-05-31 by direct user observation during ADR-078 amendment exchange: *"the previous iteration of the decision, with the programmatic extraction was not approved. How did that ADR skip ratification?"*

ADR-078's first commit (`5196e3d`, 2026-05-30) shipped with `human-oversight: confirmed` + `oversight-date: 2026-05-30` frontmatter applied per the `/wr-architect:create-adr` Step 5 "Born-confirmed write" mechanism. The mechanism reads: *"Once the user confirms the ADR via this AskUserQuestion pass, write the human-oversight marker into the frontmatter"*. The Step 5 AskUserQuestion I fired bundled draft-acceptance with substance-confirmation:

> *"ADR-078 review pass — does the problem statement + Decision Outcome (Option 6) capture the situation?"*
>
> Options: (a) Yes, capture as-written; (b) Yes with minor edits I'll dictate; (c) Pick a different option; (d) Park draft for later review

User answered "Yes, capture as-written" — confirming the draft was well-written. The marker mechanism treated that click as substance-ratification and wrote `human-oversight: confirmed`. The architect agent reads this marker as proof of ADR-066-compliant human oversight; for the period between `5196e3d` and the amendment commit `875569a` (2026-05-31), ADR-078 was being treated as ratified by the architect-agent infrastructure on a foundation it did not have.

This is structurally different from P339:

- **P339** captures: substance-question SHAPE is wrong (substance bundled into draft-acceptance question; substance not asked separately before drafting Decision Outcome / Consequences / Confirmation / Pros and Cons).
- **P340 (this ticket)** captures: born-confirmed MARKER MECHANISM is too weak (the marker write fires on ANY Step 5 "yes" answer, including one that confirms only the draft; even if the substance-question shape were correct, the marker mechanism doesn't verify that the substance was specifically approved).

P339 and P340 are sibling-class. P339 is the question-shape gap. P340 is the marker-gate gap.

## Symptoms

- ADR ships with `human-oversight: confirmed` marker even when user only confirmed draft quality, not substance.
- Architect agent reads the marker as proof of ratification (ADR-066 contract) and treats the ADR as authoritative for routine compliance.
- Substantive ADRs flow into the governance corpus with bogus ratification claims unless the user notices and pushes back AFTER the marker has shipped.
- Cross-references to ratified ADRs (e.g., other ADRs citing ADR-078 as a foundation) may build on bogus-ratified-substance.

## Workaround

User must explicitly call out: *"I never approved that substance. How did that ADR skip ratification?"* (verbatim user direction 2026-05-31). Then the marker must be retroactively reviewed; the ADR needs an amendment-history note; and the chain of dependent work needs re-examining.

## Impact Assessment

- **Who is affected**: every user invoking `/wr-architect:create-adr` whose substance preference differs from the agent's draft + every downstream consumer of ratified ADRs (architect agent, dependent ADRs, dependent code).
- **Frequency**: every ADR drafting flow where the agent picks the chosen option (P339 surface) AND the Step 5 confirm pass uses a bundled question (P340 surface).
- **Severity**: HIGH in practice — governance foundation depends on `human-oversight: confirmed` meaning what it says. When the marker can apply to substance the user didn't actually approve, the entire ratification claim chain is unreliable.
- **Analytics**: ADR-078 commit `5196e3d` is the in-session exemplar; user surfaced the gap only after the marker had shipped and Option 6 was being treated as ratified for ~1 day.

## Root Cause Analysis

### The substance-confirmation interaction pattern requirements (user direction 2026-05-31)

When the substance of a decision is being confirmed by the user, the AskUserQuestion presentation MUST satisfy ALL of the following:

1. **The user MUST be briefed on the options considered, the option selected, and the rationale.** The briefing is the substance-of-the-decision presented in a form the user can read and reason about without external lookup.

2. **The briefing MUST be done in prose, not in long AskUserQuestion text.** Long AskUserQuestion text is NOT readable on some devices (mobile clients, accessibility tooling, certain notification surfaces). Long prose + short questions IS readable across the full device matrix. The split is load-bearing: prose carries the briefing; the AskUserQuestion stays narrow.

3. **The AskUserQuestion MUST NOT be a yes/no shape.** It MUST present each considered option as a selectable option in the AskUserQuestion options array. The user picks the substantive direction positively (chooses an option), not by clicking "yes" on a bundled "is this OK?" question.

4. **The briefing prose, the question, and the options MUST NOT use IDs as explainers.** The user does NOT have access to those IDs on all devices (mobile clients without the project filesystem; notification surfaces; accessibility readers that can't follow links). Names like "ADR-074", "P315", "JTBD-006" are agent-internal references — they MUST NOT carry meaning the user has to look up to understand the option. Every option's substance MUST be self-contained in the prose + the option label/description.

5. **The user MUST be able to make an informed decision without looking up other documents.** The briefing + AskUserQuestion is a self-contained surface. If understanding a chosen option requires the user to first read another document, the briefing has failed.

### Mechanism failure that this pattern fixes

The `/wr-architect:create-adr` Step 5 "Born-confirmed write" mechanism currently treats ANY user click on the Step 5 AskUserQuestion as substance-ratification. The click is taken as a signal to write the marker. There is no verification that the click was AGAINST the substantive choice (vs. against draft quality, vs. against problem statement OK, vs. against anything else bundled into the question).

The structural fix: the marker write MUST be gated on an AskUserQuestion answer that:

- Was explicitly framed as substance-confirmation (per the 5 requirements above)
- Presented each considered option as a selectable option
- Returned an answer that selects ONE specific substantive option (not a "yes accept draft" or similar bundled answer)

Until the answer selects a specific option from the considered-options set, the marker MUST NOT be written. Draft-quality questions and substance-questions MUST be separate AskUserQuestion fires.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Amend `/wr-architect:create-adr` SKILL.md Step 5: replace the bundled "review pass" AskUserQuestion with two separate firings:
  - **Substance-confirm fire**: prose briefing of the considered options + selected option + rationale (in main turn text, NOT in AskUserQuestion text); AskUserQuestion presents each considered option as a selectable option; the user positively affirms a substantive choice.
  - **Born-confirmed marker write** ONLY when the substance-confirm fire's answer matches the option the draft was authored against. If the user picks a DIFFERENT option, re-draft Decision Outcome (and dependent sections) against the new choice; re-fire substance-confirm.
  - **Draft-quality review fire** (optional, after substance-confirm passes): narrow questions on prose quality, consulted/informed list, edge-cases — does NOT gate the marker.
- [ ] Amend `/wr-architect:capture-adr` SKILL.md if it carries an equivalent born-confirmed gate (or document that capture-adr explicitly does NOT apply the marker).
- [ ] Behavioural bats coverage:
  - Substance-confirm AskUserQuestion presents each considered option as a selectable option (not yes/no).
  - Briefing prose appears in main turn text BEFORE the AskUserQuestion fires (so device matrix readers see the briefing even if AskUserQuestion text is truncated).
  - Briefing + question + options do NOT cite IDs as explainers — each option's substance is self-contained.
  - Born-confirmed marker write fires ONLY when substance-confirm answer specifies a substantive option (not on bundled / draft-acceptance / problem-statement-OK answers).
- [ ] Cross-reference and possibly amend ADR-066 (born-confirmed marker contract) to add: the marker MUST be written ONLY in response to an explicit substance-confirmation AskUserQuestion answer that selects a specific substantive option from the considered-options set.
- [ ] Cross-reference and possibly amend ADR-064 (review-and-confirm-every-ADR gate) to add the substance-confirmation interaction-pattern requirements (the 5 requirements above) as the load-bearing shape of the gate.
- [ ] Sweep existing ADRs whose ratification claims may be bogus by the same mechanism (ADRs ratified by clicking yes on bundled questions). Likely needs a separate dedicated session — out of scope for this ticket but flag for follow-up.

## Dependencies

- **Blocks**: trustworthy ratification claims across the ADR corpus. Until the marker mechanism only fires on verified substance-confirmation, every ratified ADR is potentially bogus by the same path that ADR-078's first commit was.
- **Blocked by**: (none — fix is bounded to SKILL.md amendments + bats coverage + possibly ADR-066 / ADR-064 amendments).
- **Composes with**: P339 (substance-question shape), ADR-074 (substance-confirm-before-build framework), ADR-066 (born-confirmed marker contract), ADR-064 (review-and-confirm-every-ADR gate).

## Related

(captured via /wr-itil:capture-problem 2026-05-31 after user surfaced the bogus historical ratification claim on ADR-078 commit 5196e3d)

- **P339** — sibling-class capture of the substance-question shape at create-adr Step 5; this ticket is the marker-mechanism-gate sibling.
- **ADR-066** — born-confirmed marker contract; the load-bearing reading of the marker downstream depends on the marker only being written under verified substance-confirmation.
- **ADR-064** — review-and-confirm-every-ADR gate; the gate's load-bearing semantics depend on substance-confirmation as defined here.
- **ADR-074** — substance-confirm-before-build framework; this ticket's pattern is the create-adr-Step-5 implementation of that framework.
- **ADR-078** — concrete exemplar (original commit 5196e3d shipped bogus ratification on Option 6; amended 2026-05-31 with explicit amendment-history note).
- `packages/architect/skills/create-adr/SKILL.md` Step 5 — the prescribed amendment locus.
- `packages/architect/skills/create-adr/test/*.bats` — behavioural-coverage locus.
- Memory: `feedback_run_decisions_by_user_before_drafting.md` — the create-adr SKILL-surface rule; will be updated with the marker-mechanism requirements.
