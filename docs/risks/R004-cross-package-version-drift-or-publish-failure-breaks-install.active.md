# Risk R004: Cross-package version drift or publish failure breaks install

**Status**: Active
**Category**: delivery
**Identified**: 2026-05-03
**Owner**: plugin-maintainer
**Last reviewed**: 2026-05-03
**Next review**: 2026-11-03

## Description

The `@windyroad/*` plugin suite has hard cross-package dependencies — `@windyroad/itil` requires `@windyroad/risk-scorer`; `@windyroad/retrospective` requires both. Versions are published independently via Changesets. A release that bumps one package without coordinated bumps to its dependents — or a partial publish where one package reaches the npm registry but a dependent does not — leaves adopters in an undefined state: `npx @windyroad/<plugin>` may install but fail at runtime when calling into a sibling that does not export the expected interface, or the meta-installer (`@windyroad/agent-plugins`) may pin to a version combination that does not actually exist on npm.

Realised forms: changeset created for plugin A but not its dependent plugin B; `npm publish` succeeds for A but fails for B leaving the registry mid-state; `@windyroad/agent-plugins` package metadata pins to a version that has never been released; cross-package interface drift (A v0.10 calls B method that B v0.9 does not export). Cost of realisation: broken installs for adopters running `npx @windyroad/agent-plugins` for the first time, manual `npm unpublish` window (24-72 hours), version-skip remediation patch.

## Inherent Risk

Impact × Likelihood *before* controls are applied.

- **Impact**: 3 (Moderate — per `RISK-POLICY.md` Impact level 3: "npm publish or marketplace distribution disrupted — users can't install updates")
- **Likelihood**: 3 (Possible — multiple cross-dependencies; manual changeset authorship; observed near-misses during AFK release cadence)
- **Inherent Score**: 9
- **Inherent Band**: Medium

## Controls

- **Changesets workflow** — every release requires a changeset declaring the affected packages and bump types. Implemented under `.changeset/` and `package.json` scripts. Authority: ADR-021.
- **`check-deps.sh` runtime warning** — at session start, dependent plugins warn when their transitive dependencies are missing. Implemented in `packages/itil/hooks/check-deps.sh` and `packages/retrospective/hooks/check-deps.sh`.
- **Changeset-discipline gate** — `git commit` is gated when source-package changes lack an accompanying changeset. Implemented in `packages/itil/hooks/itil-changeset-discipline.sh`. Authority: P141.
- **`release:watch` waits for npm publish** — release pipeline waits for npm and surfaces partial-publish failures rather than silently completing. Implemented in `npm run release:watch`.
- **Above-appetite holds** — `docs/changesets-holding/` defers release when residual risk would exceed appetite, preventing premature partial publish. Authority: ADR-042.
- **Provenance signing** — npm provenance signatures detect tampered or partial publishes downstream.

## Residual Risk

Impact × Likelihood *after* controls are applied.

- **Impact**: 3 (Moderate — controls reduce likelihood not impact; a publish failure that slips through still disrupts installs)
- **Likelihood**: 2 (Unlikely — changeset gate + release:watch surface most failures before they reach adopters)
- **Residual Score**: 6
- **Residual Band**: Medium
- **Within appetite?**: No (appetite threshold is 4 Low; residual of 6 Medium exceeds)

## Treatment

**Mitigate**. Residual is above appetite because partial publish recovery requires `npm unpublish` within 72 hours and adopter notification — both are operationally expensive. Continue investing in the changeset-discipline gate and release:watch coverage. Accept Medium residual because a tighter pre-publish dependency-resolution check would require dry-running every adopter install scenario in CI — not feasible at current infrastructure scale.

## Monitoring

- **Trigger to re-assess**: Any P-ticket reporting failed `npx @windyroad/<plugin>` install. Any partial publish event in `release:watch` output. Any change to the changesets toolchain. Any new cross-package dependency declared in `packages/<plugin>/package.json`.
- **Metrics**: Count of release-watch failures per quarter; count of `@windyroad/agent-plugins` install failures reported by adopters; count of `npm unpublish` events.

## Related

- Criteria: `RISK-POLICY.md` (Impact level 3)
- Realised-as: (none yet — this is a pre-emptive standing risk; near-misses observed in AFK release cadence drove the changeset-discipline gate per P141)
- Treatment ADRs: `docs/decisions/021-changesets-for-releases.proposed.md`, `docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`
- Personas affected: `docs/jtbd/solo-developer/persona.md` (plugin-version drift across sibling projects is named pain point), `docs/jtbd/plugin-user/persona.md` (low context — adopter cannot diagnose cross-package dependency mismatch)

## Change Log

- 2026-05-03: Initial identification during pre-audit risk register sweep.
