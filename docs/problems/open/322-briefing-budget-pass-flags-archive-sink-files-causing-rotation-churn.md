# Problem 322: Tier-3 briefing-budget pass flags `*-archive*.md` sink files — re-rotating a rotation SINK proliferates siblings for ~zero reader value

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 2 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Description

`check-briefing-budgets.sh` globs ALL of `docs/briefing/*.md`, including the `*-archive*.md` rotation **sink** files. The run-retro Step 3 Tier-3 pass (Branch B, P247 "don't defer") then demands rotation of any sink ≥5120 bytes. But archive files are the DESTINATION of split-by-date rotation — re-splitting them has no clean target:

- `governance-workflow-archive.md` (6551 B) holds the NEWEST archived batch (2026-05-xx); its `-mid` (04-23/25) and `-pre-2026-04-23` siblings hold OLDER entries. Splitting archive.md by date would need a NEW `-archive-2026-05-*` sibling *between* archive.md and mid — proliferating files.
- `hooks-and-gates-archive.md` (5429 B, only +6%) — same shape.

So the pass creates a forced choice between **churn** (proliferate `-archive-N` siblings every retro) and **defer** (the P247 anti-pattern the pass exists to prevent). Neither is right — the real fix is that archives, which are NOT session-start-loaded (loaded on-demand only per README "load alongside when full historical context needed"), should not be held to the per-topic-file session-surface budget at all.

## Symptoms

- Every retro's Step 3 budget pass flags the same `*-archive*.md` files as OVER; the agent either churns (new sibling) or defers (anti-pattern).
- Splitting an archive sink has no chronologically-correct destination among existing siblings → file proliferation.

## Workaround

Leave the marginally-over archives as-is this retro (recorded as rotation candidates); the overage is on on-demand files, not the session-start surface, so the cost is ~zero.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Fix `packages/retrospective/scripts/check-briefing-budgets.sh`: exclude `*-archive*.md` from the OVER/MUST_SPLIT pass (archives are rotation sinks, not session-start surface), OR apply a higher ceiling for archive files. Update the run-retro Step 3 contract + the bats fixture accordingly.
- [ ] Confirm with the ADR-040 Tier-3 envelope intent — the 2-5KB budget targets the session-start-loaded surface; archives are explicitly on-demand.

## Dependencies

- **Composes with**: P099 (the Tier-3 budget pass), P145/P247 (the don't-defer rotation discipline — this carves out the legitimate non-defer case: a sink that shouldn't be flagged), ADR-040 (Tier-3 envelope).

## Related

- captured via /wr-retrospective:run-retro Step 3 Tier-3 pass + Step 2b (Skill-contract friction), 2026-05-27. Two archives flagged OVER (governance-workflow-archive 6551, hooks-and-gates-archive 5429); rotation deferred-with-cause to this detector fix rather than proliferating siblings.
