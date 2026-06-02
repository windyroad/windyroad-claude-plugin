# Problem 104: `/wr-itil:work-problems` partial-progress iteration outcome can paint the release queue into a mid-state corner — slice-1-without-slice-2 hazard

**Status**: Verification Pending
**Reported**: 2026-04-22
**Priority**: 16 (High) — Impact: Major (4) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: (16 × 1.0) / 2 = **8.0**

> Identified 2026-04-22 by the user during the iter-4 post-commit review of P100 slice 1: *"have you kind of painted yourself into a corner with p100? That in itself is a problem"*. Iter 4 of `/wr-itil:work-problems` landed P100 slice 1 (directory migration + README index + transitional stub + writer-side run-retro changes + architect/JTBD hook exemptions) with `outcome: partial-progress`. The resulting release queue contains a `@windyroad/retrospective` minor (slice 1's writer-side changes) that cannot ship safely until slice 2 delivers the paired SessionStart hook — adopters would absorb layout churn without the headline benefit. Even splitting off the minor (per P103's R3 remediation) leaves architect and JTBD exemption patches in the queue that advertise a path shape adopter plugins haven't yet migrated to. **This is a structural hazard of the `partial-progress` outcome category** — individual iterations can produce release-queue states that cannot be drained cleanly without user intervention.

## Description

Work-problems iterations can return any of the following outcomes per the iteration-prompt template (Step 5):

- `closed` / `verifying` / `known-error` — terminal for the ticket; releaseable.
- `investigated` — docs-only; releaseable if worth shipping.
- `scope-expanded` — ticket update only; no dev surface; trivially releaseable.
- `skipped` — no commit; nothing to release.
- `partial-progress` — **the trap**: the iteration landed commits, but those commits make architectural sense only as part of a larger change that hasn't shipped yet.

`partial-progress` is explicitly allowed in the iteration prompt (orchestrator Step 5). The intent was good — allow an iteration to ship a cleanly-scoped first cut rather than sinking the whole iteration budget into one ticket. But the release-queue consequences weren't tracked. Iter 4 of 2026-04-22 demonstrated the hazard:

- Slice 1 landed the BRIEFING migration + `run-retro` writer-side + architect/JTBD hook exemptions.
- The resulting changesets spanned 4 packages including a `@windyroad/retrospective` **minor** bump.
- Slice 2 (SessionStart hook + sibling ADR + helpfulness loop + stub retirement) required architect design judgment that could not be resolved non-interactively.
- Shipping the minor without slice 2 would move adopter layout without the paired feature (Risk 2 at 9/25 Medium per iter 4's scorer).
- Shipping ONLY the patches (R3 remediation) still releases architect/JTBD exemption paths that advertise the new `docs/briefing/*` shape — harmless in practice (adopters without the dir hit a no-op exemption) but inconsistent with the retrospective plugin that hasn't yet shipped the migration writer-side.

**Whichever subset the orchestrator picks, the release queue is an uncomfortable intermediate state.** Either hold everything until slice 2 (indefinite wait; blocks the unrelated itil patch that IS releaseable on its own), or drain a strict subset with known inconsistency (architect/JTBD exemptions ship without retrospective; or retrospective ships without exemptions; etc.). This is the "painted into a corner" state the user surfaced.

## Symptoms

- Iter 4's release-cadence branch has no clean exit: every drainable subset is a compromise.
- The retrospective minor changeset has been moved to `docs/changesets-holding/` (outside `.changeset/` entirely — `changesets/action@v1` fails with ENOENT on any subdirectory under `.changeset/`) as a holding pattern per P103's R3 fix. The holding-area README documents the provisional convention. It waits indefinitely for slice 2.
- Any future L/XL ticket that splits into slice 1 + slice 2 + slice N will reproduce the pattern.

## Workaround

Manual curation of the release queue before drain. The user (or the orchestrator per P103's fix once implemented) inspects changesets, moves slice-2-dependent ones to `docs/changesets-holding/` (outside `.changeset/` entirely, to sidestep the `changesets/action@v1` subdirectory-ENOENT defect), drains the remainder, and commits the holding state. Reinstates the held changesets when slice 2 lands.

## Impact Assessment

- **Who is affected**: User of `/wr-itil:work-problems` (primary); adopter projects that would otherwise receive mid-migration minor bumps; the plugin-developer persona during any L/XL ticket.
- **Frequency**: Every L/XL ticket worked in slices. P100 demonstrates the pattern; future L/XL tickets (P096, P097, P099, P018, P069, P078, and others) will hit the same hazard.
- **Severity**: Major. Directly constrains the AFK loop's ability to reach the release-on-npm terminal state for partial work.
- **Analytics**: Observed iter 4 2026-04-22. Expected on every future multi-slice iteration of an L/XL ticket.

## Root Cause Analysis

### Preliminary Hypothesis

Two interacting issues:

1. **Step 4 classifier omission** — `work-problems` Step 4 has no rule for "Open ticket with architect-design-level question open AND L+ effort likely to produce partial-progress → skip as architect-design". Today, P100 was dispatched despite its Design Update section flagging open architect questions (SessionStart hook existence, ADR amendment vs sibling, helpfulness-loop scope). The classifier should have skipped it and surfaced those as Outstanding Design Questions at stop-condition #2.
2. **`partial-progress` outcome has no release-queue guard** — the iteration prompt (Step 5) accepts `partial-progress` as a valid outcome without considering whether the resulting changeset queue is drainable. A partial-progress outcome that produces an unreleaseable or awkwardly-split queue is a defect; the iteration should have returned `scope-expanded` instead (no commits, findings-only).

### Investigation Tasks

- [ ] Audit existing `work-problems` Step 4 classifier for scope-expansion + architect-design-open cases. Add an explicit skip rule for tickets with Design Update sections listing open architect questions.
- [ ] Amend the iteration prompt (Step 5) to constrain `partial-progress` acceptability — the worker may only return partial-progress if the partial state is individually releaseable (patch-only within a single package or docs-only). Multi-package partials that include a minor/major bump must instead return `scope-expanded` with findings documented; the orchestrator then schedules architect review across multiple iterations.
- [ ] Consider promoting `docs/changesets-holding/` from this session's provisional convention (documented in its own README) to an orchestrator-blessed convention, with SKILL-level guidance on when iteration workers stage pending vs active changesets. If blessed, promote to ADR (candidate ADR-039) amending ADR-018 + ADR-020's above-appetite branch.
- [ ] Bats coverage: simulate an iteration that produces a multi-slice partial-progress output and assert the orchestrator handles it cleanly (classifies up-front; or rejects the partial; or stages to `pending/`).

### Fix Strategy

Two complementary fixes:

1. **Step 4 classifier**: add "Open problem with outstanding architect-design questions AND L+ effort → skip as architect-design" to the classifier table. Rely on the ticket's Design Update or Investigation Tasks section to mark open architect questions explicitly.
2. **Step 5 iteration prompt**: restrict `partial-progress` acceptability. The worker may only return `partial-progress` if the partial state is individually releaseable — patch-only within a single package, or docs-only. Multi-package partials or any partial that includes a `minor`/`major` bump must instead return `scope-expanded` with findings-only; no code commits. The orchestrator handles the full ticket across multiple iterations with architect review in between slices.

Bats coverage exercises the classifier skip path and the partial-progress restriction.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none)
- **Composes with**: P103, P053, P016, P100

## Related

- **P103 (work-problems escalates above-appetite release decisions already resolved by the risk scorer)** — sibling. P103 covers orchestrator behaviour when the queue is above appetite; P104 covers the upstream cause — the queue's composition — that made it above appetite. Both need to land together for release cadence to self-heal non-interactively in AFK mode.
- **P053 (work-problems surfaces outstanding design questions at stop-condition #2)** — sibling. P053's structured-summary pattern is the natural home for the "slice 2 is pending, here are the questions" artefact produced by the P104 classifier skip.
- **P016 (manage-problem should split multi-concern tickets)** — parent pattern at ticket-creation time. P104 is the iteration-time variant: iterating an L/XL ticket in slices can itself produce multi-concern release artefacts.
- **P100 (wr-retrospective does not auto-surface docs/BRIEFING.md)** — concrete example. Iter 4 of the 2026-04-22 session was P100 and produced the corner state documented here.
- **ADR-018 (Release cadence)** — the contract both P103 and P104 touch; amendment candidate.

## Fix Released

ADR-041 (`docs/decisions/041-auto-apply-scorer-remediations-above-appetite.proposed.md`) landed 2026-04-22 as the structural fix. Rule 7 blesses the `docs/changesets-holding/` convention (promoted from provisional) — the mechanism that keeps an un-shippable slice-1 changeset outside the `.changeset/` glob without losing its authored intent. Rule 2's auto-apply loop routes slice-1-only states through `move-to-holding` (the implemented action class in ADR-041 v1); Rule 1's "never release above appetite" invariant removes the "ship what we can, leave the rest dirty" escape hatch that previously painted queues into corners.

The holding-area README (`docs/changesets-holding/README.md`) has been updated to remove the "provisional" banner and cite ADR-041 as the authoritative basis. Rule 6 mandates that every auto-apply `move-to-holding` action append to the README's "Currently held" section, making the holding state auditable.

Contract-assertion bats at `packages/itil/skills/work-problems/test/work-problems-above-appetite-remediation.bats` asserts the `docs/changesets-holding/` string and the Rule 7 blessing. Manual behavioural verification pending a partial-progress iteration that triggers `move-to-holding` non-interactively.

Future work tracked in P108 (scorer action-class vocabulary extension) — once `revert-commit` and `feature-flag` classes implement, additional resolution paths exist for painted-into-a-corner states that `move-to-holding` alone cannot resolve (e.g., an intrinsically-risky single commit rather than a multi-changeset accumulation).
