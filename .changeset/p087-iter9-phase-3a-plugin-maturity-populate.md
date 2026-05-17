---
"@windyroad/itil": minor
---

feat(itil): ship `wr-itil-plugin-maturity-populate` (P087 Phase 3a)

Adds the population script that writes the `plugin.json` `maturity:` field
per surface and per plugin root from Phase 2 NDJSON (consumes
`wr-itil-skill-invocations` + `wr-itil-plugin-exercise-index`). Applies
ADR-053 §promotion criteria + §Bootstrapping clause; idempotent;
exit-0-always per ADR-013 Rule 6. ADR-044 silent-framework carve-out
honoured — no `AskUserQuestion` per band recompute.

Surface inventory discovered from filesystem under `packages/<plugin>/`
(`skills/`, `agents/`, `hooks/`, `commands/`); per-surface key
normalisation matches ADR-058's Phase 2a Bash-attribution pattern.
Hooks emit `invocations_30d: null` sentinel (not transcript-observable;
band derived from git axis only per architect adjustment C).
Bootstrapping clause sunset auto-derives from `max(days_shipped)` — no
calendar-date hard-code per architect adjustment D. Author-declared
`Deprecated` records (with `supersededBy:` pointer) preserved across
re-runs per ADR-053 §Confirmation #6 and architect adjustment I.

Ships under ADR-049 shim grammar (`packages/itil/bin/wr-itil-plugin-maturity-populate`).
Behavioural bats fixture (17 tests) covers ADR-063 §Confirmation criteria
1-3 (idempotency, bootstrapping vs steady-state band mapping, no
`AskUserQuestion` per band recompute) plus schema-shape / rollup
worst-case / hook null-sentinel / Deprecated-overlay preservation /
fail-safe missing-input / no-network-primitive negative-grep.

Phase 3a unblocks Phase 3b (P238 — renderer + drift detector). Phase 3a
retroactive rollout across the live monorepo composes with Phase 3b per
P087 line 133.
