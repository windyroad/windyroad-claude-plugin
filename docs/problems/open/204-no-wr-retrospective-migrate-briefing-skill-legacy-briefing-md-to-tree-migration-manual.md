# Problem 204: No /wr-retrospective:migrate-briefing skill — legacy docs/BRIEFING.md → docs/briefing/ tree migration is manual

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

> **new-jtbd-flag** (per JTBD classifier): the proposed skill addresses **adopter-artefact-layout-currency** — a third currency dimension not covered by JTBD-007 today (which scopes code-currency + README-content-currency only). Maintainer decision: amend JTBD-007 to extend currency scope (recommended) OR add new JTBD-009 (Migrate Adopter Artefacts When a Plugin's Layout Evolves).

## Description

The `wr-retrospective` plugin (v0.18.1) ships the dual-tolerant SessionStart hook (`packages/retrospective/hooks/session-start-briefing.sh`) per `P100 slice 2 / ADR-040`. The hook silently no-ops when `docs/briefing/README.md` is absent and reads from it when present, supporting both the legacy single-file `docs/BRIEFING.md` and the new per-topic `docs/briefing/` tree.

What's missing: an automation path for adopters carrying legacy `docs/BRIEFING.md` to migrate to `docs/briefing/`. Dual-tolerant read paths buy time, but a migration command closes the loop.

## Workaround

Manually split `docs/BRIEFING.md` into topic files under `docs/briefing/` per the documented layout. Error-prone and tedious for adopters with substantial briefing content.

## Impact Assessment

- **Who is affected**: every adopter project that carries legacy `docs/BRIEFING.md` from a prior `@windyroad/retrospective` release.
- **Frequency**: one-time per adopter, deferred indefinitely without an automation path.
- **Severity**: Low (dual-tolerant read keeps adopters working; only blocks the per-topic-rotation contract per Tier 3 envelope).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Architect call: amend JTBD-007 (recommended — extend currency scope a third time: code + README + artefact-layout) OR new JTBD-009 (Migrate Adopter Artefacts).
- [ ] Ship `/wr-retrospective:migrate-briefing` skill: parse legacy `docs/BRIEFING.md`, split by section headings (## / ### topic markers), write per-topic files under `docs/briefing/<topic>.md`, commit standalone with `RISK_BYPASS: legacy-briefing-migration` trailer.
- [ ] Behavioural fixture: temp dir with synthetic legacy `docs/BRIEFING.md`; assert migration produces expected per-topic file set.

## Dependencies

- **Composes with**: P100 slice 2 (dual-tolerant SessionStart hook), ADR-040 (per-topic rotation), ADR-051 (README-content-currency), JTBD-007 (Keep Plugins Current).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/117
- **Pipeline classification**: aligned-with-new-JTBD-for-existing-persona (cache_audit_note: new-jtbd-flag); safe-low-fix-risk; route=safe-and-valid + flag.
- **Affected plugin**: @windyroad/retrospective.
