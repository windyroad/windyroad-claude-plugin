# Problem 076: WSJF scoring in manage-problem does not model transitive dependencies

**Status**: Verification Pending
**Reported**: 2026-04-21
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M — amend `packages/itil/skills/manage-problem/SKILL.md` WSJF Prioritisation section to define the transitive-dependency rule: a dependent ticket's effort is the max of (own marginal effort, transitive closure of upstream dependencies' efforts). Add a worked example. Amend Step 9b (review re-assess) to walk the dependency graph and propagate effort up. Add bats doc-lint assertions for the new rule. Cross-cutting with review behaviour; no new ADR strictly required because the WSJF section is the canonical location — but a short sibling ADR (or ADR-014-adjacent amendment) is a candidate if the dependency-graph mechanics need wider coverage across the skill suite.
**WSJF**: 4.5 — (9 × 1.0) / 2 — Medium severity (the queue silently lies about what's actionable, but the value is delivered in individual fixes not in queue-accuracy); moderate effort (SKILL.md edit + review-step extension + bats).

## Description

`/wr-itil:manage-problem` WSJF Prioritisation section defines:

> **WSJF = (Severity × Status Multiplier) / Effort**
>
> **Effort** (estimated fix size — smaller effort = higher priority): S (1) / M (2) / L (4) / XL (8).

Effort is scored **per-ticket** as if the ticket were independent. Nothing in the section addresses what happens when a ticket has **transitive dependencies** on other tickets.

User observation (this session, 2026-04-21, verbatim): *"P073 is WSJF 6, but is blocked on P038 which is WSFJ 1.5. It doesn't make sense for a ticket to have a higher WSJF than a ticket it's dependant on, does it? I mean specifically, the accumulated work for P073 MUST be more than the tickets it depends on because ALL of that work needs to be done before P073 can be considered done."*

The observation is sound. If P073 cannot reach the "done" state without P038 being done first, then the **effort to close P073 includes all of P038's effort plus P073's marginal effort**. But the WSJF section treats P073's effort as its own marginal work only (M = 2), producing WSJF 6.0. P038 meanwhile has its own effort (XL = 8) and WSJF 1.5.

This is arithmetically incoherent: a ticket cannot be "higher priority" than a ticket whose work is strictly contained within it.

## Symptoms

- **Queue lies about actionability.** The dev-work ranking shows P073 at WSJF 6.0 — a "top of queue" signal — but P073 is not actionable because P038 is not done. An agent iterating the queue top-to-bottom tries to work P073, discovers it's blocked, and either skips (wastes an iteration slot) or tries to drag P038 into the work (scope explosion).
- **Cross-comparison is misleading.** A user scanning the backlog sees P073 ranked above P038 / P064 / P014 / P018 / P022 etc. and might reasonably conclude P073 is more urgent. The ranking is supposed to drive the "what to do next" decision; it drives the wrong one.
- **Dependent-ticket pattern recurs.** P073 is not the only ticket with transitive dependencies. Other instances in the current backlog:
  - **P070** — composes with P064 (external-comms leak evaluator). Currently WSJF 6.0; P064 is WSJF 3.0. If P070 is truly bundled with P064 (per P070's "Dependency on P064" note), P070 should be WSJF ≤ 3.0.
  - **P071 phased-landing** (future slices) — `work-problem` split depends on `review-problems` being split first (the work operation invokes the review step). That future slice should carry `review-problems` effort in its transitive closure.
  - **P038 / P064** — both feed P073 AND each other (shared gate surface). Circular-ish; needs explicit dependency-graph modelling.
- **Effort re-estimation rule (P047) is incomplete.** P047's bucket-change guidance covers scope-expansion on a single ticket but not transitive-scope induced by newly-recognised dependencies.

## Workaround

**Per-ticket manual re-rate** (applied to P073 this session): when a blocking dependency is noticed, edit the ticket's Effort line to XL (or the max bucket on the transitive chain) and add a note citing the dependency. WSJF recomputes automatically. This works for individual tickets the user happens to notice, but it's manual — and re-running `manage-problem review` should detect and apply the same rule mechanically across the full backlog.

## Impact Assessment

- **Who is affected**:
  - **AFK orchestrators (JTBD-006)** — `work-problems` iterates the WSJF queue top-down. Mis-ranked tickets produce wasted iterations (agent picks a "highest" ticket that turns out to be blocked).
  - **Solo-developer persona (JTBD-001)** — "enforce governance without slowing down" fails when the prioritisation lens itself is unreliable; the user double-checks every highest-WSJF pick before trusting the queue.
  - **Tech-lead persona (JTBD-201)** — audit trail of "what the ranking said" becomes untrustworthy; post-hoc rationalisation ("we worked P038 first because we realised P073 depended on it") is required instead of ranked-execution.
- **Frequency**: every `manage-problem review` that produces a ranking. The severity compounds with backlog size — more tickets = more chances for an undetected dependency to distort the queue.
- **Severity**: Medium. The queue still functions for self-contained tickets (majority); the failure is localised to dependent tickets but systemic when it happens.
- **Analytics**: N/A today; post-fix, the review output could report "N tickets re-rated up for transitive-dependency effort" so the before/after correction is visible.

## Root Cause Analysis

### Structural

`packages/itil/skills/manage-problem/SKILL.md` WSJF Prioritisation section (lines 55–94 at time of writing) is designed for per-ticket independent scoring:

- Severity, Status Multiplier, Effort are all attribute columns on a single ticket.
- Step 9b (review re-assess) iterates tickets one at a time and scores each independently.
- There is no cross-ticket graph traversal, no dependency awareness, no effort propagation.

The assumption was that each ticket is self-contained. For most tickets this holds — problems get opened as discrete friction-reports. But the suite has grown to include **surface-extension tickets** (e.g. P073 = "extend P038's gate surface to a new path") and **phased-landing execution tickets** (e.g. P071's slice chain). These are fundamentally dependent.

### The missing rule

The correct rule (stated formally):

**For any dependent ticket T with upstream dependency set D(T):**

- `Effort(T)_transitive = max(Effort(T)_marginal, max{ Effort(U)_transitive | U ∈ D(T) })`
  — i.e. the larger of T's own marginal effort OR the largest transitive effort in T's dependency tree.
- `WSJF(T) = (Severity(T) × StatusMultiplier(T)) / Effort(T)_transitive`
  — i.e. WSJF uses the transitive effort, not the marginal.

**Consequence**: `WSJF(T) ≤ min{ WSJF(U) | U ∈ D(T) }` when Severity(T) ≤ Severity(U). More precisely, T cannot be ranked above U if T depends on U AND their severities are comparable AND U's effort is in the transitive closure of T's effort.

(The general statement is "T's WSJF ≤ U's WSJF / Severity-ratio adjustment", which makes the bound tighter or looser depending on whether T has higher or lower value than U. For the common case of surface-extensions where T inherits value from U's surface, T's severity is ≤ U's and the simple bound holds.)

### Candidate fix

**1. Add a `## Dependencies` section to the problem-ticket template.**

Per-ticket explicit dependency list so the graph is legible:

```markdown
## Dependencies

- **Blocks**: <tickets that can't close until this one does>
- **Blocked by**: <tickets that must close first>
- **Composes with**: <tickets whose work overlaps but neither blocks the other>
```

Empty-list case is fine (default: no dependencies). The `Blocked by` field is the one that drives the transitive-effort rule.

**2. Amend the WSJF Prioritisation section with the transitive-effort rule.**

Add a new subsection after the existing Effort table:

```markdown
### Transitive dependencies (P076)

When a ticket lists `Blocked by: P<M>, P<N>, ...` in its `## Dependencies` section, the ticket's "to-done" effort includes all of the upstream dependencies' transitive closure. Use the transitive effort to compute WSJF:

  Effort(T)_transitive = max(
    Effort(T)_marginal,
    max{ Effort(U)_transitive | U ∈ Blocked_by(T) }
  )

Rationale: a dependent ticket cannot reach its "done" state without the upstream work happening first. Scoring the dependent at its marginal-only effort lies about what it costs to deliver.

**Worked example**: P073 marginal effort is S (one surface-row add). P073 is blocked by P038 (XL). Effort(P073)_transitive = max(S, XL) = XL. WSJF(P073) = 12 / 8 = 1.5, matching P038's WSJF.

**Note**: `Composes with` dependencies do NOT propagate effort — compositions share surface but do not strictly block.

**Note**: when a dependency closes, re-rate the dependent ticket's effort (its transitive closure shrinks). Re-rating during `manage-problem review` catches this automatically.
```

**3. Extend Step 9b (review) with a dependency-graph traversal.**

After scoring each ticket's marginal effort, run a second pass:

1. Build the dependency graph from each ticket's `## Dependencies` section.
2. Topologically sort so upstream tickets are scored first.
3. For each ticket in topological order, compute transitive effort using the rule above.
4. Update the ticket's Effort and WSJF lines if the transitive value differs from the marginal.
5. Report each transitive re-rate in the review summary so the user sees the graph effect.

Handle cycles (P038 / P064 composition) by treating them as one bundle: the bundle's effort is the max of its members' marginal efforts; bundle members share a WSJF.

**4. Add bats doc-lint assertions for the rule.**

Per ADR-037 contract-assertion pattern:
- SKILL.md's WSJF section names "transitive" or "dependency" in the heading.
- The worked example is present.
- Step 9b describes the graph traversal.
- The problem-ticket template (Step 5) includes the `## Dependencies` section.

**5. Audit existing backlog for unmodeled dependencies.**

One-time pass on `docs/problems/*.open.md` + `*.known-error.md` to add `## Dependencies` sections where implicit dependencies are noted in prose (e.g. P073's Description mentions P038/P064; P070's Direction decision section mentions P064; P071 phased-landing plan mentions internal slice ordering).

### Open design questions (architect review at implementation time)

- **Q1**: Should `## Dependencies` use bare IDs (`P038`) or cross-links (`[P038](./038-...)`)? Lean: bare IDs — less maintenance, manage-problem can render to links on demand in the review output.
- **Q2**: Should the WSJF transitive-effort rule be in manage-problem's SKILL.md only, or elevated to RISK-POLICY.md / a dedicated ADR? Lean: SKILL.md first (single source of truth for WSJF scoring) + short note in RISK-POLICY.md if scoring mechanics belong there. Full ADR only if other plugins adopt the convention.
- **Q3**: How to detect forgotten `## Dependencies` entries? Candidate: bats doc-lint scans `## Description` / `## Root Cause` sections for "blocked on P<NNN>" / "depends on P<NNN>" / "requires P<NNN>" prose and flags if the corresponding `## Dependencies` row is missing. Out-of-scope for the core fix; tracked as a follow-up enhancement.
- **Q4**: Should status transitions on upstream tickets auto-refresh downstream WSJF? e.g. when P038 closes, P073's transitive effort drops. Lean: defer the auto-refresh to the next `review` run (cheap, already periodic); don't fire transition-time graph re-walks (complexity cost not justified for a weekly-cadence review).

### Investigation Tasks

- [ ] Draft the `## Dependencies` template addition for new problem creation (Step 5).
- [ ] Draft the WSJF Prioritisation transitive-dependency subsection.
- [ ] Draft the Step 9b graph-traversal pseudocode.
- [ ] Architect review: Q1-Q4 above; decide ADR scope.
- [ ] Add bats doc-lint assertions per ADR-037 pattern.
- [ ] Audit pass on current backlog: identify implicit dependencies, add `## Dependencies` sections.
  - Initial implicit-dep observations (to verify during the audit): P070 blocks-on P064; P073 blocks-on P038 + P064; P071 phase-landing slices have internal serial deps (work-problem depends on review-problems).
- [ ] Exercise end-to-end: run `manage-problem review`; confirm the transitive re-rate fires on P073; confirm WSJF matches P038 by construction.

## Fix Released

Released in `@windyroad/itil` (next minor bump after 0.16.0 — this commit). One-sentence summary: the WSJF Prioritisation section now defines a transitive-effort rule driven off `## Dependencies` `**Blocked by**` edges; the review pass (Step 2.5 in `review-problems`, Step 9b.1 in `manage-problem`) topologically walks the graph, propagates effort, writes an `<!-- transitive: <bucket> via <UPSTREAM> -->` audit comment, and reports each re-rate as `P<NNN>: Effort <OLD> → <NEW> (transitive via <UPSTREAM>)`. Carve-outs: `.closed.md` / `.verifying.md` / `.parked.md` upstreams contribute 0; `**Composes with**` does not propagate; cycles bundle with shared WSJF as a computed artefact.

**Investigation tasks status**:
- [x] Draft the `## Dependencies` template addition for new problem creation (Step 5).
- [x] Draft the WSJF Prioritisation transitive-dependency subsection.
- [x] Draft the Step 9b graph-traversal pseudocode.
- [x] Architect review: Q1-Q4 answered in this session (Q1 bare IDs; Q2 SKILL.md-first with reassessment-criteria note; Q3 deferred as follow-up; Q4 deferred to next review run — no transition-time re-walk).
- [x] Add bats doc-lint assertions per ADR-037 pattern — plus 6 behavioural fixture tests exercising the closure algorithm directly.
- [ ] **DEFERRED (follow-up ticket)**: Audit pass on current backlog — add `## Dependencies` sections to P070, P073, P071 phased-landing slices, P038 / P064 mutual-composition. Per architect guidance, audit is a separate commit to keep this one focused on the mechanism.
- [ ] **DEFERRED (user-verification)**: Exercise end-to-end on the live backlog; confirm the transitive re-rate fires on P073; confirm WSJF matches P038 by construction.

Awaiting user verification. Review the Transitive dependencies subsection in `packages/itil/skills/manage-problem/SKILL.md`, the Step 2.5 graph traversal in `packages/itil/skills/review-problems/SKILL.md`, and run `/wr-itil:review-problems` on a backlog that contains at least one `## Dependencies` relationship to observe the re-rate fire.

## Related

- **P073** (`docs/problems/073-no-voice-tone-or-risk-gate-on-changeset-authoring.open.md`) — the motivating instance. Re-rated M → XL, WSJF 6.0 → 1.5 in the same commit that filed this ticket.
- **P070** — additional candidate for transitive re-rate (composes with P064).
- **P071** — phased-landing slices have internal serial dependencies; audit pass must capture them.
- **P047** — effort bucket re-rating rule. P076 extends P047 to the transitive-scope-induced case.
- **ADR-014** — governance skills commit their own work; review re-rates land on a single `docs(problems): review — re-rank priorities` commit.
- **ADR-037** — contract-assertion bats pattern for the new rule's SKILL.md additions.
- `packages/itil/skills/manage-problem/SKILL.md` — target of the WSJF section amendment + Step 9b extension + Step 5 template change.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — ranking must not lie; that's part of the governance-without-slowing-down promise.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — AFK orchestrators need a trustworthy queue to iterate top-down.
- **JTBD-201** (`docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md`) — audit trail of ranking decisions becomes meaningful once WSJF reflects transitive reality.
