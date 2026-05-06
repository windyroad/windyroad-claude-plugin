# Problem 150: docs/problems/README.md Verification Queue rendered newest-first contradicts section header "Ranked by release age, oldest first"

**Status**: Verification Pending (fold-fix Open → Verifying per ADR-022 P143 amendment — root cause + fix strategy + workaround documented inline; ships 2026-05-03 AFK iter 9)
**Reported**: 2026-05-02
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Possible (2)
**Effort**: S — single-line section-header text edit OR per-render sort-direction flip; bounded across `manage-problem` Step 9c / Step 9e template, `review-problems` SKILL.md, `transition-problem` Step 7, `reconcile-readme` rendering.
**WSJF**: (4 × 1.0) / 1 = **4.0**
**Type**: technical

## Description

`docs/problems/README.md` Verification Queue section header reads:

> Fix released, awaiting user verification (driven off `docs/problems/*.verifying.md` via glob per ADR-022). Ranked by release age, oldest first.

But the rendered table is sorted **newest first** — recent transitions (today's P148, yesterday's P144/P143) appear at the top; older transitions (2026-04-22 P104/P093) appear at the bottom.

This is a documentation-vs-rendering mismatch. Either the section header is wrong (the actual ordering is reverse-chronological / newest-first by intent) or the rendering is wrong (it should sort oldest-first per the contract).

The Verification Queue's purpose is to surface verification-ready candidates so the user can close them. P048's "Likely verified?" column markers (`yes (N days)` / `no (N days)`) work better when older entries are at the top — those are the candidates most likely ready to close. So "oldest first" matches the user-task semantics.

But the actual rendering history shows entries going down to "fresh" / "0 days" at the top and "10 days" / "fresh" at the bottom — newest-first. This pattern has been the de-facto rendering for many retros now (P145 evidence: same recurring drift pattern).

## Symptoms

- 2026-05-02 P148 release session: read `docs/problems/README.md` to refresh it for the P148 transition. Section header (line 43) says "Ranked by release age, oldest first." Rendered table starts with P144 (Released 2026-04-29 = 3 days old) at line 47 and ends with P093 (Released 2026-04-22 = 10 days old) at line 80. Newest-first ordering, contradicts header.
- I inserted P148 (Released 2026-05-02 = 0 days old) at the top of the table, matching the existing newest-first pattern. Had I followed the section header literally, P148 would have gone at the BOTTOM (newest entry, oldest-first sort means newest is last). The contradiction created an authoring ambiguity.
- The "Likely verified? `no (N days)`" column values are stale across the rendered table — entries say "no (0 days)" for tickets that are now 3+ days old. This is a separate but related issue: age recalculation isn't part of the Step 7 P062 / Step 5 P094 refresh contract, which would re-render columns based on today's date.

## Workaround

Authoring agents observe the existing rendered pattern and follow it (newest-first), inserting new entries at the top. Section-header text is misleading but doesn't block work — agents pattern-match against the rendered table rather than parsing the prose contract.

## Impact Assessment

- **Who is affected**: agents authoring the Verification Queue rendering across `manage-problem`, `review-problems`, `transition-problem`, `transition-problems`, `reconcile-readme`. Users reading the queue who expect oldest-first ordering per the section header.
- **Frequency**: every `.verifying.md` transition + every full review re-render — many times per week.
- **Severity**: Low — cosmetic / documentation mismatch. No data corruption, no audit-trail gap. Causes minor authoring ambiguity and may mislead users skimming the queue.
- **Likelihood**: Possible — recurring drift; pattern has been stable newest-first for many retros despite contract claiming oldest-first.
- **Analytics**: 1 confirmed observation today (P148 release insertion); pattern visible across all recent README versions in git history.

## Root Cause Analysis

### Investigation Tasks

- [ ] Decide which is the canonical ordering — oldest-first (per section header / P048 user-task semantics) or newest-first (per de-facto rendering convention).
- [ ] Audit the five SKILL.md files (`manage-problem` Step 9c / 9e, `review-problems`, `transition-problem` Step 7 P062, `transition-problems` batch render, `reconcile-readme` Step 5 render) to confirm none of them encode an explicit sort direction — drift-by-omission is the likely root cause.
- [ ] If oldest-first wins: amend the render rule to sort by Released date ASC (oldest first). Verification Queue rows top-to-bottom = oldest → newest.
- [ ] If newest-first wins: amend the section-header prose in five SKILL.md files to read "Ranked by release age, newest first" or simply "Reverse-chronological by release date".
- [ ] Either way, decide whether `Likely verified?` age column should be recomputed on every render (today_date - released_date) so stale `(0 days)` markers refresh — composes with the canonical ordering work.
- [ ] Add a behavioural bats fixture asserting the chosen ordering across a synthetic VQ table.

### Preliminary hypothesis

The Verification Queue contract was written with oldest-first intent (matches P048 user-task semantics — surface candidates ready to close first) but the rendering implementation across multiple SKILL.md files was authored ad-hoc with newest-first iteration order (matches the natural "list recent transitions" mental model agents reach for). Neither side codified the sort direction explicitly, so drift-by-omission accumulated.

The fix is small: pick one canonical ordering, encode it in all five SKILL.md render blocks (analogous to the P138 `<!-- TIE-BREAK-LADDER-SOURCE: ... -->` marker), and add a single bats assertion that drives the right outcome.

## Fix Strategy

**Kind**: improve

**Shape**: skill (`manage-problem` + `review-problems` + `transition-problem` + `transition-problems` + `reconcile-readme` SKILL.md files)

**Target file**: `packages/itil/skills/manage-problem/SKILL.md` Step 9c + Step 9e + Step 7 P062 (primary); symmetric edits in `review-problems` Step 5, `transition-problem` Step 7, `transition-problems` batch render, `reconcile-readme` Step 5 render.

**Observed flaw**: Verification Queue section header claims "oldest first" but rendered order is newest-first across multiple recent README versions. Five SKILL.md render blocks lack an explicit sort-direction encoding, so drift accumulates.

**Edit summary**: pick canonical ordering (recommend **oldest first** per P048 semantics — older entries are the likely-verified candidates the user wants to surface first); encode the sort key + direction inline at each render block ("rows sorted by Released date ASC; oldest at top per ADR-022 / P048"); add a `<!-- VQ-SORT-DIRECTION: oldest-first -->` HTML-comment marker analogous to P138's tie-break-ladder marker; add a behavioural bats fixture (`manage-problem-readme-vq-sort-order.bats`) covering 3-4 fixture entries with known dates → assert oldest at row 1.

**Evidence**:
- 2026-05-02 P148 release session: README line 43 says "oldest first" but lines 47-80 render newest-first.
- P138 (WSJF Rankings tie-break sort) — sibling rendering issue on the WSJF Rankings table; resolved with explicit multi-key encoding + greppable marker. Same fix shape applies here.
- ADR-022 (`.verifying.md` lifecycle) — establishes the queue but doesn't encode sort direction.
- P048 (Verification Queue + Likely verified column) — establishes the user-task semantics that motivate oldest-first.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — fix is independent)
- **Composes with**: P138 (WSJF Rankings tie-break sort — sibling rendering issue, same fix shape with greppable marker), P048 (Likely verified column — composes with sort direction), P145 (recurring drift pattern at SKILL.md render contracts), P149 (sibling Step 0 SKILL contract drift filed in same retro).

## Related

- **P138** (`docs/problems/138-readme-wsjf-row-order-doesnt-match-work-problems-tie-break.verifying.md`) — sibling rendering-vs-contract mismatch on the WSJF Rankings table; resolved 2026-04-28 with explicit multi-key sort + `<!-- TIE-BREAK-LADDER-SOURCE: ... -->` marker. P150 applies the same fix shape to the Verification Queue table.
- **P048** (`docs/problems/048-manage-problem-does-not-detect-verification-candidates.verifying.md`) — introduced the Verification Queue + `Likely verified?` column.
- **P049** (`docs/problems/049-known-error-status-overloaded-with-fix-released-substate.verifying.md`) — introduced `.verifying.md` lifecycle; mentions "Ranked by release age, oldest first" in the original Step 9c contract.
- **ADR-022** (`docs/decisions/022-verification-pending-status.proposed.md`) — `.verifying.md` lifecycle.
- **`packages/itil/skills/manage-problem/SKILL.md`** Step 9c / Step 9e / Step 7 P062 — primary edit targets.
- **`packages/itil/skills/review-problems/SKILL.md`** — symmetric render block.
- **`packages/itil/skills/transition-problem/SKILL.md`** Step 7 — symmetric render block.
- **`packages/itil/skills/transition-problems/SKILL.md`** — batch render block.
- **`packages/itil/skills/reconcile-readme/SKILL.md`** Step 5 — render block.
- **2026-05-02 P148 release session evidence**: README line 43 vs lines 47-80 contradiction observed and recorded.
- **`/wr-retrospective:run-retro` 2026-05-02 retro Step 2b detection**: this ticket originated from the pipeline-instability scan during today's retro; category = Skill-contract violations (rendering contract drift across multiple SKILL.md files).

## Fix Released

**Released**: 2026-05-03 (AFK iter 9; pending `@windyroad/itil` patch — fold-fix Open → Verification Pending per ADR-022 P143 amendment)

**Approach**: ratified fix-strategy choice (oldest first per ADR-022 + P048 user-task semantics). Encoded canonical Verification Queue sort direction `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC) at all six SKILL.md render sites:

- `packages/itil/skills/manage-problem/SKILL.md` — Step 5 P094, Step 7 P062, Step 9c presentation, Step 9e template (4 occurrences of the `<!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 -->` marker).
- `packages/itil/skills/review-problems/SKILL.md` — Step 3 ranking + Step 5 README template.
- `packages/itil/skills/transition-problem/SKILL.md` — Step 7 README refresh subsection.
- `packages/itil/skills/transition-problems/SKILL.md` — Step 4a batch render subsection.
- `packages/itil/skills/reconcile-readme/SKILL.md` — Step 4 row-insertion subsection.
- `packages/itil/skills/list-problems/SKILL.md` — VQ render block.

**Marker shape**: `<!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 -->` — analogous to P138's `<!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 -->`. Includes a source-of-truth pointer (per architect amendment) so future readers have a one-grep path to the authority.

**Behavioural test**: new `packages/itil/skills/manage-problem/test/manage-problem-readme-vq-sort-order.bats` 13/13 green covering:
- Marker presence at every render site (6 contract assertions).
- Released-date ASC direction prose presence (2 assertions).
- Drift-re-opens-P150 warning prose presence (2 assertions).
- Behavioural fixture sort with 4 .verifying.md fixtures of known dates → row 1 = oldest entry (1 assertion).
- Same-day-Released ID-ASC tiebreaker (1 assertion).
- P048-aligned likely-verified-first ordering (1 assertion).

**README re-rendered**: `docs/problems/README.md` Verification Queue table now top-to-bottom = oldest → newest. Undated rows (Released marker without a YYYY-MM-DD) sort first by ID ASC (16 rows — pre-existing data quality issue, marker preserved verbatim); dated rows follow oldest-first (50 rows — markers recomputed against today_date so stale `(0 days)` markers refresh). Total: 66 rows = 65 original + P150.

**Architect verdict**: PASS. No new ADR required — ADR-022 already authorises VQ ordering ("oldest first" wording in Decision Outcome line 63); ADR-014 covers single-commit grain; P138 fix-shape established as in-repo precedent at `packages/itil/skills/manage-problem/test/manage-problem-readme-tie-break-order.bats`. Marker grammar matches `TIE-BREAK-LADDER-SOURCE` shape (uppercase-kebab key + colon + value + ADR pointer). Inline fold-fix Open → Verifying endorsed per ADR-022 P143 amendment when pre-flight criteria met inline.

**JTBD verdict**: PASS. JTBD-006 primary (AFK loop continuity — actionable closure candidates surface at top of queue, not bottom; precondition for the AFK handoff working at all); JTBD-001 secondary (governance enforced via greppable marker + bats fixture, sibling P138 pattern). No persona regression — no documented need for newest-first VQ framing (that need is served by git log / changelog, not the queue).

**Changeset**: `.changeset/p150-vq-sort-direction.md` (`@windyroad/itil` patch).

**Verification criterion**: user verifies on next session by reading `docs/problems/README.md` Verification Queue table — undated rows appear first sorted by ID ASC, then dated rows sort oldest-first (row immediately after the undated cohort = 2026-04-17 P016; row N = the most-recent release in the cohort). Behavioural confirmation that the recurring-drift loop is closed comes from observing future render sites (Step 7 transitions, Step 9e review re-emits, reconcile-readme repairs) preserve oldest-first ordering across 2-3 retro cycles — measurable via `bats packages/itil/skills/manage-problem/test/manage-problem-readme-vq-sort-order.bats` exit 0 across the cycles.
