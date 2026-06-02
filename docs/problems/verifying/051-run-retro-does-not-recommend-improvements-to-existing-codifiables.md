# Problem 051: run-retro does not recommend improvements to existing skills, agents, hooks, or other codifiables

**Status**: Verification Pending
**Reported**: 2026-04-19
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: 8.0 — (8 × 2.0) / 2

## Fix Released

Shipped 2026-04-19 (AFK iter 3) — `packages/retrospective/skills/run-retro/SKILL.md` extended with the P051 improvement axis:

- **Step 2**: added an improvement-shaped reflection category ("What existing skill, agent, hook, ADR, guide, or other codifiable showed a flaw, gap, or friction this session that a targeted edit would fix?") with the (a) reproducible (b) bounded edit (c) no new concept criteria.
- **Step 4b**: extended the single flat `AskUserQuestion` option list with six improvement-axis options — `Skill — improvement stub`, `Agent — improvement stub`, `Hook — improvement stub`, `ADR — supersede or amend`, `Guide — improvement edit`, `Problem — edit existing ticket`. Kept P050's 12 creation-axis options intact; total now 19 options. Kept the single-call preference; extended the two-question fallback to include "Create, improve, or skip?".
- **Step 4b**: added P016/P017 concern-boundary splitting for multi-concern improvements; added the `≥ 3 improvements per output → coordinating ticket` discipline.
- **Step 4b stub recording**: split into two rubrics — creation rubric (Kind/Shape/Suggested name/Scope/Triggers/Prior uses) and improvement rubric (Kind/Shape/Target file/Observed flaw/Edit summary/Evidence).
- **Non-interactive fallback**: records `Kind:` alongside `Shape:` (e.g. `Kind: improve, Shape: skill, flagged — not actioned (non-interactive)`), and improvement flags retain Target file + Observed flaw so the user has context on return.
- **Step 5 summary table**: added a `Kind` column taking `create`/`improve`; the decision column gains an `improvement stub` marker for Kind=improve rows.
- **Backward compatibility**: singular shape names used across both axes so legacy `Shape: skill` greps still match.

Tests — `packages/retrospective/skills/run-retro/test/run-retro-codification-candidates.bats` extended with five P051-specific structural assertions (RED then GREEN this iteration):

- Step 2 includes an improvement reflection category for existing codifiables.
- Step 4b names improvement-shaped options for multiple shapes (≥ 3 shape-prefixed improvement rows).
- Step 4b routes improvement-axis ADR candidates to create-adr with `supersede or amend` hint.
- Step 5 summary distinguishes create from improve via a Kind column.
- Step 4b non-interactive fallback covers improvement candidates (records Kind alongside Shape).

Full run-retro test surface now 24 tests (9 P050 + 5 P051 + 10 P044), all passing. Full project test surface: 246 tests, 0 failures.

Architecture + JTBD reviews: both PASS. No new ADR required — within-skill extension on top of ADR-013 (Rules 1 + 6). Option count 19 is within the single-call preference; two-question fallback already documented in line 100 covers the escape hatch. ADR-014 explicitly scopes run-retro out for commit behaviour; unchanged in this iteration. ADR-005 Permitted Exception covers the bats structural assertions. JTBD alignment: JTBD-001 (routing reduces triage overhead), JTBD-006 (single AskUserQuestion preserved for AFK safety), JTBD-101 (parallel naming mirrors P050 so contributors see one consistent pattern).

Awaiting user verification: next `/wr-retrospective:run-retro` invocation should exercise the generalised Step 2 (creation + improvement categories), the 19-option flat `AskUserQuestion` at Step 4b, and the Kind column in Step 5 summary.

## Pacing decision (2026-04-19, user)

**Resolved**: land in the **next AFK loop**. User explicitly accepted the second rewrite of run-retro's Step 2 / 4b / 5 blocks within a short window. Rationale: the P050 shape taxonomy is still fresh and extending it is cheaper than reloading the design later.

Next loop's implementer should:
- Extend P050's single-`AskUserQuestion` shape list with improvement-axis options (`Skill improvement — stub edit`, `Agent improvement — stub edit`, `Hook improvement — stub edit`, `ADR — supersede / amend` routing to `/wr-architect:create-adr`, `Guide edit — route to update-guide / update-policy`, `Problem ticket edit — route to /wr-itil:manage-problem <NNN>` update flow, etc.). Keep all creation-axis options from P050 intact.
- Add a Step 2 reflection category for improvements (criteria: (a) flaw is reproducible / specific, (b) fix is a bounded edit to an existing file, (c) no new concept is being invented).
- Update the Step 5 "Codification Candidates" table to include a `Kind` column with values `create` / `improve`.
- Reuse P016 / P017 concern-boundary splitting when an improvement candidate touches multiple unrelated concerns.
- Extend `run-retro-codification-candidates.bats` with ≥2 improvement-shaped assertions.

## Description

P044 and P050 both framed run-retro's codification branch around **creating new** outputs — new skills (P044), new agents / hooks / scripts / etc. (P050). Missing from both: the **improvement-shaped** reflection category.

Most session learnings are not "we should invent a new X" — they are "existing X has a flaw worth fixing". A well-functioning retrospective should surface both creation candidates AND improvement candidates, routed through the same output surfaces (skill / agent / hook / settings / script / CI / ADR / guide / problem / test / memory).

Strong evidence from this session (2026-04-19): of the five session-driven problem tickets filed (P046, P047, P048, P049, P050), **four** are improvement proposals for existing codifiables:

- **P047** (WSJF effort buckets coarse) — improvement to the existing `manage-problem` WSJF scheme.
- **P048** (detect verification candidates) — improvement to the existing `manage-problem` step 9d.
- **P049** (Known Error overloaded with Fix Released sub-state) — improvement to the existing problem-file data model + lifecycle table.
- **P050** (run-retro generalises P044) — improvement to the existing run-retro skill.

Only P046 is strictly creation-shaped (recommends a new performance-specialist sub-agent OR new ADR OR prompt edit — all three candidate fixes include improvement paths too, so P046 is actually mixed).

Improvements dominate by frequency and by real value, yet today's run-retro has no reflection category for them. All improvement observations currently land as problem tickets (the default output). That works — but it loses the routing signal that the best fix shape is often a direct edit to the existing skill / agent / hook / ADR, and short-circuits the per-shape recommendation flow P044/P050 introduce.

## Symptoms

- Improvement observations flow through the problem-ticket path by default, regardless of the best fix shape. The user then has to manually decide "is this a problem, or is it just an edit to SKILL.md X?".
- Sessions that add multiple improvements to the same existing skill / agent / hook (e.g. this session added P044 → SKILL.md edit, P047 → SKILL.md edit, P048 → SKILL.md edit, all for `manage-problem`) file N problem tickets rather than recommending a coordinated improvement batch.
- Backlog grows faster than it should: every improvement observation = 1 problem ticket. Ticket management overhead scales with improvement frequency.
- The `## Related` section of any given skill's improvement tickets accumulates (P048 / P049 / P050 all reference `manage-problem/SKILL.md`) but the improvements aren't grouped into a visible "improvement queue per skill".
- Superseded ADRs are a specific instance: when a retro surfaces that ADR-N is now wrong, the improvement path is "propose ADR-N+M superseding ADR-N" — run-retro doesn't surface this either.

## Workaround

- Operator vigilance: after running run-retro, the user mentally classifies each problem ticket as "creation vs improvement to existing X" and routes manually.
- Grouping: the user periodically groups improvement tickets per skill / agent in review output, a manual scan.
- Direct bypass: for small improvements, the user skips run-retro entirely and just edits the skill file — which loses the session-reflection audit trail.

## Impact Assessment

- **Who is affected**: solo-developer persona (JTBD-001, JTBD-006) — missed routing signal; plugin-developer persona (JTBD-101) — improvement backlog fragmented across tickets rather than owned by the affected output.
- **Frequency**: every retrospective where an existing codifiable's flaw was observed. Empirically: 4/5 session-driven tickets this session. Improvement observations likely outweigh creation observations session-over-session.
- **Severity**: Minor — no user-visible breakage; cost is routing quality and backlog hygiene.
- **Analytics**: 2026-04-19 session — 4 improvement tickets filed for `manage-problem` (P047, P048), `run-retro` (P050), and the problem-file data model (P049). Zero of these were surfaced by run-retro; all were filed manually as problems.

## Root Cause Analysis

### Structural: Step 2 reflection categories are creation-centric

After P044, Step 2 in `packages/retrospective/skills/run-retro/SKILL.md` asks "What recurring workflow ... would be better as a skill?". P050 extends this to other shapes but keeps the verb ("better as", "become a new"). No category asks "what existing skill / agent / hook has a flaw we identified this session?".

### Structural: Step 4b's options assume create-or-problem-or-skip

Step 4b options (post-P044) are: Create new / Track as problem / Skip. P050 extends shape-wise but options stay create-centric. An improvement candidate that is not a problem ticket falls into a gap: the routing is create-or-else, so improvements default to problem-ticket.

### Structural: improvement observations per-output are not aggregated

If a session produces three improvements to `manage-problem`, each becomes a separate problem ticket. The session audit doesn't see "manage-problem needs 3 improvements" — it sees three unrelated tickets. Per-output aggregation would let the user (or a future `apply-improvements` skill) batch the edits coherently.

### Candidate fixes

1. **Add a Step 2 reflection category for improvements**: "Which existing skill / agent / hook / guide / ADR / script / workflow showed a flaw, gap, or friction this session that a targeted edit would fix?" Criteria: (a) flaw is reproducible / specific, (b) fix is a bounded edit to an existing file, (c) no new concept is being invented.

2. **Extend Step 4b's options** (or add a parallel Step 4c) for improvement candidates with per-shape routing:
   - **Skill improvement** → record as an improvement stub (suggested file, suggested edit summary, evidence); offer to file as a problem ticket if larger than a one-line edit.
   - **Agent improvement** → same pattern; suggested agent file + edit summary.
   - **Hook improvement** → same pattern.
   - **ADR supersede / amend** → route through `/wr-architect:create-adr` with a "supersedes ADR-N" hint.
   - **Guide edit (voice / style / risk / JTBD)** → route through the respective `update-guide` / `update-policy` skill.
   - **Script / CI improvement** → stub record.
   - **Problem ticket edit** → route through `/wr-itil:manage-problem <NNN>` (update flow).

3. **Aggregate by output** in Step 5 summary: an "Improvement Candidates" section grouped by target file (e.g. all `manage-problem/SKILL.md` improvements listed under one heading). Makes batchable edits visible.

4. **Auto-file threshold**: if a single output accumulates ≥ 3 improvements in one session, offer to open a coordinating problem ticket ("apply N improvements to X") rather than N separate tickets. Reduces ticket churn.

5. **Bats test**: assert Step 2 includes an improvement category and Step 4b/c routes improvements distinctly from creation. Mirrors the P044 test pattern.

Candidates 1 + 2 + 3 are the minimum viable fix. Candidate 4 is a nice-to-have discipline. Candidate 5 is the test discipline.

### Relationship to P044 / P050

- P044 solved the skill-creation shape (Fix Released).
- P050 extends P044 to other creation shapes (Open).
- P051 is the improvement axis across all shapes.

Together they cover the full recommendation matrix:

|                | Create new              | Improve existing |
|----------------|-------------------------|------------------|
| Skill          | P044 (Fix Released)     | P051 (this)      |
| Agent          | P050                    | P051 (this)      |
| Hook           | P050                    | P051 (this)      |
| ADR            | P050 (route to create)  | P051 (supersede / amend)  |
| Guide          | P050 (route to update)  | P051 (route to update)    |
| Script / CI    | P050                    | P051 (this)      |
| Problem ticket | (Step 4 already routes) | P051 (update flow)        |

The three tickets are best landed in order: P044 (done), P050, P051 — or P050+P051 landed together since their implementation touches the same Step 2 / Step 4b / Step 5 surfaces and batching avoids three rewrites.

### Interaction with P016 / P017 (multi-concern splitting)

The architect / jtbd review pattern that P016 / P017 enforce (concern-boundary splitting at intake) is arguably the creation-side mirror of this ticket's improvement side. When run-retro surfaces improvements, it should apply the same concern-boundary check: a proposed improvement that touches multiple unrelated concerns should split before routing. Note for the fix: reuse the P016 / P017 split prompt pattern rather than invent a new one.

### Investigation Tasks

- [ ] Architect review: decide whether to land P050 + P051 together (one SKILL.md rewrite covering both axes) or sequentially. Expected: together, since they share the Step 2 / 4b / 5 surface.
- [ ] Decide the Step 2 verb-mixing strategy. Candidate: keep the existing P044 "codification" category and add a parallel "improvement" category with its own examples.
- [ ] Enumerate improvement shapes and write an example per shape (2-3 sentences each). Mirror P050's shape list; add ADR-supersede and guide-edit as improvement-specific cases.
- [ ] Draft Step 4b / Step 4c for improvements with per-shape routing. Decide whether improvements + creations share one AskUserQuestion (with type as a first axis) or two parallel AskUserQuestion calls.
- [ ] Decide the Step 5 summary shape: flat Codification Candidates table with a `Kind` column (create / improve), OR two sub-sections.
- [ ] Draft the auto-file threshold logic (Candidate 4). Optional; keep behind an explicit AskUserQuestion prompt when triggered.
- [ ] Bats tests covering Step 2 improvement category, Step 4b/c improvement routing, and the aggregate-by-output summary. Extend `run-retro-skill-candidates.bats` or add a parallel file.
- [ ] Cross-check with this session's four improvement tickets (P047, P048, P049, P050) — would they have been surfaced cleanly by the proposed fix? If not, iterate the spec.
- [ ] Update P050 to reference P051 as the improvement-axis sibling. Keep P050 focused on creation so the concern-boundaries remain clean.

## Related

- P044: `docs/problems/044-run-retro-does-not-recommend-new-skills.known-error.md` — creation of skills (Fix Released).
- P050: `docs/problems/050-run-retro-does-not-recommend-other-codifiable-outputs.open.md` — creation of other shapes; P051 is the improvement-axis sibling.
- P046: `docs/problems/046-architect-agent-misses-performance-implications.open.md` — agent-shaped recommendation (mixed creation/improvement per its Candidate list).
- P047, P048, P049: all this session's improvement tickets for existing outputs; demonstrate the gap P051 names.
- P016: `docs/problems/016-manage-problem-should-split-multi-concern-tickets.known-error.md` — concern-boundary pattern to reuse for multi-concern improvements.
- P017: `docs/problems/017-create-adr-should-split-multi-decision-records.known-error.md` — same pattern in the ADR surface.
- P014: `docs/problems/014-aside-invocation-for-governance-skills.open.md` — aside-capture pattern for mid-session improvement recording.
- `packages/retrospective/skills/run-retro/SKILL.md` — primary fix target (Step 2 / 4b / 5 extensions alongside P050's changes).
- `packages/retrospective/skills/run-retro/test/run-retro-skill-candidates.bats` — bats test precedent.
- ADR-013: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — Rule 1 / Rule 6 apply to the improvement-routing AskUserQuestion too.
