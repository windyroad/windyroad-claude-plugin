# Problem 138: `docs/problems/README.md` WSJF Rankings table row order doesn't match `/wr-itil:work-problems`'s tie-break selection — users assume the orchestrator is broken

**Status**: Verification Pending
**Reported**: 2026-04-28
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost certain (5)
**Effort**: M — update render logic in `manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + `/wr-itil:review-problems` to sort rows in tie-break order (or add tie-break-input columns); add bats coverage; touches 3 SKILL.md files + the rendered README. No new ADR needed — the tie-break rule already lives in `work-problems` SKILL.md Step 3 and ADR-044's Prioritisation row.

**WSJF**: (10 × 1.0) / 2 = **5.0**
**Type**: technical

> Surfaced 2026-04-28 by user mid-`/wr-itil:work-problems` iter 5: *"create a problem for the WSJF ordering in @README.md. The work-problems skill has a tie breaking mechnaism for problem tickets with the same WSJF, which is correct, but that is not represented in the readme. This means P123 is being worked on when the users thinks P135 is next, and incorrectly assumes there is something wrong with the work-problems skill"*. The orchestrator picked P123 (WSJF 6.0, older-reported tie-break winner) over P135 (WSJF 6.0, listed first in the table). The selection was correct per SKILL.md Step 3 + ADR-044 Prioritisation. The README gave no signal that this would be the choice — P135 sits above P123 in the rendered table, so the user reasonably assumed P135 was next.

## Description

`/wr-itil:work-problems` SKILL.md Step 3 defines a deterministic tie-break ladder for tickets with equal WSJF:

> If there's a tie, prefer:
> 1. Known Errors over Open problems (they have a confirmed fix path — less risk of wasted effort)
> 2. Smaller effort over larger (faster throughput)
> 3. Older reported date (longer wait = higher urgency)

`docs/decisions/044-decision-delegation-contract.proposed.md` codifies this as the canonical Prioritisation rule under the framework-resolution boundary — the orchestrator does NOT ask the user about ties; it applies the ladder mechanically.

But the rendered `docs/problems/README.md` WSJF Rankings table:

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

does NOT render any of the tie-break inputs beyond the first one (Status). The Reported date is **absent from the table entirely**, so the third tie-break (older-reported) is invisible to a human reading the README. Worse, the row order within a WSJF tier appears to follow ticket-write order or severity-tier-grouping, NOT the tie-break ladder. Concrete observation from this session (2026-04-28):

- WSJF 6.0 group rendered as: `P135 → P123 → P082 → P064` (top to bottom)
- Tie-break selection (post-P064 transition): `P123 (Reported 2026-04-26) > P135 (Reported 2026-04-27)` by older-reported
- The orchestrator picked P123. The user expected P135 (top row).

The selection logic is correct. The rendering is misleading. Result: the user assumed `work-problems` was broken and surfaced this ticket to capture the gap.

This is a **trust bug**, not a correctness bug. Every time there's a WSJF tie at the top, the README and the orchestrator disagree about which ticket is "next", and the user has no visible way to reconcile the two.

## Symptoms

- WSJF Rankings table renders rows in a non-tie-break order. Spot-check 2026-04-28 (after P064 transitioned out): `P135 / P123 / P082` at WSJF 6.0 — but `work-problems` selects P123 first by older-reported tie-break (P123: 2026-04-26, P135: 2026-04-27, P082: 2026-04-21 but blocked by P038 so transitive WSJF is 1.5).
- The Reported date column is **absent from the WSJF Rankings table**. The third tie-break input is invisible to README readers.
- The tie-break ladder is documented inside `work-problems` SKILL.md Step 3 — adopters reading the published SKILL.md (after P137 lands) would see the ladder but not be able to reproduce the selection from README rows alone.
- Effect on user behaviour: user reads top row of WSJF tier, expects orchestrator to pick that one. Orchestrator picks a different one (correctly). User doubts the orchestrator. User must invoke the skill or read the SKILL.md directly to understand WHY.
- Compounding factor: the WSJF 6.0 tie also obscures **P082's transitive 1.5 WSJF via P038** — the README still shows P082 at 6.0 stale (per iter 4's pacing note), so even before the tie-break logic is applied, the README is misleading about which tickets are actually actionable. P138's fix should compose with `/wr-itil:review-problems`'s transitive re-rate pass (P076 / Step 9b.1) to keep the rendered values fresh.

## Workaround

Run `/wr-itil:review-problems` to refresh the WSJF cache — this also runs the Step 9b.1 transitive re-rate pass, which catches stale transitive WSJFs (like P082's 6.0 → 1.5). After the review, the row order may be different but is still not in tie-break order; the user must still mentally apply the ladder.

For the tie-break inference, the user can `grep '**Reported**'` across the WSJF-tied tickets to recover the third input. Adds tool calls per check.

## Impact Assessment

- **Who is affected**: Solo-developer (JTBD-001) reading the README to predict what `work-problems` will do; AFK orchestrator user (JTBD-006) reviewing iteration progress and seeing "P123 worked" when they expected "P135"; future plugin-user persona (per P137) reading the published `docs/problems/README.md` if any plugin ever ships a problems README to npm. Most directly: the user-this-session, who hit this exact confusion within the AFK loop.
- **Frequency**: Every time there's a WSJF tie at the top of the rankings. This session alone had a 4-tied WSJF 6.0 group (pre-P064 transition) and a 3-tied group (post-P064 transition). Across most sessions where multiple tickets share severity tier × status × effort × multiplier, ties are common.
- **Severity**: Minor — does not break any contract. The orchestrator's selection is correct; the README's display is just unhelpful. Compounding: erodes trust in the orchestrator (user starts second-guessing correct decisions). Per RISK-POLICY Impact-2: "CI workflow or dev tooling affected — published packages and installed plugins unaffected" — fits exactly.
- **Likelihood**: Almost certain — known gap, no controls in place, observed failure mode within the surfacing session itself. Per RISK-POLICY Likelihood-5 verbatim ("Known gap, no controls in place, or previously observed failure mode") — observed once today; would observe on every multi-iter session with WSJF ties.
- **Analytics**: 2026-04-28 session — user explicitly flagged the gap mid-iter-5 dispatch when orchestrator picked P123 over P135. The tie was 3-way (P135 / P123 / P082) at WSJF 6.0; older-reported tie-break selected P123 (2026-04-26). User's prompt cited the specific assumption: *"P123 is being worked on when the users thinks P135 is next, and incorrectly assumes there is something wrong with the work-problems skill"*.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit current render logic in `manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + `/wr-itil:review-problems` Step 9c to confirm the table-row sort key. Hypothesis: rows are sorted by WSJF descending, then within tier by severity descending, then by row-write order or ID. NOT sorted by tie-break ladder.
- [ ] Choose render strategy:
  - **Option A — Sort rows by full tie-break ladder**: WSJF desc → Status (Known Error first within tier) → Effort (S/M/L/XL ascending) → Reported date (oldest first). Row order then matches orchestrator selection 1:1. Simplest mental model for users.
  - **Option B — Add Reported date column**: keep current sort, add the missing tie-break input as a visible column. User can mentally apply the ladder. Less invasive but requires user to do the work.
  - **Option C — Both A + B**: sort by ladder AND show Reported date. Maximum clarity; modest rendering complexity.
  - **Option D — Annotate the next pick**: add a `next` marker (arrow / bold / "→") on the row that `work-problems` would currently select. Compositional with A/B/C.
- [ ] Implement the chosen strategy in the render logic. Touches `manage-problem` SKILL.md Step 5 P094 block + Step 7 P062 block + `/wr-itil:review-problems` Step 9c table output.
- [ ] Add behavioural bats coverage per ADR-005 + ADR-044: fixture writes 4 tickets with same WSJF differing by Status/Effort/Reported, asserts the rendered table row order matches `work-problems` Step 3 selection order.
- [ ] Update `docs/problems/README.md` template in `manage-problem` SKILL.md Step 9e (the Step 9e example block — the live template that downstream renderings copy).
- [ ] Compose with `/wr-itil:review-problems` Step 9b.1 transitive re-rate pass — when the transitive re-rate fires, the rendered table should also reflect the post-rate tie-break order (so P082's transitive 1.5 surfaces correctly, not the stale marginal 6.0).

### Preliminary hypothesis

The render logic in P094 and P062 was authored to sort by WSJF descending and then group by severity tier (which is one tie-break input but not the full ladder). The author's mental model was probably "show the highest-priority work first" — which works at the WSJF dimension but breaks down within ties. The tie-break ladder in `work-problems` Step 3 was added later (or in parallel) without coordinating with the render logic. ADR-044 codified the framework-resolution boundary including the Prioritisation rule but didn't audit the visualisation surface.

This is a **convention gap**, not a bug. The visualisation and the selection logic each work in isolation; they just don't agree on row order. The user can't see WHY they disagree because the third tie-break input (Reported date) isn't even rendered.

## Fix Strategy

**Phase 1 — Confirm Option C and proceed** (S, gates Phases 2+):

- **Pre-picked Option C — Both** (sort rows by tie-break ladder AND add Reported date column). Architect verdict 2026-04-28: pre-picking removes a Phase 1 consent gate per P085 act-on-obvious; the underlying tie-break rule is already settled in ADR-044 Prioritisation row + work-problems Step 3 + ADR-029, so no architect-design judgment is needed at strategy level.
- Option D (annotate next pick with `→` / bold) is compositional and nice-to-have; defer to a follow-up iter unless Phase 2 ergonomics make it free.
- Options A and B are documented above as alternatives but NOT recommended — A misses the user-visible Reported column (third tie-break input remains opaque), B keeps the surprising row order. Both inferior to C.

**Phase 2 — Implement render** (S/M):

- Update `manage-problem` SKILL.md:
  - Step 5 P094 README refresh block: sort rows by `(-WSJF, -KnownErrorBoolean, +EffortDivisor, +ReportedDate)` or equivalent multi-key sort matching `work-problems` Step 3.
  - Step 7 P062 README refresh block: same.
  - Step 9e: update the README template to show a Reported date column.
- Update `/wr-itil:review-problems` SKILL.md Step 9c: same sort key.
- Update `/wr-itil:work-problems` SKILL.md Step 1 (Scan the backlog) — clarify that the README's row order IS the work order, so the orchestrator can read top-to-bottom on cache-fresh paths.
- **Cross-site coupling note (architect verdict 2026-04-28)**: at each render block, add a one-line comment referencing `work-problems` SKILL.md Step 3 as the canonical tie-break source, so future tie-break ladder changes know to update the render side too. The coupling between rule and render is bidirectional: any future change to the ladder must update both sites or this ticket's failure mode recurs. Worth tightening into P136's ADR-044 alignment audit log so the full surface is named.

**Phase 3 — Bats coverage** (S):

- New `packages/itil/skills/manage-problem/test/` and `packages/itil/skills/review-problems/test/` bats: fixture 4 same-WSJF tickets differing by Status/Effort/Reported, assert rendered table row order = work-problems selection order.
- Behavioural per ADR-005 + ADR-044 (no structural source-content tests).

**Phase 4 — One-shot remediation**:

- Re-render `docs/problems/README.md` against the updated logic. Catches the existing 64KB README into the new sort. Lands as a `docs(problems): re-render WSJF table per P138 tie-break order` commit.

**Out of scope**:
- The tie-break **rule** itself (already settled in `work-problems` SKILL.md Step 3 + ADR-044).
- README line-3 narrative blob (P134 — different concern; both touch the same README but at different cuts).

## Dependencies

- **Blocks**: every multi-iter AFK session with a WSJF tie at top will continue to confuse the user until P138 lands.
- **Blocked by**: (none — Phase 1 can proceed standalone; the underlying tie-break rule is already documented).
- **Composes with**: P134 (`docs/problems/README.md` line 3 narrative-blob accumulator bloat — different cut on the same surface; both should converge to a clean README), P137 (plugin-published artefacts cite internal IDs — published README inherits the rendering quality this ticket addresses; if any plugin ever ships its own problems README, the rendering needs to match the orchestrator), P076 (transitive-effort rule — the rendered table should reflect transitive WSJFs after `review-problems` Step 9b.1 fires, otherwise P082's 6.0-vs-1.5 staleness surfaces here too), P069 (`docs/problems/` flat layout unskimmable — adjacent surface concern at a different cut), P136 (ADR-044 alignment audit master — Phase 2 audited `work-problem` singular SKILL.md tie-break call sites; P138 is the rendering-side gap that complements that audit).

## Related

- **`/wr-itil:work-problems` SKILL.md Step 3** — defines the tie-break ladder (Known Error > Open; smaller effort; older reported date). The rule is correct; P138 is about making it predictable from the rendered README.
- **ADR-044** (`docs/decisions/044-decision-delegation-contract.proposed.md`) — Prioritisation row codifies the tie-break as a framework-resolved decision. P138's fix preserves this — the rendering becomes a faithful reflection of the framework-resolved order.
- **P076** (`docs/problems/076-...closed.md`) — transitive dependencies rule (Step 9b.1 in `/wr-itil:review-problems`). The rendered table should reflect transitive WSJF; P138's render fix should compose with this.
- **P094** (`docs/problems/094-...closed.md`) — `manage-problem` README refresh on creation. Phase 2 amends the render logic.
- **P062** (`docs/problems/062-...closed.md`) — `manage-problem` README refresh on transition. Phase 2 amends the render logic.
- **P134** (`docs/problems/134-...open.md`) — README line-3 narrative blob. Adjacent surface; different cut.
- **P137** (`docs/problems/137-...open.md`) — plugin-published artefacts cite internal IDs. Adjacent — if a future ADR mandates README renderings ship to npm (P137's Phase 1 strategy ADR), the rendering quality this ticket addresses becomes user-facing.
- **P136** (`docs/problems/136-adr-044-alignment-audit-master.open.md`) — ADR-044 alignment audit. Phase 2 audited the singular-skill tie-break implementation; P138 is the rendering-side complement.
- **P069** (`docs/problems/069-...open.md`) — flat layout unskimmable. Adjacent README-surface concern; different cut.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — primary persona served. The "without slowing down" half is exactly what this ticket targets: predictable orchestrator behaviour visible from the README so the user doesn't doubt or second-guess.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — composes; AFK orchestrator user's progress-summary expectations include "the README and the orchestrator agree on what's next".
- 2026-04-28 session: surfaced by user mid-`/wr-itil:work-problems` iter 5 dispatch (orchestrator picked P123 via older-reported tie-break over P135 which sat at the top of the rendered table). User explicitly named the trust impact: *"incorrectly assumes there is something wrong with the work-problems skill"*.

## Fix Released

Released 2026-04-28 (AFK iter; pending @windyroad/itil patch — fold-fix commit transitions Open → Verification Pending per ADR-022). Phase 2: multi-key sort spec `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` documented at all three render-block sites (`manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + Step 9e template + Step 9c presentation, `review-problems` SKILL.md Step 3 + Step 5 README template, `work-problems` SKILL.md Step 1) with stable greppable cross-coupling marker `<!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 -->` at each render site. `Reported` column added to the WSJF Rankings table at every template + the rendered `docs/problems/README.md` so the third tie-break input is visible to README readers. Phase 3: new behavioural + structural bats `packages/itil/skills/manage-problem/test/manage-problem-readme-tie-break-order.bats` 13/13 green — covers marker presence at all five render-block sites, multi-key sort spec verbatim, Reported column in templates, drift-warning prose, AND a behavioural fixture sort (4 same-WSJF tickets differing by Status/Effort/Reported, asserts post-sort row order matches the tie-break ladder result; second fixture exercises the third tie-break level explicitly when Status + Effort tie; third fixture guards WSJF tier dominance over Status). Phase 4: `docs/problems/README.md` re-rendered against the new sort with Reported column; the WSJF 6.0 tier now shows P123 (KE M 2026-04-26) → P135 (KE M 2026-04-27) → P082 (Open M 2026-04-21) — older Known Error first, Open last, matching `/wr-itil:work-problems` Step 3 selection 1:1 (the exact case that triggered this ticket). Architect verdict 2026-04-28 PASS with one tightening (greppable marker — applied) + JTBD review (JTBD-001 primary, JTBD-006 composes — predictable orchestrator behaviour visible from rendered README). Awaiting user verification: load the README and confirm row order in any tied WSJF tier matches the orchestrator's pick, AND confirm `npx bats packages/itil/skills/manage-problem/test/manage-problem-readme-tie-break-order.bats` is green.
