# Risk R005: README / SKILL.md prose drifts from runtime behaviour

**Status**: Active
**Category**: brand
**Identified**: 2026-05-03
**Owner**: plugin-maintainer
**Last reviewed**: 2026-05-03
**Next review**: 2026-11-03

## Description

Adopter-facing documentation — package READMEs, SKILL.md prose, agent definitions — is hand-authored and ships to npm with each plugin release. The runtime behaviour it describes — hook firing patterns, skill workflows, gate marker semantics — evolves on every iteration of the development cycle. There is no architect-level gate, risk-scorer-level gate, or test-suite-level gate that detects when prose has drifted from current behaviour. The pressure stack that keeps code in sync with documented decisions has no equivalent for keeping documented prose in sync with code. Drift accumulates silently between releases and is realised by adopters reading a README that describes a prior version's behaviour.

Realised forms: a plugin README's hook table lists hooks that no longer exist (or omits hooks that do); a SKILL.md describes a workflow step that has been removed; an agent definition cites an ADR that has been superseded; the root README's package list cites a renamed package. ADR-051 audit on 2026-05-03 found ≥12 drift instances across 12 plugin READMEs. Cost of realisation: adopter loss of trust in the README as a contract; intake friction (adopter files a "bug" against documented-behaviour-that-no-longer-exists); AI-agent reading stale prose acts on out-of-date instructions and produces low-quality work.

## Inherent Risk

Impact × Likelihood *before* controls are applied.

- **Impact**: 4 (Significant — per `RISK-POLICY.md` Impact level 4: "Installed plugins degrade developer workflow — hooks fire incorrectly". From the adopter's perspective, when documented behaviour disagrees with runtime, the plugin "fires incorrectly" even if the runtime itself is correct — the adopter's mental model is broken)
- **Likelihood**: 4 (Likely — empirically observed across 12 of 12 plugin READMEs at audit time; no pressure mechanism currently detects drift)
- **Inherent Score**: 16
- **Inherent Band**: High

## Controls

- **Manual review at retro time** — `/wr-retrospective:run-retro` Step 2b surfaces doc-content concerns when retrospective participant flags them. Implemented in `packages/retrospective/skills/run-retro/SKILL.md`. Coverage is human-judgement-based; not deterministic.
- **JTBD-anchored README rule (Phase 1, advisory — partial coverage)** — ADR-051 mandates every `@windyroad/*` plugin README cites at least one current JTBD job ID; cited IDs must resolve under `docs/jtbd/<persona>/`. Phase 1 advisory script (sibling to P099 / P134 / P145 / P148 detectors) is filed but not yet shipped. Authority: ADR-051.
- **Maturity taxonomy (Phase 1, advisory only — no detector yet)** — ADR-053 defines the 5-band taxonomy; detection script is Phase 2 deferred.
- **Architect-on-edit review of plan documents** — when a plan or ADR is authored, architect agent reviews against existing decisions; catches some prose drift incidentally.
- **Capture-on-correction** — P078 contract: when adopter corrects the agent on documented-but-wrong behaviour, agent offers a problem ticket capturing the drift. Implemented in `packages/itil/hooks/itil-correction-detect.sh`.
- **The retroactive ADR-051 README refresh that landed alongside this risk file** — closes the 12 baseline drift instances detected at audit time.

## Residual Risk

Impact × Likelihood *after* controls are applied.

- **Impact**: 4 (Significant — controls reduce likelihood not impact; an adopter reading drifted prose still loses trust)
- **Likelihood**: 3 (Possible — ADR-051 retroactive refresh closes the baseline; ongoing drift persists pending Phase 2 advisory detector + Phase 4+ escalation per ADR-013 Rule 6)
- **Residual Score**: 12
- **Residual Band**: High
- **Within appetite?**: No (appetite threshold is 4 Low; residual of 12 High substantially exceeds)

## Treatment

**Mitigate**. Residual is above appetite and the impact category is Significant. Treatment requires the Phase 2 ADR-051 advisory detector to ship + the Phase 4+ escalation to a load-bearing gate per ADR-013 Rule 6 escalation pattern. Until then, retrospective-time manual review is the only recurring control. Accept High residual because (a) ADR-051 Phase 2 is the documented mitigation path, (b) the baseline drift has just been closed by the retroactive refresh, and (c) escalation to a CI-blocking gate is reserved for after the advisory detector accumulates evidence.

## Monitoring

- **Trigger to re-assess**: Any P-ticket reporting drift between documented and actual plugin behaviour. Phase 2 ADR-051 advisory detector emitting `drift_instances ≥ 2` across 3 consecutive `chore: version packages` releases (the documented escalation criterion). Any change to ADR-051 normative rules. Any plugin rename or skill split that touches multiple READMEs.
- **Metrics**: ADR-051 detector `TOTAL drift_instances=<K>` count per release (pending Phase 2); count of `realised: doc-drift` P-tickets per quarter; count of plugin READMEs missing a JTBD anchor.

## Related

- Criteria: `RISK-POLICY.md` (Impact level 4 — note the architect-review caveat: borderline 3/4; chose 4 because adopter mental-model breakage is workflow-degrading from the adopter's viewpoint regardless of runtime correctness)
- Realised-as: `docs/problems/152-no-pressure-or-nudge-for-documentation-currency.open.md` (originating ticket); the 12-instance audit baseline closed by the retroactive refresh that landed alongside this risk file
- Treatment ADRs: `docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`, `docs/decisions/053-plugin-maturity-taxonomy.proposed.md`, `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` (Rule 6 escalation pattern)
- Personas affected: `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md` (the job this risk directly degrades), `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md` (currency dimension extended to README-content currency per ADR-051), `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` ("clear patterns, not reverse-engineering" outcome is degraded when contributors must reverse-engineer runtime behaviour from source because docs disagree)

## Change Log

- 2026-05-03: Initial identification during pre-audit risk register sweep. Baseline drift count: 12 across 12 plugin READMEs (closed by the retroactive ADR-051 refresh in the same commit as this file).
