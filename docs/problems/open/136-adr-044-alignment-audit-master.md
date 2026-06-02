# Problem 136: ADR-044 alignment audit — sweep all unaudited skills/hooks/agents/ADRs/JTBDs/READMEs against the framework-resolution boundary (master ticket)

**Status**: Open
**Reported**: 2026-04-27
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3) — friction is suite-wide but per-surface bounded
**Effort**: L — ~5+ sessions across 26 edit-bearing surfaces (3 high-ask SKILLs + 4-6 medium/low-ask SKILLs + 4 critical hooks + ~2 ADR amendments). Per-surface release cadence drains projected risk to one surface at a time per P135 R1.
**WSJF**: (9 × 1.0) / 4 = **2.25**

> Master ticket for the **ADR-044 alignment audit** — the user-directed follow-up to P135's completion. P135 amended 4 SKILLs in Phase 2; the remaining suite (31 SKILLs + 65 hooks + 10 agents + 37 unaudited ADRs + 16 JTBDs + 12 READMEs) needs systematic review against the framework-resolution boundary so CLAUDE.md and other files don't contradict ADR-044. Surfaced 2026-04-27 by user direction at P135 implementation completion: *"we should also do an audit of all the files (hooks, skills, agents, etc) to make sure they align with the clarified direction and make sure CLAUDE.md and other files don't contradict"*.

## Description

ADR-044 (Decision-Delegation Contract) codifies the framework-resolution boundary: framework-resolved decisions are mechanical (no `AskUserQuestion`); the user owns 6 categories (direction-setting / deviation-approval / one-time-override / silent-framework / taste / authentic-correction). Per-action `AskUserQuestion` calls in framework-resolved zones are "lazy deferral" per Step 2d Ask Hygiene Pass classification.

P135 Phase 2 amended 4 SKILLs (run-retro Step 3/4a/4b, work-problems Step 5/2.5, manage-problem Step 9d, transition-problem Step 5 P063). The plan deferred the rest of the suite to a follow-up audit (this ticket). The remaining suite scope (verified Phase 1 inventory):

- **35 SKILL.md total**; 4 audited; **31 remaining**:
  - High-ask candidates (5+ AskUserQuestion calls): `work-problem` singular (11), `mitigate-incident` (8), `manage-incident` (7).
  - Moderate-ask (3 calls): `review-jobs`, `analyze-context`.
  - Zero-ask (likely no work needed): c4/check, c4/generate, itil/list-incidents, itil/list-problems, itil/reconcile-readme.
  - Per-package: architect 2, c4 2, connect 2, itil 16 (14 unaudited), jtbd 2, retrospective 2 (1 audited), risk-scorer 5, style-guide 1, tdd 1, voice-tone 1, wardley 1.
- **69 hooks total**; critical ask-emitters (4): `itil-assistant-output-gate.sh`, `itil-assistant-output-review.sh`, `manage-problem-enforce-create.sh`, `voice-tone-eval.sh`. Other 65: PreToolUse gates (risk-scorer 18, architect 9, others 23), UserPromptSubmit (4), PostToolUse/Stop (scattered). Most are no-ask.
- **10 agents total**; only `risk-scorer/agents/pipeline.md` references ask-behaviour (1 mention); other 9 have no explicit ask-vs-act guidance.
- **43 ADRs total** (41 proposed, 2 superseded); ADR-013 amended in P135 Phase 1; likely composes-with: ADR-022, ADR-032, ADR-040, ADR-042; remaining ~37 to audit for contradictions.
- **16 JTBDs**; no explicit ask-mandate detected in spot checks.
- **12 READMEs** (project root + per-package); no contradictory directives in spot checks.
- **141 bats files, ~253 structural-grep test assertions**; P081 territory. P136 uses `tdd-review: structural-permitted` marker as bridge; P081 Phase 2 owns canonical retrofit.

## Symptoms

- Per-session lazy-AskUserQuestion-count (Step 2d metric) dominated by unaudited SKILLs (work-problem singular at 11 ask-calls is the prime candidate; mitigate-incident at 8; manage-incident at 7).
- Without audit, future P135-class corrections cycle: each user-corrected SKILL re-derives the framework-resolution boundary instead of applying ADR-044 once.
- CLAUDE.md / READMEs / JTBDs may carry direction that contradicts ADR-044 silently — no detection mechanism today.
- ADR-044 is project-wide but only 4 of 35 SKILLs codify it; the remaining 31 SKILLs are out-of-step.

## Workaround

Per-session Step 2d Ask Hygiene Pass surfaces the lazy count; user notices high lazy count tied to a specific SKILL; user invokes `/wr-itil:work-problem <NNN>` against P136 to chip away. Without the master ticket + per-surface findings, the audit is ad-hoc and forgets surfaces.

## Impact Assessment

- **Who is affected**: every user of every windyroad SKILL with un-aligned ADR-044 prose. Solo-developer (JTBD-001) primarily; AFK-orchestration (JTBD-006) compounds because per-iter-redundant-asks multiply across iters; plugin-developer (JTBD-101) inherits via published packages.
- **Frequency**: every interactive session. Once the agent's lazy-ask habit kicks in on an un-aligned SKILL, it persists unbroken until that SKILL is amended.
- **Severity**: Moderate — degrades user experience suite-wide; per-surface bounded.
- **Likelihood**: Possible — depends on which SKILLs the user invokes; `/wr-itil:work-problem` (singular, 11 asks) is high-volume.
- **Analytics**: 2026-04-27 baseline ~5-6 lazy calls per session post-P135-Phase-2; expected to drop measurably as Phase 2/3/4 of P136 land.

## Root Cause Analysis

### Confirmed root cause

P135 Phase 2 amended only the 4 SKILLs the implementer touched. ADR-044 is project-wide; alignment requires systematic per-surface audit. The remaining suite carries pre-ADR-044 prose that wasn't reconciled.

### Investigation Tasks

- [x] Phase 1 inventory completed: 35 SKILLs / 69 hooks / 10 agents / 43 ADRs / 16 JTBDs / 12 READMEs / 141 bats.
- [x] Verified counts via Explore agent (2026-04-27).
- [x] Confirmed P135 Phase 2 already audited 4 SKILLs (run-retro / work-problems / manage-problem / transition-problem).
- [x] Identified high-ask candidates: work-problem (11), mitigate-incident (8), manage-incident (7).
- [x] Phase 2: audit work-problem singular SKILL.md. (2026-04-27) — 2 call sites classified: Step 2 selection = lazy-deferral (amended to framework-mediated tie-break ladder per ADR-044 Prioritisation row); Step 4 scope-expansion = keep (genuine ADR-044 category-2 deviation-approval surface; cosmetic cross-ref added for clarity). Architect + JTBD reviews PASS. Bats: 6 new + 19 existing assertions green; full itil package suite (534 tests) green. Changeset: `@windyroad/itil` patch shipped as `@windyroad/itil@0.21.4` at commit `c5879a2` → released at `7009ce2`.
- [x] Phase 2: audit mitigate-incident SKILL.md. (2026-04-27) — 8 raw mentions reduced to 3 distinct call surfaces: Surface 1 = argument backfill (lines 20/50/52) = lazy-deferral (amended to fail-fast usage message + exit, matching transition-problem / work-problem precedent); Surface 2 = evidence-first gate (lines 37/73) = keep — ADR-044 category-2 deviation-approval (cross-ref added); Surface 3 = risk-above-appetite commit (line 157) = keep — ADR-044 category-3 one-time-override (cross-ref added). Architect + JTBD reviews PASS. Bats: 7 new + 13 existing assertions green; full itil suite green. Changeset shipped as `@windyroad/itil@0.21.5` at commit `2b6ce32` → released at `c727823`.
- [x] Phase 2: audit manage-incident SKILL.md. (2026-04-28) — 7 raw mentions reduced to 4 distinct call surfaces: Surface 1 = duplicate-check prompt (line 133-134) = keep — direction-setting cat-1, **REFACTORED** (closes ADR-013 Confirmation #1 regression: removed `would you like to (a)/(b)/(c)` prose-ask vocabulary; lifted into AskUserQuestion options[]); Surface 2 = gather-new-incident info (line 151) = keep — direction-setting cat-1 (cosmetic cross-ref); Surface 3 = evidence-first gate on hypothesis updates (line 208) = keep — deviation-approval cat-2, **REFACTORED** (aligned with mitigate-incident's 3-option Add/Record-anyway/Cancel pattern; explicit `Evidence-gate bypassed by user — reason: <justification>` audit-trail marker); Surface 4 = risk-above-appetite commit (line 274) = keep — one-time-override cat-3 (cosmetic cross-ref). Audit found **0 lazy-deferrals** — manage-incident is fundamentally interactive (incident declaration requires user-knowledge inputs); all 4 surfaces are genuine user-authority. Architect + JTBD reviews PASS. Bats: 11 new (companion file `manage-incident-adr-044-contract.bats` with `tdd-review: structural-permitted` marker) + 14 existing assertions green; full itil suite green. Changeset: `@windyroad/itil` patch. **Phase 2 is now 3/3 done.**
- [ ] Phase 3: audit medium-ask SKILLs (review-jobs, analyze-context).
- [ ] Phase 3: audit low-ask SKILLs (~24 surfaces).
- [ ] Phase 4: audit 4 critical hooks (itil-assistant-output-gate, itil-assistant-output-review, manage-problem-enforce-create, voice-tone-eval).
- [ ] Phase 4: sweep remaining 65 hooks (single audit-log entry on this ticket).
- [ ] Phase 5: sweep 10 agents + 37 unaudited ADRs + 16 JTBDs + 12 READMEs.

## Fix Strategy

**Implementation plan**: see `/Users/tomhoward/.claude/plans/noble-cuddling-sutton.md` (drafted 2026-04-27 by Plan agent; risk-scored PASS at 3/3/4 by `wr-risk-scorer:plan`; user-approved 2026-04-27 via `/plan` workflow).

**6 phases** (sequenced for declarative-first + per-surface release cadence):

- **Phase 1 (Anchor, S ~1 hr)**: NEW P136 master ticket + README WSJF row. Doc-only, no changeset.
- **Phase 2 (High-ask SKILL audit, M ~3 hrs across 3 sessions)**: 3 separate per-skill audits + per-skill commits + per-skill `@windyroad/itil` patches drained between each. work-problem (11 calls) → mitigate-incident (8) → manage-incident (7).
- **Phase 3 (Medium + low-ask SKILL audit, M ~3 hrs across 4-6 sessions)**: 26 remaining SKILLs. Group truly zero-ask SKILLs (c4/check, c4/generate, list-incidents, list-problems, reconcile-readme) into single audit-log entry; 4-6 actual edit-bearing commits.
- **Phase 4 (Hook audit, S-M ~2 hrs)**: 4 critical hooks per-hook commits + changesets. Remaining 65 hooks bundled into single audit-log entry.
- **Phase 5 (Sweep, S ~1 hr)**: Agent + ADR + JTBD + README sweep. Bundle no-change-needed entries into single doc-only audit-log commit closing P136.
- **Phase 6 (Bats retrofit)**: NOT in P136 scope — P081 Phase 2 territory. P136 uses `tdd-review: structural-permitted` marker as bridge.

**Per-surface release cadence (R1 from P135 plan, validated)** drains projected release risk to one surface at a time. Each surface change ships its own release; drain before next surface starts.

**Deviation-candidate-only flow** (NOT auto-edit) per ADR-044 spirit. Each per-surface finding rides through ADR-044's 5-option deviation-approval `AskUserQuestion` (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer) at retro end. User can reject; SKILL reverted via `git revert`.

**No CLAUDE.md changes** — settled at P135 plan-approval. Don't re-litigate.

## Dependencies

- **Blocks**: per-session lazy-AskUserQuestion friction continues on un-audited SKILLs until P136 Phases 2-4 land.
- **Blocked by**: (none — Phase 1 can proceed standalone; subsequent phases sequenced per plan).
- **Composes with**: P135 (predecessor — established ADR-044 + amended 4 SKILLs), P132 (inverse-P078 enforcement), P081 (canonical bats retrofit; P136 bridge via `tdd-review: structural-permitted` marker), P130 (orchestrator presence-aware dispatch — same family of agent-discipline gaps), P131 (user-space writes — same family).

## Implementation Plan (inline — durable across sessions)

> Drafted 2026-04-27 by the Plan agent during a `/plan` workflow; risk-scored PASS at 3/3/4 by `wr-risk-scorer:plan`; user-approved 2026-04-27 via `ExitPlanMode`. The plan content lives inline here (mirroring the P081 plan-inline pattern from earlier this session) so it survives any future `/plan` workflow overwriting `~/.claude/plans/noble-cuddling-sutton.md`. Resume in a fresh session by invoking `/wr-itil:work-problem 136`.

### Phase 1 — Anchor (S, ~1 hr) — DONE 2026-04-27 commit `7d80211`

NEW master ticket (this file) + README WSJF row insertion. Doc-only, no changeset, no release.

### Phase 2 — High-ask SKILL audit (M, ~3 hrs across 3 sessions)

3 SKILLs with 5+ AskUserQuestion calls — highest-friction first:

1. `packages/itil/skills/work-problem/SKILL.md` (singular — 11 calls)
2. `packages/itil/skills/mitigate-incident/SKILL.md` (8 calls)
3. `packages/itil/skills/manage-incident/SKILL.md` (7 calls)

**Per-skill loop** (3 separate sessions/commits/releases):

1. Read SKILL.md against the ADR-044 framework-resolution checklist:
   - Each `AskUserQuestion` call classified as (a) framework-resolved → lazy-deferral candidate, (b) one of 6 user-owned categories → keep, (c) ambiguous → deviation-candidate.
2. Surface findings to user via ADR-044 deviation-approval flow. **Do NOT auto-edit.** User approves amend / keep / supersede per call via the 5-option `AskUserQuestion` (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer).
3. Apply approved amendments; behavioural-by-default bats updated; structural-grep tests touched get `tdd-review: structural-permitted` marker per P081.
4. Per-skill changeset: `@windyroad/itil` patch. Drain release before next skill.

### Phase 3 — Medium-ask + low-ask SKILL audit (M, ~3 hrs across 4-6 sessions)

26 remaining unaudited SKILLs. Same per-skill discipline as Phase 2.

- 2 moderate-ask: `review-jobs` (3 calls), `analyze-context` (3 calls).
- 24 low/zero-ask: scattered across architect, c4, connect, itil, jtbd, risk-scorer, style-guide, tdd, voice-tone, wardley packages.
- Group truly zero-ask SKILLs (c4/check, c4/generate, list-incidents, list-problems, reconcile-readme) into a single "audited — no change needed" log entry on this ticket; no commits required for those.
- Estimated 4-6 actual edit-bearing commits across 26 SKILLs.

### Phase 4 — Hook audit (S-M, ~2 hrs)

4 critical ask-emitters first (sequenced):

1. `packages/itil/hooks/itil-assistant-output-gate.sh`
2. `packages/itil/hooks/itil-assistant-output-review.sh`
3. `packages/itil/hooks/manage-problem-enforce-create.sh`
4. `packages/voice-tone/hooks/voice-tone-eval.sh`

Per-hook: read prose for nudges that push the agent toward over-ask in framework-resolved zones; surface deviation-candidates; user approves; amend hook prose only. Per-hook commit + changeset.

Remaining 65 hooks audited as a single sweep entry on this ticket (most are PreToolUse gates with no ask-prose) — bundled no-change-needed audit-log commit.

### Phase 5 — Agent + ADR + JTBD + README sweep (S, ~1 hr)

Lower-risk surfaces. Per-surface: cross-reference ADR-044; if no contradiction, log "audited — no change needed" on this ticket. If contradiction found in a load-bearing ADR (e.g., ADR-022 / ADR-032 / ADR-040 / ADR-042), surface as a separate ADR amendment commit (composes-with-pattern; not bundled with SKILL edits).

Bundle the no-change-needed entries into a single doc-only audit-log commit closing P136.

### Phase 6 — Bats retrofit (NOT in P136 scope)

~248 structural-grep assertions across 141 files are P081 territory. P136 uses the `tdd-review: structural-permitted` marker as the temporary bridge for any bats touched during Phases 2-4; **P081 Phase 2 owns the canonical retrofit**. P136 cross-references P081; closing P136 does NOT require bats retrofit completion.

### Architectural trade-offs (decisions for the implementer)

1. **Per-surface vs bundled releases** — chose per-surface (R1 from P135, validated). Each high-ask SKILL gets its own release; sweep phases bundle no-change entries.
2. **Eager retrofit vs deviation-candidate-only** — chose deviation-candidate-only (ADR-044 spirit). Audit produces evidence; user approves each amendment. Auto-edit would violate the contract P135 just established.
3. **Risk-scoring per-surface vs per-phase** — chose per-surface for high-ask SKILLs (Phase 2) + 4 critical hooks (Phase 4); group low-ask SKILLs into one risk-scoring call (Phase 3 sweep).
4. **Bats during audit vs deferred to P081** — chose deferred + marker bridge. Touching SKILLs whose bats are structural-heavy (manage-incident ~14, work-problem ~22) invalidates greps; the `tdd-review: structural-permitted` marker preserves test-green-as-safety-signal during the bridge window.

### Sequencing

Phase 1 (anchor) → Phase 2 (high-ask SKILLs, sequenced by ask-volume) → Phase 3 (remaining SKILLs) → Phase 4 (hooks) → Phase 5 (sweep). Phase 6 is composes-with-P081, not P136-owned.

### Verification

End-to-end test plan covering all 5 phases:

1. **Phase 1 verification**: P136 master ticket exists; README WSJF table shows P136 row; `bash packages/itil/scripts/reconcile-readme.sh docs/problems` exits 0. ✓ DONE 2026-04-27.
2. **Phase 2 verification per-skill**: invoke the audited skill in a real session; observe no AskUserQuestion fires in framework-resolved zones (per the per-skill amendments); per-skill bats green; @windyroad/itil patch released and visible at `npm view @windyroad/itil version`.
3. **Phase 3 verification**: same per-skill exercise across the 26 surfaces; aggregate "audited" count on P136 reaches 26/26 (4 P135 + 22 zero-or-low-ask covered).
4. **Phase 4 verification per-hook**: trigger each amended hook; observe no over-ask prose surfaces; per-hook bats green.
5. **Phase 5 verification**: each agent / ADR / JTBD / README in scope is logged as "audited — no change needed" or has its amendment commit; P136 audit-log shows 100% coverage.
6. **Cross-phase ROI metric**: Step 2d "Ask Hygiene Pass" lazy-count metric trends down across consecutive retros as Phases 2-4 land.
7. **Anti-regression for the deviation-candidate surface**: every per-skill amendment goes through ADR-044's deviation-approval AskUserQuestion at retro end. If the user rejects an amendment, the SKILL is reverted via `git revert`.
8. **P081 cross-reference**: any bats touched during Phases 2-4 carries the `tdd-review: structural-permitted` marker; P081 Phase 2 retrofit (separate work) eventually replaces these with behavioural form.

### How to resume P136 in a fresh session

Type `/wr-itil:work-problem 136` (singular). The manage-problem flow opens this ticket, reads the inline plan above, and surfaces the next-phase checklist. Phase status is tracked via the `Investigation Tasks` checklist at the top of this ticket — agent updates checkboxes as phases complete.

P136 stays at WSJF 2.25 in the queue; it is **NOT picked up automatically by `/wr-itil:work-problems` AFK loop** because the per-skill audit is user-directed work that needs the deviation-approval AskUserQuestion at retro end, which only fires in the orchestrator's main turn (interactive).

## Related

- **ADR-044** (`docs/decisions/044-decision-delegation-contract.proposed.md`) — the architectural anchor. Captures the 6-class authority taxonomy + framework-mediated surface enumeration + anti-BUFD-for-framework-evolution clause + R6 numeric gate Reassessment Trigger.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 amended in P135 Phase 1.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — commit-grain precedent. Per-surface commits per ADR-014.
- **ADR-022** (`docs/decisions/022-problem-verification-pending.proposed.md`) — lifecycle precedent.
- **ADR-040** (`docs/decisions/040-progressive-disclosure-tier-policy.proposed.md`) — declarative-first precedent (R1 cadence + advisory enforcement matches).
- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — auto-apply with bounded vocabulary precedent (deviation-approval surface inherits the spirit).
- **P135** (`docs/problems/135-decision-delegation-contract-master.open.md`) — predecessor master ticket.
- **P132** (`docs/problems/132-...open.md`) — inverse-P078 over-asks; P132's Phase 4 enforcement hook is gated on R6 (post-P136 measurement).
- **P081** (`docs/problems/081-...open.md`) — canonical bats retrofit. P136 cross-references P081 in Phase 6.
- **P130** (`docs/problems/130-...open.md`) — orchestrator presence-aware dispatch.
- **P131** (`docs/problems/131-...open.md`) — agents write to `.claude/` user space.
- `/Users/tomhoward/.claude/plans/noble-cuddling-sutton.md` — the approved 6-phase implementation plan.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — primary persona served. Suite-wide alignment IS the without-slowing-down outcome.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — primary persona served. AFK iters compound friction across un-aligned SKILLs.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-the-suite-with-new-plugins.proposed.md`) — composes via per-surface SKILL.md edits that ship to adopters.
- **JTBD-201** (audit trail) — composes via Step 2d "Ask Hygiene Pass" lazy-count metric trend across consecutive retros as Phases land.
- 2026-04-27 session evidence: P135 implementation completed; user surfaced the audit gap directly: *"we should also do an audit of all the files (hooks, skills, agents, etc) to make sure they align with the clarified direction and make sure CLAUDE.md and other files don't contradict"*. /plan workflow opened; Plan agent designed 6-phase plan; risk-scorer:plan PASS at 3/3/4; user approved.
