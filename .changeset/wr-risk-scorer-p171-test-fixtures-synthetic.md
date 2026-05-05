---
"@windyroad/risk-scorer": patch
---

Test-only fix: synthetic fixtures for `drain-register-queue.bats` + `bootstrap-catalog.bats` SKILL-wording assertion (CI green; P171 captures deeper divergence)

Two pre-existing test regressions in `@windyroad/risk-scorer`'s bats suite, both rooted in P168 commit `8edaf7b` ("FFS WIPE THE RXXX risks ... THEY ARE WRONG") which wiped `docs/risks/TEMPLATE.md` and renamed R001 without updating dependent fixtures. CI failure surfaced via push:watch when 33 unpushed commits batched today (P116 hazard).

`packages/risk-scorer/scripts/test/drain-register-queue.bats`:

- setup() previously did `cp $REPO_ROOT/docs/risks/TEMPLATE.md ...` and `cp $REPO_ROOT/docs/risks/R001-confidential-info-leak-via-public-repo-push.active.md ...` — both source files were wiped or renamed in the canonical state.
- Replacement: synthesize fixture-local `TEMPLATE.md` and an old-shape `R001-...active.md` inline via `cat <<EOF`. Drain script's `TEMPLATE.md` existence gate (line 66) and old-shape filename regex (line 126) are preserved by the synthetic fixtures so the existing 16-test contract exercises end-to-end without canonical-state coupling.
- Inline P171 cross-reference documents the workaround status.
- Verified locally: 16/16 tests pass.

`packages/risk-scorer/skills/bootstrap-catalog/test/bootstrap-catalog.bats`:

- Test 1325 asserted SKILL.md contains `requires docs/risks/ scaffold` wording. SKILL.md was rewritten in the wipe iter to say "directory may or may not exist; created on demand; bootstrap owns the directory's full lifecycle" — the assertion was inverted.
- Updated assertion to match new contract: grep for `may or may not exist | creates it on demand | owns the directory's full lifecycle`.
- Renamed test from "requires scaffold" to "owns directory lifecycle".
- Verified locally: 19/19 tests pass.

The synthetic-fixture pattern is workaround-shape, not canonical-shape. P171 (`docs/problems/171-drain-register-queue-script-and-tests-reference-obsolete-pre-wipe-r-file-shape.open.md`) captures the underlying script-vs-format divergence for a future fix iter that:

- removes the vestigial `TEMPLATE_FILE` gate from `drain-register-queue.sh`
- updates generated filename + dedupe regex to canonical bare-`.md` shape
- replaces synthetic-fixture bats with real-shape fixtures
- adds reciprocal contract bats asserting drain output matches catalog

Refs P171, P168, P116 (push:watch local-only-commits hazard surfaced this).
