---
status: "proposed"
date: 2026-04-17
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [tomhoward]
consulted: []
informed: []
reassessment-date: 2026-07-17
---

# Shared code duplicated into per-package lib/ kept in sync by script + CI drift check

## Context and Problem Statement

The `install-utils.mjs` module is used by 12 `packages/*/lib/install-utils.mjs` copies. The canonical source lives at `packages/shared/install-utils.mjs`. Prior to P026, there was no mechanism to keep the copies in sync: edits to the canonical source were not propagated, causing subtle drift bugs across packages.

Any shared code that must remain available to published packages without cross-package runtime coupling will face the same problem. A decision is needed about how to handle this kind of code sharing — for `install-utils.mjs` today and for any future shared utility.

## Decision Drivers

- **Self-contained published packages**: Each `wr-*` plugin should install from the marketplace without requiring sibling packages to be present. A `packages/shared/` runtime dependency would break this.
- **Low author-time cost**: The canonical source should live in one place so authors don't edit many copies.
- **Drift detection**: When copies fall out of sync, CI should fail loudly.
- **Familiar tooling**: Solutions that use standard Unix tools + bats tests are preferred over custom build infrastructure.

## Considered Options

1. **Option A — Re-export from `packages/shared/`**: Each package's `lib/install-utils.mjs` does `export * from '../../shared/install-utils.mjs'`. One source of truth, zero drift possible.
2. **Option B — Sync script + CI drift check**: Authors edit `packages/shared/install-utils.mjs` only. A script (`scripts/sync-install-utils.sh`) copies the canonical file to all `packages/*/lib/install-utils.mjs`. A CI step runs the script in `--check` mode and fails if drift is detected. Author-time friction but published-package independence preserved.
3. **Option C — Leave as-is (accept drift)**: Rejected — drift had already caused observable bugs (P026 reported real symptoms).

## Decision Outcome

Chosen option: **"Option B — Sync script + CI drift check"**, because it preserves the "self-contained published package" property (each plugin installs without sibling packages at runtime) while eliminating the silent-drift failure mode. The author-time cost of running `npm run sync:install-utils` before committing edits is modest and surfaces clearly in CI when forgotten.

This decision establishes a pattern: future shared code whose consumers must remain independent at install time should follow the same duplicate-and-sync model unless a stronger reason to re-export exists.

## Consequences

### Good

- Published packages remain self-contained — consumers install one `wr-*` plugin and it works without needing `packages/shared/`.
- Drift becomes a loud CI failure rather than a silent correctness bug.
- The pattern is discoverable: `scripts/sync-*.sh` + matching CI step + matching bats test is a recognisable shape future shared code can mirror.

### Neutral

- Canonical-file authorship lives in `packages/shared/`; per-package copies are read-only in practice. This is an inversion of the usual "edit where you see it" reflex but is consistent across all shared code following this pattern.
- **Two destination-path conventions, one sync mechanism.** Every shared helper's canonical copy lives under `packages/shared/` and is synced into every consuming package via its `sync-<name>.sh` + `check:<name>` CI gate. The destination subpath *within* each package depends on the helper's role:
  - **Cross-cutting libs** (e.g. `derive-first-dispatch.sh`, `migrate-problems-layout.sh`, `install-utils.mjs`) — canonical at `packages/shared/` or `packages/shared/lib/`, synced flat into each package's `lib/` (e.g. `packages/itil/lib/derive-first-dispatch.sh`).
  - **Hook helpers** (e.g. `session-marker.sh`, `leak-detect.sh`, `external-comms-key.sh`, `command-detect.sh`) — canonical at `packages/shared/hooks/lib/`, synced into each package's `hooks/lib/` (e.g. `packages/itil/hooks/lib/session-marker.sh`) so the helper sits beside the hooks that consume it.

  Both share the same drift-detection and self-contained-package guarantees — hook helpers are *synced per-package*, not *sourced directly* from `packages/shared/`, so the self-containment driver above holds either way. Only the destination subdirectory differs. A new shared helper picks its subpath by role: a hook helper under `hooks/lib/`, anything else under `lib/`. The § Confirmation criterion below (parallel `sync-<utility>.sh` / `check:<utility>` per new utility) applies to both — the sync *mechanism* is identical; only the destination subpath varies.

### Bad

- Author-time friction: authors must remember to run `npm run sync:install-utils` after editing the canonical source. Forgetting is caught by CI but delays feedback from "next save" to "next push".
- Drift detection relies on CI always running. If a contributor bypasses CI (merge without status checks, direct push to main), drift can enter `main` undetected. The `--check` step should be in the required-checks list once branch protection is configured.
- Storage overhead: 12 copies of the same file. Negligible today (small file) but scales linearly with shared-code volume.

## Confirmation

- `packages/shared/install-utils.mjs` exists and is byte-identical to all `packages/*/lib/install-utils.mjs` copies (verified by `npm run check:install-utils`).
- `scripts/sync-install-utils.sh` supports `--check` mode that exits non-zero if any copy diverges from the canonical source.
- `.github/workflows/ci.yml` includes a step that runs `npm run check:install-utils` and fails the build on drift.
- `packages/shared/test/sync-install-utils.bats` covers: (a) canonical-to-copies sync succeeds from clean state, (b) `--check` mode detects divergence, (c) idempotent re-runs don't modify files.
- When a new shared utility is added, a parallel `sync-<utility>.sh` / `check:<utility>` / bats test set is established following the same shape.

## Pros and Cons of the Options

### Option A — Re-export from `packages/shared/`

- Good: Zero drift possible. One source of truth.
- Good: No author-time workflow step.
- Bad: Breaks self-contained-package property — a user installing `wr-itil` alone wouldn't have `packages/shared/` available at runtime.
- Bad: Requires changes to all consumers' import paths plus packaging configuration to bundle `packages/shared/` into each published artefact, which reintroduces duplication at a different layer.

### Option B — Sync script + CI drift check (chosen)

- Good: Self-contained packages preserved.
- Good: Drift becomes a CI failure, not a silent bug.
- Good: Uses standard tools (bash, bats, GitHub Actions).
- Bad: Author-time step is easy to forget.
- Bad: 12× file-system duplication (trivial today, concerning if shared code grows).

### Option C — Leave as-is

- Good: No tooling changes needed.
- Bad: Drift has already caused observable bugs. Rejected on that basis.

## Reassessment Criteria

> **Reassessment FIRED 2026-05-26 (P283 prong-2 oversight drain).** The ">5 shared modules" trigger below is objectively met — ~8 canonical helpers now live under `packages/shared/` (install-utils, derive-first-dispatch, session-marker, leak-detect, command-detect, external-comms-key, external-comms-gate, migrate-problems-layout). **User-directed outcome: move to a bundler-based shared-code approach.** Design + implementation tracked at **P304**; this ADR will be amended or superseded once the bundler design lands. The duplicate-and-sync convention below remains the operative decision until then (so `human-oversight`/`status` are unchanged — this is a forward-pointer note, not a decision reversal).

Revisit this decision when:
- Shared-code volume grows significantly (e.g., >5 shared modules), at which point the storage and cognitive overhead of the duplicate-and-sync pattern may outweigh its benefits and a bundler-based approach should be considered. **[FIRED 2026-05-26 — see note above; outcome tracked at P304.]**
- The project adopts a packaging system (esbuild, rollup, etc.) that can bundle `packages/shared/` into each published plugin transparently — then Option A becomes viable without breaking self-containment.
- Contributors repeatedly land drift in `main` because CI was bypassed, indicating that the CI-only enforcement is insufficient and a pre-commit hook may be warranted.
