# Problem 244: Phase 3 (F9) `wr-itil-plugin-maturity-list` in-suite display shim — reads installed plugins' plugin.json maturity field, emits NDJSON-per-surface + rollup-per-plugin

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Phase 3 (F9) `wr-itil-plugin-maturity-list` in-suite display shim — reads installed plugins' plugin.json maturity field via marketplace-cached path per ADR-003, emits NDJSON-per-surface + rollup-per-plugin. ADR-063 §F9 names this as a Phase 3 contract (NOT a deferred follow-on) per architect adjustment A2 to ADR-063 itself. P087 iter-9 architect review (2026-05-17) reaffirmed Phase 3a scope as strict per ADR-014 commit-grain and explicitly carved out F9 as a separate sibling ticket — this ticket — so the deliverable does not get lost. Sibling to P237 (Phase 3a — population script), P238 (Phase 3b — renderer + drift detector), P239 (Phase 3c — bats doc-lint), P240 (Phase 3d — JTBD amendments). Captured per architect adjustment E in P087 iter-9.

The shim composes with the eventual upstream `claude plugin list` extension when it ships — the upstream extension can adopt the same NDJSON shape. Until then, F9 is the adopter-facing machine-readable rollup view across installed plugins.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Author `packages/itil/scripts/plugin-maturity-list.sh` canonical body — discovers installed `@windyroad/*` plugins via marketplace-cached `~/.claude/plugins/cache/<owner>/<plugin>/<version>/.claude-plugin/plugin.json` per ADR-003; reads each `maturity:` field; emits NDJSON one record per surface (with `kind` ∈ `{skill, agent, hook, command, plugin-rollup}`) plus one rollup record per plugin. `schema_version: "1.0"` on every record.
- [ ] Author `packages/itil/bin/wr-itil-plugin-maturity-list` shim per ADR-049 grammar.
- [ ] Author bats fixture covering ADR-063 §Confirmation criteria 7 (NDJSON shape: one record per surface + one rollup per plugin; `schema_version: "1.0"` on every record; exit 0 always) and 8 (no network primitive — negative-grep). Behavioural per ADR-052.
- [ ] Stderr-comment fallback (ADR-013 Rule 6) — no `@windyroad/*` plugins installed / marketplace cache inaccessible / all installed plugins missing `maturity:` field all hit the zero-records path with stderr-comment, exit 0.
- [ ] Decide marketplace-cache discovery mechanism: glob `~/.claude/plugins/cache/*/*/`+latest-version-resolution vs `claude plugin list --json` parse. Architect review on the discovery contract.

## Dependencies

- **Blocks**: (none — F9 is independent of Phase 3b / 3c / 3d ordering)
- **Blocked by**: P237 (Phase 3a populates the `plugin.json` `maturity:` field this shim reads). Until P237 lands and is rolled out across installed plugins, the shim reads empty / missing fields and hits the stderr-comment fallback.
- **Composes with**: P087 (parent), ADR-063 §F9 (Phase 3 contract), ADR-058 §Confirmation #8 (schema_version precedent), ADR-049 (shim grammar), ADR-003 (marketplace-cached read path), ADR-013 Rule 6 (fail-safe).

## Related

- P087 — parent: no maturity / battle-hardening signal on plugins, skills, agents, or hooks.
- ADR-063 — Phase 3 presentation-layer contract; §F9 names this shim as Phase 3 contract.
- ADR-053 — Phase 1 taxonomy.
- ADR-058 — Phase 2 measurement scripts; §Confirmation #8 schema_version precedent.
- ADR-003 — marketplace-only distribution; read path for installed plugin.json.
- ADR-049 — bin shim grammar.
- ADR-013 Rule 6 — non-interactive fail-safe.
- ADR-052 — behavioural bats coverage.
- P237 — Phase 3a (writer); blocks this ticket via populated `plugin.json`.
- P238 — Phase 3b (README renderer + drift detector); sibling.
- P239 — Phase 3c (bats doc-lint per plugin); sibling.
- P240 — Phase 3d (JTBD outcome amendments); sibling.
