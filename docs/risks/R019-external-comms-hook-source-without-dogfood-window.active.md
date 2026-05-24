# Risk R019: External Comms Hook Source Without Dogfood Window

**Status**: Active (auto-scaffolded — pending review)
**Category**: <!-- pending review — auto-scaffolded from pipeline hint -->
**Identified**: 2026-05-17
**Owner**: pending review
**Last reviewed**: 2026-05-17
**Next review**: 2026-05-17
**Curation**: pending review (auto-scaffolded 2026-05-17)

## Description

Hook source change replacing cached-key derivation across 2 plugins shipping single-commit without held-changeset dogfood; R003 modulator stack lands at 8/25 even with bats + architect-twice + ADR-056 dual-parse because no in-commit runtime exercise of external-comms surface

> Auto-scaffolded by the Phase 2b drain (ADR-056) from a `wr-risk-scorer:pipeline`
> RISK_REGISTER_HINT bullet. The description is the agent's prefill; scoring
> fields below carry the ADR-026 ungrounded-output sentinel until human curation.

## Inherent Risk

Impact × Likelihood *before* controls.

- **Impact**: not estimated — no prior data
- **Likelihood**: not estimated — no prior data
- **Inherent Score**: not estimated — no prior data
- **Inherent Band**: not estimated — no prior data

## Controls

- pending review — controls to be enumerated during curation.

## Residual Risk

Impact × Likelihood *after* controls.

- **Impact**: not estimated — no prior data
- **Likelihood**: not estimated — no prior data
- **Residual Score**: not estimated — no prior data
- **Residual Band**: not estimated — no prior data
- **Within appetite?**: pending — scoring not estimated

## Treatment

pending review — treatment decision deferred until scoring is curated.

## Monitoring

- **Trigger to re-assess**: any new pipeline hint with this risk_slug
- **Metrics**: count of `.risk-reports/` entries citing this slug

## Related

- Criteria: `RISK-POLICY.md`
- Realised-as: <!-- link to docs/problems/P<NNN> when known -->
- Treatment ADRs: <!-- link to docs/decisions/ADR-<NNN> when treatment lands -->

## Evidence Log

Auto-populated from `.risk-reports/` via Phase 2b drain.

- 2026-05-16T06:28:35Z: fired in `.risk-reports/2026-05-16T06-28-35-commit.md` (reason: above-appetite-residual)

## Change Log

- 2026-05-17: Auto-scaffolded by Phase 2b drain (ADR-056). Pending human curation.
