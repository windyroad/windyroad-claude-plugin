# Problem 174: Topic-file rotation contract requires `first-written` HTML metadata that doesn't exist on most briefing entries — Step 3 Branch A unenforceable in practice

**Status**: Open
**Reported**: 2026-05-06
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Topic-file rotation contract assumes `first-written` HTML metadata that doesn't exist on most entries — Step 3 Branch A unenforceable.

`/wr-retrospective:run-retro` Step 3 Tier 3 budget pass surfaces files with bytes >= 2x ceiling as `MUST_SPLIT`, mandating split-by-subtopic OR split-by-date with no defer permitted. Split-by-date requires the `first-written` HTML comment metadata per Step 1.5; split-by-subtopic needs sub-topic boundaries.

**2026-05-06 evidence (I001 mitigation retro)**: 3 MUST_SPLIT files (`governance-workflow.md`, `hooks-and-gates.md`, `releases-and-ci.md`). `grep -c first-written` returns 1, 1, 3 entries per file (vs ~20-30 entries each). `grep -nE '^##\|^###'` shows 1-2 top-level sections per file with bullet entries directly under them.

Without metadata, split-by-date is arbitrary (no signal for which entries are oldest). Without rich heading structure, split-by-subtopic isn't a clean fit. Contract ends up unenforceable in practice — agent must defer (which Branch A says is not eligible) or pick arbitrary splits.

**Fix candidates** (deferred to investigation; pick after architect review):

- **(a) One-time metadata-bootstrap pass** that backfills `first-written` from `git blame` per entry. Mechanical: walk `docs/briefing/*.md`, run `git blame -L <line>,<line>` for each entry's anchor line, extract the earliest commit date, append `<!-- first-written: YYYY-MM-DD | last-classified: <today> | signal-score: 0 -->` HTML comment per Step 1.5 schema. Reversible (just delete the comments). Preserves existing entries.
- **(b) Amend Step 3 Branch A** to accept "no metadata + no clear subtopic → record OVER and surface in summary, no forced action this retro" as a non-defer outcome. Effectively narrows Branch A to files where AT LEAST ONE rotation option is feasible. Avoids the unenforceability trap.
- **(c) Add a Step 1.5b requirement** that any new briefing entry MUST carry `first-written` comment. Bootstraps forward but doesn't address the legacy-entry gap.

Likely combination: (a) for the bootstrap + (c) for going forward. (b) as a fail-safe on top.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause
- [ ] Create reproduction test

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P145 (run-retro Tier 3 rotation prompt accumulates defer answers recurringly — same Step 3 surface; P145 fixed the recurring-defer pattern, this ticket addresses the new failure mode that emerged after P145's fix forced action on MUST_SPLIT)

## Related

(captured via /wr-itil:capture-problem during 2026-05-06 I001 mitigation retro Step 3; expand at next investigation)
