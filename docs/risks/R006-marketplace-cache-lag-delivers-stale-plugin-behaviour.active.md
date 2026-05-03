# Risk R006: Marketplace cache lag delivers stale plugin behaviour

**Status**: Active
**Category**: delivery
**Identified**: 2026-05-03
**Owner**: plugin-maintainer
**Last reviewed**: 2026-05-03
**Next review**: 2026-11-03

## Description

Per ADR-003, `@windyroad/*` plugins distribute via the Claude Code marketplace cache rather than direct file installation. When a release lands on npm, adopter sessions running against a stale marketplace cache continue to load the prior version's hooks, skills, and agents until the cache refreshes — which does not happen automatically on every prompt. An adopter who reads a README describing the latest behaviour may experience the prior release's behaviour because their session has not yet picked up the new cached artefacts. Worse, partial-cache states where some artefacts have refreshed but others have not produce inconsistent runtime behaviour that is hard to diagnose.

Realised forms: hook A loads the new code, hook B loads the old code, gate marker semantics disagree between them; adopter installs `@windyroad/<plugin>@latest` but session continues running cached @prior-version code; SKILL.md prose loads from new cache but supporting agent definition loads from old cache. P106 (silent no-op of `claude plugin install`) was a realised incident in this class.

## Inherent Risk

Impact × Likelihood *before* controls are applied.

- **Impact**: 4 (Significant — per `RISK-POLICY.md` Impact level 4: "Installed plugins degrade developer workflow")
- **Likelihood**: 3 (Possible — cache refresh is implicit in Claude Code's marketplace distribution model; observed P106 silent no-op; multiple adopter projects on the same machine compound the issue)
- **Inherent Score**: 12
- **Inherent Band**: High

## Controls

- **`/install-updates` skill** — refreshes the marketplace cache and re-installs all `@windyroad/*` plugins in the current project plus every sibling project. Implemented in `.claude/skills/install-updates/`. Authority: ADR-047.
- **End-of-session prompt to run `/install-updates`** — release-loop close instruction surfaces the refresh command. Implemented in `install-updates` skill description.
- **Changesets-driven release versioning** — every published version bumps the package metadata so adopters can see their installed version vs the latest. Authority: ADR-021.
- **Restart-Claude-Code surfacing** — install-updates explicitly calls out the session-restart requirement so cached code is reloaded.
- **Single-plugin update path** — `npx @windyroad/<plugin> --update` provides a per-plugin escape hatch when the meta-update fails.

## Residual Risk

Impact × Likelihood *after* controls are applied.

- **Impact**: 4 (Significant — controls reduce likelihood not impact; an adopter running stale cache still degrades workflow)
- **Likelihood**: 2 (Unlikely — `/install-updates` is well-exercised; ADR-047 + ADR-007 marketplace cache contract; remaining likelihood is the "user forgets to run /install-updates" residual)
- **Residual Score**: 8
- **Residual Band**: Medium
- **Within appetite?**: No (appetite threshold is 4 Low; residual of 8 Medium exceeds)

## Treatment

**Mitigate**. Residual is above appetite because cache-lag is structural to the marketplace distribution model — the fix would require a session-start prompt that runs `/install-updates` automatically. Continue surfacing `/install-updates` at end-of-release loops and at session start. Accept Medium residual because automatic refresh on every session start would burn cache + tokens for the common case where no update has shipped, and adopters with stable plugins do not want forced refresh latency.

## Monitoring

- **Trigger to re-assess**: Any P-ticket reporting stale-cache-induced misbehaviour. Any change to the marketplace cache invalidation contract. Any change to `/install-updates` semantics. Any change to how Claude Code resolves plugin artefact paths.
- **Metrics**: Count of `realised: cache-lag` P-tickets per quarter; count of `/install-updates` invocations per release cycle (proxy for adopter-side refresh hygiene).

## Related

- Criteria: `RISK-POLICY.md` (Impact level 4)
- Realised-as: `docs/problems/106-claude-plugin-install-silent-noop-leaves-old-code-in-place.verifying.md` (the P106 silent no-op incident drove ADR-047 install-updates contract)
- Treatment ADRs: `docs/decisions/003-marketplace-only-distribution.proposed.md`, `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md`, `docs/decisions/007-marketplace-cache.proposed.md`
- Personas affected: `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md` (the job this risk directly degrades), `docs/jtbd/plugin-user/persona.md` (low context — adopter cannot self-diagnose cache-vs-source mismatch)

## Change Log

- 2026-05-03: Initial identification during pre-audit risk register sweep.
