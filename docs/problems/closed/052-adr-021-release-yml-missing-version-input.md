# Problem 052: ADR-021 release.yml missing `version: npm run version` input — first production exercise shipped drifted PR

**Status**: Closed
**Reported**: 2026-04-19
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: S
**WSJF**: 24.0 — (12 × 2.0) / 1  — transitioned 2026-04-19 after root cause confirmed and fix implemented in same session

## Description

ADR-021 (Plugin manifest version sync mechanism) wired the manifest-sync script into the root `package.json` `scripts.version` entry, on the assumption that `changesets/action@v1` invokes `npm run version` when creating the Version Packages PR. First production exercise (commit `5b2b634`, Release workflow run `24618590442`, 2026-04-19) proved the assumption wrong.

The changesets/action v1 log shows:

```
[command]/opt/hostedtoolcache/node/20.20.2/x64/bin/node /home/runner/work/agent-plugins/agent-plugins/node_modules/@changesets/cli/bin.js version
```

The action invoked `@changesets/cli version` **directly** — bypassing the `npm run version` npm script — because the workflow did not pass a `version:` input. Per the action's README, `version:` is optional and defaults to `changeset version`. My sync script never ran.

Result: Version PR #30 contains `packages/itil/package.json: 0.4.4` and `packages/retrospective/package.json: 0.1.6` but leaves `packages/itil/.claude-plugin/plugin.json: 0.4.3` and `packages/retrospective/.claude-plugin/plugin.json: 0.1.5` — the exact drift P042 + ADR-021 were supposed to prevent.

## Symptoms

- Version Packages PR #30 diff lists `package.json` and `CHANGELOG.md` per package, but NOT the sibling `.claude-plugin/plugin.json`.
- Direct inspection of the PR branch (`changeset-release/main`) shows `package.json: 0.4.4` vs `plugin.json: 0.4.3` for `@windyroad/itil` (same drift shape for retrospective).
- The Release workflow run log records `@changesets/cli/bin.js version` being invoked — not `npm run version`.
- ADR-021's Confirmation section claimed "the next Changesets 'Version Packages' PR includes both `packages/*/package.json` and `packages/*/.claude-plugin/plugin.json` updates in a single diff" — this behavioural criterion was NOT met on first exercise.
- The CI guard (`npm run check:plugin-manifests`) did not catch the drift on the PR branch because GitHub Actions does not re-run `pull_request` workflows when the head ref is updated by a `GITHUB_TOKEN`-authenticated bot push (default protection against runaway workflows). The guard would fire on the next human push to the branch.

## Workaround

Before releasing Version PR #30: manually run `node scripts/sync-plugin-manifests.mjs` locally, commit the resulting plugin.json updates to the PR branch, then merge.

For the systemic fix: edit `.github/workflows/release.yml` to pass `version: npm run version` explicitly to the changesets/action step. One-line YAML change.

## Impact Assessment

- **Who is affected**: every consumer of the Windy Road marketplace — same blast radius as P042 (solo-developer, plugin-developer personas) because the fix they shipped to prevent drift doesn't actually prevent it in the release pipeline. Currently only 2 plugins are mid-release (itil, retrospective); any release under the current config will drift.
- **Frequency**: every Changesets "Version Packages" PR, which is every release cycle. Continuous.
- **Severity**: High — the P042 fix was released on the assumption the hook fires. It doesn't. The marketplace would still serve stale plugin.json if the Version PR is merged as-is.
- **Analytics**: Release workflow run `24618590442` log line confirms direct invocation. `gh pr diff 30` confirms no plugin.json entries in the diff. Direct git fetch + read of `origin/changeset-release/main` confirms the version drift.

## Root Cause Analysis

### Confirmed root cause (2026-04-19)

Two compounding defects in ADR-021's implementation:

1. **`.github/workflows/release.yml` does not pass the `version:` input to `changesets/action@v1`**. The action's default (when the input is absent) is to execute `changeset version` directly via its bundled Node CLI, not to shell out to `npm run version`. My ADR-021 wiring assumed the latter. Evidence: the action's README (https://github.com/changesets/action#with-publishing) lists `version` as optional and notes it defaults to `changeset version`.

2. **ADR-021's Confirmation section was test-absent for the wiring**. The source-review criterion checked that `scripts.version` in `package.json` contains the correct string, and the behavioural criterion assumed the PR diff would include plugin.json. Neither criterion tested that `release.yml` actually invokes `npm run version`. A source-grep test against `release.yml` for `version: npm run version` would have caught this before merge.

### Confirmed fix strategy

Two coordinated edits:

1. `.github/workflows/release.yml`: add `version: npm run version` to the `changesets/action@v1` `with:` block.
2. `docs/decisions/021-plugin-manifest-version-sync-mechanism.proposed.md`: strengthen the Confirmation section to add a source-review criterion that `.github/workflows/release.yml` contains the explicit `version:` input, AND a bats test assertion that does the same grep.

### Investigation Tasks

- [x] Confirm the action's default behaviour — done via log inspection + README review.
- [x] Confirm the PR diff shows drift — done via `gh pr diff 30` and direct branch read.
- [x] Edit `.github/workflows/release.yml` to add `version: npm run version`.
- [x] Edit ADR-021 Confirmation section to add the release.yml source-review criterion and bats assertion.
- [x] Extend `packages/shared/test/plugin-manifest-sync.bats` with a new assertion on `.github/workflows/release.yml` (8 assertions now passing locally).
- [ ] Re-push; watch the Release workflow re-run against the updated config; verify plugin.json entries appear in the refreshed Version PR diff.
- [ ] Only then run `npm run release:watch` to merge and publish.

## Fix Released

Fix implemented on 2026-04-19 in the same session that surfaced the drift:

- `.github/workflows/release.yml` — added `version: npm run version` to the `changesets/action@v1` step. This is the explicit Changesets extension point the action uses to invoke the repo's custom version script; without it, the action defaults to `changeset version` directly.
- `docs/decisions/021-plugin-manifest-version-sync-mechanism.proposed.md` — Confirmation section strengthened with a release.yml source-review criterion and a bats regression-guard assertion. ADR-021 frontmatter `revised: 2026-04-19` added to record the P052 revision.
- `packages/shared/test/plugin-manifest-sync.bats` — new assertion `release.yml passes 'version: npm run version' to changesets/action (P052)` grep-checks `.github/workflows/release.yml`. Total assertions: 8 (all passing locally).
- Version PR #30 will be re-generated when this commit pushes; expectation is the refreshed PR diff contains `packages/itil/.claude-plugin/plugin.json` (0.4.3 → 0.4.4) and `packages/retrospective/.claude-plugin/plugin.json` (0.1.5 → 0.1.6) alongside the existing `package.json` + `CHANGELOG.md` entries.

Released in: _pending this commit's push + Release workflow re-run._

Awaiting user verification that Version PR #30 (or its replacement) contains the coordinated plugin.json bumps AND that the drift detected above is closed.

## Related

- P042: `docs/problems/042-changesets-does-not-sync-plugin-manifest-version.known-error.md` — the parent problem; ADR-021 was intended to fix it. P052 is a direct follow-up on ADR-021's implementation.
- ADR-021: `docs/decisions/021-plugin-manifest-version-sync-mechanism.proposed.md` — the ADR whose Confirmation was insufficient on first exercise.
- `.github/workflows/release.yml` — the fix target.
- `packages/shared/test/plugin-manifest-sync.bats` — the test to extend.
- changesets/action README — https://github.com/changesets/action — source of the default-behaviour confirmation.
- Version PR #30 (`changeset-release/main`, HEAD `f1565d9`) — the live drift surface awaiting this fix.
