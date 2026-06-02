# Problem 194: ADRs accumulate forward-chronology evidence inline (Phase 2 dogfood evidence, amendment history, cross-iter cross-references) — `decisions` bucket dominates context at 41% / 1.3 MiB

**Status**: Closed
**Reported**: 2026-05-15
**Closed**: 2026-05-31
**Priority**: 6 (Med) — Impact: 3 (Moderate — context-bucket dominance compounds session-cost across all consumers) x Likelihood: 2 (Possible — pattern emerges as the suite matures) (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: L (deferred — re-rate at next /wr-itil:review-problems)

## Closed as no longer relevant

**Closure date**: 2026-05-31 (foreground relevance-scan batch 5, user-confirmed)
**Closure reason**: implementation-shipped-via-different-shape — the routine-cost half of P194 (architect-agent context-bucket dominance from pulling every per-ADR body inline) is structurally resolved by ADR-077's compendium pattern, which gives a token-cheap per-ADR summary surface that routine reads use instead of the bloated per-ADR bodies.
**Evidence (per ADR-026 grounding + ADR-079 evidence-based relevance-close pass)**:
- `docs/decisions/077-decisions-compendium-as-token-cheap-load-surface.proposed.md` exists — defines the compendium pattern
- `packages/architect/scripts/generate-decisions-compendium.sh` exists — the generator
- `docs/decisions/README.md` (the compendium) carries per-ADR `### ADR-NNN` entries with `**Confirmation:**` / `**Chosen:**` summary fields; routine architect-agent reads load this surface, not the bloated per-ADR bodies
- ADR-078 ("compendium Decision Outcome progressive disclosure") amended the compendium to also include Decision Outcome on the ADRs that have one — further closing P194's content-coverage gap (P337 tracks the generator-side implementation)
- Routine-cost (the 41% dominance was from architect routine reads pulling every per-ADR body) is structurally addressed

**Caveat**: deep-dive ADR reads still pay per-ADR bloat (forward-chronology evidence, amendment history, cross-iter cross-references). P194's framing covered both routine and deep-dive paths; only the routine path is structurally addressed. If structural bloat-per-ADR-body is the real future concern, it deserves a fresh focused ticket (sibling P337 may absorb some of this scope; P296 covers SKILL.md extraction analogy).
**Relevance evidence shape**: implementation-shipped-via-different-shape (compendium pattern superseded the original "archive forward-chronology" framing; deep-dive bloat tracked separately if needed)
**Authorising decision**: P346 user direction 2026-05-31; user confirmed P194 in foreground relevance-scan batch 5.

## Description

The 2026-05-15 deep-layer context analysis (`docs/retros/2026-05-15-context-analysis.md`) measured the `decisions` bucket at 1,346,837 bytes (1.3 MiB / 41% of total measured context). Five ADRs each exceed 38 KB, with ADR-060 at 92,688 bytes leading the bucket.

The pattern across the largest ADRs:
- **ADR-060** (Problem-RFC-Story framework, accepted) — 92 KB. Phase 1 framework + Phase 2 dogfood evidence + amendment cross-references all inline.
- **ADR-032** (Governance skill invocation patterns, proposed) — 73 KB. Original invocation-pattern decision + ADR-027 supersession + worked-example matrix all inline.
- **ADR-059** (Pipeline consume-catalog + bootstrap-from-reports, proposed) — 48 KB.
- **ADR-061** (Dogfood graduation criteria, proposed) — 39 KB.
- **ADR-051** (JTBD-anchored README with drift advisory, proposed) — 38 KB.

The forward-chronology evidence (Phase 2 dogfood + amendments + cross-iter references) is load-bearing for audit-trail purposes but inflates every session's context because the ADR is read in full at session start. Sibling pattern P134 (line-3 truncation discipline + rotation to `README-history.md`) is the existing precedent for separating display-tier content from history-tier content; the same pattern would apply to ADRs (per-decision body for display, per-decision `-history.md` sibling for amendments / dogfood / cross-iter references).

## Symptoms

- `decisions` bucket dominates the cheap-layer context measurement at 41%.
- Five individual ADRs each exceed 38 KB; the top two exceed 70 KB.
- Reading any single ADR in full consumes ~10-20% of the cheap-layer budget.
- Pattern compounds — every new ADR amendment, every new Phase 2 dogfood iteration, every cross-iter cross-reference accretes to the in-display body.

## Workaround

Manual ADR-by-ADR review on amendment: maintainer can choose to extract amendment history into a sibling `-history.md` file, but no contract / script currently surfaces the surface or codifies the rotation rule. The discipline is honour-system.

## Impact Assessment

- **Who is affected**: every session that loads ADR context (i.e. every session — `docs/decisions/` is on the cheap-layer measurement path).
- **Frequency**: continuous — the cost compounds with each session as new ADR content lands.
- **Severity**: Moderate — context dominance is friction, not correctness; but the friction is universal (affects every JTBD persona that runs Claude Code in this repo).
- **Analytics**: see `docs/retros/2026-05-15-context-analysis.md` Top-N Offenders table.

## Root Cause Analysis

### Investigation Tasks

- [ ] Survey the largest ADRs (60, 32, 59, 61, 51) for content classes: decision body / dogfood evidence / amendment history / cross-iter references. Quantify what fraction of each ADR is each class.
- [ ] Decide whether the P134 sibling-history-file pattern (or equivalent) applies to ADRs. Per-ADR `<NNN>-amendments.md` or `<NNN>-dogfood.md` candidate shapes.
- [ ] Identify the rotation trigger (e.g. ADR body > 30 KB? amendment count > 3? specific dogfood-iteration threshold?).
- [ ] Author a Tier 3 advisory script (sibling to `check-briefing-budgets.sh` and `check-problems-readme-budget.sh`) that surfaces over-budget ADRs at retro time.
- [ ] If the rotation pattern is approved, extract ADR-060 Phase 2 dogfood evidence to `docs/decisions/060-dogfood.md` as the first worked example.
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.

### Preliminary Hypothesis

ADR bodies accumulate forward-chronology evidence because there's no documented rotation pattern. The P134 + P099 + P145 surface family (display-tier vs history-tier separation; advisory budget script + behavioural bats + ADR-tier budget) is reusable per JTBD-101 — applying it to ADR bodies is the natural extension.

The rotation discipline does NOT delete history; it moves history to a sibling file that's read on demand but NOT loaded at session start. ADR-040's tiered-disclosure framing already supports this for briefing tier 3; ADRs are a parallel surface.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P099 (briefing tier 3 advisory enforcement; reusable pattern), P134 (line-3 truncation discipline; precedent for display vs history), P145 (briefing rotation defer-pattern), P097 (SKILL.md mix-runtime-with-rationale; sibling content-class problem on a different surface)

## Related

- `docs/retros/2026-05-15-context-analysis.md` — measurement evidence.
- `docs/decisions/060-problem-rfc-story-framework-...accepted.md` — largest ADR (92 KB).
- P134 (`docs/problems/closed/134-...md`) — line-3 truncation discipline; precedent.
- P099 (`docs/problems/closed/099-...md`) — briefing tier 3 advisory enforcement.
- P145 (`docs/problems/closed/145-...md`) — briefing rotation defer-pattern.
- P097 (`docs/problems/known-error/097-skill-md-runtime-size-mixes-policy-with-runtime-steps.md`) — sibling content-class problem on SKILL.md surface.
- ADR-040 (`docs/decisions/040-...md`) — tiered-disclosure framing.
- Captured by `/wr-retrospective:run-retro` Step 4b Stage 1 + user direction "don't defer the stage 1 ticketing" (2026-05-15).
