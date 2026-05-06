# Problem 171: drain-register-queue.sh and tests reference obsolete pre-wipe R-file shape

**Status**: Open
**Reported**: 2026-05-05
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`packages/risk-scorer/scripts/drain-register-queue.sh` and its dependent bats coverage reference the **pre-wipe R-file shape** (`R<NNN>-<slug>.active.md` with structured frontmatter — Status / Category / Identified / Owner / Inherent Risk / Controls / Residual Risk / Treatment / Monitoring sections). The **canonical post-wipe shape** (per the 2026-05-04 user direction *"FFS WIPE THE RXXX risks ... THEY ARE WRONG"*, commit `8edaf7b`) is **bare `R<NNN>-<slug>.md`** without status frontmatter and a slug-only catalog body (title + description + Recogniser section + path patterns). The drain script wasn't swept when the wipe landed, so the script and the catalog format are now out of sync.

**Concrete symptoms**:

- (a) `drain-register-queue.sh` line 51-66 has a vestigial `TEMPLATE_FILE` existence gate for a file that explicitly should not exist per the wipe direction. The `TEMPLATE_FILE` argument is passed to the python body but never consumed (verified: `grep -n "template_file\|template" packages/risk-scorer/scripts/drain-register-queue.sh` shows only the unpacking line at 91, no read).
- (b) `drain-register-queue.sh` line 167 generates new R-files with `.active.md` extension that don't match the canonical post-wipe naming convention.
- (c) `drain-register-queue.sh` line 126 regex `^R(\d+)-(.+)\.active\.md$` for dedupe-against-existing matching won't match any current canonical R-file (since they are now `R<NNN>-<slug>.md`).
- (d) Tests at `packages/risk-scorer/scripts/test/drain-register-queue.bats` line 23-25 had to synthesize fixture-local `TEMPLATE.md` and an old-shape `R001-...active.md` inline (commit landed today as part of the post-CI-failure fix) to make CI green. The fixture's setup() comment cross-references this ticket. The fixtures preserve the OLD-shape contract until the script can be updated.
- (e) `bootstrap-catalog` (which already operates on the new shape) and `drain-register-queue` (which still operates on the old shape) carry a divergent contract about R-file naming — both write to `docs/risks/` but with different filename patterns. Adopters consuming both surfaces would see inconsistent file naming.

## Symptoms

- CI test failure on `packages/risk-scorer/scripts/test/drain-register-queue.bats` line 23 setup (`cp "$REPO_ROOT/docs/risks/TEMPLATE.md" docs/risks/TEMPLATE.md` — `cp: cannot stat ...: No such file or directory`) until the synthetic-fixture fix landed today. Cascaded ~70 test failures from the same setup() error.
- CI test failure on `packages/risk-scorer/skills/bootstrap-catalog/test/bootstrap-catalog.bats` line 56 (`bootstrap-catalog SKILL.md requires docs/risks/ scaffold` — assertion failed because the SKILL.md was correctly rewritten to say "may or may not exist; created on demand" but the test still asserted the old "requires scaffold" wording).
- Once-fixed: tests pass with synthetic fixtures, but the underlying drain-script-vs-canonical-shape divergence persists. Future drain runs against actual `docs/risks/` will produce `.active.md` files that don't match the canonical naming.

## Workaround

Synthetic-fixture pattern in test setup() — generate `TEMPLATE.md` + an old-shape `R001-...active.md` inline via `cat <<EOF`. This isolates the test contract from canonical state and keeps CI green. Landed in this iter alongside Slice 1 of P170 story map. Deferred items listed in the bats setup() comment cross-reference this ticket.

## Impact Assessment

- **Who is affected**: maintainer (test fixture maintenance overhead); future contributors trying to reason about the canonical R-file format (now ambiguous between two shapes); potentially adopters who would consume `drain-register-queue.sh` from `@windyroad/risk-scorer` once it ships.
- **Frequency**: drain script fires on every risk-scorer pipeline action with a queued hint, so once shipped, divergence would surface on every drain run.
- **Severity**: Moderate — divergence is functional (script generates files in a non-canonical format) but bounded (script is currently held-changeset / pre-release per the queued `@windyroad/risk-scorer` changeset; the user can resolve before adopter exposure).
- **Analytics**: count of `R*.active.md` files in `docs/risks/` after a drain run vs canonical `R*.md` — currently zero `.active.md` files exist canonically, so any drain output would create the divergence.

## Root Cause Analysis

Per user direction 2026-05-04 (commit `8edaf7b`, "FFS WIPE THE RXXX risks ... THEY ARE WRONG"), the wipe was scoped to:
- `docs/risks/R001-R006` legacy files (deleted)
- `docs/risks/TEMPLATE.md` (deleted)
- Install-updates risk-register templates (deleted)
- Broken markdown refs in P158/P159

The wipe then ran the new `extract-risks-from-reports.sh` which generated the new-shape files (R007-R011 + R001 regenerated under the new slug naming). It did NOT update:
- `packages/risk-scorer/scripts/drain-register-queue.sh` (still expects old-shape)
- `packages/risk-scorer/scripts/test/drain-register-queue.bats` (still expects old-shape)

The drain script is from an EARLIER iteration (Phase 2b drain, ADR-056). The wipe direction effectively superseded the drain script's contract but the script wasn't swept in the same iter. P116 (33 unpushed commits hitting CI as one batch) was the surfacing mechanism — local CI didn't run on the wipe commit alone, so the test regression wasn't caught until the batch push today.

Surface 2026-05-05 during the P170 story map Slice 1 release-queue drain (user-direction "Drain release queue + end session" after Slice 1 commit). push:watch failed CI on hook tests; investigation revealed the drift; user-direction "Fix tests now, then drain" landed the synthetic-fixture workaround so CI could go green; this ticket captures the deeper script-vs-format divergence for a future fix iter.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Confirm `drain-register-queue.sh` line 51-66 TEMPLATE_FILE gate is purely vestigial (TEMPLATE_FILE arg unused in python body) — quick `grep -n template_file packages/risk-scorer/scripts/drain-register-queue.sh` confirms only line 91 unpacking, no read
- [ ] Decide canonical R-file naming convention: `.active.md` (script's current expectation) vs `.md` (post-wipe canonical). The wipe direction says bare `.md`; the script needs to align.
- [ ] Audit other consumers of the R-file shape — `extract-risks-from-reports.sh`, `bootstrap-catalog` skill, `create-risk` skill — for the same divergence
- [ ] Plan minimal-scope fix: (a) remove TEMPLATE_FILE gate from drain script (vestigial), (b) update generated filename to bare `.md`, (c) update dedupe regex to `^R(\d+)-(.+)\.md$`, (d) replace synthetic-fixture bats setup with real-shape fixtures, (e) reciprocal contract bats asserting the script's output matches the canonical catalog format
- [ ] Create reproduction test: a behavioural bats that runs the drain script + asserts the output filename is canonical-shape

## Dependencies

- **Blocks**: graduation of `@windyroad/risk-scorer` queued changeset (P168 / ADR-059) without producing divergent R-files in adopter projects. Currently the queued changeset is on `.changeset/` awaiting release; the divergence won't manifest until the script actually fires against an adopter's `docs/risks/` post-release.
- **Blocked by**: (none directly — fix is bounded to the risk-scorer package; no external dependencies)
- **Composes with**: P168 (the wipe direction's parent ticket; this is the cleanup pass), ADR-056 (Phase 2b drain — this script is the deliverable), ADR-059 (consume-catalog protocol — divergence affects what consumers see).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- P168 (Verifying — pipeline consume-catalog + bootstrap; the wipe commit `8edaf7b` was Commit 3 of P168's fix chain)
- ADR-056 (Phase 2b drain — `drain-register-queue.sh` is the deliverable that needs the sweep)
- ADR-059 (consume-catalog and bootstrap-from-reports — describes the new catalog shape)
- P116 (push:watch local-only-commits hazard — surfacing mechanism: 33 unpushed commits batched today exposed the latent CI regression)
- Today's commits landing the synthetic-fixture workaround (CI-green hold-over until this ticket fixes the underlying script)
- User direction 2026-05-04: *"FFS WIPE THE RXXX risks ... THEY ARE WRONG"* + *"There shouldn't be a template in the directory"* (P168 ticket body, ADR-059 cross-reference)
