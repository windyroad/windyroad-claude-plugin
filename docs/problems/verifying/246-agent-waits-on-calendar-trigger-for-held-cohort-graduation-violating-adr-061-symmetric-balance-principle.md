# Problem 246: Agent waits on calendar trigger for held-cohort graduation — violates ADR-061 symmetric balance principle

**Status**: Verifying
**Reported**: 2026-05-17
**Root cause confirmed**: 2026-05-18
**Fix released**: 2026-05-18 (`@windyroad/itil@0.33.0`, source commit `229539c`; consumed in version-packages commit `a032ca9` 2026-05-17 22:29:58 UTC, merged via PR #142 / merge commit `e243fc3` 2026-05-18 08:36:11 AEST; current ships at 0.35.2)
**Priority**: 9 (Med) — Impact: 3 (Moderate — held cohorts accumulate beyond their actual evidence-based release-readiness; delays compound; user has to manually intervene to trigger graduation when the framework's own principle says graduate now) × Likelihood: 3 (Likely — fired today on 3-entry P087 cohort; pattern matches I001 / I002 manual-graduation precedent earlier this month)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 9/2 = **4.5** (raw Priority/Effort retained per README display convention; Known Error → Verifying on release per ADR-022; awaiting in-loop verification window — 5 AFK iterations across ≥2 sessions per § Verification (post-release))

## Description

Class-of-behaviour: when held-changeset cohorts in `docs/changesets-holding/` are eligible for graduation per ADR-061 Rule 1 symmetric balance (`release-risk ≤ problem-ticket Priority`) AND no negative evidence has accumulated, the agent waits on the calendar trigger (`≥7-day dogfood`) instead of evaluating actual risk and graduating now.

### Refined framing (post-2026-05-17 user direction)

The deeper defect: **the calendar trigger should not exist as a criterion at all**. The dogfood criterion is "positive evidence shows the surface works as desired" — that's an evidence threshold, not a time threshold. User direction at session 4 wrap: *"Dogfooding makes sense, but it shouldn't be time based, it should be until we are happy that it's working as desired."*

Every existing reinstate-trigger in `docs/changesets-holding/README.md` is phrased as `≥7 days in-repo dogfood with <evidence condition> — review at /wr-itil:work-problems Step 6.5 on or after <date>, OR risk scorer downgrades release residual ≤ 4/25`. The calendar predicate (`≥7 days` / `on or after <date>`) is the load-bearing waste — when the evidence condition is met BEFORE 7 days, the calendar artificially delays graduation; when evidence is NEGATIVE (e.g. P166+P163 hook misfired 5+ times this session), the calendar's expiry would falsely promote graduation. Time tracks nothing relevant.

Correct framing: graduate when **positive evidence shows the surface works as desired** (defined per-surface). Hold while **evidence is missing OR negative**. The risk-scorer's evaluation is the evidence-evaluation surface; if it can't reach a verdict, the answer is "need more evidence", not "wait 7 days".

The "≥7-day dogfood" was originally a heuristic baseline from I001 / I002 manual graduations. It encoded the empirical observation that those particular surfaces took ~7-10 days to accumulate enough evidence to feel safe. That heuristic should NOT become a contract — it confuses "this much time happened" with "evidence accumulated".

Evidence — 2026-05-17 session 4 iter 9 wrap:
- 3-entry P087 atomic-cohort in `docs/changesets-holding/` (Phase 2a + 2b + 3a):
  - Phase 2a held since earlier session (likely 2026-05-16)
  - Phase 2b held since 2026-05-16
  - Phase 3a held just now (iter 9) via ADR-042 Rule 2 auto-remediation when scoring hit 9/9/9 above-appetite
- Auto-remediation rationale (per iter 9 retro): R005 release-coordination drift + R007 user-stated-precondition (Phase 3a depends on Phase 2a/2b released)
- KEY OBSERVATION: if the WHOLE cohort graduates together (atomic-batch per ADR-061 Rule 3b), R007 precondition is satisfied automatically — Phase 3a's dependency on 2a/2b being released is met by atomic release
- KEY OBSERVATION: zero negative signal in Phase 2a + 2b dogfood since hold (days of in-repo source-level exercise; no defect reports)
- Agent's loop-end surface offered "wait for 2026-05-23 OR risk downgrade" as the framework-prescribed default
- User correction (P078 strong-signal): *"Why are we waiting? That seems to go against the principles if you ask me."*

The principle: ADR-061 Rule 1 explicitly says graduate when symmetric balance favors it (release-risk ≤ ticket-Priority). The 7-day floor was a heuristic baseline from I001 / I002 manual graduations — NOT a hard wait condition. When evidence supports earlier graduation, evidence wins over heuristic.

Sibling tickets:
- **P234** (fictional defer rationalization) — different surface (prose-defer in iter outputs); same underlying class (agent treats deferral as default when evidence supports action)
- **P236** (iter queues proceed-vs-defer as direction when framework trigger already fired) — different surface (outstanding_questions queue); same underlying class (agent over-defers framework-resolved decisions)
- **P162** (codify dogfood-graduation criteria) — parent ticket defining the symmetric-balance principle; this ticket captures the agent failing to apply that principle
- **ADR-061** Rule 1 (symmetric balance) — the principle being violated
- **ADR-042** Rule 2 (auto-move-to-holding when above appetite) — the mechanism that placed Phase 3a in holding; correct mechanism but cohort-graduation eligibility check needs to fire ALSO

Distinguishing surface: orchestrator's loop-end Step 2.5 surfacing presents calendar trigger as the primary release option, instead of evaluating actual risk via the just-shipped Phase 2b cohort-aware evaluator (`packages/risk-scorer/scripts/evaluate-graduation.sh`) and presenting the evidence-grounded recommendation.

Preferred fix: orchestrator loop-end Step 2.5 (or Step 6.5 within-appetite drain check) MUST invoke the cohort-aware graduation evaluator against each held cohort. If the evaluator emits `reinstate-from-holding`, the orchestrator graduates AUTOMATICALLY (policy-authorised silent proceed per ADR-013 Rule 5 + ADR-061 Rule 1). The calendar trigger fires ONLY when evaluator cannot reach a verdict (evidence floor not met). NEVER present "wait for calendar" as a primary option when evaluator returns ready-to-graduate.

## Symptoms

- Held cohorts accumulate in `docs/changesets-holding/` past their evidence-based readiness.
- Orchestrator loop-end summary offers "wait for calendar trigger" as an option even when risk-scorer evaluator would graduate.
- User has to manually direct graduation (I001 / I002 precedent + 2026-05-17 incident).
- Risk-scorer's Phase 2b cohort evaluator (just shipped this session, `@windyroad/risk-scorer@0.10.0`) is not consulted at the orchestrator's release-decision points.

## Workaround

User issues direct graduation command. Currently manual.

## Impact Assessment

- **Who is affected**: every orchestrator session that releases work via the held-cohort path. Pattern fires once per cohort accumulation.
- **Frequency**: 3 times in May 2026 alone (I001 2026-05-06, I002 2026-05-11, P087 cohort 2026-05-17).
- **Severity**: Moderate — delays compound; held cohorts grow over time; user has to police the calendar.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Audit orchestrator Step 2.5 / Step 6.5 SKILL.md surfaces for calendar-vs-evaluator decision ordering — completed 2026-05-18 session 6 iter 4; Step 6.5 within-appetite branch is the correct site per ADR-061 Rule 5 verbatim ("within-appetite drain mode per ADR-018 Step 6.5"); no Step 2.5 site needed (architect re-confirmation a0b8cac3672fd9bc2).
- [x] Wire the Phase 2b cohort-aware evaluator into Step 6.5 within-appetite drain check (and/or Step 2.5 loop-end emit) — completed 2026-05-18 session 6 iter 4; `packages/itil/skills/work-problems/SKILL.md` Step 6.5 gained the "Cohort-graduation pre-check" sub-step BEFORE the Drain action; invokes `wr-risk-scorer-evaluate-graduation`; branches per the 3-status taxonomy (`resolved` → auto-graduate per ADR-061 Rule 5 + ADR-013 Rule 5, `vp-blocked` → skip per Rule 2, `halt-no-resolution` → framework-prescribed halt per Rule 1a terminal).
- [x] **Amend ADR-061** to remove calendar-trigger phrasing from reinstate-trigger contracts — criterion is evidence-of-working-as-desired, not elapsed time. Per-surface evidence definitions replace per-surface day counts. — **Reframed (architect verdict a0b8cac3672fd9bc2)**: ADR-061 Rule 4 + Rule 5 are already evidence-based by construction; no ADR amendment needed. Rule 4 explicitly enumerates per-class evidence shapes (gate-fire log entries, detector firings, auto-fix commit log, session-trail entries) per ADR-026 cite + persist + uncertainty grounding. The calendar-rejection framing is implicit in ADR-061's rejection of Option 3 (calendar-time graduation) on decision-maker direction. P246 is a calibration ticket against ADR-061, not a new architectural choice. Status flip `proposed` → `accepted` deferred until ≥ 3 distinct Rule-5 auto-graduations land cleanly (parallels ADR-042's Innovation Window pattern).
- [x] **Sweep `docs/changesets-holding/README.md` reinstate-trigger language** — completed 2026-05-18 session 6 iter 4; Process section step 5 amended to state criterion is evidence-of-working-as-desired, NOT elapsed wall-clock time; calendar predicates explicitly rejected as primary triggers; user direction cited verbatim. **Architect-verdict scope-bound**: per-entry `Currently held` lines authored BEFORE the P246 framing are RETAINED as at-hold-time historical contracts (NOT retroactively rewritten); new entries SHOULD phrase their reinstate criterion as evidence-of-working-as-desired only.
- [x] Create reproduction test — completed 2026-05-18 session 6 iter 4; `packages/itil/skills/work-problems/test/work-problems-step-6-5-cohort-graduation.bats` (39 contract-assertion class fixtures per ADR-037; covers pre-check invocation, 3-status branching, cohort propagation, framework-prescribed halt point, evidence-based criterion, calendar-trigger rejection, user direction citation, policy authorisation, governance gates, audit trail, idempotency, README Process amendment, P246 self-identification).

### Root Cause

**Defective contract clause**: `docs/changesets-holding/README.md` Process section step 5 (pre-P246) framed graduation as a conjunction of "evidence floor met AND within-appetite drain mode" but the orchestrator's Step 6.5 SKILL.md surface did NOT invoke the evaluator. The `wr-risk-scorer-evaluate-graduation` deterministic Rule 1a join + Rule 2 VP carve-out + Rule 3b cohort-grouping pass shipped in Phase 2b BUT was not consulted at the orchestrator's release-decision points. The agent fell back to per-entry calendar-trigger prose (`≥7 days in-repo dogfood ... on or after <date>`) as the de-facto primary trigger because it was the only agent-readable signal at the orchestrator surface.

**Deeper defect (per user refined framing 2026-05-17)**: the calendar trigger should not have existed as a criterion at all. The dogfood criterion is "positive evidence shows the surface works as desired" — that's an evidence threshold, not a time threshold. The `≥7-day` floor was originally a heuristic baseline from I001 / I002 manual graduations (those particular surfaces took ~7-10 days to accumulate enough evidence to feel safe). That heuristic should NOT have become a contract clause; it confused "this much time happened" with "evidence accumulated".

### Fix

`packages/itil/skills/work-problems/SKILL.md` Step 6.5 — insert "Cohort-graduation pre-check (per ADR-061 Rule 5; P246)" sub-step BEFORE the Drain action when the within-appetite-with-releasable-material branch fires AND `docs/changesets-holding/` is non-empty. Pre-check invokes `wr-risk-scorer-evaluate-graduation`, parses each `GRADUATION_CANDIDATE` line, branches per the 3-status taxonomy. `resolved` → `git mv docs/changesets-holding/<basename> .changeset/<basename>` + README "Recently reinstated" audit append + ADR-042 Rule 3 amend (policy-authorised silent proceed per ADR-013 Rule 5 + ADR-061 Rule 5; no `AskUserQuestion` mid-iter). `vp-blocked` → skip per ADR-061 Rule 2 carve-out. `halt-no-resolution` → halt at the new framework-prescribed "Step 6.5 cohort-graduation halt-no-resolution halt" point per ADR-061 Rule 1a terminal. Class=3b cohorts graduate atomically (Rule 3b cohort propagation — entire cohort ships or none does). Governance gates ride the amend per ADR-061 Rule 7; audit trail per Rule 6. The pre-check is idempotent when holding-area is empty AND when no candidates resolve. SKILL.md Mid-loop ask discipline list gains the new halt point; Non-Interactive Decision Making table gains 3 rows (resolved/vp-blocked/halt-no-resolution paths); Mid-loop ask between iters row enumerates the new halt point.

`docs/changesets-holding/README.md` Process step 5 — amended prose explicitly states graduation criterion is **positive evidence that the surface works as desired** (Rule 4 per-class evidence floor), NOT elapsed wall-clock time. Calendar predicates explicitly rejected as primary triggers. User direction cited verbatim. Per-entry `Currently held` lines NOT retroactively rewritten (architect verdict — at-hold-time historical contracts preserved).

`packages/itil/skills/work-problems/test/work-problems-step-6-5-cohort-graduation.bats` — 39 contract-assertion class fixtures per ADR-037 covering the load-bearing prose surfaces. All 39 fixtures pass; iter-2 P250 fixture (24 assertions) preserved.

### Fix Released

Shipped 2026-05-18 in `@windyroad/itil@0.33.0`:

- Source commit: `229539c` "fix(itil): P246 Step 6.5 cohort-graduation pre-check before Drain (evidence-based, not time-based)" (2026-05-18 08:25:08 AEST)
- Changeset removed: `.changeset/wr-itil-p246-step-6-5-cohort-graduation-pre-check.md` (per ADR-022 P143 fold-fix — changeset removal IS the canonical fix-shipped signal)
- Version-packages commit: `a032ca9` (2026-05-17 22:29:58 UTC) — `0.32.3` → `0.33.0`
- Merge PR: #142, merge commit `e243fc3` (2026-05-18 08:36:11 AEST)
- Current cache: `@windyroad/itil@0.35.2` — 4 subsequent release cycles (0.34.0 / 0.35.0 / 0.35.1 / 0.35.2) with zero regression on the Step 6.5 cohort-graduation pre-check surface

**Empirical exercise evidence (in-session this monorepo, 2026-05-18)**: the Step 6.5 cohort-graduation pre-check fired and graduated an atomic-cohort end-to-end. `docs/changesets-holding/README.md` "Recently reinstated" section records both `wr-itil-p170-phase4-p4-1-related-problems-lookup-row.md` and `wr-itil-p170-phase3-p3-1-phase4-p4-2-step-1-5b-jtbd-trace.md` as "Reinstated 2026-05-18 by the orchestrator's new Step 6.5 cohort-graduation pre-check (`wr-risk-scorer-evaluate-graduation` emitted `status=resolved` for the `phase-3-phase-4-end-of-chain-user-verification` cohort)". This exercises:

- Rule 1a deterministic join — evaluator resolved both held basenames to their P170 ticket
- Rule 3b cohort propagation — both atomic-cohort members graduated together
- Rule 5 policy-authorised silent proceed — no `AskUserQuestion` fired mid-iter
- Rule 6 audit-trail append — README "Recently reinstated" section captured both reinstatements with cited evidence
- The held cohort survived 4 subsequent release cycles (0.33.0 → 0.35.2) with no false-positive graduation of the `p166-p163-external-comms-hook-side-sha256.md` entry, which the evaluator correctly held back per the negative evidence floor (P198 sibling ticket records 5+ recurrences of the marker-key-derivation friction — `status=vp-blocked` or evidence-floor-not-met)

Verification window remains in-flight per § Verification (post-release) — 5 AFK iterations across ≥2 sessions of low-risk iters. Recovery path: `/wr-itil:transition-problem 246 known-error` after reverting commit `229539c`.

## Change Log

- 2026-05-17: Captured by /wr-itil:capture-problem at session 4 iter 9 wrap following user correction (P078 strong-signal: *"Why are we waiting? That seems to go against the principles if you ask me."*). Initial framing: agent over-waited on calendar trigger; should invoke risk-evaluator instead.
- 2026-05-17: Refined framing applied post-session-4-wrap per user direction (*"Dogfooding makes sense, but it shouldn't be time based, it should be until we are happy that it's working as desired."*). Calendar trigger reframed as defective contract clause; evidence-of-working-as-desired is the actual criterion.
- 2026-05-18 (session 6 iter 4): Worked via /wr-itil:work-problems AFK loop. Architect + JTBD pre-edit reviews completed (architect ISSUES adopted: drop `no-graduate-evidence-floor` branch, halt-no-resolution → terminal halt not outstanding_questions, no retroactive Currently held rewrite, ADR-061 status stays `proposed`). SKILL.md Step 6.5 amended with Cohort-graduation pre-check sub-step + new framework-prescribed halt point + 3 new Non-Interactive Decision Making table rows. `docs/changesets-holding/README.md` Process step 5 amended (evidence-based, not time-based, with user-direction citation). 39-fixture bats coverage created (all pass). P234, P236, P247 (sibling defer-class-of-behaviour tickets) stay Open — this fix is bounded to the cohort-graduation surface; the broader meta-class fix lives across multiple tickets per their distinct surfaces. Transitioned Open → Known Error (root cause confirmed, fix in source).
- 2026-05-18 (session 7 iter 2): Known Error → Verifying via /wr-itil:work-problems AFK loop. Fold-fix per ADR-022 P143 amendment — changeset `wr-itil-p246-step-6-5-cohort-graduation-pre-check.md` removed in version-packages commit `a032ca9` (2026-05-17 22:29:58 UTC, shipped `@windyroad/itil@0.33.0`), merged via PR #142 / merge commit `e243fc3` (2026-05-18 08:36:11 AEST); current cache `@windyroad/itil@0.35.2` spans 4 subsequent release cycles (0.34.0 / 0.35.0 / 0.35.1 / 0.35.2) with zero regression. Empirical exercise evidence (in-session): Step 6.5 cohort-graduation pre-check fired and graduated `wr-itil-p170-phase4-p4-1-related-problems-lookup-row.md` + `wr-itil-p170-phase3-p3-1-phase4-p4-2-step-1-5b-jtbd-trace.md` atomic-cohort per `wr-risk-scorer-evaluate-graduation` `status=resolved` emission, exercising Rule 1a deterministic join + Rule 3b cohort propagation + Rule 5 silent proceed + Rule 6 audit-trail append end-to-end. Architect + JTBD pre-edit reviews PASS — no new ADR required (ADR-022 P143 fold-fix + ADR-014 single-commit grain + ADR-031 per-state subdir + P186 evidence-first cell shape all honoured). README WSJF Rankings row removed; Verification Queue row inserted at 2026-05-18 same-day-ID-ASC position (after P240, before P250); evidence cell carries `yes — observed: ...` cross-release proof per P186. Recovery path: `/wr-itil:transition-problem 246 known-error` after reverting commit `229539c`.

## Dependencies

- **Blocks**: future held-cohort accumulation will continue to require manual graduation until fixed
- **Blocked by**: none — fix is purely orchestrator-side SKILL.md + evaluator-wire-in
- **Composes with**: P162 (parent principle), ADR-061 Rule 1, ADR-042 Rule 2, ADR-013 Rule 5

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P162** — parent: codify dogfood-graduation criteria
- **P234** / **P236** — sibling defer-class-of-behaviour tickets
- **ADR-061** Rule 1 — symmetric balance principle
- **ADR-042** Rule 2 — move-to-holding mechanism
- **ADR-013** Rule 5 — policy-authorised silent proceed
