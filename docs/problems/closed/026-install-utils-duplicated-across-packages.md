# Problem 026: install-utils.mjs duplicated across all packages

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: S (fix implemented)
**WSJF**: n/a (fix released, pending verification)

## Description

`packages/shared/install-utils.mjs` is a canonical source of shared installer utilities, but each of the 12 per-package `lib/` directories contains a full byte-for-byte copy (`packages/*/lib/install-utils.mjs`). The per-plugin `bin/install.mjs` scripts import from their local `../lib/install-utils.mjs`, not from `packages/shared/`. This means any bug fix or enhancement to the shared utilities must be applied in 13 places — and there is no automated check to detect divergence.

P025 is a concrete example: the `updatePlugin` fix was initially applied only to `packages/shared/install-utils.mjs` and the `bin/` entry points. The risk scorer caught the divergence before commit, requiring the same fix to be applied manually to all 12 `lib/` copies. Without the risk scorer catching it, 11 packages would have shipped the fix while 1+ packages remained broken.

## Symptoms

- A bug fix applied to `packages/shared/install-utils.mjs` does not affect any installed package — each package uses its own `lib/` copy
- A developer who fixes shared and forgets the lib copies ships a partial fix (some packages fixed, others not)
- `diff packages/shared/install-utils.mjs packages/architect/lib/install-utils.mjs` returns non-empty output whenever the shared copy has been updated but lib copies have not
- P025 required 25 file edits where 2 would have sufficed if a single shared copy were used

## Workaround

When modifying `packages/shared/install-utils.mjs`, always also update all 12 `packages/*/lib/install-utils.mjs` copies with the identical change. Use `git diff --stat` after editing to confirm all 13 copies are touched before committing.

## Impact Assessment

- **Who is affected**: Plugin developer persona — anyone maintaining or extending the installer code. Indirectly affects all end users if a lib-copy divergence ships a partial or broken fix.
- **Frequency**: Every time install-utils.mjs is modified. Given active development on the plugin suite, this is a recurring risk on every release cycle.
- **Severity**: High — divergence is easy to miss (no automated guard), and a missed lib copy means one or more packages ship broken update/install behaviour silently.
- **Analytics**: P025 (2026-04-16) is a confirmed instance where the risk scorer caught the divergence at commit time.

## Root Cause Analysis

### Cause

Each package is published as a self-contained npm package with its own `bin/` and `lib/` directories. The `lib/install-utils.mjs` copies were introduced so that the published package bundle contains everything it needs without depending on a sibling workspace package at runtime. The `packages/shared/` directory exists as a source-of-truth during development, but there is no build step, symlink, or re-export mechanism that keeps the lib copies in sync with the shared source.

### Investigation Tasks

- [x] Identify the divergence pattern (P025 — risk scorer caught it)
- [x] Confirm all 12 lib copies are identical to shared (verified via `diff` during P025 fix)
- [x] Evaluate consolidation options (see Fix Strategy)
- [x] Implement fix: Option B (sync script) + Option C (CI drift check)

### Fix Strategy Options

**Option A — Re-export from shared (requires runtime import path)**
Replace each `packages/*/lib/install-utils.mjs` with a one-line re-export:
```js
export * from "../../shared/install-utils.mjs";
```
Pros: single source of truth, zero duplication. Cons: packages are no longer self-contained — the relative path `../../shared/` must exist at runtime (fine for monorepo dev, breaks for users who `npx` the package unless shared is bundled).

**Option B — Build step copies shared into each lib/**
Add a pre-publish or pre-release script that copies `packages/shared/install-utils.mjs` into `packages/*/lib/` automatically:
```bash
for pkg in packages/*/; do cp packages/shared/install-utils.mjs "$pkg/lib/install-utils.mjs"; done
```
Pros: self-contained published packages, single source of truth during development, no import path issues. Cons: adds a build step; forgetting to run it before publish causes the same divergence.

**Option C — CI drift check**
Add a CI job that diffs `packages/shared/install-utils.mjs` against each `packages/*/lib/install-utils.mjs` and fails if any differ. Does not fix the duplication but makes divergence impossible to ship.
Pros: lightweight, no restructuring. Cons: doesn't eliminate the need to edit 13 files; it only ensures they stay in sync.

**Recommended**: Option B (build step) with Option C (CI guard) as belt-and-suspenders. Option A is cleaner architecturally but risks runtime path issues for end users.

## Fix Released

Implemented 2026-04-17 (this session):

- **Sync script** (Option B): `scripts/sync-install-utils.sh` copies `packages/shared/install-utils.mjs` into every `packages/*/lib/install-utils.mjs`. Exposed as `npm run sync:install-utils`. Run after editing the shared source and before committing.
- **CI drift check** (Option C): `packages/shared/test/sync-install-utils.bats` fails the build if any lib/ copy has diverged from shared. An explicit "Check install-utils.mjs copies in sync (P026)" step was added to `.github/workflows/ci.yml` that invokes `npm run check:install-utils` before the meta-installer dry-run.
- **`check:install-utils` npm script** exposes the drift check with an actionable remediation hint (`Run: bash scripts/sync-install-utils.sh`).
- **BATS test coverage**: 5 tests in `packages/shared/test/sync-install-utils.bats` — verifies canonical source exists, script is executable, at least one copy exists, no drift currently, and that `--check` correctly flags intentional divergence (tested in a temp workspace so the repo is untouched).

Pending user verification in production: commit lands, CI passes, next edit to `packages/shared/install-utils.mjs` is caught by the drift check if lib/ copies are not synced.

## Related

- `packages/shared/install-utils.mjs` — canonical source
- `packages/*/lib/install-utils.mjs` — 12 copies (architect, risk-scorer, c4, jtbd, itil, retrospective, style-guide, tdd, voice-tone, wardley, connect, agent-plugins)
- `scripts/sync-install-utils.sh` — sync script (fix)
- `packages/shared/test/sync-install-utils.bats` — drift check (CI guard)
- P025: `docs/problems/025-update-flag-fails-at-project-scope.known-error.md` — triggered discovery of this problem (risk scorer caught divergence during P025 fix)
