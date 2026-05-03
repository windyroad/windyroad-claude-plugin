# Risk R003: Installer corrupts user's Claude Code config

**Status**: Active
**Category**: operational
**Identified**: 2026-05-03
**Owner**: plugin-maintainer
**Last reviewed**: 2026-05-03
**Next review**: 2026-11-03

## Description

Each `@windyroad/*` plugin's installer (`packages/<plugin>/install.mjs`, dispatched by `npx @windyroad/<plugin>`) writes into the adopter's `.claude/settings.json` to register hooks, agents, and permissions. The same installer is invoked by the `@windyroad/agent-plugins` meta-installer in batch mode. A defect in the merge logic — clobbering the adopter's existing entries, dropping unrelated keys, mis-parsing comments, or producing invalid JSON — silently corrupts the adopter's primary Claude Code configuration file and every session opened against that config will misbehave or fail to start.

Realised forms: install.mjs writes a malformed JSON document; uninstaller removes more keys than it added; meta-installer race condition when two plugins write the same file concurrently; settings.json schema migration breaks an older adopter's legacy shape. Cost of realisation includes adopter trust loss (hard to recover), manual recovery via backup or `.claude/settings.json.bak`, and reputation impact if the corruption is reproducible across multiple installs.

## Inherent Risk

Impact × Likelihood *before* controls are applied.

- **Impact**: 5 (Severe — per `RISK-POLICY.md` Impact level 5: "Installer silently corrupts user's Claude Code config, publishes packages with malicious/broken bin scripts, or leaks npm auth tokens via CI logs")
- **Likelihood**: 2 (Unlikely — settings-merge logic is centralised in `packages/shared/install-utils/` and has behavioural bats coverage; precedent of one realised incident — P047 install-updates overriding adopter governance files)
- **Inherent Score**: 10
- **Inherent Band**: High

## Controls

- **Centralised install utilities** — every plugin's installer dispatches the same merge primitives in `packages/shared/install-utils/`. A fix lands once, every plugin benefits. Implemented under `packages/shared/`.
- **Behavioural bats coverage of merge / write paths** — fixtures simulate adopter-side `settings.json` shapes (empty, present-with-other-plugins, malformed, with comments, with overrides) and assert the post-install shape. Implemented under `packages/shared/install-utils/test/*.bats`. Authority: ADR-052.
- **Backup-on-write convention** — installers keep a `.claude/settings.json.bak` for one-step recovery. Implemented in shared install utilities.
- **Marker semantics for governance artefact scaffolding** — ADR-009 markers prevent the installer from overwriting adopter-authored governance files (per ADR-047). Implemented in `packages/<plugin>/install.mjs` and shared utilities.
- **Architect + risk-scorer commit gates** — installer changes go through governance review. Implemented in `packages/architect/hooks/architect-enforce-edit.sh` and `packages/risk-scorer/hooks/risk-score-commit-gate.sh`.
- **`--dry-run` flag** — adopters can preview installer behaviour before committing to a write. Implemented in shared install entrypoint.

## Residual Risk

Impact × Likelihood *after* controls are applied.

- **Impact**: 5 (Severe — controls reduce likelihood not impact; a corruption that slips through is still Severe)
- **Likelihood**: 1 (Rare — centralised merge code, backup convention, marker semantics, and bats coverage make occurrence very unlikely)
- **Residual Score**: 5
- **Residual Band**: Medium
- **Within appetite?**: No (appetite threshold is 4 Low; residual of 5 Medium exceeds)

## Treatment

**Mitigate**. Residual is above appetite because the impact category is Severe and a single realised event would damage adopter trust significantly. Maintain centralised merge code, expand bats coverage on adopter shapes seen in the wild, and keep the backup-on-write convention. Accept Medium residual because driving Likelihood below Rare would require pre-publication adopter-side integration testing — not feasible without dedicated CI.

## Monitoring

- **Trigger to re-assess**: Any P-ticket reporting installer-induced config corruption or settings.json malformation. Any change to the shared install utilities. Any change to ADR-009 marker semantics. Any change to Claude Code's settings.json schema.
- **Metrics**: Count of installer P-tickets per release; count of adopter-reported uninstall-restore-from-backup events.

## Related

- Criteria: `RISK-POLICY.md` (Impact level 5)
- Realised-as: `docs/problems/047-install-updates-overrides-adopter-governance-files.verifying.md` (the only known prior realised incident — drove ADR-009 marker semantics + ADR-047 install-updates contract)
- Treatment ADRs: `docs/decisions/009-gate-marker-semantics.proposed.md`, `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md`, `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`
- Personas affected: `docs/jtbd/solo-developer/persona.md` (silent config corruption is the persona's named pain point), `docs/jtbd/plugin-user/persona.md` (low context — adopter cannot recover without backup)

## Change Log

- 2026-05-03: Initial identification during pre-audit risk register sweep.
