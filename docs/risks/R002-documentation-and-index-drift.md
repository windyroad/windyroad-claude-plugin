# R002: Documentation / index / cross-reference drift across docs

Multiple docs that should agree about a fact (skill names, ADR numbers, sort-spec, lifecycle suffix, render-block contracts) drift apart over commits. In agentic systems, documentation IS runtime-active configuration — agents read SKILL.md / README.md / agent.md every invocation — so drift produces wrong agent behaviour, not just confused human readers.

Sub-classes: README index drift from filesystem; ticket lifecycle rename without paired README update; ADR-vs-ADR inconsistency; SKILL.md sort-spec drift across N render-block sites; truncation discipline misapplied across multiple SKILL.md surfaces.

## Recogniser

**Path patterns** (any match → consider this entry):

- `*/README.md` (any plugin or repo-local README)
- `packages/*/skills/*/SKILL.md`, `packages/*/skills/*/REFERENCE.md`
- `packages/*/agents/*.md`
- `docs/decisions/*.md`
- `docs/jtbd/*/JTBD-*.md`
- `docs/problems/README.md` (the ticket index)
- `CLAUDE.md`, `RISK-POLICY.md`

**Diff-content keywords** (any match → consider):

- `sort by`, `tie-break`, `render`, `lifecycle suffix`, `WSJF`, `Verification Queue`
- ADR-NNN tokens / JTBD-NNN tokens / R/PNNN tokens that move (added or removed) when the referenced file's content changes
- "Last reviewed" lines (P134 truncation discipline)

**Anti-patterns** (looks like R002 but isn't):

- A single-doc edit that doesn't touch any cross-references → not drift; just a routine doc edit.
- Drift where the cause is a published-package referencing repo-only paths → score as **R006** (publish-boundary), not R002.
- "Doc-only ticket capture introduces stale metadata" surfaced in `.risk-reports/` is incident-level (one ticket file) — not a cross-doc drift class; **skip**.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | **primary** | Drift introduced or detected at commit time |
| push | yes | cumulative; cross-session drift detected on next reconcile preflight |
| release | yes | cumulative; published prose drift reaches adopters |
| external-comms | no | not an outbound-prose class |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 3 (Moderate) — drift causes wrong agent behaviour but typically degrade-not-corrupt; per L63.
- **Likelihood**: 4 (Likely) — without load-bearing detectors, drift accumulates monotonically.
- **Inherent score**: 12
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| P159 commit-hook (`retrospective-readme-jtbd-currency.sh`) | Commit touches a JTBD-anchored README without paired update | 1 (sub-class: JTBD-anchored README) | -1 likelihood for that sub-class | Bump +1 for JTBD-README sub-class |
| P062/P094/P118 reconcile contracts on `docs/problems/README.md` | Ticket transition / create / drift detected | 2 (sub-class: ticket-index) | -1 likelihood for that sub-class | Bump +1 for ticket-index sub-class |
| Architect / JTBD review on every Edit/Write | Project-file edit | 3 (broad path) | -1 likelihood, broad coverage | Bump +1 broadly |
| P134 line-3 truncation discipline | `docs/problems/README.md` line 3 edited | n/a (sub-class hygiene) | 0 paths (impact-shaping) | Risk of accumulator regression |
| `check-namespace-prefix-leakage.sh` (advisory) | Retro time | n/a | 0 paths (advisory not blocking) | n/a (catches at retro, not commit) |

Lifetime residual likelihood across all sub-classes: covered sub-classes (JTBD + ticket-index) → 1; uncovered sub-classes (ADR-vs-ADR, sort-spec across N render-block sites) → 2-3.

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Single-file edit, no cross-references touched | -1 | Cross-doc drift requires multi-doc coupling; single-file can't introduce it |
| Edit touches a JTBD-anchored README | 0 (covered by P159 hook) | Load-bearing detector fires |
| Edit touches `docs/problems/README.md` | 0 (covered by P062/P094/P118) | Reconcile contracts fire |
| Edit touches ≥2 ADRs that reference each other | +1 | ADR-vs-ADR drift sub-class has only retro-time advisory coverage |
| Edit touches a SKILL.md render-block (sort-spec / table-render / etc.) without paired updates to other render sites | +1 | Render-block-across-N-sites class is uncovered (P138/P150-style) |
| Commit message includes "render", "sort", "tie-break" | +1 (consider whether ALL render sites updated) | Author often touches one site without the others |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 2 (Unlikely) — covered sub-classes drop to 1; uncovered sub-classes stay at 2-3; weighted across class = 2.
- **Residual score**: 6
- **Residual band**: Medium — above appetite.

**Above appetite** because uncovered sub-classes (ADR-vs-ADR, sort-spec drift across N render-block sites) have only retro-time advisory coverage. Adding load-bearing detectors per the P159 / ADR-051 pattern (P161 generalisation) drops residual to 1 → score 3 / Low.

## Watch-out

- New render-block sites added to one SKILL.md without paired updates to the other N sites is the canonical regression mode (P138 WSJF tie-break sort sites; P150 VQ sort direction sites).
- ADR-045 vs ADR-038 type inconsistencies — when one ADR documents a pattern that contradicts another's, agents reading either get conflicting guidance.
- Truncation discipline (P134) is sub-class-specific to `docs/problems/README.md`; novel surfaces with similar accumulator-prose-line risk aren't yet protected.

## See also

- **Generalisation**: R009 (functional defects) — R002 is the doc-drift specialisation.
- **Sibling**: R006 (publish-boundary divergence) — drift between published prose and source-tree references is its own class.
- **Drivers / ADRs**: P051, P158, P159, P161, P138, P150, P118, P134, ADR-051 amended (load-bearing-from-the-start clause).
