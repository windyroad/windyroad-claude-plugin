# Problem 154: P137 namespace-prefix detector must run against npm pack output not source tree — source-tree advisory misses publish-manifest drift class (broken-shim regression caught only after production ship)

**Status**: Verification Pending
**Reported**: 2026-05-03
**Priority**: 15 (High) — Impact: Significant (3) x Likelihood: Almost certain (5)
**Effort**: M — bounded extension to ADR-055's `check-namespace-prefix-leakage.sh` advisory: invoke `npm pack --pack-destination /tmp/<workspace> --json` per workspace package, extract the resulting tarball, walk the extracted file set with the existing detector. Behavioural bats per ADR-052 (synthetic broken fixture asserting tarball-only-leak detection vs source-tree-only-leak detection). No new ADR required — covered under ADR-055's reassessment-criteria clause + composes with ADR-049 plugin-bundled-script resolution. XL only if it requires reshaping the entire detector pipeline; M as a sibling advisory script + invocation in retro Step 2b cross-reference.

**WSJF**: (15 × 1.0) / 2 = **7.5**

> Surfaced 2026-05-03 by user during the AFK `/wr-itil:work-problems` loop, mid-iter-20: *"hey, for P137, should it run against the package.tgz that get's produced by npm pack?"*. Question landed at exactly the right moment — iter 20 (P033 Phase 2b) had ALSO surfaced (sibling-finding) that `packages/itil/package.json` files array was missing `"scripts/"`, causing `bin/wr-itil-*` shims (added by iter 3 P151 fix shipped in @windyroad/itil@0.23.2) to publish broken across 5 production versions (itil@0.23.2 → 0.24.0). First production-real instance of exactly the regression class the user's question covers — the source-tree-walking detector (just shipped iter 17 P137 Phase 1 + ADR-055 in @windyroad/retrospective@0.15.0) missed this because the source tree exposes `scripts/` even when the published tarball doesn't.

## Description

P137 Phase 1 (just shipped 2026-05-03 in @windyroad/retrospective@0.15.0 with ADR-055 namespace-prefixed-permalinks resolution + advisory detector) walks `packages/*/SKILL.md`, hooks/*.sh, agents/*.md etc. directly in the source tree. The detector greps for un-prefixed internal IDs (`ADR-NNN`, `JTBD-NNN`, `P-NNN`) and emits drift instances with classification by class. ADR-055 codifies the rule: `ADR-NNN → WR-ADR-NNN`, `JTBD-NNN → WR-JTBD-NNN`, `PNNN → WR-PNNN`.

**The gap**: the detector measures source-tree state, not publish-manifest state. What ships to npm under `@windyroad/<plugin>` is the file set produced by `npm pack` — which filters via `.npmignore` and `package.json#files`. The detector can therefore:

1. **False-positive on filtered files** — internal scripts, test fixtures, dev-only docs that the user never sees. Source-tree advisory flags them; adopter never sees them.
2. **Miss files in the tarball that aren't on the walked path** — anything outside the walked globs that ships via `files: ["..."]` in package.json.
3. **Miss entire missing-from-tarball regressions** — exactly the iter-20 sibling-finding shape: bin shim references `../scripts/` which IS in source tree (so source-tree advisory wouldn't flag any leak there) but is MISSING from the published tarball (so adopter shims hard-fail at exec).
4. **Miss build-step transformations** — none today, but future contract should be tarball-based not source-based for forward-compatibility (transpile, bundle, rewrite).

P137's detector is correct at what it measures: drift between source-tree content and the namespace-prefix rule. P154 is about adding a SECOND detector mode (or a second pass) that measures drift between the published tarball and the same rule. Both axes matter; neither subsumes the other.

The user's framing in their question elevates this from "nice to have" to "load-bearing for the detector's purpose": the detector exists to catch things that confuse adopter agents (per JTBD-302 plugin-user "Trust README describes installed behaviour"). What confuses adopter agents is what the adopter actually sees when they `npm install @windyroad/<plugin>` and the agent reads `node_modules/@windyroad/<plugin>/...`. That's the tarball, not the source tree.

## Symptoms

- An adopter installs `@windyroad/itil@0.24.0` (current latest as of 2026-05-03 prior to R1 fix-and-continue patch) and invokes `wr-itil-reconcile-readme` (per published `manage-problem` SKILL.md Step 0). The shim resolves on `$PATH` but exec-s into `../scripts/reconcile-readme.sh` — `scripts/` is NOT in the `files` array of itil's `package.json`, so the script is not in the tarball, so the exec fails with `no such file or directory`. **First production-real instance — driver for P154.**
- The 2026-05-03 source-tree-walking detector (ADR-055 + check-namespace-prefix-leakage.sh, Phase 1 advisory) reports baseline `13 packages / 81 files / 2880 drift_instances` against the source tree. It has zero output describing the broken-shim publishing-manifest leak — because that leak only manifests in the tarball, which the source-tree advisory does not measure.
- An iter authoring a new bin shim follows the ADR-049 pattern (bin/wr-<plugin>-<name> + scripts/<name>.sh) but forgets to update package.json files array — exactly what iter 3 P151 fix did for itil and iter 20 P033 Phase 2b had to retroactively fix. The pattern is repeatable; without a tarball-shape detector, every new shim is a candidate for the same bug.
- Adopter agents reading `node_modules/@windyroad/<plugin>/CHANGELOG.md` see entries citing `bin/wr-<plugin>-<name>` shims as "added" / "fixed" — but the corresponding scripts aren't in the install. Adopter trust degrades silently.
- A future build step (e.g. transpilation, content rewrite during pack) would invalidate the source-tree advisory entirely; the source content and shipped content would diverge by design. Tarball-shape detector is forward-compatible.

## Workaround

Source-side temporary workarounds:

- Manual: every PR that touches `bin/` or `scripts/` runs `npm pack --dry-run` and a human inspects the file list. Brittle (skipped under time pressure); doesn't survive AFK iters.
- Adopter-side: clone the source repo, point claude-plugin marketplace at the local clone via dev mode. Defeats the plugin model.
- Adopter-side: `npm install` then manually copy missing scripts/ from the source GitHub repo. Heavyweight; brittle on plugin updates.

Until P154 lands, mitigation is inspection + hot-fix-and-continue per the iter-20 + R1 precedent (sibling-finding caught after production ship; ADR-042 above-appetite remediation R1 closed the broken-shim case for itil; P154's detector would catch the next instance pre-release).

## Impact Assessment

- **Who is affected**: The **plugin-user persona** (`docs/jtbd/plugin-user/persona.md` + JTBD-302 just-shipped 2026-05-03). Every adopter project that installs any `@windyroad/<plugin>` package whose `package.json` files array might drift from the bin/scripts/agents/hooks layout the SKILL.md / agents / hooks reference at runtime.
- **Frequency**: Continuous risk class. Drift instances accumulate from every commit that adds new bin shims, new scripts, new files-referenced-by-shipped-content paths without simultaneously updating the files array. The risk is bounded by the rate of bin/scripts/ surface change × the rate of files-array audits — with the latter currently 0 (no detector).
- **Severity**: Significant — adopters experience hard exec failures on documented invocations. Per RISK-POLICY Impact-3 ("...some adopters confused or misled, no data corruption, recoverable...") — adopter has a recovery path (upgrade to next patched version) but the trust-violation in the meantime is real and observable.
- **Likelihood**: Almost certain — known gap, no controls in place, **already manifest** across 5 published itil versions. Matches RISK-POLICY Likelihood-5 verbatim ("Known gap, no controls in place, or previously observed failure mode").
- **Analytics**: Direct production evidence (2026-05-03):
  - @windyroad/itil@0.23.2 / 0.23.3 / 0.23.4 / 0.23.5 / 0.24.0 — all 5 versions on npm carry broken shims (`bin/wr-itil-reconcile-readme` + `bin/wr-itil-check-problems-readme-budget`). 5/5 versions affected. ADR-055 source-tree advisory reported drift_instances=2880 baseline but ZERO of those instances flagged the broken-shim publishing-manifest leak.
  - Iter 20 (P033 Phase 2b) sibling-finding made the bug observable. Without iter 20's coincidental need to add `scripts/` to risk-scorer's files array, the broken itil shims would have shipped uncaught for an unbounded number of further releases.
- **Concrete user-cited evidence (2026-05-03 mid-iter-20)**: user observed *"hey, for P137, should it run against the package.tgz that get's produced by npm pack?"*. Question surfaced exactly when iter 20's broken-shim sibling-finding was about to be reported in the ITERATION_SUMMARY. P154 is the load-bearing form of P137's prevention surface — the source-tree advisory becomes a fast pre-publish smoke test; the npm-pack-output detector becomes the release-time CI gate.

## Root Cause Analysis

### Preliminary Hypothesis

ADR-055's Phase 1 detector is correctly scoped to source-tree drift but the design didn't yet anticipate that `package.json#files` is itself a contract surface the detector should validate. The fix shape:

1. **Add a tarball-shape detector mode** — script extension that runs `npm pack --pack-destination <tmpdir> --json` per workspace package (or `npm pack --workspaces --json` from root if the marketplace structure permits it), parses the JSON output to locate each `*.tgz`, extracts each tarball to a structured tmpdir, and walks the extracted file set with the existing namespace-prefix detector logic. The same drift instance vocabulary applies; the only delta is the file-set source.
2. **Cross-check files-array integrity** — for every `bin/wr-<plugin>-<name>` shim in the tarball, assert that its target `scripts/<name>.sh` (or wherever the shim exec-s) is also in the tarball. This catches the iter-20 broken-shim class directly. Same script can also assert that every file referenced by a shipped SKILL.md / hook / agent is itself shipped.
3. **Phase 1 advisory mode** — exit-0 always per ADR-013 Rule 6 + ADR-040 declarative-first. Emit `TARBALL_DRIFT package=<name> tgz=<path> shim=<bin/wr-...> target=<scripts/...> tarball-status=<missing|present>` lines.
4. **Phase 2 R6-gated load-bearing hook escalation** — if drift instances persist across 3 consecutive `chore: version packages` releases, escalate to a release-time CI gate per the P131/P135 R6 precedent.
5. **Wire into retro Step 2b cross-reference** — same shape as the source-tree detector wires in (when it lands) — so the advisory surfaces during AFK loops too.

Candidate fix shapes to explore in the architect-design phase:

1. **Single advisory script extending check-namespace-prefix-leakage.sh** — adds a `--mode tarball|source|both` flag. Default `source` for backward compatibility; `tarball` for the new mode; `both` for CI invocation. P154's primary recommended shape.
2. **Separate sibling script `check-tarball-shipped-shims.sh`** — focuses purely on bin/scripts/ resolvability inside the tarball. Smaller scope; cleaner audit trail; doesn't muddy the existing namespace-prefix detector. Architect's call.
3. **prepublishOnly hook in package.json** — runs the detector inline at publish-time. Closest to release-time CI gate but couples plugin packaging to the detector. Probably Phase 2 territory.
4. **Postpack validator** — runs after `npm pack` produces the tgz, validates contents, fails the publish if drift detected. Sibling shape to (3); release-time-only.

### Investigation Tasks

- [ ] Confirm `npm pack --json` output shape across the workspace (per-workspace tarball produced; expected fields: `filename`, `files`, `entryCount`, etc.).
- [ ] Survey existing `bin/wr-<plugin>-<name>` shims across all `@windyroad/*` plugins — count how many follow the ADR-049 pattern + how many have files-array-aligned manifests. Establishes the broken-shim baseline.
- [ ] Architect review — pick fix shape (1) extension vs (2) sibling script. Decide whether Phase 1 lands now as advisory-only OR includes the prepublishOnly invocation pattern.
- [ ] Implement Phase 1 advisory + behavioural bats per ADR-052 (synthetic broken fixture: a workspace with a shim referencing a script not in files array; expect TARBALL_DRIFT line; clean fixture: same workspace with files array including scripts/; expect zero output).
- [ ] Wire the advisory invocation into `/wr-retrospective:run-retro` Step 2b cross-reference — same shape as the source-tree detector when that wiring lands.
- [ ] Phase 2 (R6-gated): after 3 consecutive releases observed without recurrence, evaluate whether to escalate to a release-time CI gate (postpack validator).
- [ ] Generalise to non-shim manifest drift — files referenced from shipped SKILL.md / hooks / agents that are themselves not shipped. Same detector class.
- [ ] Filed as separate ticket if scope expands beyond `@windyroad/*` plugin packaging — adopter-project tarball drift would compose-with this surface (e.g., adopter SaaS marketing HTML / public docs that drift from the actual published product feature set, per P152 Phase 2 generalization).

## Dependencies

- **Blocks**: P137 Phase 2 mechanical sweep — the sweep should run against tarball output not source tree, so P154 must land before Phase 2 to ensure the sweep targets the ground-truth file set.
- **Blocked by**: (none — P137 Phase 1 advisory already shipped; P154 extends it. P033 Phase 2b's iter-20 sibling-finding provided the empirical ground truth that motivates this ticket but doesn't strictly block it.)
- **Composes with**: P137 (parent — semantic correctness of internal-ID references in shipped artifacts; P154 is the publish-manifest-aware variant); P151 / ADR-049 (executable correctness of plugin-bundled scripts via bin/-on-PATH; P154's tarball detector validates the same shim shape from the publisher side); P140 (Step 6.5 fix-and-continue — P154 closes the prevention surface that fix-and-continue currently catches as remediation only); P082-family (changeset / CHANGELOG content gates — same publish-manifest-as-contract framing); P137 Phase 2 mechanical sweep (depends on P154's tarball-aware detector for ground-truth file set)

## Related

- P137 (`docs/problems/137-published-plugin-artifacts-reference-internal-ids-confuses-adopter-agents.verifying.md`) — parent ticket; Phase 1 advisory just shipped iter 17 + @windyroad/retrospective@0.15.0; P154 is the npm-pack-output sibling that makes the detector load-bearing for the actual adopter visibility surface.
- P151 (`docs/problems/151-published-skills-reference-repo-relative-script-paths.verifying.md`) — closed Verifying via @windyroad/itil@0.23.2 + bin/-on-PATH ADR-049. The shim shape iter 20 found broken in package.json files array originated here.
- P140 (`docs/problems/140-...verifying.md`) — Step 6.5 fix-and-continue contract; P154's release-time gate would close the prevention surface that fix-and-continue catches as remediation.
- ADR-049 (`docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md`) — codifies the bin/wr-<plugin>-<name> + scripts/<name>.sh pattern; P154 validates that BOTH paths reach the tarball.
- ADR-055 (`docs/decisions/055-...proposed.md`) — namespace-prefix advisory rule + Phase 1 source-tree detector; P154 extends to tarball-shape variant under reassessment-criteria clause.
- ADR-040 (`docs/decisions/040-declarative-first-then-enforce.proposed.md`) — Phase 1 advisory / Phase 2 R6-gated escalation pattern; P154 follows.
- ADR-013 (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) Rule 6 — non-interactive fail-safe; advisory exit-0 always.
- JTBD-302 (`docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`) — primary persona job served. Adopter-trust framing for the detector's load-bearing-ness.
- 2026-05-03 R1 commit (3f671b9 in this AFK loop session) — "fix(itil): ship scripts/ in tarball so wr-itil-* shims resolve in adopters (P140 fix-and-continue R1)". First production fix-and-continue of the very regression class P154 closes.
- iter 20 ITERATION_SUMMARY (P033 Phase 2b) — sibling-finding source. Recorded inline:
  > "itil's package.json `files` array is missing 'scripts/' — its existing wr-itil-* shims (wr-itil-reconcile-readme etc.) exec into ../scripts/ which doesn't ship in the npm tarball. Same root cause as the risk-scorer fix above. Recommend follow-up ticket / fix-and-continue iter to add 'scripts/' to packages/itil/package.json."

## Fix Released — Phase 1 (2026-05-03 P154 iter)

Phase 1 of the tarball-shape detector shipped via `@windyroad/retrospective` minor bump (changeset `wr-retrospective-p154-tarball-shipped-shims-advisory`). Concretely:

- **Advisory detector** — `packages/retrospective/scripts/check-tarball-shipped-shims.sh`. Diagnose-only, silent-on-pass per ADR-045 + ADR-013 Rule 6 + ADR-040. Walks `<root>/packages/<plugin>/package.json` workspaces; runs `npm pack --dry-run --json` per workspace to enumerate the shipped file set; for every `bin/wr-<plugin>-<name>` shim in the tarball, parses the shim source for the `exec`'d `scripts/<name>.sh` target and asserts the target path is also in the tarball. Skips non-ADR-049-grammar bins (`bin/install.mjs`, `bin/check-deps.sh`, `bin/windyroad-<plugin>` legacy installers). Reports `TARBALL_DRIFT package=<name> shim=<bin/wr-...> target=<scripts/...> tarball-status=missing` lines + `TOTAL packages=<N> with_drift=<M> missing_targets=<K>` summary. Exit 0 always. Exit 2 on parse error (root dir missing or `npm` unavailable).

- **Bin shim** — `packages/retrospective/bin/wr-retrospective-check-tarball-shipped-shims` per ADR-049 grammar.

- **Behavioural bats fixture** — `packages/retrospective/scripts/test/check-tarball-shipped-shims.bats` per ADR-052 default. 15 tests, all GREEN. Asserts script *output* on temp-fixture trees, never script source content. Coverage: clean workspace silent-on-pass; broken-shape workspace (`files: ["bin/"]` omitting `scripts/`) emits the canonical TARBALL_DRIFT line; multi-shim and multi-package aggregation; deterministic `<package>/<shim>` sort order; non-ADR-049-grammar bin exclusion; missing-root-dir exit 2 path.

- **Dogfood-fix** — `packages/retrospective/package.json` adds `"scripts/"` to the `files` array. Pre-fix smoke: detector reported 5 TARBALL_DRIFT instances under `@windyroad/retrospective` (the iter-20 regression class replicated across 5 sibling check-* shims — `wr-retrospective-check-internal-id-leaks`, `-check-readme-jtbd-currency`, `-check-skill-md-budgets`, `-list-plugin-attribution`, `-measure-context-budget`). Post-fix: silent-on-pass — all targets resolve in the tarball.

**Live-repo baseline**: as of the post-fix commit, `packages/retrospective/scripts/check-tarball-shipped-shims.sh .` returns no output (exit 0) — every `@windyroad/<plugin>` workspace currently passes the detector. This is the reassessment-anchor count for Phase 2 progress (zero drift means Phase 2 R6-gated escalation is currently inapplicable; reassess if drift rises).

**What's deferred (Phase 2)**:

- Wire the advisory into `/wr-retrospective:run-retro` Step 2b cross-reference alongside `check-internal-id-leaks.sh` (P137 Phase 1) and `check-readme-jtbd-currency.sh` (P158). Same shape as the source-tree detector — when the wiring lands, the advisory surfaces during AFK loops too.
- Promotion to load-bearing PreToolUse hook (Phase 3) iff drift_instances ≥ 1 across 3 consecutive `chore: version packages` releases without correction. Mirrors the ADR-052 PostToolUse-advisory → PreToolUse-blocking precedent.
- Generalisation to non-shim manifest drift (files referenced from shipped SKILL.md / hooks / agents that are themselves not shipped) — same detector class, separable extension.

**Composes with**: ADR-049 (executable correctness — sibling `bin/`-on-PATH ADR; this detector enforces ADR-049's confirmation criterion 5 from the publish-manifest side); ADR-055 (sibling adopter-context decision — same `packages/retrospective/scripts/` home + retro Step 2b cross-reference target when P137 Phase 2 wiring lands); ADR-052 (behavioural-tests-default); ADR-040 (declarative-first); ADR-038 (progressive disclosure); ADR-045 (silent-on-pass); ADR-013 Rule 6 (advisory-then-escalate fail-safe).

**Verification path for the user**: read this Fix Released section, run `packages/retrospective/scripts/check-tarball-shipped-shims.sh .` from the repo root, confirm silent-on-pass output (exit 0). Run the bats fixture: `node_modules/.bin/bats packages/retrospective/scripts/test/check-tarball-shipped-shims.bats` — confirm 15/15 tests pass. To exercise the broken-case detection, temporarily revert `"scripts/"` from `packages/retrospective/package.json#files` and re-run the detector; the 5 retrospective shim TARBALL_DRIFT lines should re-appear.

Awaiting user verification.
