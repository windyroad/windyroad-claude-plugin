# Problem 169: Build recogniser-shape catalogue into @windyroad/risk-scorer plugin (automatic bootstrap + ongoing maintenance)

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Build recogniser-shape catalogue into @windyroad/risk-scorer plugin (automatic bootstrap + ongoing maintenance) — Phase 1 scorer-side, Phase 2 bootstrap-side.

**Phase 1** updates `packages/risk-scorer/agents/pipeline.md` to consume the recogniser-shape catalogue:
- Recogniser block for slug-match (path patterns + diff-content keywords + anti-patterns)
- Controls table with "if absent for THIS action" column for band-reduction
- Modulators table for per-action adjustment with max-pessimistic composition (per user direction 2026-05-04)

Needs ADR-056-style dual-parse contract for in-flight cached prompts (adopters running pre-update prompt cache continue to function).

**Phase 2** ships:
- Starter catalogue (5-7 universal entries with placeholder paths/controls — adopter authoring direction "Starter + bootstrap" per user 2026-05-04)
- `extract-risks-from-reports.sh` update to emit recogniser-shape skeleton (placeholder recogniser/controls/modulators awaiting curation)
- `bootstrap-catalog` SKILL.md update consuming the new shape
- ADR-056 amendment for hint extension to carry recogniser hints (5-column shape OR orchestrator drain step prompts user for extras)

Each phase held in `docs/changesets-holding/` for in-repo dogfood window before adopter release (per user direction 2026-05-04: "Phased: scorer first, then bootstrap").

Surfaces this catalogue's recogniser-shape change (commit 092804d this session) from this-repo-only into the published `@windyroad/risk-scorer` minor bump arc.

## Symptoms

(deferred to investigation)

- This repo's catalogue (10 entries in recogniser shape, commit 092804d) is the ONLY catalogue currently using this shape.
- The plugin's pipeline.md scorer prompt still uses the older "reduces from N to N because rationale" per-control language; doesn't read the recogniser/controls/modulators tables.
- The plugin's `extract-risks-from-reports.sh` still emits skeleton-with-sentinels entries (per ADR-059 Verdict shape); doesn't emit recogniser-shape skeletons.
- Adopters who install `@windyroad/risk-scorer` get the old shape; benefits of the recogniser-shape catalogue don't propagate.

## Workaround

(deferred to investigation)

Adopters can manually author catalogue entries in the recogniser shape using this repo's `docs/risks/R001-R010.md` as templates. The pipeline.md scorer's slug-match-and-judgement-fallback still works; it just doesn't consume the structured tables.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: plugin-maintainer (cost of building); secondary: every adopter (benefits don't propagate until shipped).
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation) — likely Moderate; benefits of recogniser-shape are real but adopters are functioning today.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Architect review: design contract for the pipeline.md update — recogniser-shape consumption, dual-parse contract for in-flight cached prompts, adopter migration path
- [ ] Architect review: design contract for the bootstrap-from-empty + starter-catalogue layering — what entries belong in the starter (universal vs project-specific), how does the bootstrap extend, how does the curate-update path work
- [ ] JTBD review: which persona jobs are served (likely JTBD-001 enforce-governance + JTBD-006 AFK-safety + JTBD-007 keep-plugins-current; JTBD-101 plugin-developer for the starter contract)
- [ ] ADR-056 amendment OR new ADR: hint format extension for the drain path to carry recogniser hints (5-column shape OR 3-column + orchestrator-curation step)
- [ ] Decide: starter catalogue scope — which entries from this repo's R001-R010 generalise to ALL plugin adopters vs which are project-specific
- [ ] Decide: dual-parse contract shape for the pipeline.md update — accept old "reduces from N to N" output during cache-window AND new recogniser-shape output, OR force a major bump and require adopter cache refresh
- [ ] Phase 1 implementation: pipeline.md update + bats coverage + held changeset
- [ ] Phase 2 implementation: starter catalogue + extractor update + bootstrap-catalog SKILL.md update + ADR amendment + held changeset
- [ ] Dogfood pass per phase: run pipeline scorer against this repo's commits with new shape; verify residual reconciliation against `.risk-reports/` history
- [ ] Stress-test: pick a recent above-appetite report; re-derive risk-items consuming the new catalogue; check recogniser surfaces correct entries + modulators apply correctly + residual matches

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — all preconditions in place: catalogue shape commit 092804d shipped; ADR-059 + extract-risks-from-reports.sh + bootstrap-catalog skill + create-risk flag-driven path all in commit 8edaf7b)
- **Composes with**: P168 (parent — verifying; this is the operationalisation follow-up), P137 (publish-boundary controls — adopter shipping concerns), P159 (load-bearing-from-the-start pattern — the shape this update follows for advisory→blocking promotion path)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-059 (P168 design ADR — current scope is bootstrap-shape sentinels; this ticket extends to recogniser-shape)
- ADR-056 (slug primitive + 3-column hint; needs amendment or new sibling for recogniser-hint shape)
- ADR-049 + ADR-055 (publish-boundary controls — adopter pipeline.md prompt-cache concerns)
- ADR-051 amended (load-bearing-from-the-start; the dogfood-then-ship pattern this ticket follows)
- This-session catalogue recogniser-shape commit: 092804d
- This-session R001-R010 recogniser-shape entries in `docs/risks/`
- Architect review (this session) recommendations B1 / A2 / A5 / A1+B2 / A3 / B3 / drop+simplify
- AskUserQuestion decisions 2026-05-04: D1 framing = recogniser-shaped; D3 modulator composition = max-pessimistic; adopter authoring = Starter + bootstrap; dogfood gating = Phased (scorer first)
- Existing related tickets surfaced by 3-keyword grep: P024, P090, P114, P168 (none are direct duplicates; P168 is the parent ADR-059 effort, this is its operationalisation successor)
