# R006: Published-package references source-tree-only paths and IDs

Plugins are authored in a monorepo where SKILL.md / agent.md / hook prose can freely reference repo-only artefacts (`docs/decisions/NNN-...md`, `docs/problems/PNNN`, `docs/jtbd/<persona>/JTBD-NNN-...md`, `RISK-POLICY.md`, sibling `packages/<other-plugin>/scripts/foo.sh`). When the plugin is published to npm, only `packages/<this-plugin>/` ships in the tarball; adopters install into their own project where those paths don't exist.

Three sub-classes:
- **Internal-ID leakage** (P137): unprefixed `ADR-NNN`/`JTBD-NNN`/`P-NNN` in published prose; resolves to UNRELATED IDs in adopter context (worst case) or doesn't resolve (best case).
- **Repo-relative path leakage** (P151): `bash packages/itil/scripts/foo.sh` hard-fails at adopter installs.
- **Publish-manifest drift** (P154): `bin/` shim exists in source but isn't in `package.json` `files` array → ships broken; source-tree-walking detectors miss this.

## Recogniser

**Path patterns** (any match → consider this entry):

- `packages/*/skills/*/SKILL.md`, `packages/*/skills/*/REFERENCE.md`
- `packages/*/agents/*.md`
- `packages/*/hooks/*.sh` (hook prose with internal references)
- `packages/*/README.md`
- `packages/*/package.json` (specifically `files` array)

**Diff-content keywords** (any match → consider):

- `bash packages/`, `cp packages/` (repo-relative path invocations)
- `ADR-[0-9]{3}`, `JTBD-[0-9]{3}`, `P[0-9]{3}` patterns NOT prefixed with `@windyroad/<plugin>:`
- `docs/decisions/`, `docs/jtbd/`, `docs/problems/`, `RISK-POLICY.md`, `CLAUDE.md` references in published-surface prose
- `"files": [` in package.json (especially additions/deletions)

**Anti-patterns** (looks like R006 but isn't):

- References inside `packages/<plugin>/docs/` (per-plugin internal docs that DO ship in the tarball) — those resolve correctly at adopter installs; not the leakage class.
- ADR/JTBD references prefixed with `@windyroad/<plugin>:` namespace per ADR-055 — explicitly publisher-scope.
- Cross-plugin internal references (e.g., `wr-itil` SKILL.md citing `@windyroad/risk-scorer:RISK_REGISTER_HINT:`) — agentic compositions; namespace prefix ensures resolvability.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Source-tree references introduced here |
| push | yes | cumulative |
| release | **primary** | Failure surfaces at adopter installation |
| external-comms | no | Not the outbound-prose lens (different surface than R001) |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 4 (Significant) — `RISK-POLICY.md` L64: "skills fail to load" / "installer breaks". Adopter hard-fail at Step 0 (path case) OR adopter agent applies mis-resolved-ID semantics (ID case).
- **Likelihood**: 5 (Almost certain) — pre-control state was P137 inherent 20 with "Almost certain"; production evidence: `@windyroad/itil@0.23.2 → 0.24.0` shipped broken bin shims for 5 versions before P154 detector caught it.
- **Inherent score**: 20
- **Inherent band**: Very High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| ADR-049 `$PATH bin/` shim pattern | Repo-relative `bash packages/...` is replaced by `wr-<plugin>-<command>` shim | 1 (sub-class: path leakage) | -1 likelihood for path class | Bump +1 for path-leakage sub-class |
| ADR-055 namespace-prefixed permalinks | Internal IDs in published prose use `@windyroad/<plugin>:` prefix | 2 (sub-class: ID leakage) | -1 likelihood for ID class | Bump +1 for ID-leakage sub-class |
| `check-namespace-prefix-leakage.sh` advisory at retro | Retro time | n/a (advisory not blocking) | 0 paths (post-hoc catch only) | n/a |
| P154 npm-pack-extension to detector | Detector runs against `npm pack` tarball output | 3 (sub-class: publish-manifest drift) | -1 likelihood for manifest class | Bump +1 for manifest-drift sub-class |
| `package.json` `files` array curation | Manual at PR time | n/a (manual discipline) | 0 paths | Bump +1 if `files` array not audited for this commit |

Lifetime residual likelihood across sub-classes: each sub-class has 1 specific path; project-wide weighted = 2 (Unlikely).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Commit adds new `packages/*/scripts/` files BUT `package.json` `files` array NOT updated | +2 | Canonical publish-manifest drift — source has it; tarball doesn't |
| Commit adds SKILL.md prose citing `bash packages/<plugin>/scripts/foo.sh` without ADR-049 shim | +1 | Path-leakage sub-class direct hit |
| Commit adds SKILL.md prose with bare `ADR-NNN` token (no `@windyroad/<plugin>:` prefix) | +1 | ID-leakage sub-class direct hit |
| New `packages/<plugin>/` directory (a new plugin) being added | +1 | No prior `files` array discipline; high risk of manifest drift in v0.1 |
| Commit edits ONLY `packages/<plugin>/docs/` (per-plugin docs that DO ship) | -1 | These references resolve in tarball; not the leakage surface |
| `npm pack` was run + output inspected for this commit | -1 | Empirical evidence of correct manifest |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 2 (Unlikely) — three independent paths covering different sub-classes; residual reflects sub-class coverage gaps + advisory (not blocking) nature.
- **Residual score**: 8
- **Residual band**: Medium — above appetite.

**Above appetite** because the controls are mostly **advisory at retro time**, not commit-blocking. Production evidence: `@windyroad/itil@0.23.2 → 0.24.0` shipped 5 broken-shim versions before P154 detector caught it. Phase-2 promotion to commit-blocking (per the P159 / ADR-051 load-bearing-from-the-start pattern) drops residual to 1 → score 4 / Low.

## Watch-out

- The three sub-classes have very different controls — map the report's specifics to the right sub-class:
  - hard-fail at Step 0 of a skill → repo-relative path → ADR-049 shim missing.
  - adopter agent applies mis-resolved ID → internal-ID → ADR-055 prefix missing.
  - bin shim missing in tarball but present in source → publish-manifest → `files` array gap, P154 detector.
- Don't assume "we have ADR-049, we're safe" — file-array regression only surfaces in tarball, not source.
- Hook prose changes that ship under `patch` but actually shift behaviour are also R010 (semver) territory; flag both.

## See also

- **Generalisation**: R009 (functional defects) — R006 is the publish-boundary specialisation.
- **Sibling**: R010 (semver violation) — under-classification of behavioural changes that crossed publish boundary.
- **Drivers / ADRs**: P137 (ID-leakage), P151 (script-path leakage), P154 (npm-pack-extension), ADR-049 (`$PATH bin/`), ADR-055 (namespace-prefixed permalinks), ADR-014 (commit grain).
