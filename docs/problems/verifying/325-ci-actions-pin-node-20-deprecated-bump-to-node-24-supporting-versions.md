# Problem 325: CI actions pin Node-20 versions (`checkout@v4`, `setup-node@v4`) — GitHub deprecates Node 20 on runners; bump before the forced 2026-06 migration

**Status**: Verification Pending
**Reported**: 2026-05-28
**Priority**: 4 (Low-Med) — Impact: 2 x Likelihood: 2 (deferred — re-rate at next /wr-itil:review-problems; time-bounded, see below)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Fix Released

- **Release marker**: shipped in `@windyroad/architect@0.13.0` / `@windyroad/itil@0.39.0` / `@windyroad/retrospective@0.22.0` / `@windyroad/risk-scorer@0.11.3` on 2026-05-31 (release commit e9f7ce4 → CI passed → release PR merged → npm publish via changesets workflow).
- **Fix summary**: bumped `actions/checkout@v4` → `@v5` and `actions/setup-node@v4` → `@v5` across `.github/workflows/*.yml` in prior commit b698b45 (`fix(ci): bump Node-20 action pins to Node-24-supporting majors (P325 known error)`). The Node 24 default-flip (2026-06-02) no longer triggers deprecation warnings.
- **Awaiting user verification**: confirm CI runs clean on the next push (no Node 20 deprecation warnings emitted by GitHub Actions runners).

## Description

The CI workflows pin `actions/checkout@v4` and `actions/setup-node@v4`, which run on **Node 20**. GitHub is deprecating Node 20 on Actions runners:

- **2026-06-02**: runners force JavaScript actions to **Node 24** by default (opt-out temporarily via `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true`).
- **2026-09-16**: Node 20 is **removed** from the runner image.

Surfaced as a deprecation **annotation** on the **Quality Gates** + **Release** workflows during the 2026-05-28 `npm run push:watch` run (ref: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/).

**Fix**: bump the pinned actions to versions that ship on Node 24 — `actions/checkout@v5`, `actions/setup-node@v5`, and any other `@vN` actions — across all `.github/workflows/*.yml`. Do it before the 2026-06-02 default flip so CI neither emits the warning nor risks a silent break at the 2026-09-16 removal.

## Symptoms

- Deprecation annotation on every CI run: *"Node.js 20 actions are deprecated… actions/checkout@v4, actions/setup-node@v4… forced to Node.js 24 by default starting June 2nd, 2026… Node.js 20 will be removed from the runner on September 16th, 2026."*

## Workaround

None needed yet — the actions still run on Node 20 until 2026-06-02. The annotation is advisory until then.

## Impact Assessment

- **Who is affected**: CI for this repo (maintainer-facing); no adopter/runtime impact.
- **Frequency**: every CI run emits the annotation; hard break only if left past the 2026-09-16 Node-20 removal.
- **Severity**: low now, escalating — **time-bounded**: trivial bump now, vs a broken pipeline if forgotten past September 2026.

## Root Cause Analysis

**Confirmed**: GitHub Actions runner image is deprecating its Node-20 JavaScript runtime in two stages — forced flip to Node 24 on 2026-06-02, removal of Node 20 from the image on 2026-09-16 (ref: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/). Three first-party actions in this repo's workflows shipped on the Node-20 runtime line: `actions/checkout@v4`, `actions/setup-node@v4`, `actions/github-script@v7`. The Node-24-supporting majors of each are `@v5`, `@v5`, and `@v8` respectively. `changesets/action@v1` is a third-party action with its own release cadence — not implicated by the GitHub Node-20 runner deprecation; left alone.

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems (note the time-bound — Likelihood rises as 2026-06-02 / 2026-09-16 approach). — Re-rated 2026-05-30 (work-problems iter-9): kept Priority 4 / Effort S; bumps are mechanical and the fix landed within the same iter.
- [x] Enumerate all `@vN` action pins across `.github/workflows/*.yml` (checkout, setup-node, and any others); confirm which run on Node 20. — Surveyed across `ci.yml`, `release.yml`, `release-preview.yml`: 3 × `actions/checkout@v4`, 3 × `actions/setup-node@v4`, 2 × `actions/github-script@v7`, 1 × `changesets/action@v1` (third-party, out of scope).
- [x] Bump each to a Node-24-supporting major (checkout@v5, setup-node@v5, etc.); verify CI green on the bump. — Bumped: checkout@v4→v5, setup-node@v4→v5, github-script@v7→v8 across all three workflow files. **CI-green verification deferred** to the next push (orchestrator owns release cadence per work-problems iter-9 constraint); that's the K→V trigger.

## Fix Strategy

Bump first-party Node-20-runtime action pins to Node-24-supporting majors across `.github/workflows/*.yml` — 8 pin lines total in 3 files. No workflow logic changes; the `node-version: 20` field (which selects the Node runtime for project scripts) is independent of action runtime and is unchanged. Fix applied in work-problems iter-9 (2026-05-30) ahead of commit; transitions to Verification Pending on the next CI-green run after release.

## Dependencies

- **Blocks**: (none — but the 2026-06-02 / 2026-09-16 GitHub dates bound when this must land.)
- **Composes with**: (none)

## Related

- captured via /wr-itil:capture-problem 2026-05-28 — surfaced by the push:watch CI annotation during the RFC-011 release push; captured immediately rather than surfaced as a session-wrap recommendation (P148 recurrence corrected — see P148).
