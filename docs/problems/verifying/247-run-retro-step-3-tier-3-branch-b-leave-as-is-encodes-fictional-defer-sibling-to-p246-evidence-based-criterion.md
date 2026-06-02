# Problem 247: run-retro Step 3 Tier 3 Branch B "leave-as-is" encodes fictional defer — sibling to P246 evidence-based criterion

**Status**: Verifying
**Reported**: 2026-05-17
**Root cause confirmed**: 2026-05-18
**Fix released**: 2026-05-18 (`@windyroad/retrospective@0.19.0`, source commit `b22e006`; consumed in version-packages commit `1ef3157` 2026-05-17 23:01:05 UTC, merged via PR #143 / merge commit `10aecdf` 2026-05-18 09:05:28 AEST; current ships at 0.20.2)
**Priority**: 9 (Med) — Impact: 3 (Moderate — briefing topic files accumulate past Tier 3 thresholds; each retro defers ratherthan rotating; the deferred rotations have no scheduled-future-surface; same fictional-defer class as P234 / P145 / P246 at a different SKILL surface) × Likelihood: 3 (Likely — fired today on session 4 wrap retro for 14 OVER files; will fire on EVERY future retro until SKILL contract is amended)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 9/2 = **4.5** (raw Priority/Effort retained per README display convention; Known Error → Verifying on release per ADR-022; Phase 1 ships in 0.19.0; awaiting in-loop verification window — 5 AFK iterations across ≥2 sessions per § Verification (post-release); Phase 2 rotation work remains deferred with this ticket as scheduled-future-surface per P179)

## Description

Class-of-behaviour: when `/wr-retrospective:run-retro` Step 3 Tier 3 budget pass detects topic files OVER threshold but with ratio < 2.0x (Branch B), the contract permits "leave-as-is" as an option. The agent picks "leave-as-is" reflexively (Branch B default) and records `Decision: defer (Branch B)` in the retro summary. **The defer has no scheduled-future-surface** — "next retro will pick it up when more signal accumulates" is the same fictional defer that P246 captures for held-cohort graduation.

The SKILL contract's Branch B is itself a defective contract clause (sibling to ADR-061's calendar-trigger predicates that P246 flags). Both encode "wait for more time/signal" without a concrete trigger condition.

Evidence — 2026-05-17 session 4 wrap retro:
- 14 topic files detected OVER threshold (5120 bytes):
  - 12 in Branch B (1.0x-2.0x range)
  - 2 within 0.05x of MUST_SPLIT threshold (hooks-and-gates-archive.md 1.96x; releases-and-ci-archive.md 1.94x)
- Agent's retro summary marked ALL 14 as `defer (Branch B)` without:
  - Evaluating whether sub-topic boundaries exist (Branch B option 1)
  - Evaluating whether date stratification exists (Branch B option 2)
  - Evaluating whether ≥3 noise-classified entries surfaced this retro per file (Branch B option 3)
- User correction: *"The 14 files are over the limit, but you are deferring splitting them. Why? When are you hoping they will get dealt with?"*
- The "leave-as-is" option's contract semantics: *"record the OVER state in the Step 5 summary; no action this retro. Picks up next retro when more signal accumulates."* — but next retro isn't scheduled; the "more signal" condition is undefined.

Sibling tickets:
- **P246** — agent waits on calendar trigger for held-cohort graduation; same class at the held-changeset surface
- **P234** — fictional defer rationalization (prose-defer surface)
- **P145** — recurring-defer at Tier 3 budget rotation surface specifically (this ticket generalizes)
- **P148** — Stage 1 ticketing fictional-defer at Step 4b Stage 1 surface
- **P179** — phases are fine IF captured with scheduled-future-surface

Distinguishing surface: run-retro Step 3 Tier 3 Branch B "leave-as-is" option. The Branch A force-action path (ratio ≥ 2.0x) is correct — that's the evidence threshold. Branch B's defer-permitted should be either:
(a) eliminated entirely — if OVER, rotate now via the best-fit option (subtopic / date / trim-noise); never leave-as-is
(b) tightened to require explicit per-file justification when leave-as-is fires (e.g. "no subtopic boundary AND no date stratification AND no noise entries — file content is fundamentally dense and cannot rotate"); record the justification per-file in the retro summary

Preferred fix: option (a). Per the P246 principle (evidence-based criterion, not heuristic), if a file is OVER threshold there IS evidence to act on; "no action" requires positive evidence that none of the rotation options apply, which is itself a per-file evaluation that's mechanical and AFK-safe.

## Symptoms

- Retro summaries show `defer (Branch B)` for files OVER threshold without per-file justification.
- Topic files accumulate past 2.0x threshold before forced action via Branch A — the lag time is wasted potential, not safety margin.
- Each retro re-defers the same files; the "more signal" condition for "next retro" is never explicitly evaluated.
- Sibling P145 already documented "recurring defer of Tier 3 rotation at retros 2026-05-15 + 2026-05-17 morning" — the pattern is RECURRENT, evidence-attested, and the SKILL contract still encodes it as the default.

## Workaround

User catches each retro's defer + manually directs rotation. Currently manual (the 2026-05-17 session 4 wrap retro is the worked example — user's "When are you hoping they will get dealt with?" surfaced the gap).

## Impact Assessment

- **Who is affected**: every retro that touches topic files past threshold. Frequency: every retro that runs (the budget script always emits OVER lines for accumulated content).
- **Frequency**: today's retro has 14 OVER files; every prior retro since the briefing tree was split (~2026-04-22) probably had at least 1-3 deferred files per cycle.
- **Severity**: Moderate. Files accumulate past 2.0x before forced action; user has to police the defer.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems (re-rated at WSJF 4.5 pre-iter; effort re-rated as S after architect-confirmed option A scope)
- [x] **Amend `/wr-retrospective:run-retro` Step 3 Tier 3 SKILL.md** — option (a) shipped at this iter (eliminate "leave-as-is"; fall-through becomes split-by-date safe default mirroring Branch A precedent)
- [x] Create reproduction test — `packages/retrospective/skills/run-retro/test/run-retro-step-3-tier-3-branch-b-evidence-based.bats` (11 assertions, all passing; behavioural input-signal fixtures + narrow SKILL-prose backstops per P081)
- [ ] **Phase 2 — Rotate the 14 OVER files** currently in `docs/briefing/` per the new evidence-based criterion. Deferred to a separate iter (scope-bound per architect verdict 2026-05-18 — keeps the contract-fix commit clean per ADR-014 grain; rotation work is mechanical fall-through to split-by-date under the new contract). Phase 2 iter will: (a) run `check-briefing-budgets.sh` to enumerate the current OVER set; (b) apply Branch B rotation per file (split-by-subtopic / split-by-date / trim-noise with split-by-date safe-default fall-through); (c) commit per ADR-014 grain as `docs(briefing): rotate OVER files per evidence-based criterion (P247 Phase 2)`. This ticket IS the scheduled-future-surface for the Phase 2 rotation work per P179 carve-out — the ticket stays Known Error until Phase 2 ships, then transitions to Verifying.
- [ ] **Phase 3 — Audit other run-retro Step contracts** for similar "leave-as-is" / "defer to next retro" patterns (Step 1.5 Tier 1 promotion, Step 2b detection skipping, Step 4a verification-pending leaving-alone). Separate ticket if any are found.

## Fix

**Iter (2026-05-18, /wr-itil:work-problems orchestrator iter 5)**: amended `packages/retrospective/skills/run-retro/SKILL.md` Step 3 Tier 3 Branch B (lines 334-340) to eliminate the "leave-as-is" fall-through. New contract:

- Branch B always rotates — "wait for more signal to accumulate" is named as the fictional-defer anti-pattern P247 closes.
- The three concrete triggers (subtopic / date / ≥3 noise entries) remain; the fall-through when none fire becomes **split-by-date (safe default)** mirroring Branch A's existing precedent ("zero false-split risk").
- The trim-noise branch tightened: if trim alone brings the file below threshold, record as the rotation action; if still OVER, fall through to split-by-date in the same retro turn — do NOT defer.
- ADR-013 Rule 5 + ADR-044 framework-mediated surface citations added inline so the silent-rotation discipline is discoverable from Branch B prose without cross-referencing.

**User direction cited verbatim** in SKILL.md prose: *"The 14 files are over the limit, but you are deferring splitting them. Why? When are you hoping they will get dealt with?"* (2026-05-17 session 4 wrap retro).

**Sibling-class linkage**: Fix mirrors P246 (commit 229539c, cohort-graduation surface) — same fictional-defer class, different SKILL surface, same evidence-based principle (ADR-061 Rule 1 symmetric balance — evidence-based, not time-based).

**Bounded scope**: this iter's commit covers ONLY the SKILL contract amendment + bats fixture + ticket lifecycle. The Phase 2 rotation work for the 14 currently-OVER files is deferred to a separate iter per ADR-014 commit grain (architect verdict 2026-05-18). This ticket stays Known Error until Phase 2 ships.

**Tests**: `npx bats packages/retrospective/skills/run-retro/test/run-retro-step-3-tier-3-branch-b-evidence-based.bats` — 11/11 pass. `npx bats packages/retrospective/scripts/test/check-briefing-budgets.bats` — 20/20 pass (input-signal layer unchanged).

## Fix Released

Shipped 2026-05-18 in `@windyroad/retrospective@0.19.0`:

- Source commit: `b22e006` "fix(retro): P247 Step 3 Tier 3 Branch B eliminate 'leave-as-is' — evidence-based rotation (closes Phase 1)" (2026-05-18)
- Changeset removed: `.changeset/retro-p247-step-3-tier-3-branch-b-evidence-based.md` (per ADR-022 P143 fold-fix — changeset removal IS the canonical fix-shipped signal)
- Version-packages commit: `1ef3157` (2026-05-17 23:01:05 UTC) — `0.18.2` → `0.19.0`
- Merge PR: #143, merge commit `10aecdf` (2026-05-18 09:05:28 AEST)
- Current cache: `@windyroad/retrospective@0.20.2` — 3 subsequent release cycles (0.20.0 / 0.20.1 / 0.20.2) with zero regression on the Step 3 Tier 3 Branch B evidence-based rotation surface

**Phase 1 scope (shipped)**: SKILL.md contract amendment + behavioural+structural bats fixture + ticket lifecycle Open → Known Error.

**Phase 2 scope (deferred — this ticket IS the scheduled-future-surface per P179)**: rotate the 14 currently-OVER topic files in `docs/briefing/` per the new evidence-based criterion (split-by-subtopic / split-by-date / trim-noise with split-by-date safe-default fall-through). Phase 2 iter will commit per ADR-014 grain as `docs(briefing): rotate OVER files per evidence-based criterion (P247 Phase 2)` and transition this ticket Verifying → Closed after the rotation work lands AND the verification window completes. The K → V transition is gated on Phase 1 alone because Phase 1 is a self-contained shipped slice; the broader meta-class fix (Phase 2 + P234 + P145 + P148 + P246 across distinct SKILL surfaces) lives across multiple tickets per their distinct surfaces — same scope-bounding shape exercised in P246's K → V transition this session.

**Sibling-class linkage**: Fix mirrors P246 (commit `229539c`, `@windyroad/itil@0.33.0`, K → V earlier this session) — same fictional-defer class, different SKILL surface, same evidence-based principle (ADR-061 Rule 1 symmetric balance — evidence-based, not time-based). The K → V transition shape (release-vehicle citation, Phase 2 deferral via P179 SFS, single-commit grain per ADR-014, README Verification Queue insert per P186 evidence-cell shape) is identical to P246's transition pattern verified in iter-2 of this session.

Verification window remains in-flight per § Verification (post-release) — 5 AFK iterations across ≥2 sessions of low-risk iters. Recovery path: `/wr-itil:transition-problem 247 known-error` after reverting commit `b22e006`.

## Change Log

- **2026-05-17** — Captured during session 4 wrap retro (P078 strong-signal user correction). Sibling-class to P246 at Tier 3 Branch B surface.
- **2026-05-18** — Iter 5 of `/wr-itil:work-problems` AFK loop: architect-confirmed option A (eliminate "leave-as-is"; fall-through = split-by-date safe default). JTBD review PASS (JTBD-001 friction-removal, JTBD-006 AFK-safe-default, JTBD-101 reusable pattern). SKILL.md amended; behavioural+structural bats fixture (11 assertions) added; transitioned Open → Known Error. Phase 2 (14-file rotation) deferred to separate iter.
- **2026-05-18** (session 7 iter 3): Known Error → Verifying via `/wr-itil:work-problems` AFK loop. Fold-fix per ADR-022 P143 amendment — changeset `retro-p247-step-3-tier-3-branch-b-evidence-based.md` removed in version-packages commit `1ef3157` (2026-05-17 23:01:05 UTC, shipped `@windyroad/retrospective@0.19.0`), merged via PR #143 / merge commit `10aecdf` (2026-05-18 09:05:28 AEST); current cache `@windyroad/retrospective@0.20.2` spans 3 subsequent release cycles (0.20.0 / 0.20.1 / 0.20.2) with zero regression on the Branch B evidence-based rotation surface. Architect + JTBD pre-edit reviews PASS — no new ADR required (ADR-022 P143 fold-fix + ADR-014 single-commit grain + ADR-031 per-state subdir + P186 evidence-first cell shape + ADR-061 Rule 1 evidence-based Phase 2 deferral via P179 SFS all honoured). README Known Error Rankings row removed; Verification Queue row inserted at 2026-05-18 same-day-ID-ASC position (after P246, before P250); evidence cell carries P186-conformant default. Recovery path: `/wr-itil:transition-problem 247 known-error` after reverting commit `b22e006`.

## Dependencies

- **Blocks**: every future retro will continue to over-defer until fixed
- **Blocked by**: none — fix is purely SKILL.md edit + per-Branch-B-option mechanical evaluation
- **Composes with**: P246 (parent class principle), P234 (fictional defer parent), P145 (Tier 3 surface predecessor — should fold P145 into this ticket or supersede)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P246** — sibling class at held-cohort graduation surface (calendar trigger vs evidence)
- **P234** — parent class (fictional defer rationalization)
- **P145** — predecessor ticket at this exact surface (Tier 3 recurring defer) — likely fold this ticket into P145 OR supersede P145
- **P148** — sibling class at Step 4b Stage 1 (deferring observations to Tickets Deferred section without skill_unavailable cause)
- **P179** — phases are fine IF scheduled-future-surface named (this ticket IS the SFS for the 14-file rotation work)
- **ADR-061** Rule 1 — symmetric balance principle (evidence-based, not time-based)
- **ADR-013** Rule 5 — policy-authorised silent proceed (Branch A correctly uses this; Branch B should too when evidence supports rotation)
