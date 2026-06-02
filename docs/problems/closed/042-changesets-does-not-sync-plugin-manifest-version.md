# Problem 042: Changesets does not sync plugin manifest version

**Status**: Closed
**Reported**: 2026-04-18
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: L (sync mechanism design + ADR + implementation + CI guard)
**WSJF**: 8.0 (16 × 2.0 / 4)  — transitioned 2026-04-19 after fix strategy selected

## Description

The release pipeline updates `packages/<plugin>/package.json` `version`
(via `changesets/action`) and publishes to npm. It does NOT update
`packages/<plugin>/.claude-plugin/plugin.json` `version`. The Claude Code
marketplace reads `plugin.json` at git HEAD when serving the plugin
catalogue, so `claude plugin update` reports the stale manifest version
as "latest" even though npm has newer code.

Discovered 2026-04-18 while running `npx @windyroad/agent-plugins
--update` across seven sibling projects. Every plugin's manifest was 0–4
patch versions behind the npm-published version. Three were behind by
minor versions:

| Plugin | Manifest (pre-fix) | npm |
|---|---|---|
| wr-itil | 0.1.0 | 0.4.0 (3 minors behind) |
| wr-connect | 0.1.0 | 0.3.5 (3 minors behind) |
| wr-tdd | 0.1.0 | 0.2.3 (1 minor + patches behind) |
| wr-voice-tone | 0.1.0 | 0.2.1 (1 minor + patches behind) |
| wr-style-guide | 0.1.0 | 0.2.1 (1 minor + patches behind) |
| wr-retrospective | 0.1.0 | 0.1.5 (5 patches behind) |
| wr-c4 | 0.1.0 | 0.1.4 (4 patches behind) |
| wr-wardley | 0.1.0 | 0.1.4 (4 patches behind) |
| wr-risk-scorer | 0.3.0 | 0.3.4 (4 patches behind) |
| wr-architect | 0.3.0 | 0.3.1 (1 patch behind) |
| wr-jtbd | 0.5.0 | 0.5.1 (1 patch behind) |

The immediate symptom (stale manifests) was corrected in commit `51eec23`
by manually copying each `package.json` `version` into the matching
`plugin.json`. This ticket addresses the **systemic process gap** so the
drift cannot recur.

## Symptoms

- `claude plugin update <plugin>@windyroad` reports "already at latest"
  when npm has a newer published version
- Sibling projects running `npx @windyroad/agent-plugins --update` get
  out-of-date code installed under the (false) impression that they are
  current
- Users who diagnose the gap (e.g. by checking npm versus marketplace
  manually) lose trust in the auto-update mechanism
- The drift accumulates silently over many releases — the longer between
  manual corrections, the larger the gap

## Workaround

After every npm release, manually run a sync script (or apply manual
edits) that copies `version` from each `packages/<plugin>/package.json`
into `packages/<plugin>/.claude-plugin/plugin.json`, commit, and push.
Effective but easy to forget.

## Impact Assessment

- **Who is affected**: Every consumer of the windyroad marketplace —
  solo-developer persona (JTBD-001, JTBD-003, JTBD-006), plugin-developer
  persona (JTBD-101). Today: 7 sibling projects on this machine; in
  general: every project that runs `claude plugin install` or
  `claude plugin update` against this marketplace.
- **Frequency**: Continuous — any release without a manual sync pass
  introduces drift; every install/update against the marketplace returns
  the stale version
- **Severity**: Significant — silently delivers stale code to users; the
  failure is invisible to the user and to the orchestrator (no error,
  no warning)
- **Analytics**: 11/11 plugins were drifted as of 2026-04-18. Zero
  releases between 2026-04-17 (last npm publish) and 2026-04-18 included
  a corresponding manifest bump.

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

The `.github/workflows/release.yml` workflow uses `changesets/action@v1`
with `publish: npm run release` (which is `changeset publish`).
`changeset publish`:

1. Bumps `packages/<plugin>/package.json` `version` based on queued
   changesets.
2. Runs `npm publish` for each bumped package.
3. Knows nothing about `.claude-plugin/plugin.json` files.

There is no pre-publish or post-publish hook anywhere in the repo that
keeps the two version fields in lock-step. `scripts/sync-install-utils.sh`
syncs `install-utils.mjs` between packages but does not touch
`plugin.json`.

`packages/agent-plugins/package.json` has its own `version` (0.1.6) which
is unrelated to the per-plugin manifests but adds to the inventory of
versions to keep aligned (its own `plugin.json`-equivalent does not exist,
so this aspect is not currently affected).

### Fix Strategies

1. **Pre-publish sync script** — add a script `scripts/sync-plugin-manifests.sh`
   that walks `packages/*/package.json` and copies the `version` into
   `packages/*/.claude-plugin/plugin.json`. Wire it into either:
   - `npm run release` (run before `changeset publish`), OR
   - The release workflow as a step before/after the changesets action,
     committing the manifest changes back to the release PR.

2. **Pre-commit hook** — install a pre-commit hook (husky or similar)
   that detects when a `package.json` `version` is bumped and refuses to
   commit unless the matching `plugin.json` is bumped to the same value.
   Stronger guarantee but more friction during normal development.

3. **Single source of truth** — generate `plugin.json` from `package.json`
   at build time. `plugin.json` becomes a build artefact, not a hand-edited
   file. Requires either committing the generated file (back to square one
   sync-wise) or shipping a generator that the marketplace runs (not
   currently supported by Claude Code's marketplace mechanism).

4. **Changesets custom config** — Changesets supports a custom
   `getReleasePlan` or post-version hooks via `@changesets/changelog-*`
   plugins, or a custom `changeset config.json` formatter. Likely the
   cleanest integration point: the version-bump step (which produces the
   "Version Packages" PR) would also touch `plugin.json`.

The architect (P041/P042 review session) recommended that whichever
strategy is chosen, the choice itself should be captured in a new ADR
("Plugin manifest version sync mechanism") citing ADR-002 and ADR-018.

### Investigation Tasks

- [x] Confirm the systemic gap (changesets does not touch plugin.json) —
      verified 2026-04-18 via `.github/workflows/release.yml` and
      `npm run release` script inspection
- [x] Apply immediate corrective fix — done in commit 51eec23
- [x] Author the new ADR — ADR-021 chosen Option 4 (Changesets `version`
      script hook) with Option 1 (pre-publish workflow step) documented
      as the fallback
- [x] Implement the chosen sync mechanism — `scripts/sync-plugin-manifests.mjs`
      (Node, cross-platform, with `--check` mode) wired into the root
      `package.json` `version` script so the Changesets action picks it
      up automatically when producing the "Version Packages" PR
- [x] Add a CI guard — `.github/workflows/ci.yml` now runs
      `npm run check:plugin-manifests` on every PR and push to main;
      `packages/shared/test/plugin-manifest-sync.bats` covers the
      check/sync/drift-detection behaviour (7 assertions, all passing)
- [ ] Document the sync mechanism in CONTRIBUTING.md or the release
      runbook — deferred; the ADR-021 Confirmation section and the
      inline script header provide the reference documentation for now

## Fix Released

Fix implemented on 2026-04-19 under ADR-021:

- `scripts/sync-plugin-manifests.mjs` — Node script walking `packages/*/package.json` and copying `version` into the sibling `.claude-plugin/plugin.json`. Supports `--check` mode.
- Root `package.json` wiring: `scripts.version = "changeset version && node scripts/sync-plugin-manifests.mjs"` — the Changesets action extension point. Plus `sync:plugin-manifests` and `check:plugin-manifests` for manual / CI use.
- `.github/workflows/ci.yml` — new step runs `npm run check:plugin-manifests` on every PR and push to main, failing the build if any manifest has drifted.
- `packages/shared/test/plugin-manifest-sync.bats` — 7-assertion drift-guard test covering script presence, current-tree OK, drift detection, sync mutation, skip-without-manifest, and npm-script wiring.

Released in: _pending release cadence check (this iteration)_.

Awaiting user verification that the next Changesets "Version Packages" PR includes a coordinated `packages/*/.claude-plugin/plugin.json` version bump alongside the `packages/*/package.json` bump, and that CI fails if drift is introduced manually.

## Related

- ADR-002: `docs/decisions/002-monorepo-per-plugin-packages.proposed.md`
  — establishes per-plugin packages and changesets as the versioning
  mechanism; this ticket extends that decision to cover manifest sync
- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`
  — lean release principle; manifest drift undermines this principle by
  silently de-coupling "released" from "available via marketplace"
- ADR-018: `docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`
  — inter-iteration release cadence; manifest drift makes the cadence
  meaningless because what gets released is not what gets served
- P028: `docs/problems/028-governance-skills-should-auto-release-and-install.open.md`
  — adjacent: governance skills should auto-release-and-install. This
  ticket is the upstream blocker — auto-install is moot if the
  marketplace serves stale versions
- Commit 51eec23: corrective fix that brought all 11 manifests into
  sync as of 2026-04-18; baseline for the regression-prevention test
