# Problem 330: derive-release-vehicle helper requires pre-edit of ticket changeset reference — three-touch when one-touch would suffice

**Status**: Known Error
**Reported**: 2026-05-30 (work-problems wrap retro)
**Priority**: 6 (Medium) — Impact: 2 (Minor — adopter UX friction on every K→V transition; recoverable via documented exit-2 routing) × Likelihood: 3 (Possible — fires on every K→V where the changeset reference isn't already in the ticket body)
**Effort**: S (small helper amendment OR manage-problem fix-ship-step seed; either path is single-file)
**WSJF**: 6.0 (re-rated 2026-05-31; Effort S confirmed; was 3.0 placeholder)

## Description

The `wr-itil-derive-release-vehicle` helper (shipped @windyroad/itil@0.37.0 iter 1 this session; dogfooded 3 times in K→V iters this session) exits 2 with `ERROR: no .changeset/<name>.md reference in <ticket-path>` when invoked before the K→V transition writes the `## Fix Released` section. K→V is typically the surface that adds the changeset reference — so the contract forces a three-touch sequence per K→V transition: pre-edit ticket to seed changeset reference, run helper, then edit citation block. One-touch would suffice if either the helper or the manage-problem fix-ship step seeded the reference deterministically.

## Symptoms

- 4 K→V dogfoods this session (P267 iter 2, P316 iter 5, P281 iter 8, P302 iter 10). Of those:
  - P267 iter 2: inherited the changeset reference from prior iter 1 work (worked first-call)
  - P316 iter 5: required exit-2 routing — append changeset path to ticket body, re-run helper
  - P281 iter 8: required exit-2 routing — same pattern as P316
  - P302 iter 10: required exit-2 routing — same pattern as P316/P281 (4th data point; 3/4 dogfoods = 75% hit rate)
- Helper script: `packages/itil/scripts/derive-release-vehicle.sh` line 109 (the contract check that emits the ERROR).
- Concrete observable: iter 8 first probe returned `ERROR: no .changeset/<name>.md reference in docs/problems/known-error/281-...md` exit 2; iter manually appended the reference, second probe returned exit 0. iter 10 (P302) reproduced exactly: first probe `ERROR: no .changeset/<name>.md reference in docs/problems/known-error/302-...md` exit 2; appended `**Release vehicle**: .changeset/p302-decision-confirmation-presentation-rule.md ...` paragraph to Fix Strategy; second probe exit 0 with full citation.
- Cross-iter session evidence: 3 of 4 dogfoods (~75%) hit the friction — sustained pattern, confirmed across sessions (P302 iter 10 is a separate subprocess from P281 iter 8; same defect class fires reliably).

## Workaround

Pre-edit the ticket file to insert the changeset filename reference before invoking `wr-itil-derive-release-vehicle <ticket-id>`. Documented in the transition-problem SKILL contract.

## Impact Assessment

- **Who is affected**: every K→V transition using the helper (orchestrator iters + interactive `/wr-itil:transition-problem to-verifying` invocations).
- **Frequency**: 2 of 3 K→V dogfoods this session (~66%); ~5-10 K→V transitions per week typical sustained rate.
- **Severity**: Minor — recoverable via documented routing, not a blocker. But UX friction compounds over many K→V cycles.
- **Analytics**: friction observed only on the helper-call surface; no production damage; no adopter-side impact.

## Root Cause Analysis

### Why the helper requires the reference up-front

The helper's contract is "derive release vehicle from a closed-ticket file body that already cites the changeset". The original design assumed the changeset reference would be in the ticket body BEFORE K→V — typical for the manage-problem flow where the fix commit explicitly names the changeset in the ticket (fold-fix pattern, `closes P<NNN>` commit). But the standalone K→V transition path (where the fix shipped in a prior iter and K→V is its own iter) doesn't seed the reference — there's no fold-fix to drag the reference into the body.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Confirm the 3 candidate fix options below + architect verdict on which option fits ADR-049 shim contract + ADR-022 lifecycle — **Option B ratified by user 2026-06-01** in /wr-itil:work-problems AFK iter dispatch instruction ("User RATIFIED P330 fix locus: Option B (manage-problem fix-ship step seeds .changeset/<name>.md reference inline in ticket body)")
- [x] Codify Option B in manage-problem SKILL.md Step 7 + transition-problem SKILL.md Step 6 (copy-not-move per ADR-010 amended / P093) with structural bats backstop — shipped in this iter's commit (2026-06-01)
- [ ] Bats coverage extending derive-release-vehicle.bats with the K→V-standalone path — **deferred-retrofit**: the structural backstop at `packages/itil/skills/manage-problem/test/manage-problem-release-vehicle-seed.bats` (with ADR-052 § Surface 2 `tdd-review: structural-permitted` marker citing this task) carries the contract in the meantime; behavioural K→V-mock test follows in a separate commit

## Fix Strategy

**Status: Option B ratified and codified 2026-06-01.** User-ratified in this iter's /wr-itil:work-problems AFK dispatch instruction. Codification shipped in this iter's single ADR-014 commit: `packages/itil/skills/manage-problem/SKILL.md` Step 7 + `packages/itil/skills/transition-problem/SKILL.md` Step 6 amended with the seed-`Release vehicle`-reference-BEFORE-rename step + structural bats backstop at `packages/itil/skills/manage-problem/test/manage-problem-release-vehicle-seed.bats`. The three-option analysis is preserved below for historical audit trail.

**Release vehicle**: .changeset/wr-itil-p330-option-b.md

Three candidate options (architect verdict needed — **awaiting user ratification**):

### Option A — helper accepts `--changeset <name>` flag

`wr-itil-derive-release-vehicle --changeset .changeset/<name>.md <NNN>` — caller passes the changeset path explicitly; helper skips the ticket-body grep when the flag is present.

**Pros**:
- Surgical: helper-only edit (~10 lines in `derive-release-vehicle.sh` argument parsing + grep skip).
- No SKILL.md churn; transition-problem Step 6 contract unchanged.

**Cons**:
- Caller-burden inversion: the K→V caller must now look up the changeset name, which is **exactly what the helper was designed to do**. Pushing the lookup to the caller re-invents the contract.
- Doesn't address the underlying audit-trail gap: ticket bodies still lack the changeset reference, so future "which changeset shipped P<NNN>" grep stays broken.
- Doesn't match the user's observed workaround pattern (the workaround is body-edit — `**Release vehicle**: .changeset/...` paragraph appended to Fix Strategy — not flag-pass).
- Standalone K→V iter (iter N+M for a fix shipped at iter N) still needs lookup logic somewhere; flag just moves the lookup outward.

### Option B — manage-problem fix-ship step seeds reference inline (RECOMMENDED)

`/wr-itil:manage-problem` Step 7 (the K→V transition surface that writes `## Fix Released`) AND/OR Step 11 (commit handling when the fix folds with the closing commit) edits the ticket body to insert a `**Release vehicle**: .changeset/<name>.md` paragraph in the Fix Strategy section BEFORE the `git mv` to `.verifying.md`. Every fix-ship seeds the reference deterministically.

**Pros**:
- Root-cause fix: closes the audit-trail gap at the natural seed point — fix-ship has the changeset name (it just created the changeset).
- Matches the user's documented workaround pattern verbatim (the iter-10 P302 workaround was: append `**Release vehicle**: .changeset/p302-...md` to Fix Strategy — exactly what this codifies).
- Helper contract stays unchanged (no flag, no new exit-code routing).
- Ticket body becomes self-documenting for the audit trail — future `grep -r .changeset/ docs/problems/closed/` finds which changeset shipped each ticket.
- Deterministic across all K→V paths (folded-fix, standalone-iter, orchestrator AFK drain).

**Cons**:
- Touches `packages/itil/skills/manage-problem/SKILL.md` Step 7 — adds an explicit body-edit step before the K→V rename (one extra Edit-tool call per transition).
- Doesn't help legacy tickets shipped before codification — exit-2 routing in transition-problem Step 6 remains as a recovery path for those (already documented).
- Cross-skill consistency: `/wr-itil:transition-problem` Step 6 inherits the same seed step via the in-skill Step 7 copy (per ADR-010 amended "copy, not move") — two surfaces to keep in sync.

### Option C — combine A + B (belt-and-braces)

Both flag AND inline seeding.

**Pros**:
- Defence in depth: even if fix-ship misses the inline seed (Option B), the helper-flag (Option A) is a fallback.

**Cons**:
- Larger surface area for the same outcome.
- Once Option B ships, Option A becomes vestigial — the exit-2 routing already documented in `transition-problem` SKILL Step 6 is itself a recovery path; a third path adds no clear value.
- Violates ADR-038 progressive disclosure: extra surface that does not pay for its own cognitive cost.

### Recommendation: Option B

Recommended pick: **Option B**. Rationale:
1. Matches the user's lived workaround pattern (iter-10 P302 body-edit). Codifying observed behaviour beats inventing a new surface.
2. Closes the audit-trail gap at the natural seed point — fix-ship knows the changeset name; pushing the lookup to a flag-caller re-creates the gap.
3. Helper contract stays unchanged; exit-2 routing remains as the legacy-ticket recovery path (already documented in `transition-problem` SKILL Step 6).
4. Survives ADR-049 shim contract review (no helper-side change) and ADR-022 lifecycle review (the inline seed lands in the same fix-ship commit that creates the changeset, riding ADR-014 single-commit grain).

**Pending ratification** — per `feedback_confirm_decision_substance_before_building` + `feedback_run_decisions_by_user_before_drafting`, the locus pick (A/B/C) is a genuine ≥2-option design decision and must be human-confirmed BEFORE dependent SKILL edits ship. Surfaced via outstanding_question in the 2026-06-01 iter retro.

**Kind**: improve  
**Shape**: skill (manage-problem SKILL.md Step 7 + transition-problem SKILL.md Step 6 inline copy per ADR-010 amended)  
**Target file**: `packages/itil/skills/manage-problem/SKILL.md` Step 7 + `packages/itil/skills/transition-problem/SKILL.md` Step 6 (copy-not-move per ADR-010)  
**Observed flaw**: 3-touch K→V cycle when 1-touch would suffice; helper assumes prior reference seed that standalone K→V iter doesn't provide  
**Edit summary** (Option B, pending ratification): insert body-edit step in manage-problem Step 7 (and transition-problem Step 6 inline copy) that appends `**Release vehicle**: .changeset/<name>.md` paragraph to the ticket's Fix Strategy section BEFORE the `git mv` to `.verifying.md`; helper contract unchanged; legacy-ticket exit-2 routing remains documented

## Dependencies

- **Blocks**: (none — workaround works)
- **Blocked by**: (none)
- **Composes with**: ADR-049 (`bin/` PATH naming grammar), ADR-022 (Verifying lifecycle), `/wr-itil:transition-problem` Step 6, `/wr-itil:work-problems` Step 5 K→V iter pattern

## Related

- P267 (Verifying — the codification ticket that shipped the helper this session)
- P281 (Verifying — second K→V dogfood instance where exit-2 routing required)
- P316 (Verifying — first K→V dogfood instance where exit-2 routing required)
- P302 (Verifying — fourth K→V dogfood instance where exit-2 routing required; transitioned this iter)
- 2026-05-30 work-problems iter 8 retro observation (captured in `docs/retros/2026-05-30-work-problems-iter8-p281-kv.md` outstanding_questions)
- 2026-05-30 work-problems wrap retro (P330 capture)
- 2026-05-30 work-problems iter 10 retro (P302 K→V dogfood — this evidence append)
- 2026-06-01 work-problems iter (this iter) — Fix Strategy refinement + Option B recommendation pending user ratification
