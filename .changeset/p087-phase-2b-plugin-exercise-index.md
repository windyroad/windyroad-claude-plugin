---
"@windyroad/itil": minor
---

P087 Phase 2b — ship `wr-itil-plugin-exercise-index` script + shim covering the git-history axis of ADR-058's plugin-maturity measurement mechanism. Sibling to Phase 2a's `wr-itil-skill-invocations` transcript-axis surface.

Runs `git log --reverse --name-only --pretty=format:%H|%aI|%s` once at the project root, auto-discovers plugins by listing `packages/*/`, emits one NDJSON record per plugin to stdout. Schema v1.0 fields: `schema_version`, `axis`, `plugin`, `commits_window`, `window_days`, `days_shipped`, `closed_tickets_window`, `tickets_window_days`, `breaking_change_age_days`, `composite_index`. Window cutoff applied in-Python against `%aI` author-date (git's `--since=Nd` form observed empirically unreliable against fixture date inputs on 2026-05-16 — invocation contract preserved verbatim; date filter routed to Python; ADR-058 NDJSON output shape unchanged). Single git-log pass collapses ADR-058 §Script contracts' two-pass shape into one walk (cheaper + resistant to git's date-parser quirks).

`composite_index = log10(commits_window+1) + log10(closed_tickets_window+1) + (days_shipped >= 60 ? 1.0 : 0.0)` verbatim from ADR-058 line 112 (Option E6 "MAY emit alongside band" carve-out). `days_shipped` tracks `min(author_date)` per plugin (robust against commit-topology / rebase / cherry-pick reordering).

Exit 0 always per ADR-013 Rule 6 (outside-git-repo, missing `packages/`, opt-out marker all hit the zero-records/stderr-comment path). Privacy posture per ADR-035: opt-out marker `.claude/.skill-metrics-opt-out`, no network primitive (negative-grep enforced via bats), content sanitisation (commit subjects parsed only for `BREAKING|feat!|fix!` token presence; subject prose discarded after the boolean test; never echoed to stdout).

Behavioural confirmation: 19 bats fixtures covering ADR-058 §Confirmation criteria 6 (git-axis composite with three commits one in window, plus per-plugin emission, plus literal-`|`-in-commit-subject parser defence per architect 2026-05-16 advisory), 7 (outside-git-repo + missing-packages), 8 (schema-version) plus opt-out / no-network / content-sanitisation / composite-index formula / breaking-marker / closed-tickets-window dual-layout (suffix-based + directory-based) / window-days filter / category-overrides forward-extension flag. All green.

Smoke-tested against this monorepo: itil composite_index 4.28 (Phase 2 prototype 4.11), retrospective 3.34 (prototype 3.30), risk-scorer 3.32, architect 3.22 — top-of-list matches 2026-05-03 prototype intuition; drift accounted-for by elapsed time + new commits since prototype. Performance 1.07s warm-cache on this workstation (boundary of ADR-058 ≤1.0s; well under the 5s reassessment threshold).

Phase 2c (performance reassessment for `wr-itil-skill-invocations` 7.8s warm-cache observation against 5157 jsonl) and Phase 3 (retroactive assessment + README badges) remain queued as discrete Investigation Tasks under P087.
