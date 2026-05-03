# Risk R002: Hook regression breaks installed users' workflow

**Status**: Active
**Category**: operational
**Identified**: 2026-05-03
**Owner**: plugin-maintainer
**Last reviewed**: 2026-05-03
**Next review**: 2026-11-03

## Description

The `@windyroad/*` plugins inject behaviour into adopters' Claude Code sessions through `UserPromptSubmit`, `PreToolUse`, and `PostToolUse` hooks. A regression in any hook — false-positive block, infinite loop, mis-parsed input, missing dependency — directly degrades the workflow of every project that has the plugin installed. Unlike server-side software where the maintainer can roll forward, an adopter sitting at a broken `claude` session has no straightforward path to "downgrade" without uninstalling and reinstalling the plugin.

Realised forms: a `PreToolUse:Edit` hook that misclassifies a path and blocks legitimate edits; a `UserPromptSubmit` hook that times out and fails the prompt; a `PostToolUse` hook that crashes and leaves a stale gate marker; a `check-deps.sh` that fails-closed when a dependency is present but mis-detected. Each prevents the adopter from working until they discover the breakage and intervene manually.

## Inherent Risk

Impact × Likelihood *before* controls are applied.

- **Impact**: 4 (Significant — per `RISK-POLICY.md` Impact level 4: "Installed plugins degrade developer workflow — hooks fire incorrectly, skills fail to load, or installer breaks for users who already have the packages")
- **Likelihood**: 3 (Possible — hook surface is broad; bats coverage is uneven across 30+ hooks; behaviour depends on caller environment which the hook cannot fully control)
- **Inherent Score**: 12
- **Inherent Band**: High

## Controls

- **Behavioural bats coverage** — every hook has at least one bats fixture exercising its happy path. Implemented under `packages/<plugin>/hooks/test/*.bats`. Authority: ADR-052 (behavioural tests default).
- **`check-deps.sh` per dependent plugin** — `@windyroad/itil` and `@windyroad/retrospective` warn at session start when transitive dependencies are missing. Implemented in `packages/itil/hooks/check-deps.sh` (referenced from hooks.json) and `packages/retrospective/hooks/check-deps.sh`.
- **Architect + risk-scorer commit gates** — every hook change goes through governance review before commit. Implemented in `packages/architect/hooks/architect-enforce-edit.sh` and `packages/risk-scorer/hooks/risk-score-commit-gate.sh`.
- **Marker semantics with TTL** — gate markers expire after 3600s preventing permanent lock-out from a hook regression. Implemented across `packages/<plugin>/hooks/*-mark-reviewed.sh`. Authority: ADR-009 (marker semantics).
- **`/install-updates` skill** — adopters can refresh stale plugin code in one command after a fix is published. Implemented in `.claude/skills/install-updates/`. Authority: ADR-047.
- **`BYPASS_*` environment-variable overrides** — adopters can bypass a misbehaving gate as a last resort while a fix lands.

## Residual Risk

Impact × Likelihood *after* controls are applied.

- **Impact**: 4 (Significant — controls reduce likelihood not impact; a regression that slips through still degrades workflow)
- **Likelihood**: 2 (Unlikely — bats coverage and gate review catch most regressions before merge)
- **Residual Score**: 8
- **Residual Band**: Medium
- **Within appetite?**: No (appetite threshold is 4 Low; residual of 8 Medium exceeds)

## Treatment

**Mitigate**. Residual is above appetite because installed-plugin regressions affect every adopter's session. Continue investing in behavioural bats coverage (ADR-052), keep marker TTL short, and ship `/install-updates` as the recovery path. Accept Medium residual because dropping below appetite would require pre-publication manual integration testing on an adopter project — not feasible without dedicated CI infrastructure.

## Monitoring

- **Trigger to re-assess**: Any hook regression that reaches an adopter session (P-ticket with `realised: hook-regression` tag). Any change that introduces a new hook surface. Any breaking change in Claude Code's hook event API.
- **Metrics**: Count of P-tickets categorised as hook-regression per quarter; count of `BYPASS_*` overrides observed in `.risk-reports/` per month.

## Related

- Criteria: `RISK-POLICY.md` (Impact level 4)
- Realised-as: `docs/problems/077-work-problems-step-5-does-not-delegate-to-subagent.verifying.md`, `docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.open.md`, `docs/problems/146-afk-iteration-subprocess-bash-until-loop-polls-bats-output-with-bats-console-regex-against-tap-format.verifying.md` (each is a hook-or-skill regression that affected adopter workflow)
- Treatment ADRs: `docs/decisions/009-gate-marker-semantics.proposed.md`, `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md`, `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`
- Personas affected: `docs/jtbd/solo-developer/persona.md` (silent config corruption is named pain point), `docs/jtbd/plugin-user/persona.md` (low context on repo internals — adopter cannot self-diagnose), `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` (audit-trail outcome is degraded when hook regressions corrupt or silently bypass audit-trail capture)

## Change Log

- 2026-05-03: Initial identification during pre-audit risk register sweep.
