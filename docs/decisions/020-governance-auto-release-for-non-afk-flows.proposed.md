---
status: "proposed"
date: 2026-04-19
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-07-19
---

# Governance skills auto-release when changesets are queued

## Context and Problem Statement

Governance skills under ADR-014 (`manage-problem`, `manage-incident`) commit their own completed work — a commit with a changeset is produced by the skill itself at the end of step 11. That commit then sits in the local working tree waiting for the user to run `npm run push:watch` and `npm run release:watch` before the fix lands on npm.

For AFK orchestrators, ADR-018 already solves this: Step 6.5 in `work-problems` runs `wr-risk-scorer:assess-release` after each iteration commit and drains the push/release queue when cumulative pipeline risk reaches appetite. Live evidence from 2026-04-18 (P040/P041 release cycles) shows the pattern works non-interactively.

What ADR-018 does not cover — and this ADR does — is the non-AFK governance invocation path. When a user runs `/wr-itil:manage-problem` or `/wr-itil:manage-incident` directly (outside `work-problems`), step 11 / the terminal commit step ends at `git commit`. The user must remember to release. The result is either (a) silent changeset accumulation across multiple non-AFK skill invocations, or (b) extra user attention per fix, undermining the "under 60 seconds" target in JTBD-001 and the "must not leave task context" persona constraint in JTBD-005.

P028 (Governance skills should auto-release after completing fixes) is the problem ticket this ADR resolves.

## Decision Drivers

- **Lean release principle (ADR-014)**: governance skills commit their own work; the natural extension is that the same skills release their own work when a changeset is queued. AFK orchestrators already do this (ADR-018); non-AFK flows are the remaining gap.
- **Pure-scorer contract (ADR-015)**: scoring logic lives in the scorer skills; skills must delegate, not re-implement.
- **Non-interactive authorisation (ADR-013 Rule 6)**: `push:watch`/`release:watch` are policy-authorised when residual risk is within appetite per `RISK-POLICY.md` — no `AskUserQuestion` is required for the release itself.
- **JTBD-001 (Enforce Governance Without Slowing Down)**: under-60-second target; manual release is a 1-3 minute interruption per fix.
- **JTBD-005 (Invoke Governance Assessments On Demand)**: must not leave task context; manual release requires switching to terminal commands.
- **Symmetry with ADR-018**: AFK and non-AFK governance flows should have the same release behaviour where safe. Divergence between the two modes erodes operator trust.
- **P028**: the open problem this ADR resolves.

## Considered Options

1. **New ADR citing ADR-014 + ADR-018 as lineage (chosen)** — a separate decision document mirroring ADR-018's symmetric pattern. Keeps ADR-014 focused on "commit their work".
2. **Amend ADR-014 in place** — extend ADR-014's step sequence and Confirmation to include push+release. ADR-014 is still `.proposed.md`, so amendment is structurally possible.
3. **Rely on the user remembering to release after non-AFK skill runs (status quo)** — no change.
4. **Shared release-helper skill / script** — extract the push+release sequence into a shared helper invoked by each governance skill.

## Decision Outcome

Chosen option: **"New ADR citing ADR-014 + ADR-018 as lineage"**, because it follows the precedent set by ADR-018 (symmetric decision, separate file, cited lineage) and preserves single-purpose ADRs. ADR-014 stays focused on "commit their work"; ADR-020 covers "drain the queue after commit for non-AFK flows".

Amending ADR-014 was rejected because ADR-018 was already carved out as its own decision — amending ADR-014 now would be inconsistent and would expand its scope beyond the commit layer. A shared helper skill was rejected as premature (only two skills currently qualify; a helper becomes worthwhile once a third in-scope skill is added — see Reassessment Criteria).

### Scope

**In scope (this ADR):**

- `packages/itil/skills/manage-problem/SKILL.md` (step 11 terminal commit sequence)
- `packages/itil/skills/manage-incident/SKILL.md` (terminal commit step in the Report section)

**Out of scope for now (inherited once adopted):**

- `packages/architect/skills/create-adr/SKILL.md`
- `packages/retrospective/skills/run-retro/SKILL.md`
- `packages/jtbd/skills/update-guide/SKILL.md`
- `packages/risk-scorer/skills/update-policy/SKILL.md`

These skills are out of scope for ADR-014 today and therefore do not yet have the `work → score → commit` sequence that ADR-020 extends. When a future ADR brings them into ADR-014 scope, they inherit ADR-020 automatically and must add the post-commit release step alongside the commit step.

### Mechanism

After the skill's `git commit` step lands, the same terminal step MUST continue with:

1. **Delegate to the release scorer** — two paths are valid (per ADR-015):
   - **Primary**: subagent type `wr-risk-scorer:pipeline` via the Agent tool.
   - **Fallback**: skill `/wr-risk-scorer:assess-release` via the Skill tool. The skill wraps the same pipeline subagent.
2. **Read the returned** `RISK_SCORES: commit=X push=Y release=Z` line.
3. **Drain condition** — if `push` or `release` is within appetite (≤ 4/25, "Low" band per `RISK-POLICY.md`) AND `.changeset/` is non-empty, proceed to drain.
4. **Drain action (non-interactive, policy-authorised per ADR-013 Rule 6):**
   - Run `npm run push:watch` (push + wait for CI).
   - If `.changeset/` is non-empty after push (i.e. there is an outstanding release), run `npm run release:watch` (merge the release PR + wait for npm publish).
5. **Failure handling** — if `release:watch` fails (CI failure, publish failure), stop and report the failure. Do not retry non-interactively.
6. **Above-appetite branch (superseded by ADR-042 2026-04-23)** — if push/release risk is above appetite (≥ 5/25), the skill MUST auto-apply scorer remediations incrementally until residual risk is within appetite, OR halt the skill per ADR-042 Rule 5 if the scorer cannot produce a convergent plan. The skill MUST NOT release above appetite under any circumstance. The skill MUST NOT call `AskUserQuestion` as a shortcut out of the auto-apply loop. See ADR-042 for the full rule set (Rules 1–7), the open vocabulary (Rule 2a), the Verification Pending carve-out (Rule 2b), and the halt-on-exhaustion semantics (Rule 5). The prior "Release skipped — run manually when ready" text is retired.

Scope is **per-skill**: unlike ADR-018's loop-level rule, ADR-020 fires once per governance skill invocation after that invocation's single commit. It does not iterate. When ADR-042 Rule 2's auto-apply loop fires inside a non-AFK skill invocation, each auto-apply is its own commit (ADR-042 Rule 3 — no iteration wrapper to fold into).

### Amendment 2026-05-15 — Graduatable held-changeset disjunct (ADR-061 Rule 8)

The Mechanism above predicates the drain condition (step 3) on `.changeset/` non-empty. This amendment adds a symmetric disjunct per **ADR-061 (Dogfood graduation criteria for held changesets — symmetric risk balance drives the reinstate decision)** Rule 8 so the drain wakes when graduation-eligible material exists in `docs/changesets-holding/` even when `.changeset/` is empty. The combined amended drain condition reads:

```
Drain when: pipeline residual ≤ 4/25 AND
            (.changeset/ non-empty OR
             docs/changesets-holding/ contains entries that satisfy ADR-061 Rule 1
             AND are not VP-blocked per ADR-061 Rule 2)
```

Step 3 of the Mechanism is amended to read: *"**Drain condition** — if `push` or `release` is within appetite (≤ 4/25, "Low" band per `RISK-POLICY.md`) AND (`.changeset/` is non-empty OR `docs/changesets-holding/` contains entries that satisfy ADR-061 Rule 1 graduation criterion AND are not VP-blocked per ADR-061 Rule 2), proceed to drain."* Step 4 (Drain action) gains a preceding sub-step: *"Graduatable held entries are first reinstated to `.changeset/` via `git mv` per ADR-061 Rule 6 audit-trail discipline (the skill report logs the pre-apply / post-apply scores, the evidence-artefact citation, the resolved problem-ticket ID + Priority value, and the graduation class)."*

Rationale: symmetric to ADR-018's 2026-05-15 amendment. The non-AFK governance path inherits the same empty-conjunct coupling failure mode observed in I002 (2026-05-11): when ADR-042 Rule 2/6 auto-apply moves every changeset to holding, the `.changeset/` non-empty conjunct silently silences the drain. Adding the graduatable-holding disjunct closes the coupling at the drain-condition layer; ADR-061 Rule 1's symmetric never-hold-below-graduation-threshold invariant ensures held entries become graduation-eligible when release-risk decays at or below problem-ticket Priority. The per-skill / once-per-invocation scope is otherwise unchanged. Above-appetite behaviour remains governed by ADR-042 per step 6. P162 (`docs/problems/open/162-codify-dogfood-graduation-criteria-with-counterfactual-risk-assessment-for-held-changesets.md`) Phase 4 lands this amendment.

### Non-interactive authorisation

Per ADR-013 Rule 6, `npm run push:watch` and `npm run release:watch` are policy-authorised actions when the risk-scorer reports residual risk within appetite. No `AskUserQuestion` is required for the release itself. The fail-safe applies only when residual risk is above appetite or when CI/publish fails.

## Consequences

### Good

- Non-AFK governance flows now match AFK behaviour: commit → score → drain when safe. Reduces mode divergence and operator surprise.
- Unreleased changesets stop accumulating silently across non-AFK skill invocations.
- User no longer pays a 1-3 minute manual-release tax per governance fix, directly serving JTBD-001's under-60-second target.
- Release decision is delegated to the scorer (ADR-015 single source of truth), not re-implemented per skill.
- Fail-safe path (above appetite, CI failure) is consistent with ADR-018.

### Neutral

- Governance skill invocations take longer when a release fires (push + CI + npm publish — typically 1-3 minutes). For the solo-developer persona, this is still faster than remembering to release later.
- The terminal step of in-scope skills gains a post-commit sequence that must be kept in sync with ADR-018's Step 6.5.

### Bad

- A flaky CI or npm publish fails the skill's release step. The commit stands; the release is deferred to manual action. Mitigated by the fail-safe (stop and report).
- Two skill files (manage-problem, manage-incident) must be updated in lockstep to pick up the new pattern; drift between them is possible. Mitigated by the source-review Confirmation item below.
- Auto-install is explicitly not addressed — see P045 (auto plugin install after governance release) for why this is deferred.

## Confirmation

Compliance is verified by:

1. **Source review**: the terminal commit step of each in-scope skill references `assess-release` AND `push:watch` AND `release:watch` in the correct order:
   - `packages/itil/skills/manage-problem/SKILL.md` (step 11)
   - `packages/itil/skills/manage-incident/SKILL.md` (terminal commit step under "Report")
2. **Test**: a bats test asserts that `packages/itil/skills/manage-problem/SKILL.md` references both `assess-release` and `release:watch` in its step-11 post-commit sequence. The same test asserts the pattern in `manage-incident/SKILL.md`. This test may be deferred to P012 (skill testing harness) alongside ADR-014's deferred test.
3. **Behavioural**: a non-AFK invocation of `/wr-itil:manage-problem` that produces a commit with a changeset triggers `push:watch` + `release:watch` automatically when push/release risk is within appetite. Verifiable by inspecting the release log of any non-AFK governance skill run.

## Reassessment Criteria

Revisit this decision if:

- ADR-014 or ADR-018 is superseded, which would break the lineage assumption.
- `push:watch` / `release:watch` are removed or renamed in `package.json`.
- Claude Code gains in-session plugin reload — at that point P045's auto-install concern becomes viable and may fold back into ADR-020 or its successor.
- A third in-scope governance skill adopts ADR-014 — at that point consider extracting the post-commit release sequence into a shared helper skill rather than maintaining three+ copies.
- Operational data shows the post-commit release step reliably fails — might indicate release reliability rather than the rule.

## Related

- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — commit layer; ADR-020 extends the terminal step with a release layer
- ADR-018: `docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md` — AFK release cadence; this ADR is the symmetric non-AFK decision following the same pattern
- ADR-015: `docs/decisions/015-on-demand-assessment-skills.proposed.md` — pure-scorer contract; defines the Agent-vs-Skill fallback for delegation
- ADR-013: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — Rule 6 provides the non-interactive authorisation basis for `push:watch`/`release:watch`
- ADR-019: `docs/decisions/019-afk-orchestrator-preflight.proposed.md` — AFK preflight (loop-start); ADR-020 operates post-commit, a different lifecycle phase
- P028: `docs/problems/028-governance-skills-should-auto-release-and-install.known-error.md` — problem ticket this ADR resolves
- P045: `docs/problems/045-auto-plugin-install-after-governance-release.open.md` — split-out auto-install concern (deferred)
- ADR-061: `docs/decisions/061-dogfood-graduation-criteria.proposed.md` — symmetric outflow contract for held changesets; Rule 8 amends §3 drain condition (2026-05-15 amendment above)
- P162: `docs/problems/open/162-codify-dogfood-graduation-criteria-with-counterfactual-risk-assessment-for-held-changesets.md` — driver ticket for the 2026-05-15 amendment (Phase 4)
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-005: `docs/jtbd/solo-developer/JTBD-005-assess-on-demand.proposed.md`
- JTBD-006: `docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`
