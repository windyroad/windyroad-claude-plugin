# Problem 339: `/wr-architect:create-adr` flow drafts substantive ADR decision (picks Considered Option, bakes Decision Outcome) THEN asks Step 5 confirm — instead of running the option choice past the user FIRST before drafting

**Status**: Verification Pending (subsumed by P340; shipped together)
**Reported**: 2026-05-31
**Transitioned to Known Error**: 2026-05-31
**Fix released**: 2026-06-01 — @windyroad/architect@0.13.0 (commit 4a36ae1)
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems; HIGH in practice — substance-of-decision rides agent-recommended Option N to commit unless the user notices and pushes back)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; likely amends `/wr-architect:create-adr` SKILL.md Step 2 + Step 5; behavioural bats coverage on the "ask chosen-option BEFORE writing Decision Outcome" invariant)

## Description

Surfaced 2026-05-31 by direct user correction during ADR-078 drafting: *"I never approved the scripted extraction. You are supposed to run decisions by me"*.

Concrete sequence that triggered the correction:

1. User asked: "is there enough information in here to follow the decisions without have the consult the full ADR file. It doesn't look like there is"
2. Agent captured P337 (compendium gap) and outlined 5 considered options for the fix
3. Agent invoked `/wr-architect:create-adr` to draft ADR-078
4. Agent fired Step 2-equivalent AskUserQuestion bundling "chosen option" + "decision-makers" + "flow" — user answered "No, do the ADR first" + "Find best practices first"
5. Agent then ran best-practices research (WebSearch + WebFetch)
6. Agent then *wrote the full ADR with a recommended Option 6 baked into Decision Outcome*, then fired Step 5 AskUserQuestion: "ADR-078 review pass — does the problem statement + Decision Outcome (Option 6) capture the situation?"
7. User answered "Yes, capture as-written" — reading the question as "do you accept the draft I authored"
8. Agent treated that as substance-approval and committed ADR-078 with Option 6 as the chosen direction
9. User came back: "Is that a programmatic extraction or a LLM based extraction?" → revealed Option 6 (programmatic with heuristics) was NOT what the user would have chosen if asked explicitly. User iterated through Option 8 → Option 8b → Option 9. Final direction = Option 9 (architect-on-edit writes README entry directly), which is *substantially different* from the Option 6 the agent baked in.
10. User direct correction: *"I never approved the scripted extraction. You are supposed to run decisions by me"*.

The Step 5 confirm-pass shape — agent drafts full ADR with chosen option baked into Decision Outcome, then asks "is this OK?" — converts substance-confirmation into draft-acceptance, which is NOT the same thing. The user reading "Yes, capture as-written" was confirming the draft was well-written, NOT authorizing Option 6 as the choice (Option 9 was always reachable but never surfaced as a peer).

## Symptoms

- Agent reaches Step 5 with a fully-drafted ADR including a chosen Decision Outcome.
- Step 5 AskUserQuestion bundles "is the problem statement OK + does Option X capture it?" — multi-axis question that confounds problem-framing approval with substance-choice approval.
- User's "Yes" reads as draft-acceptance; agent treats it as substance-approval.
- Substantive Decision Outcomes ship unless the user notices and pushes back on the chosen option.
- ADR-074 / P315 class at the create-adr surface specifically — agent builds dependent work (full Decision Outcome + Consequences + Confirmation + Pros and Cons paragraphs) on a substance the user hasn't authorized.

## Workaround

User must explicitly call out: "I haven't authorized the chosen option; surface the options as a separate AskUserQuestion before drafting Decision Outcome". This is what the user did on this turn ("I never approved...").

## Impact Assessment

- **Who is affected**: every user invoking `/wr-architect:create-adr` whose chosen-option preference differs from the agent's recommendation.
- **Frequency**: every multi-option ADR drafting flow where the user has substantive direction not yet expressed.
- **Severity**: HIGH in practice — substantive ADRs may ship with agent-chosen substance unless the user catches the slip. ADR-066 human-oversight marker doesn't help here because Step 5 fires the AskUserQuestion that lands the marker — the marker says "this ADR is human-oversighted" but the oversight pass was *on the draft, not the substance choice*.
- **Analytics**: ADR-078 commit `5196e3d` is the in-session exemplar; user revealed the substance-direction differed from Option 6 only after the draft landed.

## Root Cause Analysis

`/wr-architect:create-adr` SKILL.md Step 2 derive-first dispatch correctly identifies that **Considered Options** and **Decision Outcome** are category-1 direction-setting fields. But it bundles them into a single flow with the rest of the draft fields. The Step 5 confirm pass is described as the load-bearing "review-and-confirm-every-ADR" gate per ADR-064 but is operationally treated as a final-draft-OK pass, not as a substance-choice pass.

The architectural gap: there is no SKILL-prescribed step between "Considered Options collected" and "Decision Outcome drafted" that ASKS the user which option to chose BEFORE Decision Outcome is written. Step 5 is too late — by then the substance has already shaped the Consequences + Confirmation + Pros and Cons + Reassessment Criteria sections that build on the chosen option.

ADR-074 already covers this class of behaviour at the *propose-fix* surface in `/wr-itil:manage-problem`. The fix surface is symmetric: `/wr-architect:create-adr` Step 4 (write the ADR file) is the create-adr equivalent of manage-problem's propose-fix — both sites should pre-confirm the substance before writing dependent content.

P315 is the existing master-class capture of "agent builds dependent work before human-confirming substance". This ticket is the create-adr-specific subclass.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Amend `/wr-architect:create-adr` SKILL.md Step 2: when `Considered Options` resolves to 2+ options (i.e. there IS a real choice), fire a DEDICATED AskUserQuestion asking the user to pick the chosen option BEFORE Step 4 writes the Decision Outcome / Consequences / Confirmation / Pros and Cons sections.
- [ ] Step 5 AskUserQuestion shape: split into 3 narrower questions — (a) problem-statement OK? (b) does the WRITTEN Decision Outcome accurately render the user's pre-confirmed substance choice? (c) anyone to add to consulted/informed? — separates draft-acceptance from substance-choice (which was already pre-confirmed).
- [ ] Behavioural test (bats): assert SKILL.md prescribes the substance-confirm-before-draft step; assert Step 5 question shape doesn't bundle substance with draft acceptance.
- [ ] ADR amendment to ADR-074 (substance-confirm-before-build) extending its scope to explicitly include `/wr-architect:create-adr` Step 4 as a covered pre-build surface — OR a sibling-amendment to ADR-064.
- [ ] Cross-reference ADR-078's "substance pinned up-front" architect verdict — that verdict was correct in form (substance WAS pinned in `<prose>`) but the substance was Option-6-as-recommendation, not user-direction. The architect agent reading the prose can't distinguish "user pinned Option 6" from "agent proposes Option 6 + user hasn't disagreed yet" — this is a separate sibling gap.

## Dependencies

- **Blocks**: clean ADR-074-compliance for `/wr-architect:create-adr` Step 4.
- **Blocked by**: (none — fix is bounded to SKILL.md amendment + bats coverage).
- **Composes with**: ADR-074 (substance-confirm-before-build), ADR-064 (review-and-confirm-every-ADR), P315 (master-class capture of build-on-unconfirmed-substance behaviour).

## Fix Released

Released 2026-06-01 in **@windyroad/architect@0.13.0** (fix commit `4a36ae1`, packaged via `1d1d6a8 chore: version packages`). P340 captures the marker-mechanism sibling and subsumed this ticket — the same SKILL.md amendment closed both. The AFK iter 2026-05-31 fix shipped:

- `packages/architect/skills/create-adr/SKILL.md` Step 5 split into Step 5a (substance-confirm fire — prose briefing + option-shaped AskUserQuestion + no-IDs-as-explainers + informed-decision-without-external-doc-lookup) + Step 5b (optional draft-quality review fire, does NOT gate the marker).
- ADR-064 § Decision Outcome amended 2026-05-31 with the five interaction-pattern requirements (extending the 2026-05-27 ADR-074 amendment).
- ADR-066 § Decision Outcome item 5 amended 2026-05-31 to tighten marker-write trigger to "substance-confirm answer specifying a substantive option."
- `packages/architect/skills/create-adr/test/create-adr-substance-confirm-pattern.bats` adds 11 behavioural-assertion bats on the new contract; existing `create-adr-adr-044-contract.bats` Step 5 negative-of-negative guard still passes (loosened to "AskUserQuestion appears in Step 5 across two fires").
- Changeset `.changeset/p339-p340-substance-confirm-pattern.md` (@windyroad/architect minor).

Awaiting user verification: next `/wr-architect:create-adr` invocation should fire the new Step 5a substance-confirm AskUserQuestion (briefing in main-turn prose; option-shaped not yes/no; no IDs as explainers) BEFORE drafting Decision Outcome, and the `human-oversight: confirmed` marker should write ONLY on a substantive option-pick answer.

## Related

(captured via /wr-itil:capture-problem 2026-05-31 after user correction during ADR-078 drafting session 9)

- **P315** — master-class capture of agent-builds-substance-before-confirming-substance.
- **ADR-074** — substance-confirm-before-build framework; this is the create-adr-surface subclass.
- **ADR-064** — review-and-confirm-every-ADR (Step 5 load-bearing gate); the SKILL contract reads as substance-confirm but ships as draft-confirm in practice.
- **ADR-066** — born-confirmed marker; the marker confirms the draft was reviewed, not that the substance choice was authorized BEFORE drafting.
- **ADR-078** — concrete in-session exemplar (commit 5196e3d); will be amended in same session to swap Option 6 → Option 9 per user direction.
- `packages/architect/skills/create-adr/SKILL.md` Step 2 + Step 5 — the prescribed amendment loci.
- `packages/architect/skills/create-adr/test/*.bats` — behavioural-coverage locus for the substance-confirm-before-draft invariant.
- Memory: `feedback_confirm_decision_substance_before_building.md` — already-captured user-direction; this ticket is the SKILL-surface specific implementation gap.
