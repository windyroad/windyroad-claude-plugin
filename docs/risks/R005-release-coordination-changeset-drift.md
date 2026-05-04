# R005: Release-coordination / changeset queue drift

The monorepo ships ~10 plugins via Changesets; each plugin is independently versioned but often coupled. Drift takes several forms: changeset for plugin A without coupled changeset for dependent plugin B; multiple accumulated `.changeset/*.md` files trigger an unintended release-PR shape; Case-1 multi-slice WIP changeset that should stay in `docs/changesets-holding/` leaks into `.changeset/` and auto-publishes; "patch" bump on a SKILL.md amendment that's actually behavioural.

Cross-plugin coupling is structurally common because agentic compositions span plugin boundaries.

## Recogniser

**Path patterns** (any match → consider this entry):

- `.changeset/*.md`
- `docs/changesets-holding/*.md`
- `packages/*/CHANGELOG.md`
- `packages/*/package.json` (version field — usually managed by changesets-action, but manual edits flag here)

**Diff-content keywords** (any match → consider):

- `"@windyroad/*": minor`, `: major`, `: patch` (changeset frontmatter)
- "held-area", "reinstate", "multi-slice"
- (a commit touching `packages/*/source` that does NOT include a paired `.changeset/*.md`)

**Anti-patterns** (looks like R005 but isn't):

- A "patch"-bumped changeset for hook-prose that's actually behavioural → that's the **R010** (semver violation) sub-class; flag both R005 and R010.
- A changeset moved between `.changeset/` and `docs/changesets-holding/` as a deliberate held-area / reinstate operation — that's a control fire, not a regression.
- Bundled-changeset push (multiple bumps land together) when bumps are semantically independent — NORMAL, don't flag.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Changeset declaration / queue change happens here |
| push | **primary** | Bundled-bump release-PR shape revealed at push |
| release | yes | Wrong-bump-class consequences land at adopter sites |
| external-comms | no | Internal coordination class |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 3 (Moderate) — `RISK-POLICY.md` L63: "npm publish or marketplace distribution disrupted — users can't install updates". Mismatched cross-plugin versions land at adopters under `^` semver and produce subtle errors.
- **Likelihood**: 3 (Possible) — multi-plugin coordination is structurally complex; held-area inventory historically runs ~3 concurrent.
- **Inherent score**: 9
- **Inherent band**: Medium

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| `itil-changeset-discipline.sh` (P141) | `git commit` includes `packages/*/source` change | 1 | -1 likelihood (forces classification surface to exist) | Hard-block; if bypassed `BYPASS_CHANGESET_GATE=1`, bump +2 |
| `docs/changesets-holding/` held-area pattern (ADR-042 Rule 7) | Multi-slice WIP changeset moved to held area with reinstate trigger | 2 | -1 likelihood | Bump +1 (multi-slice WIP without parking) |
| ADR-014 single-commit grain | Source change pairs with its changeset in one commit | 3 | -1 likelihood | Bump +1 (intra-commit coupling lost) |
| ADR-042 auto-apply remediations | Above-appetite push residual triggers `move-to-holding` | n/a (orchestrator) | 0 paths (only fires above-appetite) | n/a |
| Held-area README "Currently held" / "Recently reinstated" tables | Always (declarative audit-trail) | n/a (audit trail) | 0 paths | Lower visibility |

Lifetime residual likelihood = 1 (Rare; capped at floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| `BYPASS_CHANGESET_GATE=1` was used (env var bypass) | +2 | Gate effectively didn't fire; classification surface skipped |
| Held-area inventory >5 concurrent (dogfood pipeline congestion) | +1 | Each held bump is a coordination liability |
| Cross-commit coupling (a feature spans 2-3 commits each with own changeset) | +1 | Per-commit gate sees one slice at a time; can't catch coupling across slices |
| Multi-slice WIP changeset that should be in held area is in `.changeset/` | +1 | Will auto-publish on next release-watch |
| Bundled-changeset push of N≥3 bumps where author hasn't reviewed coupling | +1 | Surprise-bump-set risk |
| Changeset declares same package twice (duplicate frontmatter) | +1 | Coordination tool error; merge resolution may clip one |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — three independent paths stack to capped reduction.
- **Residual score**: 3
- **Residual band**: Low — within appetite.

**At appetite**. Controls stack working.

## Watch-out

- "Bundled-changeset push surprise" (multiple pending bumps land together) is NORMAL when bumps are semantically independent — don't flag as risk.
- Held-area inventory >5 concurrent signals dogfood pipeline congestion (steady-state ~3).
- Cross-commit coupling bypasses the per-commit gate; manual review is the only catch.
- Sub-class: a `chore`-bumped changeset that's actually `feat` — under-classification. R010 catches the semver dimension; R005 catches the queue-shape dimension.

## See also

- **Sibling**: R010 (semver violation) — under-classification of bump class is R010's territory; R005 is queue-shape coordination.
- **Generalisation**: R009 (functional defects) — coordination drift is a functional defect at the release process level.
- **Drivers / ADRs**: P141, P162 (codify dogfood-graduation criteria), P104 (painted-into-corner), P085/P064/P159 (concurrent held exemplars), ADR-014, ADR-018, ADR-020, ADR-042 (Rule 7).
