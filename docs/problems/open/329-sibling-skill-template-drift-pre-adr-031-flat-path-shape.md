# Problem 329: sibling SKILL.md path templates carry pre-ADR-031 flat-path shape

**Status**: Open
**Reported**: 2026-05-30
**Priority**: 6 (Medium) — Impact: 3 (Moderate — same adopter-side mis-classification risk as P281, broader surface: 6 SKILLs vs 1) x Likelihood: 2 (Likely-but-narrower — each SKILL is invoked less frequently than capture-problem; agent inference may compensate in some flows)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

P281 closed the capture-problem SKILL.md template-refresh sub-shape. Six SIBLING SKILLs carry the same pre-ADR-031 flat-path shape drift in their prose / fix-up commands:

- `packages/itil/skills/manage-problem/SKILL.md` line 446 — Step 4 `**File path**: `docs/problems/<NNN>-<kebab-case-title>.open.md`` (same defect as P281's capture-problem line 188).
- `packages/itil/skills/manage-problem/SKILL.md` lines 645, 757 — `git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md` (state transitions that would re-introduce flat layout).
- `packages/itil/skills/review-problems/SKILL.md` line 48 — same `git mv` flat-path transition.
- `packages/itil/skills/transition-problems/SKILL.md` line 138 — same.
- `packages/itil/skills/transition-problem/SKILL.md` line 143 — same.
- `packages/itil/skills/reconcile-readme/SKILL.md` lines 72-73 — grep patterns hard-coded to flat-shape file naming.
- `packages/itil/skills/capture-rfc/SKILL.md` lines 164, 249 — RFC-specific flat shape (`docs/rfcs/RFC-<NNN>-<slug>.proposed.md` vs ADR-031-equivalent per-state shape).

Per architect verdict on P281 (2026-05-30): each SKILL.md is independently authored. ADR-031 imposes a layout contract, not an edit-atomicity contract. Partial scope (capture-problem only) was OK; this descendant captures the remaining work.

## Symptoms

- Adopter agents following any of these SKILL.md templates literally would land tickets / state transitions at the pre-ADR-031 flat path.
- Concrete blast radius unbounded — agents may infer from on-disk inventory and avoid the bug (as happened in this repo for P279/P280), but adopters with empty problems/ dirs or inconsistent layouts hit the literal-template path.
- README cache mis-classification risk identical to P281.

## Workaround

- Same as P281: `git mv` to per-state subdir after every capture or transition.
- Maintainer-side: refresh each SKILL.md template literal to name the per-state shape per ADR-031.

## Impact Assessment

- **Who is affected**: any adopter project consuming `@windyroad/itil` whose agents follow SKILL.md templates literally without on-disk-inventory inference override.
- **Frequency**: (deferred to investigation)
- **Severity**: Medium — same recoverable-via-`git mv` shape as P281 but multiplied by 6 SKILLs.
- **Analytics**: out of scope for capture.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Refresh `manage-problem/SKILL.md` Step 4 path template (line 446) + all `git mv` transitions (lines 645, 757) to per-state subdir shape
- [ ] Refresh `review-problems/SKILL.md` line 48 `git mv` transition
- [ ] Refresh `transition-problems/SKILL.md` line 138
- [ ] Refresh `transition-problem/SKILL.md` line 143
- [ ] Refresh `reconcile-readme/SKILL.md` lines 72-73 grep patterns (or document dual-tolerant semantic if intentional during RFC-002 migration window)
- [ ] Refresh `capture-rfc/SKILL.md` lines 164, 249 RFC-equivalent shape
- [ ] Cross-check `capture-story`, `capture-story-map`, `manage-rfc`, `manage-story`, `manage-story-map` SKILLs for the same drift
- [ ] Add behavioural bats coverage per-SKILL (mirror P281's `packages/itil/skills/capture-problem/test/capture-problem.bats` P281: SKILL.md path-template tests)
- [ ] Verify the `git mv` patterns work under per-state-subdir layout (mv between `open/` and `known-error/` subdirs vs mv within same parent dir)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — independent fix work per SKILL)
- **Composes with**:
  - **P281** (parent — same root cause, capture-problem-specific sub-shape closed first)
  - **ADR-031** (per-state-subdir layout decision)
  - **RFC-002** (dual-tolerant migration window — relevant for reconcile-readme grep patterns)

## Related

- **P281** (`docs/problems/known-error/281-capture-problem-skill-template-references-pre-adr-031-flat-path-shape.md`) — parent, capture-problem template-refresh shipped 2026-05-30 (work-problems iter 7).
- **ADR-031** (`docs/decisions/031-problem-ticket-directory-layout.accepted.md`) — the ratified per-state-subdir layout this SKILL drift violates.
- Architect verdict on P281 (2026-05-30): "Partial scope is fine. Each SKILL.md is independently authored. Queueing P281-descendant tickets for capture-rfc, manage-problem Step 4, review-problems, transition-problems, transition-problem, reconcile-readme is correct."
- Sibling ADR-candidate: "agent inference vs literal SKILL template precedence" question deserves a NEW ADR per architect verdict on P281 — recommend new sibling ticket if a maintainer wants to take that on directly; otherwise rolls into this ticket's investigation as a follow-on once template-refresh is shipped.
