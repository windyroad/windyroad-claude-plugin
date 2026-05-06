# Problem 162: Codify dogfood-graduation criteria for held changesets — symmetric risk assessment (release-risk vs delay-risk) drives the reinstate decision, not arbitrary calendar guards

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 12 (High) — Impact: Significant (3) x Likelihood: Almost certain (4)
**Effort**: M — new ADR (sibling to ADR-042) defining the graduation contract + risk-scorer extension to compute counterfactual delay-risk + behavioural bats covering the counterfactual scoring path + amendment to docs/changesets-holding/README.md "Process" section + retroactive application to currently-held P085, P064, P159 to establish baseline graduation evidence. **Bound tightened 2026-05-04**: delay-risk equates 1:1 with the held changeset's underlying problem-ticket Priority (Impact × Likelihood already computed per RISK-POLICY.md), so the Phase 2 risk-scorer extension is a lookup (`changeset → problem ID → existing Priority`), NOT a new evidence-collection pipeline. The L-growth-risk via `.afk-run-state/dogfood-evidence.jsonl` + windowed metrics is closed. Firmly M.

**WSJF**: (12 × 1.0) / 2 = **6.0**
**Type**: technical

> Surfaced 2026-05-04 by user direction at end of `/wr-itil:work-problems` AFK loop iter 7 surfacing pass — verbatim: *"I love it. This is a really good pattern - dog food here and when robust, include in the release - we should make that a standard going forward and have a robust process for it, so we are rigourous with the application of the process. 1-2 weeks is arbritrarty and too long. What are the concrete signals that will tell us when it's ready to be included in the published packages?"* and *"Definitly risk-scorer related - basically, we would ask 'what is the release risk (along with all the other queued changes) if we added it to the release now?' But we need to think about when is the right time to ask. Also, we need to consider the value in releasing. We should do a counterfactual risk assessment - 'what is the risk of delaying the release of this longer?' i.e. what are the risks users are facing without this new feature"*.

## Description

ADR-042 Rule 2 establishes the move-to-holding remediation: when cumulative pipeline residual exceeds appetite (≥ 5/25), the orchestrator can `git mv` a changeset from `.changeset/` to `docs/changesets-holding/` to drop release risk while preserving the underlying fix commit. The mechanism works — three changesets currently held (`wr-itil-p085-assistant-output-gate.md`, `wr-risk-scorer-p064-external-comms-gate.md`, `wr-retrospective-p159-readme-jtbd-currency-hook.md`), all load-bearing-from-the-start hook surfaces awaiting in-repo dogfood evidence before user-facing release.

What's missing: **the reinstate-side contract**. The README's "Currently held" entries each name a vague "reinstate trigger" — typically "user signals comfort with hook behaviour OR scorer downgrades residual below appetite after dogfood observation". This is unmeasurable in practice:

1. **"User signals comfort"** is human-judgment with no observable evidence shape. The user has no way to know when the dogfood window is sufficient — they'd be guessing. Calendar-time windows (e.g. "hold 7-14 days") were explicitly rejected by the user as *"arbitrary and too long"*.

2. **"Scorer downgrades residual below appetite"** is closer, but the current scorer doesn't have any input that would change its mind. It scores the SAME pipeline state every time — held changesets stay held forever unless something else changes the residual.

The user's direction reframes the graduation question as a **symmetric risk balance** rather than a one-sided release-risk threshold:

- **Release risk** (current): "what is the risk of shipping the held changeset to npm now?" — the existing scorer dimension. Driven by load-bearing surfaces, bats coverage, blast radius, prior incidents.
- **Delay risk** (proposed addition): "what is the risk of NOT shipping this fix to users right now?" — currently zero in the model, which is wrong.

**Key insight (2026-05-04)**: we don't need to invent counterfactual delay-risk scoring — **it already exists, on every problem ticket, as the Priority field**. Every held changeset is the fix for a problem ticket (P085 / P064 / P159 are the live cases). Every problem ticket has a calculated `Priority = Impact × Likelihood` per RISK-POLICY.md — and that Priority IS the cost-of-not-having-the-fix. Impact is "what's the worst business consequence if the problem occurs"; Likelihood is "how likely is it to affect users in the current codebase". Both are direct measures of delay-risk. The asymmetry the project carries today is structural — we *compute* problem Priority for ranking dev-work via WSJF, then *throw it away* when the same fix is held in `docs/changesets-holding/`. The same number that justifies prioritising the fix is the number that justifies releasing the fix.

The reinstate-criterion becomes: **"reinstate when release-risk ≤ problem-ticket Priority"** — the same balance ADR-042 applies on the release-side, applied symmetrically against the score we already have. As dogfood evidence accumulates (more commits without false-positive, more auto-fix invocations succeeding, no unrecovered errors), release-risk decays. The problem-ticket Priority stays constant (or climbs if Likelihood re-rates upward as more users hit the gap — handled by the existing `/wr-itil:review-problems` re-rate pass). Eventually release-risk drops below Priority. That's the graduation.

## Symptoms

- Three changesets held in `docs/changesets-holding/` (P085 since 2026-04-24, P064 since 2026-04-26, P159 since 2026-05-04). No formalized exit criteria for any of them. P085 + P064 are 8-10 days old with no visible reinstate progress despite presumably accumulated dogfood evidence in the contributor's local repo.
- The orchestrator's Step 6.5 risk scoring re-fires on every iter but doesn't read accumulated dogfood evidence — held changesets stay held with no progressive signal.
- The user must remember to manually reinstate by `git mv`'ing a changeset back to `.changeset/` and pushing — a step that has no clear trigger and no documented "this is the time" indicator.
- ADR-042's Rule 2 is monotonic in one direction (stuff-flows-to-holding-when-above-appetite) but has no codified flow back (stuff-leaves-holding-when-evidence-justifies). The vocabulary is open per Rule 2a; the reinstate vocabulary is empty.
- New "load-bearing-from-the-start" surfaces (this loop's P159 hook is the third such pattern after P085 and P064) will keep accumulating in holding without a graduation contract — by month 6, the holding directory may have N entries with no clear reinstate path.

## Workaround

Manual reinstate via `git mv docs/changesets-holding/<name>.md .changeset/` + push. User must remember to do this; no agent reminder; no observable signal saying "now is the right time".

## Impact Assessment

- **Who is affected**: Plugin-developer persona (JTBD-101) authoring load-bearing surfaces — they pay the upfront move-to-holding cost expecting eventual release; without graduation, the surface stays effectively unreleased indefinitely. Plugin-user persona (JTBD-302) affected indirectly — features land in main but never reach npm where adopters consume them.
- **Frequency**: Every load-bearing-from-the-start surface (currently 3 known: P085 / P064 / P159). Each future drift-detector / commit-time hook / risk-leak gate is a candidate. Conservative forecast: 1-3 new holds per quarter.
- **Severity**: Significant (3) — features developed and dogfooded but not released = user-facing value is invisible. Not catastrophic (the fix exists in source, just not in published versions); not negligible (the entire point of the plugin model is publish-via-npm).
- **Likelihood**: Almost certain (4) — every load-bearing surface follows the move-to-holding pattern (verified by ADR-042 Rule 2 application across 3 distinct surfaces); without graduation criteria, every one will accumulate.

## Root Cause Analysis

ADR-042 was authored to address P103 (orchestrator escalated resolved release decisions instead of auto-applying) and P104 (partial-progress painted release queue into a corner). Both root causes are about the **inflow** to holding — what should land in `.changeset/` vs `docs/changesets-holding/`. The ADR's Rule 7 blesses the holding location as the authoritative mechanism but does not pin **outflow** criteria. The Reassessment criterion explicitly mentions "above-appetite resolution" as the trigger but not below-threshold reinstate.

This is the inverse-failure-mode of the original problem: ADR-042 made the inflow decision tractable; the symmetric outflow decision was not yet load-bearing in 2026-04-23 because no surface had been held. Now three surfaces have been held over an 8-day window, the symmetric question is load-bearing, and the contract gap is visible.

The deeper observation (per the user's verbatim framing): **risk assessment in the project today is asymmetric**. We score the risk of doing-things (commit / push / release) but not the risk of NOT-doing-things (delay / defer / hold). This asymmetry is fine when defaults are "do" and the question is "should we hold?" — but inverts when defaults are "hold" and the question is "should we ship?". The graduation contract needs the symmetric counterfactual scoring because it asks the inverse question.

**However** (2026-05-04 refinement): the symmetric score is not missing — it exists on the problem ticket as Priority. The structural gap is the *connection* between the held changeset and its originating problem-ticket Priority, not the *invention* of a new score. Every changeset filename (e.g. `wr-itil-p085-assistant-output-gate.md`) already carries the problem ID by convention. The risk-scorer extension is therefore a join operation (`changeset filename → problem ID → ticket file → Priority field`), not a new evidence pipeline. This collapses Phase 2's complexity by an order of magnitude.

### Investigation Tasks

- [ ] Architect review on the proposed ADR shape — sibling ADR vs ADR-042 amendment; per-class graduation matrix; counterfactual delay-risk framework grounding.
- [ ] JTBD review on the persona-fit — JTBD-006 + JTBD-101 + JTBD-302 alignment.
- [ ] Phase 1 — Draft + land the new ADR.
- [ ] Phase 2 — Risk-scorer extension implementing counterfactual scoring (separate iter).
- [ ] Phase 3 — Retroactive application to P085 + P064 + P159 (separate iter).
- [ ] Phase 4 — docs/changesets-holding/README.md Process amendment (separate iter).

## Fix Strategy

**Phase 1 (next interactive iter)**: New ADR — `docs/decisions/<NNN>-dogfood-graduation-criteria.proposed.md`. Sibling to ADR-042. Codifies:

1. **The graduation question**: "is release-risk ≤ problem-ticket Priority for this held changeset?"
2. **Release-risk computation**: existing ADR-042 Rule 2 / RISK-POLICY.md scoring against current pipeline state with the held changeset hypothetically reinstated.
3. **Delay-risk computation = problem-ticket Priority lookup** (the 2026-05-04 insight). For each held changeset:
   - **Resolve the originating problem ticket** via the changeset filename convention (`<package>-p<NNN>-<slug>.md` → ticket ID `P<NNN>`). When the convention is ambiguous or absent, the ADR pins a fallback (changeset body grep for `P\d+` references; halt-and-prompt if still unresolved).
   - **Read the ticket's `Priority` field** (Impact × Likelihood, already computed and re-rated by `/wr-itil:review-problems`). That number IS delay-risk. No new evidence pipeline; no calendar-time accumulators; no separate dimension.
   - **Multi-ticket changesets**: a changeset that references multiple problem tickets uses `max(Priority)` across the referenced set (the most-painful-to-defer wins).
4. **The reinstate trigger**: "release-risk ≤ problem-ticket Priority" → orchestrator's Step 6.5 emits a `RISK_REMEDIATIONS:` entry with `reinstate-from-holding` action class (open-vocabulary per ADR-042 Rule 2a). Agent reads + applies.
5. **Optional dogfood-evidence augmentation**: a baseline-evidence floor (e.g. ≥ N firings of the gate without false-positive) MAY gate the graduation, but the floor is a *prerequisite for evaluating graduation at all*, not a *score input*. The score itself is the symmetric pair (release-risk, problem-ticket Priority). Floor exists to prevent reinstating before the dogfood window has produced enough observation; it does NOT add a new dimension to the score.
6. **When to ask**: Step 6.5 evaluates graduation only when (a) the held changeset's hold-window has produced the baseline evidence floor AND (b) the orchestrator is in within-appetite drain mode (i.e. would drain anyway). Avoids running graduation queries every iter when nothing else is shipping.
7. **Per-class graduation matrices**: PreToolUse:Bash gates / UserPromptSubmit detectors / commit-hook-with-auto-fix surfaces / SessionStart additionalContext hooks each have different baseline evidence requirements (the floor in #5). The score itself stays uniform across classes — release-risk vs problem-ticket Priority. Only the *floor* is class-specific.

**Phase 2 (separate iter)**: Risk-scorer extension implementing the counterfactual scoring path. **Now a join, not an evidence pipeline**: read held-changeset filename → resolve problem ID → read `docs/problems/<NNN>-*.<status>.md` → extract `Priority` field → compare against current release-risk score. Emits `reinstate-from-holding` remediation when `release-risk ≤ Priority` AND the class-specific evidence floor is met. Behavioural bats covering: (a) release-risk > Priority → no remediation; (b) release-risk ≤ Priority + floor met → remediation emitted; (c) ambiguous/missing problem reference in changeset → halt-with-prompt; (d) multi-ticket changeset uses `max(Priority)`; (e) Priority climbs (Likelihood re-rated up by `/wr-itil:review-problems`) → graduation triggers without release-risk decay.

**Phase 3 (separate iter)**: Retroactive application to P085 + P064 + P159 — for each held changeset, look up the originating problem ticket's current Priority, score release-risk with the changeset hypothetically reinstated, emit graduation verdict. Establishes graduation-criteria baseline by exercising the join on real surfaces. Closes the open question of "are P085 / P064 / P159 ready to ship now?"

**Phase 4 (eventual)**: Amendment to `docs/changesets-holding/README.md` "Process" section adding the graduation flow as an explicit step. Move-to-holding stays open-ended; graduation becomes documented and observable.

## Dependencies

- **Blocks**: (none — until graduation criteria exist, P085 / P064 / P159 stay held with no clear reinstate path; future load-bearing surfaces will accumulate. No direct ticket-level block, but the value of move-to-holding is reduced without the symmetric exit.)
- **Blocked by**: (none — Phase 1 ADR is self-contained; risk-scorer extension in Phase 2 composes with existing scorer surface, not blocked by any other ticket.)
- **Composes with**: P076 (WSJF transitive-dependency rule — delay-risk should account for dependent work), P033 (risk register — delay-risk is itself a standing-risk class for adopters; composes with R005 + the risk-register surface), P085 (held changeset — first instance of pattern this ticket codifies), P064 (held changeset — second instance), P159 (held changeset — third instance, drove this ticket's surfacing)

## Related

- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — parent decision; this ticket is the symmetric outflow contract.
- **`docs/changesets-holding/`** — three currently-held changesets (P085 / P064 / P159) all need graduation criteria.
- **P085** (`docs/problems/085-assistant-asks-when-obvious-and-uses-prose-instead-of-askuserquestion.verifying.md`) — held since 2026-04-24; first instance of the load-bearing-from-the-start hold pattern.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.verifying.md`) — held since 2026-04-26; second instance.
- **P159** (`docs/problems/159-jtbd-currency-detector-should-be-load-bearing-commit-hook-with-auto-fix-not-retro-advisory.verifying.md`) — held 2026-05-04 (this loop); third instance, drove this ticket's surfacing.
- **R005** (`docs/risks/R005-readme-skill-md-prose-drifts-from-runtime-behaviour.active.md`) — standing risk register entry; delay-risk concept this ticket introduces aligns conceptually with the standing-risk surface.
- **ADR-026** (evidence-grounded scoring — counterfactual delay-risk needs to ground in observable evidence, not speculation).
- **ADR-013 Rule 5** (policy-authorised silent-action — graduation-driven reinstate is policy-authorised once criteria are met; no per-reinstate AskUserQuestion needed).
- **JTBD-006** (Progress the Backlog While I'm Away) — orchestrator should auto-graduate held changesets without user intervention when criteria are met.
- **JTBD-101** (Extend the Suite with New Plugins) — plugin-developer pays move-to-holding cost expecting graduation; without criteria the cost has unclear payoff.
- **JTBD-302** (Trust README describes installed behaviour) — plugin-user persona indirectly affected; held features don't reach adopters until graduation.

## Change Log

- **2026-05-04** — Opened by `/wr-itil:manage-problem` invocation from orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 surfacing pass. Skeleton ticket — chosen signal shape (risk-scorer-driven counterfactual) + chosen home (new ADR) + Investigation Tasks deferred to architect/JTBD review at next interactive session. Initial duplicate-check: no existing tickets cover graduation criteria (P103/P104 are inflow-side, closed). Captured via manage-problem (P119) instead of capture-problem because the just-shipped capture-problem skill (P155 commit 86e99e5, released as @windyroad/itil@0.25.0) is not yet in the local plugin cache mid-session — sibling-finding flagged in iter 4 outstanding_questions.
- **2026-05-04** — Updated by user direction: *"the coutner factual risk score is the already calcualted risk score (AKA Priority) of the problem"*. Reframes Phase 2 from "new evidence-collection pipeline" to "join over existing data" — counterfactual delay-risk = Priority field on the originating problem ticket, looked up via changeset filename convention (`<package>-p<NNN>-<slug>.md`). Effort bound tightened (M-could-grow-to-L → firmly M; the L-growth path via `.afk-run-state/dogfood-evidence.jsonl` is closed). Description / Root Cause Analysis / Fix Strategy Phases 1-3 rewritten to reflect the symmetric-score-already-exists insight. Dogfood-evidence floor preserved as a *prerequisite for evaluating graduation* (anti-too-early gate), not as a score input. Multi-ticket changeset handling pinned: `max(Priority)`. WSJF unchanged at 6.0; ranking-bearing fields (Priority / Effort / WSJF) unchanged in bucket terms, so README.md refresh per P094 conditional-update trigger does not fire.
- **2026-05-06** — Linked from incident I001 (`docs/incidents/I001-unreleased-changeset-queue-violates-lean-wip-and-raises-cumulative-release-risk.restored.md`). Phase 3 (retroactive application to P085 + P064 + P159) executed manually as the I001 mitigation: graduated all three orthogonal-gate holds back to `.changeset/` and shipped to npm (`@windyroad/itil@0.26.0`, `@windyroad/retrospective@0.18.0`, `@windyroad/risk-scorer@0.7.0`). Empirical inputs from this manual exercise refine the codification scope: (a) the **graduation-criteria-by-class** distinction is real — orthogonal-gate holds (independent gating criteria, no shared dogfood-evidence requirements) graduate independently of atomic-cohort holds (P170 RFC framework, ADR-060 finding 12 atomic-graduation contract). Fix Strategy should distinguish these two graduation classes explicitly. (b) **User-comfort-signal as graduation trigger** is empirically valid — all three holds reinstated cleanly with no observed false-positives in the post-graduation `push:watch` + `release:watch` drain. Dogfood-window ages at graduation: P085 12 days, P064 10 days, P159 2 days. Suggests dogfood-window length is NOT a hard floor — when no false-positive evidence accumulates, scorer's inherent risk reduction can fire earlier. (c) Architect advisory at I001 declaration: consider amending ADR-042 Rule 6 to encode "orthogonal-gate holds graduate independently of atomic-cohort holds" as a Rule 7 sub-clause. JTBD anchoring should add JTBD-006 (queue-drain) + JTBD-001 (change-set-level governance) to existing JTBD-101 / JTBD-302 anchors. The I001 manual exercise is the empirical baseline P162 codification needed to pin its design — Phase 1 ADR can now ground in observable evidence per ADR-026 evidence-grounding.
