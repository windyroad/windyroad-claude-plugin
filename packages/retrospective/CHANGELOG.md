# @windyroad/retrospective

## 0.20.0

### Minor Changes

- dd93da4: P087 Phase 3b — plugin maturity drift detector ships (`wr-retrospective-check-plugin-maturity-drift`). New `packages/retrospective/scripts/check-plugin-maturity-drift.sh` canonical body + `packages/retrospective/bin/wr-retrospective-check-plugin-maturity-drift` ADR-049 shim. Sibling to ADR-051's `check-readme-jtbd-currency.sh` — same detector pattern, different anchor (`plugin.json` `maturity:` field vs JTBD ID citation).

  Compares each plugin's rendered README maturity badge against the canonical `plugin.json` `maturity:` field and emits NDJSON-per-drift signals to stdout:

  - `missing-badge` — plugin.json has maturity but README has no badge
  - `stale-band` — README badge band mismatches canonical record
  - `orphan-badge` — README has badge but plugin.json has no maturity
  - `anti-pattern-section` — README has a standalone `## Maturity` section
  - `anti-pattern-url` — README has a shields.io URL or inline SVG

  Exit code 0 always per ADR-013 Rule 6 fail-safe / ADR-040 declarative-first — drift is data, not failure. Downstream consumers (run-retro Step 2b future wiring, release pre-flight habit, Phase 4 escalation per ADR-063 §Reassessment Triggers) decide whether to act.

  14 behavioural bats fixtures at `packages/retrospective/scripts/test/check-plugin-maturity-drift.bats` cover: clean fixture, stale-band, missing-badge, orphan-badge, anti-pattern-section, anti-pattern-url, multi-plugin aggregation, exit-0-always invariant, package-without-README skip, ADR-035 no-network primitive, NDJSON output shape.

## 0.19.0

### Minor Changes

- b22e006: P247 Phase 1: `/wr-retrospective:run-retro` Step 3 Tier 3 Branch B eliminates the "leave-as-is" fall-through (sibling-class to P246's cohort-graduation fix at the work-problems Step 6.5 surface).

  The prior contract permitted Branch B (file ratio between 1.0× and 2.0× ceiling) to fall through to "leave-as-is — record the OVER state in the Step 5 summary; no action this retro. Picks up next retro when more signal accumulates." Every retro re-deferred the same files; "more signal" was undefined. The 2026-05-17 session-4 wrap retro deferred 14 OVER topic files via this clause, prompting the user correction _"The 14 files are over the limit, but you are deferring splitting them. Why? When are you hoping they will get dealt with?"_ — which P247 captures verbatim.

  New contract:

  - Branch B always rotates — being OVER threshold IS the evidence; "wait for more signal to accumulate" is named in-prose as the fictional-defer anti-pattern P247 closes.
  - The three concrete triggers (subtopic / date / >=3 noise entries) remain; the fall-through when none fire becomes **split-by-date (safe default)** — mirroring Branch A's existing precedent ("zero false-split risk").
  - The trim-noise branch tightened: if trim alone brings the file below threshold, record as the rotation action; if still OVER, fall through to split-by-date in the same retro turn — do NOT defer.
  - ADR-013 Rule 5 + ADR-044 framework-mediated surface citations inlined so the silent-rotation discipline is discoverable from Branch B prose without cross-referencing.

  New behavioural+structural bats fixture `packages/retrospective/skills/run-retro/test/run-retro-step-3-tier-3-branch-b-evidence-based.bats` — 11 assertions: 5 behavioural input-signal fixtures against `check-briefing-budgets.sh` exercising the Branch A / Branch B selector ratios (1.0x / 1.5x / 1.96x / under-threshold / 2.0x) + 6 narrow SKILL-prose backstops per P081 linking the prose contract to the driver ticket (P247), the sibling-class precedent (P246), and the governance authorities (ADR-013 Rule 5, ADR-044 framework-mediated surface).

  Scope-bound per ADR-014: this changeset covers ONLY the SKILL contract amendment + tests + ticket lifecycle. The Phase 2 work — rotating the 14 currently-OVER topic files under the new contract — is deferred to a separate iter, with the P247 ticket itself serving as the scheduled-future-surface per P179 carve-out.

  Closes P247 Phase 1. P247 transitions Open → Known Error.

## 0.18.2

### Patch Changes

- 3fbcd53: P097 empirical baseline: first concrete application of ADR-054's sibling-`REFERENCE.md` pattern to `packages/retrospective/skills/analyze-context/`.

  Extracted `## Composition with sibling measurements` and `## ADRs cited` sections (~1.7KB combined) from `SKILL.md` to new sibling `REFERENCE.md`; added 2 lazy-load pointer lines per ADR-054 § "Sibling REFERENCE.md pattern" (~280B). Net `SKILL.md` reduction: -1,212 bytes (-7.7%); skill remains OVER WARN but no longer accumulates rationale + lineage at the runtime hot path. All 18 sibling structural-grep bats stay green (token-by-token verified pre-extraction); 21 `check-skill-md-budgets.sh` bats stay green.

  Content-equivalent refactor — no behavioural change to the `/wr-retrospective:analyze-context` flow. Per-skill `REFERENCE.md` sibling files are net-new in the retrospective package; this is the canonical empirical example for downstream plugin authors (JTBD-101) and the first proof-of-pattern instance ahead of P241 (MUST_SPLIT cohort, blocked by P081 Layer B), P242 (install-updates project-local), and P243 (WARN-band cohort) follow-ons.

## 0.18.1

### Patch Changes

- 670929a: P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T2: dual-tolerant SKILL.md glob updates for `docs/problems/` migration window

  Extend every load-bearing problem-ticket enumeration glob in `@windyroad/itil` and `@windyroad/retrospective` SKILL.md surfaces to be **dual-tolerant** — matches BOTH the current flat layout (`docs/problems/<NNN>-<title>.<state>.md`) AND a future per-state subdir layout (`docs/problems/<state>/<NNN>-<title>.md`). Forward-compatible: today's flat-layout tickets continue to enumerate identically; the new pattern matches zero files until T5's bulk migration commit lands per-state subdir tickets.

  **Files updated** (14 SKILL.md surfaces + 1 new bats fixture):

  - `packages/itil/skills/manage-problem/SKILL.md` — Step 3 next-ID compute (`local_max` + `origin_max` recursive enumeration per architect finding 2), Step 7 README-refresh prose, Step 8 list summary, Step 9 fast-path freshness check, Step 9b open/known-error scan, ticket-by-ID lookup at line 481.
  - `packages/itil/skills/work-problems/SKILL.md` — Step 1 backlog scan (state-filtered enumeration).
  - `packages/itil/skills/list-problems/SKILL.md` — scope prose, freshness check, live scan globs.
  - `packages/itil/skills/review-problems/SKILL.md` — scope prose, Step 2 re-scoring scan, Step 4 verification glob, Step 5 README rendering.
  - `packages/itil/skills/work-problem/SKILL.md` — freshness check pathspec pair.
  - `packages/itil/skills/transition-problem/SKILL.md` — Step 2 ticket discovery + Ownership boundary surface line.
  - `packages/itil/skills/transition-problems/SKILL.md` — Step 2a ticket discovery.
  - `packages/itil/skills/capture-problem/SKILL.md` — Step 2 duplicate-detect grep + Step 3 next-ID compute (recursive form per architect finding 2).
  - `packages/itil/skills/manage-incident/...`, `link-incident/SKILL.md`, `close-incident/SKILL.md`, `report-upstream/SKILL.md` — incident-side ticket lookups.
  - `packages/itil/skills/capture-rfc/SKILL.md`, `manage-rfc/SKILL.md` — forward-audit per architect 2026-05-07 advisory; problem-trace and RFC-section update lookups.
  - `packages/retrospective/skills/run-retro/SKILL.md` — Step 4a verification-close housekeeping glob.

  **New behavioural enforcement** (ADR-051 + ADR-052 load-bearing-from-the-start):

  `packages/itil/scripts/test/dual-tolerant-glob-rfc-002-t2.bats` exercises the canonical dual-tolerant pattern shapes (state-filtered enumeration, ID-anchored lookup, all-state-all-tickets next-ID compute, brace-expansion ID + state-set, pathspec-pair) against three synthetic fixtures (flat-only, per-state-only, mixed both-layouts). Asserts observable enumeration; does NOT structurally grep SKILL.md prose. P081-compliant per architect finding 3.

  **Architect finding 2 surface** — capture-problem and manage-problem next-ID compute use the recursive form `ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null | sed 's|.*/||' | grep -oE '^[0-9]+'` and `git ls-tree -r --name-only origin/main` so flat-104 + per-state-204 BOTH contribute to max-ID — never re-allocates an already-taken ID across the migration window.

  **Pathspec-pair contract** (load-bearing find for SKILL.md call sites): `ls X Y 2>/dev/null` where one half has zero matches exits NONZERO — the bats fixture documents this so SKILL.md call sites treat STDOUT emptiness as the canonical "no tickets" signal, NOT exit code zero.

  **T6 cleanup** removes the flat-layout half post-T5 verification, returning to ADR-031's prescribed single-pattern shape. The dual-pattern window spans T1 → T6 and bounds the transient layout-coexistence exposure.

  **No current behaviour changes**:

  - Flat-layout enumerations continue to enumerate identically (the new per-state half of the OR has zero matches today).
  - All other paths and skill semantics unchanged.
  - I2 invariant (no type-branching) verified against `packages/itil/scripts/test/i2-no-type-branching.bats` — all 9 I2 assertions pass post-edit.
  - Full repo bats suite (1,949 tests) green post-edit.

  Refs: RFC-002 T2; P069 (driver); P170 / ADR-060 (RFC framework dogfood).

## 0.18.0

### Minor Changes

- 91c28fb: P159: ship `retrospective-readme-jtbd-currency.sh` PreToolUse:Bash hook + ADR-051 amendment + Recommended Section Structure rewrite to load-bearing-from-the-start commit-gate with prose-woven framing

  Closes the gradualism gap that ADR-051 Phase 1's advisory-only consumption surface left open: the most-common drift class (contributor adds a skill/hook/agent and forgets the README) ships in a commit that does not touch README.md, so a retro-time consumer (P158, `df47ad1`) sees the drift only after the contributor has already committed. The amended Phase 1 ships the load-bearing-from-the-start variant: a PreToolUse:Bash hook on `git commit` runs the existing detector against the post-commit working tree and denies the commit when `drift_instances > 0`. The advisory script + retro Step 2b wiring survive as backup signals.

  User correction (P078 capture-on-correction) drove the direction: _"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"_.

  **What ships**

  - New PreToolUse:Bash hook `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh` — fires on `git commit` invocations (substring match catches `git commit -m`, `git commit --amend`, leading `cd && git commit`, `chore: version packages` release commits, etc.); runs `check-readme-jtbd-currency.sh` against the project's `./packages/` + `./docs/jtbd/`; denies with PreToolUse JSON when `TOTAL drift_instances > 0`. Per-invocation deterministic; no marker (mirrors P125 / P141 no-marker precedent — architect-approved when detection cost stays under ~150ms). Truncates the drift_hints CSV to the first hint to bound the deny-band ≤300 bytes for worst-case slug + hint combinations per ADR-045.
  - Wired into `packages/retrospective/hooks/hooks.json` as a PreToolUse entry with matcher `"Bash"`.
  - BYPASS env: `BYPASS_JTBD_CURRENCY=1` (parallel naming to sibling P141 `BYPASS_CHANGESET_GATE=1`). Fail-open paths per ADR-013 Rule 6: outside a git work tree, in adopter projects without `./packages/` or `./docs/jtbd/`, on detector-script failure, on parse error. Allow path silent-on-pass per ADR-045 Pattern 1.
  - Deny redirects to wr-jtbd:agent recovery + hand-edit fallback (graceful degradation when `@windyroad/jtbd` is not installed) per ADR-013 Rule 1.
  - 19 behavioural bats `packages/retrospective/hooks/test/retrospective-readme-jtbd-currency.bats` per ADR-052 — drift-detection × 7 (no-anchor, skill-inventory-drift, slug name, recovery path, deny-band, release commits, --amend); allow × 4 (clean, BYPASS, non-Bash, non-commit); fail-open × 5 (outside git tree, no packages/, no docs/jtbd/, empty JSON, malformed JSON); silent-on-pass × 3 (clean tree, non-Bash, non-commit). 19/19 green.

  **ADR-051 amendment** (`docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`)

  - New Decision Driver: "Load-bearing-from-the-start for drift class" — drift detectors are a different class from design-question / policy detectors; advisory-then-escalate gradualism re-creates the failure mode the detector exists to solve.
  - New Normative rule 4: PreToolUse:Bash hook gates `git commit` against the detector.
  - Recommended Section Structure clause **rewritten**: bolt-on `## Jobs to be Done` section rejected as anti-pattern; prose-weaving target guidance added (lead value-framing section names JTBD job; per-skill / per-hook / per-agent descriptions name the job they serve); persona-primacy preservation rules carried over (lead prose's value framing reflects primary readership persona); heading vocabulary remains non-normative.
  - Confirmation criterion 5 amended: Phase 1 surface is the commit-hook + retro Step 2b advisory backup.
  - Confirmation criterion 6 added: hook bats coverage.
  - Confirmation criterion 8 amended: original "escalate-after-3-releases" trigger superseded; new trigger monitors load-bearing surface for false-positives + undetected semantic drift + generalisation pressure.
  - Reassessment Criteria block refreshed to reflect the load-bearing surface + new generalisation trigger (P161).
  - Out-of-scope updated: Phase 2 (12-README prose-weaving refresh) deferred; auto-fix orchestration (wr-jtbd:agent grant-Edit decision) deferred; load-bearing-as-default-for-drift-class generalisation queued at P161.
  - Consequences updated: Bad/Good/Neutral sections refreshed for the commit-hook surface; performance budget cited (~80–150ms per commit; ~3s per AFK session).

  **JTBD doc edits** (per JTBD agent's Phase 1 acceptance criteria)

  - `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`: Desired Outcome bullet 6 rewritten from "advisory in Phase 1, escalates if drift accumulates" to "load-bearing at commit time per P159; retro/release-time advisories ride as backup signals". Related decisions block updated: ADR-051 description refreshed; new entries for P159 + P158.
  - `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md`: Desired Outcome line 22 rewritten from "detectable via advisory script" to "enforced at commit time via PreToolUse:Bash hook; retro/release-time advisories ride as backup signals". Related decisions block updated.

  **Tactical bootstrap drift fixes** (ADR-053 bootstrapping clause precedent)

  - `packages/architect/README.md`: added `/wr-architect:capture-adr` skill mention (clears the existing skill-inventory-drift hint from `d28bd51`).
  - `packages/itil/README.md`: added `/wr-itil:capture-problem` skill mention (clears the existing skill-inventory-drift hint from `86e99e5`).
  - These are tactical drift-currency fixes, not the strategic Phase 2 prose-weaving refresh (deferred to a separate iter).

  Post-fix detector signal: `TOTAL packages=12 with_jtbd=12 drift_instances=0` — bootstrap commit clears the gate naturally without BYPASS.

  **Verdicts**

  Architect: PASS — proceed with Phase 1 design as scoped. Five advisory observations folded in: hook placement in retrospective confirmed; fire on any `git commit` confirmed; in-place ADR-051 amendment (no supersession); P158 lifecycle Verifying → Closed; deny string graceful-degradation fallback added.

  JTBD: PASS — three same-commit doc edits all applied (JTBD-302 + JTBD-007 + ADR-051 amendment carries prose-weaving target guidance + persona-primacy preservation + anti-pattern citation). Re-review after JTBD policy edits also PASS.

  **Phase 2-3 explicitly deferred**: 12-README prose-weaving refresh; auto-fix orchestration via wr-jtbd:agent grant-Edit decision. P158 transitions Verifying → Closed (retro wiring survives as backup advisory). P161 filed for the broader drift-class-generalisation observation.

  Closes P159

## 0.17.0

### Minor Changes

- d1156ab: P154: ship `check-tarball-shipped-shims.sh` advisory + dogfood-fix `scripts/` in `files` array so detector + sibling shims actually resolve in adopters

  Closes the iter-20 sibling-finding regression class — `bin/wr-<plugin>-<name>` shims that exec into `../scripts/<name>.sh` but ship broken because `package.json#files` omits `scripts/`. The source-tree-walking detector shipped in `@windyroad/retrospective@0.15.0` (ADR-055 + check-internal-id-leaks.sh, P137 Phase 1) measures source-tree namespace-prefix drift but cannot see this publishing-manifest leak — `scripts/` exists on disk so the source-tree advisory finds nothing, while the npm tarball ships without it so adopters hit `no such file or directory` at invocation time.

  P154 closes that prevention surface from the publish-manifest side.

  Adds:

  - `packages/retrospective/scripts/check-tarball-shipped-shims.sh` — diagnose-only advisory that runs `npm pack --dry-run --json` per workspace, parses the `files` array, and asserts every `bin/wr-<plugin>-<name>` shim's `exec`'d `scripts/<name>.sh` target is also in the tarball. Silent-on-pass (no output when clean) per ADR-045. Always exits 0 (advisory only) per ADR-013 Rule 6 + ADR-040 declarative-first. Emits `TARBALL_DRIFT package=<name> shim=<bin/...> target=<scripts/...> tarball-status=missing` lines + `TOTAL packages=<N> with_drift=<M> missing_targets=<K>` summary on drift, terse machine-readable per ADR-038. Skips non-ADR-049-grammar bins (`bin/install.mjs`, `bin/check-deps.sh`, `bin/windyroad-<plugin>` legacy installers) — only ADR-049-shape shims are subject to the contract. Pre-checks for `npm` on PATH; exits 2 if root dir or npm missing.
  - `packages/retrospective/bin/wr-retrospective-check-tarball-shipped-shims` — `$PATH`-resolved shim per ADR-049 grammar. Adopter invocation point for the new advisory.
  - `packages/retrospective/scripts/test/check-tarball-shipped-shims.bats` — 15 behavioural tests per ADR-052 default. Asserts script output on temp-fixture trees: clean workspace produces no output; broken-shape workspace (`files: ["bin/"]` omitting `scripts/`) emits the canonical `TARBALL_DRIFT` line; multi-package + multi-shim drift aggregates correctly; non-ADR-049-grammar bins are silently ignored; output is sorted deterministically by `<package>/<shim>` identifier.

  Dogfood-fix:

  - `packages/retrospective/package.json` — adds `"scripts/"` to the `files` array. The new tarball-shipped-shims script + the 5 sibling check-\* shims (P137 Phase 1 + sibling advisories) all `exec` into `../scripts/` paths; without `scripts/` in `files`, the tarball ships every adopter shim broken. Same fix-and-continue R-pattern as `@windyroad/itil@0.23.x` → `0.24.0` (commit 3f671b9, P140 R1 — adopter shims silently broken across 5 published versions before P154's detector existed to catch it).

  Live-repo verification (pre-fix): `packages/retrospective/scripts/check-tarball-shipped-shims.sh .` reported 5 broken shims under `@windyroad/retrospective` (the iter-20 regression class replicated). Post-fix: silent-on-pass — all targets resolve in the tarball.

  Composes with:

  - ADR-049 (executable correctness — sibling `bin/`-on-PATH ADR; P154 detector enforces ADR-049's confirmation criterion 5 from the publish-manifest side).
  - ADR-052 (behavioural-tests-default — fixture asserts script output on temp trees, not source content).
  - ADR-055 (sibling adopter-context decision — same `packages/retrospective/scripts/` home + retro Step 2b cross-reference target when P137 Phase 2 wiring lands per ADR-055 Confirmation criterion 4).
  - ADR-040 (declarative-first then enforce — Phase 1 advisory, Phase 2 R6-gated escalation to release-time CI gate deferred per ticket).
  - ADR-038 (progressive disclosure — terse machine-readable signal).
  - ADR-045 (hook injection budget — silent-on-pass discipline).
  - ADR-013 Rule 6 (advisory-then-escalate fail-safe).

  JTBD-302 (Trust That the README Describes the Plugin I Just Installed — plugin-user persona) is the primary anchor: adopter-installed shims that hard-fail with `no such file or directory` are exactly the trust-violation the JTBD codifies. JTBD-101 (Extend the Suite with New Plugins — plugin-developer) is the secondary anchor: future contributors adding new `bin/wr-<plugin>-<name>` shims get retro-time feedback before the regression ships.

  Phase 2 (deferred): wire the advisory into `/wr-retrospective:run-retro` Step 2b alongside check-internal-id-leaks.sh and check-readme-jtbd-currency.sh; promote to load-bearing PreToolUse hook iff drift_instances ≥ 1 across 3 consecutive `chore: version packages` releases without correction.

## 0.16.0

### Minor Changes

- df47ad1: P158: wire ADR-051 Phase 1 JTBD currency advisory into `/wr-retrospective:run-retro` Step 2b

  `/wr-retrospective:run-retro` Step 2b now invokes `wr-retrospective-check-readme-jtbd-currency` (the ADR-051 Phase 1 detector shipped under P152) on every retro and surfaces drift findings in the retro summary's Pipeline Instability section. Wiring was originally deferred per ADR-051 Confirmation criterion 5 ("wiring into `/wr-retrospective:run-retro` Step 2b is deferred to a follow-on iter once the detector is empirically validated against current READMEs"); the validation precondition was met by the retroactive 12-plugin README refresh that landed alongside this change (commit 8df1692).

  Adds:

  - New "JTBD currency advisory (ADR-051 Phase 1, P158)" sub-section in run-retro Step 2b. Runs the detector advisory; emits one-line clean signal when `drift_instances == 0`, full per-package code block when `drift_instances ≥ 1`, fail-open inline log when the detector exits non-zero. Same fail-open contract as Step 3's `check-briefing-budgets.sh` defensive trip.
  - `packages/retrospective/README.md` documents the wiring + lists every shipped advisory shim under a new `## Advisory scripts` section. Closes the residual `skill-inventory-drift` finding the detector was producing pre-wiring.

  The change is advisory-only — `drift_instances` is signal-as-data, not a gate. Phase 2 escalation criterion (load-bearing hook iff `drift_instances ≥ 2` across 3 consecutive `chore: version packages` releases without correction) is captured inline so future contributors know the bar.

  JTBD-302 (Trust That the README Describes the Plugin I Just Installed) is now serviced at retro-time rather than only at audit-prep time. JTBD-007 (Keep Plugins Current Across Projects) currency dimension extended from code-currency to README-content-currency per ADR-051.

## 0.15.0

### Minor Changes

- 439f30e: P137 Phase 1 — plugin-published artefacts use namespace-prefixed permalinks for internal IDs (ADR-055).

  Adds `check-internal-id-leaks.sh` at
  `packages/retrospective/scripts/check-internal-id-leaks.sh` — a read-only
  advisory script that walks shipped-artefact surfaces under
  `<root>/packages/<plugin>/` (skills/<skill>/SKILL.md, agents/_.md,
  hooks/_.sh, CHANGELOG.md) and reports each artefact carrying bare
  internal-ID tokens (`ADR-NNN` / `JTBD-NNN` / `PNNN`) that lack the
  `WR-` namespace prefix.

  The detector emits `OVER <plugin>/<file> bare_count=<N>` lines for each
  file with leaks plus a final `TOTAL packages=<N> with_leaks=<M>
drift_instances=<K>` summary. Output is empty when no shipped artefact
  carries bare tokens — silent-on-pass per the hook injection budget
  discipline. Always exits 0 (advisory only); exit 2 only on root-dir
  parse error.

  REFERENCE.md sibling files are excluded from the scan per the SKILL.md
  runtime budget policy — they are intentionally lazy-loaded
  maintainer-facing content, not adopter-runtime. Lines beginning
  `# @adr` / `# @jtbd` / `# @problem` are also excluded so docstring
  structured annotations on script bodies don't false-fire (those
  annotations are maintainer source comments, never expanded into
  adopter agent context).

  ADR-055 (proposed in this release at
  `docs/decisions/055-plugin-published-namespace-prefixed-internal-ids.proposed.md`)
  codifies the resolution strategy. The chosen rule is **namespace-prefix
  as primary** (`ADR-014` written as `WR-ADR-014`, `JTBD-101` as
  `WR-JTBD-101`, `P137` as `WR-P137`) with **GitHub permalinks as
  progressive enhancement** — `[WR-ADR-014](https://github.com/windyroad/agent-plugins/blob/main/...)`.

  Rationale — only namespace-prefixing closes the wrong-resolution failure
  path. Adopter agents pattern-match on the visible token, not the URL
  host. `[ADR-014](https://github.com/windyroad/...)` still presents
  `ADR-014` as the human-readable token; an adopter project that has its
  own `ADR-014` will conflate them at the agent's pattern-match stage.
  Only a token-level disambiguator (`WR-`) closes failure mode 3 (adopter
  agent applies UNRELATED ADR-014 from its own tree).

  Five candidate strategies were considered (per the driver ticket §RCA);
  ADR-055 explicitly rejects strip (lossy — kills institutional
  cross-references), disclaimer-at-top (brittle — disclaimer fades from
  agent working memory by tool-result expansion), and build-step rewrite
  (premature — adds publish-pipeline coupling to solve a problem
  namespace + opportunistic-sweep solves at lower cost).

  A bin shim at `packages/retrospective/bin/wr-retrospective-check-internal-id-leaks`
  follows the bin/-on-PATH grammar so adopters running
  `npx @windyroad/retrospective` can invoke the detector via
  `wr-retrospective-check-internal-id-leaks` once their plugin install
  wires it onto `$PATH`.

  The bats fixture at
  `packages/retrospective/scripts/test/check-internal-id-leaks.bats` is
  behavioural-default — asserts script _output_ on temp-fixture trees,
  never script source content. 23 tests covering bare-ID detection across
  all 4 surfaces, WR-prefix exclusion, docstring-annotation exclusion,
  REFERENCE.md exclusion, deterministic ordering, count accuracy, TOTAL
  summary aggregation, and error path.

  **Baseline measurement** (2026-05-03 against the windyroad-claude-plugin
  source repo): `TOTAL packages=13 with_leaks=81 drift_instances=2880`.
  This is the reassessment-anchor count. Phase 2 opportunistic sweep
  proceeds when files are touched for other reasons; Phase 3 (promotion
  to blocking PreToolUse hook) triggers when `drift_instances ≤ 100` and
  three consecutive monthly retros confirm no regression.

  ADR-055 completes the adopter-context cluster of ADRs landed
  2026-04-28..2026-05-03: bin/-on-PATH (executable correctness),
  JTBD-anchored README (currency), behavioural-tests-default
  (test-discipline), maturity taxonomy (battle-hardening signal), SKILL.md
  runtime budget (size), and now namespace-prefixed internal IDs
  (semantic correctness). Six ADRs unified by the plugin-user
  "trust adopter-facing artefacts" frame.

  This release ships Phase 1 only — the advisory detector + the strategy
  ADR. Mechanical replacement across the 2,880 baseline drift instances
  follows opportunistically, no big-bang rewrite.

## 0.14.0

### Minor Changes

- 69a7546: P097 Phase 1 — SKILL.md runtime budget policy advisory detector.

  Adds `check-skill-md-budgets.sh` at
  `packages/retrospective/scripts/check-skill-md-budgets.sh` — a read-only
  advisory script that walks `<root>/packages/*/skills/*/SKILL.md` and
  `<root>/.claude/skills/*/SKILL.md`, measures byte size, and reports each
  SKILL.md exceeding the WARN threshold (default 8192 bytes) or the
  MUST_SPLIT threshold (default 16384 bytes) in the OVER / MUST_SPLIT
  output vocabulary inherited verbatim from `check-briefing-budgets.sh`
  (P099 / P145 / ADR-040).

  REFERENCE.md sibling files are excluded from the scan per ADR-054 — they
  are intentionally lazy-loaded via explicit SKILL.md pointers and not
  subject to the runtime budget.

  Bin shim ships at
  `packages/retrospective/bin/wr-retrospective-check-skill-md-budgets`
  per ADR-049 grammar.

  Behavioural bats fixture ships at
  `packages/retrospective/scripts/test/check-skill-md-budgets.bats` —
  21 tests, all behavioural per ADR-052 (asserts script output on
  temp-fixture skill trees, no greps of script source).

  Companion ADR in `docs/decisions/`:

  - ADR-054 (proposed) — SKILL.md runtime budget policy. Codifies the
    `[runtime]` / `[reference]` / `[deprecated]` content classification
    taxonomy, the sibling REFERENCE.md lazy-load pattern, the per-skill
    pointer-overhead ceiling (≤ 20 pointers / ≤ 1.6 KB), the byte
    budgets, and the P132 / ADR-044 silent-framework carve-out for
    REFERENCE.md reads.

  Thresholds are env-var overridable (`SKILL_MD_WARN_BYTES`,
  `SKILL_MD_MUST_SPLIT_BYTES`).

  Phase 1 advisory only. Phase 2-3 (retroactive `[reference]` extraction
  across the top-10 SKILL.md offenders) is `Blocked by: P081` Layer B
  maturity per the 2026-04-27 P097 Phase 1 audit finding (80 of 116
  manage-problem contract assertions structural-grep SKILL.md prose;
  behavioural retrofit needs P081 Layer B harness primitives first).

### Patch Changes

- 1804168: docs(retrospective): rewrite stale ADR-027 compatibility notes in run-retro/SKILL.md (P014 — ADR-032 supersession trail)

  ADR-027 (Governance skill auto-delegation) was superseded by **ADR-032** (Governance skill invocation patterns) on 2026-04-21. Three "ADR-027 compatibility note" blocks in `packages/retrospective/skills/run-retro/SKILL.md` (Step 2b lines around 166, Step 2c around 212, Step 4a around 377) described a hypothetical migration to Step-0 subagent auto-delegation that no longer happens — under ADR-032's foreground-synchronous pattern, run-retro's Steps execute directly in main-agent context with no subagent boundary to cross.

  This patch rewrites each of the three compat blocks to **ADR-032 supersession notes** that:

  - Cite ADR-032 as the supersession reference
  - Record explicitly that no Step-0 subagent migration applies
  - Preserve a parenthetical "(was: ADR-027 compatibility note)" pointer for cross-reference continuity with prior commits

  Bats tests at `test/run-retro-verification-close-housekeeping.bats:93-98` and `test/run-retro-pipeline-instability-scan.bats:83-86` are re-pointed at the new strings (`ADR-032 supersession note` + `No Step-0 subagent migration applies`). Both tests retain their structural-grep shape; converting to behavioural fixtures is a follow-up (P081 anti-pattern flagged in inline comments).

  Part of P014's execution-tracker work for ADR-032 closure conditions. The remaining ADR-032 deliverables (capture-problem skill, capture-adr skill, pending-questions-surface hook) are split into subordinate child tickets in a sibling commit; capture-retro stays deferred per P088.

## 0.13.0

### Minor Changes

- b18c142: feat(retrospective): JTBD-anchored README drift advisory script (closes P152 Phase 1)

  Adds `check-readme-jtbd-currency.sh` (and `wr-retrospective-check-readme-jtbd-currency` bin shim per ADR-049) — the Phase 1 advisory detector codified by ADR-051.

  The detector walks `packages/*/README.md`, greps for `JTBD-\d{3}` citations, resolves each cited ID against `docs/jtbd/<persona>/JTBD-NNN-*.md` (any status suffix), and emits per-package signal:

  ```
  README package=<name> has_jtbd_anchor=<yes|no> cited_jobs=<N> known_jobs=<M> drift_hints=<csv>
  TOTAL packages=<N> with_jtbd=<M> drift_instances=<K>
  ```

  `drift_hints` vocabulary:

  - `missing-jtbd-section` — README has no `JTBD-\d{3}` cite.
  - `stale-jtbd-citation` — cited ID has no resolving file under `docs/jtbd/`.
  - `deprecated-jtbd-citation` — cited ID resolves only to `.deprecated.md` / `.superseded.md`.
  - `skill-inventory-drift` — a directory under `packages/<plugin>/skills/` is not named in the README.

  Phase 1 closes the asymmetric pressure-stack P152 surfaces: the project has dense gates for code drift (architect, JTBD, risk-scorer, style-guide, voice-tone, TDD, changeset-discipline) but zero gates for README content drift. Plugin READMEs are hand-maintained and silently drift between releases — empirical baseline on detector first-run is 12/12 plugins flagged with `drift_instances=12`.

  Advisory only — exit code is always 0 per ADR-013 Rule 6 fail-safe / ADR-040 declarative-first / ADR-051 Phase 1. Phase 2 (R6-gated load-bearing hook) escalates if `drift_instances ≥ 2` across 3 consecutive `chore: version packages` releases without correction.

  Phase 1 ships:

  - ADR-051 — `@windyroad/*` plugin READMEs anchor on JTBD job IDs with declarative drift advisory.
  - JTBD-302 — Trust That the README Describes the Plugin I Just Installed (new plugin-user job).
  - JTBD-007 amendment — currency expansion from code-currency to doc-content-currency.
  - 12 behavioural bats fixtures (drift / clean / stale / deprecated / inventory / multi-package / no-readme cases) per ADR-005 + P081.
  - bin/ shim per ADR-049 naming grammar.

  Out of scope for Phase 1 (filed as follow-on work):

  - Retroactive refresh of the 12 plugin READMEs to JTBD-anchored shape.
  - Wiring the detector into `/wr-retrospective:run-retro` Step 2b.
  - Generalisation to adopter-project surfaces (marketing HTML, public docs, changelog narrative).
  - Walking `.github/ISSUE_TEMPLATE/*.yml` per JTBD-lead's Phase 1.5 recommendation.

  Architect APPROVED at low risk: net-new advisory script + ADR + JTBD job + JTBD amendment + bats; no executable code change; no commit-gate path touched. JTBD PASS — primary fit JTBD-302 (newly filed) + JTBD-007 (currency expansion); composition fit JTBD-001 / JTBD-101 / JTBD-202 / JTBD-301.

## 0.12.5

### Patch Changes

- 7fe4a2c: retrospective: `check-briefing-budgets.sh` now emits `MUST_SPLIT <basename> reason=ratio-exceeds-2x` for topic files at or above 2× the configured Tier 3 ceiling, in addition to the existing `OVER` line. `run-retro` Step 3 Tier 3 silent-agent rotation gains a Branch A heuristic that narrows the option set to split-by-subtopic / split-by-date (with split-by-date as the safe default) for `MUST_SPLIT` files — the `trim-noise` and `leave-as-is` defer escape hatches are not eligible. Branch B (only `OVER`, no `MUST_SPLIT`) retains the original four-option heuristic with defer permitted inside the reassessment-trigger envelope. This promotes ADR-040's "≥ 2× ceiling for ≥ 2 consecutive retro cycles" reassessment trigger from policy-revisit-time to per-cycle script enforcement, closing the recurring-defer accumulator gap (P145).

## 0.12.4

### Patch Changes

- 45e133d: P153: replace inline repo-relative `packages/*/hooks` and `packages/*/skills` directory-enumeration glob loops in `analyze-context` SKILL.md (Step 2 — Decompose per-plugin attribution, previously L56-67) with the `$PATH`-resolved `wr-retrospective-list-plugin-attribution` bin shim wrapper per ADR-049 reassessment-criteria clause 3. Adopter sessions running `/wr-retrospective:analyze-context` previously emitted zero `PLUGIN-HOOKS` / `PLUGIN-SKILLS` rows because the inline glob `packages/*/hooks` expanded to nothing in adopter trees (no `packages/` dir under adopter project root) — silent zero-byte degradation, distinct failure mode from P151's hard-fail at exit 127. The new helper script at `packages/retrospective/scripts/list-plugin-attribution.sh` resolves both modes: source-tree first (preserves windyroad source-repo dev-session output), `$PATH`-derived plugin-cache walk fallback (sniffs `*/cache/<owner>/<plugin>/<version>/bin` entries and back-walks each plugin's root for hooks + skills byte counts), and emits a `PLUGIN-ATTRIBUTION not-measured reason=no-plugin-source-resolvable` sentinel per ADR-026 when neither resolves. The 3-line shim wrapper at `packages/retrospective/bin/wr-retrospective-list-plugin-attribution` is `exec "$(dirname "$0")/../scripts/list-plugin-attribution.sh" "$@"` matching the ADR-049 naming grammar. New bats coverage: `packages/retrospective/scripts/test/list-plugin-attribution.bats` pins the script's behavioural contract (10 tests covering existence, exit code, source-tree output shape per plugin, multi-plugin enumeration, cache-fallback resolution from a synthetic cache layout, the not-measured sentinel branch, and ADR-038 ≤150-byte per-row budget); cross-plugin grep-as-lint at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` extended with a new `@test` block matching `for X in packages/<plugin>/{hooks,skills,scripts,bin}` directory-enumeration patterns and a new shim smoke test (11 tests total). ADR-049 reassessment-criteria clause 3 explicitly anticipated this surface; no new ADR required.

## 0.12.3

### Patch Changes

- 148d189: P151: replace `bash packages/retrospective/scripts/measure-context-budget.sh` invocations in published SKILL.md with the `$PATH`-resolved `wr-retrospective-measure-context-budget` bin shim wrapper per ADR-049. Adopter sessions running `/wr-retrospective:run-retro` Step 2c (cheap-layer context-budget measurement) and `/wr-retrospective:analyze-context` Step 2 (deep-layer baseline) previously hard-failed because the repo-relative path does not resolve in adopter trees. The new shim ships in `packages/retrospective/bin/` as a 3-line `exec "$(dirname "$0")/../scripts/measure-context-budget.sh" "$@"` body. Two SKILL.md invocation sites updated (`run-retro` Step 2c L179, `analyze-context` Step 2 L45). The canonical script body at `packages/retrospective/scripts/measure-context-budget.sh` is unchanged; existing `packages/retrospective/scripts/test/measure-context-budget.bats` continues to test the canonical path. ADR-049 codifies the rule: plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths; naming grammar `wr-<plugin>-<kebab-script-name>` is fixed. Cross-plugin grep-as-lint bats at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` catches regressions at CI.

## 0.12.2

### Patch Changes

- 3f3e71d: Close P148 (agent defers ticket creation to retro summary instead of immediately invoking `/wr-itil:manage-problem`). Architect-picked Fix 1+2 hybrid:

  - **Fix 1 (prose tightening)**: `run-retro` SKILL.md Step 4b Stage 1 AFK-branch rewritten to name `cause: skill_unavailable` as the only valid fallback gate, require every Tickets Deferred entry carry an explicit `cause:` field, enumerate the four named anti-pattern rationalisations the agent must NOT use (session-length pressure, lifecycle weight, retro-summary-defer preference, fabricated subcommands), cite the user's verbatim correction phrase, and cite ADR-044 framework-mediated surface + P145 sibling pattern. Step 5 retro summary template gains a `### Tickets Deferred` section with `Observation | Cause | Citation` columns.
  - **Fix 2 (advisory check script)**: new `packages/retrospective/scripts/check-tickets-deferred-cause.sh` walks `docs/retros/*.md` retro summaries and emits per-file plus TOTAL violation counts; exit 0 always (advisory per ADR-040 declarative-first / ADR-013 Rule 6); Cause allowlist is single-source `{skill_unavailable}`.

  23 behavioural bats added per ADR-037 + P081 (20 in `check-tickets-deferred-cause.bats` + 3 in `run-retro-stage-1-fallback-gating.bats`); 23/23 green; full retrospective suite 127/127 green confirming no regression.

## 0.12.1

### Patch Changes

- 258ac25: P135 Reassessment Trigger automation — Step 2d auto-flags Phase 4 enforcement hook when R6 numeric gate fires.

  Per ADR-044's Reassessment section + P135's R6 numeric gate (lazy AskUserQuestion count remains ≥2 across 3 consecutive retros after Phase 2/3 land), Step 2d "Ask Hygiene Pass" now auto-queues a deviation-candidate in the orchestrator's `outstanding_questions` queue when the gate fires. The deviation-candidate carries:

  - `category: "deviation-approval"`
  - `existing_decision: "ADR-044 Reassessment / declarative-first; P135 Phase 4 gated on R6"`
  - `contradicting_evidence: <3 consecutive retros' lazy counts + citations to docs/retros/<date>-ask-hygiene.md per retro>`
  - `proposed_shape: "amend"`
  - `rationale: "R6 numeric gate fired; declarative-first declared insufficient; Phase 4 enforcement hook now warranted per P135 plan"`

  The deviation-candidate surfaces at loop end (Step 2.5 in `/wr-itil:work-problems`) with the standard 5-option `AskUserQuestion`. **The framework reminds itself** — no manual tracking needed for the Phase 4 evaluation gate.

  ADR-044 Reassessment section amended to explicitly name the R6 numeric criterion + cross-reference Step 2d's auto-queue mechanism.

  Bats coverage: `packages/retrospective/skills/run-retro/test/run-retro-step-2d-r6-auto-flag.bats` (9 assertions covering Step 2d + ADR-044 cross-references).

  Refs: P135 (master), ADR-044 (Reassessment Trigger), ADR-014 (commit grain).

## 0.12.0

### Minor Changes

- fae42aa: P135 Phase 2 (Skill amendments — `@windyroad/retrospective` half) per ADR-044 (Decision-Delegation Contract).

  Removes per-action `AskUserQuestion` calls in `run-retro` where the framework has already resolved the decision (lazy deferral per Step 2d Ask Hygiene Pass classification). Replaces with silent agent-action + Step 5 retro summary surfacing. User correction via the P078 capture-on-correction surface (authentic-correction per ADR-044 category 6).

  **Step 3 — briefing removals**: replaced "Use the AskUserQuestion tool to confirm any removals" with silent-classification per Step 1.5 ownership rules. Agent owns remove / trim / compress decisions; user reads Step 5 summary and corrects via authentic-correction if a removal was wrong.

  **Step 3 — Tier 3 topic-file rotation (P099)**: replaced the per-file 4-option `AskUserQuestion` with silent agent-picked rotation shape based on heuristics (file mtimes for split-by-date / Step 1.5 signal scores for trim-noise / sub-topic boundaries for split-by-subtopic). Surfaced choice + per-file delta in Step 5 summary. AFK and interactive modes use identical behaviour (no `AskUserQuestion` differentiation).

  **Step 4a — verification close**: replaced per-candidate "Close P<NNN> / Leave / Flag" `AskUserQuestion` with close-on-evidence delegation to `/wr-itil:transition-problem <NNN> close` (cross-plugin dispatch). Per-candidate ask was sub-contracting framework-resolved decisions back to the user. Closes are reversible (`/wr-itil:transition-problem <NNN> known-error` flip-back); recovery path documented inline alongside each close action. Cross-plugin dispatch contract has explicit failure-mode handling: dispatch-failed surfaces in summary; dispatch-unavailable gracefully falls back; close-action result records in Decision column.

  **Step 4b Stage 2 — fix-shape per ticket**: replaced per-ticket 4-option `AskUserQuestion` with agent-picks-obvious-fit shape from the catalog (skill / agent / hook / settings / script / CI / ADR / JTBD / guide / test fixture / memory / internal-code). User edits ticket if shape was wrong. Recording mechanics unchanged; the Stage 2 catalog is unchanged — only the asking-vs-acting boundary changed.

  **Bats coverage** (Phase 2 R3 + R5):

  - `packages/retrospective/skills/run-retro/test/run-retro-step-4a-cross-plugin-dispatch.bats` (NEW per R3) — 11 assertions covering dispatch contract, failure-mode surfacing, dispatch-unavailable graceful fallback, recovery-path documentation, same-session-verifyings exclusion preservation, legacy-3-option-block removal.
  - `packages/retrospective/skills/run-retro/test/run-retro-step-4a-recovery-path.bats` (NEW per R5) — 6 assertions covering recovery-path documentation inline, recovery skill invocation naming, P124 precedent citation, reversibility affirmation, Step 5 summary surfacing, authentic-correction routing.

  Refs: P135 (master), ADR-044 (anchor), ADR-014 (commit grain), ADR-022 (lifecycle), ADR-026 (grounding), ADR-013 Rule 1 narrowing precedent, P078 (authentic-correction surface), P124 (verifying-flip-back precedent), P132 (inverse-P078 enforcement).

## 0.11.0

### Minor Changes

- 5d414fc: P135 Phase 5 (Measurement) — `run-retro` Step 2d "Ask Hygiene Pass" + advisory script.

  Per ADR-044 (Decision-Delegation Contract), every retro emits a per-session classification of the agent's `AskUserQuestion` calls so the **lazy-AskUserQuestion-count** regression metric is visible at session-time rather than after the user notices the friction. Phase 5 lands BEFORE Phase 2/3 to establish baseline so the lazy-count drop after Phase 2/3 land is measurable.

  **New surfaces:**

  - `packages/retrospective/skills/run-retro/SKILL.md` Step 2d — classify each session AskUserQuestion call per ADR-044's 6-class authority taxonomy (direction / deviation-approval / override / silent-framework / taste / correction-followup / **lazy**). Emit table in Step 5 retro summary; persist trail entry at `docs/retros/<YYYY-MM-DD>-ask-hygiene.md`.
  - `packages/retrospective/scripts/check-ask-hygiene.sh` — advisory diagnostic mirroring `check-briefing-budgets.sh` shape. Reads `docs/retros/*-ask-hygiene.md` trail; tabulates lazy-count trend over last N retros. Exits 0 (always advisory). Window override via `ASK_HYGIENE_WINDOW`.
  - `packages/retrospective/scripts/test/check-ask-hygiene.bats` — 18 behavioural assertions covering empty dir, missing dir, single entry, multi-entry sort, TREND line, window override, category-coverage, format tolerance, cross-shell portability (P124 / P133 lessons), and read-only contract.

  **Anti-pattern preserved**: classification ownership is silent agent judgement (no AskUserQuestion-about-AskUserQuestion meta-loop). The lazy count is the regression signal; correction is the user's call (via direction-setting / deviation-approval / authentic-correction per ADR-044 categories) on the user's own cadence.

  Refs: P135 (master ticket), ADR-044 (anchor), ADR-040 (Tier 3 advisory-not-fail-closed precedent), ADR-038 (progressive-disclosure budget), ADR-026 (cost-source grounding for citations), ADR-005 / ADR-037 (behavioural test pattern).

## 0.10.0

### Minor Changes

- 75238fb: P101 / ADR-043: two-layer context-usage analyzer for the retrospective plugin. Sessions now end with a per-source-bucket context-usage summary in the retro report; bloat is detected at session-time rather than after the user notices.

  **Cheap layer** — new Step 2c in `run-retro/SKILL.md`, placed between Step 2b (Pipeline-instability scan) and Step 3 (Update the briefing tree). Invokes a new read-only diagnostic primitive `packages/retrospective/scripts/measure-context-budget.sh` and renders a per-source-bucket table in the retro summary. Static budget proof keeps the cheap layer under ~2.5 KB output per retro (well below the 5% / 200K cheap-layer envelope). Defensive fail-open trip: if the script exits non-zero or the report exceeds the configurable `CONTEXT_BUDGET_MAX_BYTES` ceiling, Step 2c emits a one-line pointer and skips the bucket table. AFK behaviour identical to interactive (no `AskUserQuestion`).

  **Deep layer** — new skill `/wr-retrospective:analyze-context` at `packages/retrospective/skills/analyze-context/SKILL.md`. On-demand analyzer with richer heuristics: per-turn attribution (when `.afk-run-state/*.jsonl` accessible), per-plugin decomposition of the `hooks` and `skills` aggregate buckets, comparable-prior-grounded suggestion generation, and policy-breach detection against ADR-038 / ADR-040 / P097 budgets. Output: `docs/retros/<date>-context-analysis.md` with an HTML-comment-trailer carrying the bucket-snapshot for delta-from-prior comparison. User-invoked only; never auto-fires per ADR-013 Rule 6.

  **Snapshot persistence** — chosen via architect verdict over gitignored JSON or `/tmp` markers. The HTML-comment trailer pattern mirrors ADR-040's per-entry signal-score block and satisfies ADR-026's cite + persist + uncertainty rule (every snapshot is a re-readable artefact in committed history). First-retro / no-prior path emits the explicit `no prior snapshot — first measurement this project` sentinel rather than silently omitting the delta column.

  **Measurement methodology** — byte-counting on disk for the cheap layer (deterministic, hermetic, statically budget-bound) plus framework-injected sentinel (`not measured — framework-injected, no on-disk source`) for `available-skills` / `subagent-types` / `deferred-tools` listings that cannot be byte-counted from the project filesystem. Deep layer uses the cheap-layer baseline plus `usage` token aggregation from session logs when available.

  **Suggestion grounding** — the new skill is added to ADR-026's "Per-agent prompt amendments" target list. SKILL.md prose explicitly bans qualitative-only phrases (`load is negligible`, `microseconds only`, `minimal`, `small change`, `trim X to reduce bloat` without comparable prior). Every top-N offender row carries a concrete byte count + measurement-method citation; every suggestion cites a comparable prior reclamation (P095 / P099 / P100 precedents) or emits `not estimated — no prior data` per ADR-026 line 90.

  **ADR-014 amendment** — Commit Message Convention table gains a `docs(retros): context analysis YYYY-MM-DD` row for the deep skill's output. Amended within ADR-014's existing reassessment window per the precedent of P118's reconcile-readme amendment; no new ADR for the convention row itself.

  **Tests** — 28 behavioural assertions on the diagnostic script (`packages/retrospective/scripts/test/measure-context-budget.bats`); 12 doc-lint structural assertions on the run-retro Step 2c block; 18 doc-lint structural assertions on the new analyze-context SKILL.md. Full retrospective suite 157/157 green.

  **Composition with sibling measurement infrastructure** — `briefing` aggregate row in the cheap layer is upstream of P099's per-topic-file `check-briefing-budgets.sh` advisory (which keeps its own surface intact) and P105's per-entry signal-vs-noise pass (which keeps the entry-level grain). The three measurements are at three different granularities and compose by hierarchy without double-counting; the deep layer cites P099 and P105 outputs as evidence sources rather than re-measuring.

  **JTBD alignment** — JTBD-001 (Enforce Governance Without Slowing Down) primary; JTBD-006 (Progress the Backlog While I'm Away) for AFK loops where the cheap-layer summary surfaces in iteration summaries; JTBD-005 (Invoke Governance Assessments On Demand) for the deep-layer skill (textbook on-demand assessment shape per the persona guidance). JTBD review confirmed plugin-developer attribution affordance (per-plugin decomposition surfaces in the deep layer) and OSS-adopter / plugin-user silence affordance (cheap layer never errors on missing surfaces; uses `not measured` sentinels everywhere).

  **Architect verdict** — Option B (sibling ADR, not extension of ADR-038) chosen explicitly. ADR-038 stays scope-bounded to UserPromptSubmit governance prose; ADR-043 is the observability layer that consumes what every other progressive-disclosure ADR individually budgets. The pattern ADR-040 / P099 / ADR-043 establishes — read-only advisory script + behavioural bats fixture + ADR-tier-budget amendment — is the documented shape for any accumulator-doc surface that needs progressive-disclosure enforcement.

  P101 transitions Open → Known Error in this commit (root cause confirmed, fix path clear, fix landing). Verification Pending follows the next release per ADR-022. P091's "Build a measurement harness" investigation task closes as subsumed by this broader analyzer+suggestion design.

## 0.9.0

### Minor Changes

- ee47ce5: P099: Tier 3 budget enforcement for the briefing tree (advisory script + run-retro Step 3 rotation pass)

  `@windyroad/retrospective` gains a Tier 3 budget enforcement mechanism for `docs/briefing/<topic>.md` files. Closes the P099 gap left after P100 slices 1+2 — Tier 1 (Critical Points) was already enforced via P105's signal-vs-noise pass, but Tier 3 (per-topic files) was honour-system and topic files had drifted to 1.3-3.4× over their 5 KB ceiling.

  - New script `packages/retrospective/scripts/check-briefing-budgets.sh` — read-only advisory diagnostic. Walks `docs/briefing/*.md`, reports each topic file at or above the configured threshold (`OVER <basename> bytes=<N> threshold=<N>`). Default threshold 5120 bytes (upper bound of ADR-040 Tier 3 envelope), overridable via `BRIEFING_TIER3_MAX_BYTES`. Always exits 0 — overflow is signal, not failure (CI-fail-closed would block routine retros mid-session per JTBD-001). README.md excluded (Tier 2). Output sorted by basename for stable diffs. Mirrors `packages/itil/scripts/reconcile-readme.sh` placement and shape.
  - New behavioural bats fixture `packages/retrospective/scripts/test/check-briefing-budgets.bats` — 14 tests covering existence + executable + empty-dir + under-threshold + over-threshold + boundary-exact + README-excluded + env-var-override + non-md-ignored + missing-dir-exit-2 + sort-stability. Behavioural, not structural grep on SKILL.md (per P081 / `feedback_behavioural_tests.md`).
  - `run-retro` SKILL.md Step 3 — gains the **Tier 3 budget rotation pass** as its final action. Invokes the script after edits + Step 1.5 delete-queue persistence + README refresh. Interactive path: `AskUserQuestion` with four rotation shapes per ADR-013 Rule 1 (split-by-subtopic / split-by-date / trim-noise / defer). AFK fallback: defers to retro summary's new "Topic File Rotation Candidates" section per ADR-013 Rule 6. Step 5 summary template gains the matching Topic File Rotation Candidates table.
  - ADR-040 amended — Tier 3 promoted from "informational" to advisory enforcement. New Reassessment trigger: ≥ 3 topic files exceed 2× the configured ceiling for ≥ 2 consecutive retro cycles → revisit threshold or promote to fail-closed. Reusable-pattern note (JTBD-101) names the advisory-script + bats + ADR-tier-budget-amendment triplet for future accumulator surfaces (risk register per P102, ADR index, problems index).

  Closes P099 → Verification Pending.

### Patch Changes

- a6a8503: P088: run-retro SKILL.md — add "Never invoke as a background agent" anti-pattern clause; ADR-032 defers `capture-retro` sibling pending context-marshalling resolution.

  Settles the user direction (2026-04-21) on P088's three in-iter scope items: (a) ADR-032 amendment marks `/wr-retrospective:capture-retro` as deferred at both enumeration sites (initial three-sibling list + "New background siblings" list) with cross-reference to P088; (b) `packages/retrospective/skills/run-retro/SKILL.md` gains a "When to use" preamble naming the supported invocation surfaces (foreground `/wr-retrospective:run-retro` + `claude -p` subprocess per P086) and an anti-pattern clause forbidding `Agent(run_in_background: true)` invocation; (c) P086 ticket file gains a settlement note clarifying retro-inside-`claude -p`-subprocess remains correct and distinct from the deferred background-agent surface. Item (d) (extending run-retro with a session-log parser) is OUT OF SCOPE per ticket hedge.

  - New behavioural-contract bats fixture `packages/retrospective/skills/run-retro/test/run-retro-anti-pattern-clause.bats` — six structural assertions on the SKILL.md anti-pattern clause (presence, P088 driver citation, supported-surface enumeration, deferred-surface explicit naming, preamble placement, ADR-032 cross-reference). Documents the structural-with-fallback-note path per architect verdict (ADR-037 permitted exception); P081 follow-up tracks the behavioural-test infrastructure (synthetic subagent surface) that would replace structural assertions once a subagent-mock harness exists.
  - ADR-032 amendment is **minimal** per architect verdict: only the in-scope three-sibling enumeration sites are touched. Background-capture pattern wording stays unchanged because the pattern still works for `capture-problem` and `capture-adr` (their inputs are self-contained aside payloads). The retro-context-layer taxonomy ADR is deliberately deferred — landing taxonomy prose without that ADR pre-empts a design decision P088's Investigation Tasks explicitly leave open.

  Closes P088 → Verification Pending.

## 0.8.0

### Minor Changes

- 2c30de2: P100 slice 1 + slice 2 — surface and structure for cross-session learnings.

  **Slice 1 (writer-side, commit 5d367e9):** `run-retro` SKILL.md Steps 1, 3, and 5 updated to target the new tiered briefing layout. Step 1 reads `docs/briefing/README.md` + per-topic files; Step 3 edits per-topic files under `docs/briefing/<topic>.md` and refreshes the README index; Step 5 summary heading renamed to "Briefing Changes" and records per-topic citations.

  **Slice 2 (consumer-side, this release):** New `SessionStart` hook `packages/retrospective/hooks/session-start-briefing.sh` with matcher `"startup"` extracts the `## Critical Points (Session-Start Surface)` section from `docs/briefing/README.md` and injects it once per session — so adopters no longer need hand-authored CLAUDE.md pointers to receive cross-session learnings. The transitional `docs/BRIEFING.md` stub from slice 1 is deleted (legacy path retires). Architected as a sibling to ADR-038 (progressive disclosure + once-per-session budget for UserPromptSubmit) via the new **ADR-040 (proposed)** "Session-start briefing surface — SessionStart hook over tiered directory + indexed README", which documents the reuse / net-new boundary against ADR-038 and caps the Tier 1 (boot injection) output at ≤ 2 KB / ≤ 500 tokens.

  Closes **P100**.

## 0.6.0

### Minor Changes

- 6ed71dc: run-retro adds Step 2b Pipeline-instability scan (closes P074)

  The retro reflection prompts were framed around product-code work and
  under-reported **pipeline-level instability** — hook TTL expiries,
  marker-vs-file deadlocks, skill-contract violations, release-path
  failures, subagent DEFERRED/ISSUES FOUND outcomes, repeat workarounds,
  and session-wrap silent drops. These recurred every session without
  ticketing, so the WSJF queue never saw pipeline cost.

  Step 2b is a dedicated evidence-scan step placed between Step 2
  reflection and Step 4 ticket creation. Shape mirrors P068's Step 4a:
  glob / evidence-scan / categorise / dedup / prompt. Six signal
  categories enumerated. ADR-026 grounding required on each detection
  (tool invocation + session position + observable outcome; no bare
  counts). Interactive AskUserQuestion has four options per ADR-013
  Rule 1 (Create new ticket / Append to P<NNN> / Record in retro report
  only / Skip — false positive). AFK fallback populates a new Pipeline
  Instability section in the retro summary and defers ticket creation to
  the user, matching Step 4a's deferral pattern per
  feedback_verify_from_own_observation.md.

  Ownership boundary: run-retro surfaces detections;
  `/wr-itil:manage-problem` creates or updates tickets and commits per
  ADR-014. run-retro does not write problem files directly.

  - New bats doc-lint: `run-retro-pipeline-instability-scan.bats` — 12
    assertions covering the step header, six-category enumeration,
    ADR-026 grounding, AskUserQuestion contract, AFK fallback,
    manage-problem delegation, dedup against existing tickets, ADR-027
    compat note, section placement, Step 5 summary integration, and
    P068 shape cross-reference.

## 0.5.0

### Minor Changes

- 8d766e2: run-retro Step 4b flips to ticket-first codification (closes P075)

  Every codify-worthy observation flows through a two-stage flow: Stage 1
  mechanically creates a problem ticket (no user decision on ticketing);
  Stage 2 records the proposed fix strategy on that ticket via a 4-option
  AskUserQuestion. The legacy 19-option flat list is removed — it
  presented ticketing as one choice among many, but in practice the
  ticketing axis had a foregone answer every time. Flipping the flow
  removes the redundant question and keeps codification as a single
  structured prompt per ticket.

  - Stage 1: delegates to `/wr-itil:manage-problem` (or
    `/wr-itil:capture-problem` once the ADR-032 background sibling ships);
    applies P016 concern-boundary split before ticketing; fires
    mechanically in AFK mode.
  - Stage 2: per-ticket AskUserQuestion with header "Proposed fix" and
    four architect-pinned options — `Skill — create stub`, `Skill —
improvement stub`, `Other codification shape` (free-text Fix Strategy
    capture, not cascading AskUserQuestion per architect lean), and
    `Self-contained work — no codification stub` (with Rule 6 audit note
    preventing silent-skip). Records a `## Fix Strategy` section on the
    ticket.
  - AFK branch: Stage 2 defers via the ADR-032 deferred-question
    contract; Stage 1 ticketing is unaffected by AFK mode.

  Interaction notes: P044's recommend-new-skills intent rides in Stage 2
  Option 1; P050's shape generalisation rides in Stage 2 Option 3
  free-text capture; P051's improvement axis rides in Stage 2 Option 2
  for skill shape (non-skill improvements ride in Option 3). P068 Step 4a
  unaffected. P074 pipeline-instability signals feed Stage 1 naturally.

  ADR-032 Confirmation section amended with the
  foreground-spawns-N-background-fanout case so Stage 1's per-observation
  capture invocations have an explicit contract home.

## 0.4.0

### Minor Changes

- c268327: **run-retro**: add Step 4a "Verification-close housekeeping" so session-wrap surfaces `.verifying.md` tickets whose fixes were exercised successfully in-session, with specific citations (closes P068).

  New Step 4a fires between the existing Step 4 (problem tickets) and Step 4b (codification candidates). It globs `docs/problems/*.verifying.md`, reads each ticket's `## Fix Released` section, scans session activity for specific invocation citations (test runs, commits, skill invocations, hook firings, release cycles), and categorises each ticket as exercised-successfully / not-exercised / exercised-with-regression.

  Close-candidate decisions go through `AskUserQuestion` with the fix summary AND specific citations inline (per ADR-013 Rule 1) — the prompt is self-contained so the user can decide without reading the full ticket file. Three options: close now (delegates to `/wr-itil:manage-problem` Step 7 for the transition — run-retro does not rename or commit), leave as Verification Pending, or flag for manual review.

  Non-interactive / AFK fallback (per ADR-013 Rule 6) writes a new "Verification Candidates" section into the retro report; does NOT auto-close and does NOT delegate to manage-problem.

  - Evidence citations must be specific (tool invocation + observable outcome, not bare counts) per ADR-026 grounding.
  - Ownership boundary: run-retro surfaces evidence only; `/wr-itil:manage-problem` Step 7 owns the Verification Pending → Closed transition (rename + Status edit + P057 re-stage + ADR-014 commit per ADR-022).
  - ADR-027 compatibility note embedded: when Step-0 auto-delegation lands on run-retro, the evidence scan must either run in main-agent context before delegation (preferred) or the delegation prompt must include an explicit session-activity summary.
  - Same-session verifyings (tickets transitioned to `.verifying.md` in the currently-running session) are skipped — subsequent-session exercise is the meaningful signal.

  Composes with manage-problem Step 9d (the age-based heuristic path) — both can fire independently; closing via either de-lists the ticket from both queues.

  Cites the user's documented preference in `feedback_verify_from_own_observation.md` to verify from in-session observations rather than deferring everything to the user.

## 0.3.0

### Minor Changes

- 4a107a3: Extend run-retro's codification branch with an **improvement axis** for existing
  skills, agents, hooks, ADRs, and guides (P051).

  - Step 2 gains an improvement-shaped reflection category alongside the
    creation-shaped category introduced by P044/P050.
  - Step 4b's single flat `AskUserQuestion` option list adds six improvement-axis
    options (`Skill — improvement stub`, `Agent — improvement stub`, `Hook —
improvement stub`, `ADR — supersede or amend`, `Guide — improvement edit`,
    `Problem — edit existing ticket`). All 12 creation options from P050 retained.
  - P016/P017 concern-boundary splitting reused for multi-concern improvements;
    ≥ 3 improvements per output prefers a coordinating ticket over N separate ones.
  - Step 5 Codification Candidates table adds a `Kind` column (`create` /
    `improve`); non-interactive fallback records `Kind:` alongside `Shape:`.
  - 5 structural bats assertions added to
    `run-retro-codification-candidates.bats`; full run-retro test surface 24/24
    green, full project suite 246/246 green.

## 0.2.0

### Minor Changes

- f0de540: run-retro: generalise codification branch from skills to 12 shapes (P050)

  - **Step 2** superseded from "recurring workflow ... as a skill" to "recurring pattern ... better codified", with a shape sub-list naming 12 shapes (skill, agent, hook, settings, script, CI step, ADR, JTBD, guide, problem, test fixture, memory). "Skill" is retained as one worked example so the P044 muscle memory survives.
  - **Step 4b** now uses a single `AskUserQuestion` with flat shape-prefixed options (`Skill — create stub`, `Agent — create stub`, `Hook — create stub`, `ADR — invoke create-adr`, `JTBD — invoke update-guide`, ...). Dedicated codification skills are routed to rather than duplicated (`wr-architect:create-adr`, `wr-jtbd:update-guide`, `wr-voice-tone:update-guide`, `wr-style-guide:update-guide`, `wr-risk-scorer:update-policy`, `wr-itil:manage-problem`). Fallback to a two-question flow is documented for Claude Code versions where option-count limits bite.
  - **Step 4b non-interactive fallback (ADR-013 Rule 6)** extended: records each candidate as `flagged — not actioned (non-interactive)` with the identified Shape in the Step 5 summary.
  - **Step 5 summary** uses a unified "Codification Candidates" table with `Shape | Suggested name | Scope | Triggers | Decision` columns. Empty-table-omit rule retained.
  - **Backward compatibility**: `run-retro-skill-candidates.bats` assertions updated in place to accept either P044 phrasing or P050 phrasing. "Skill" remains a worked example in Step 2's shape list.
  - New parallel bats `run-retro-codification-candidates.bats` — 9 assertions covering the generalised surface. All 19 run-retro assertions GREEN.

  Deferred: P051 (improvement-axis sibling) — the shape taxonomy established here is the base for P051's extension.

## 0.1.6

### Patch Changes

- 66de931: retrospective: run-retro recommends new skills for recurring workflows (P044)

  The run-retro skill previously routed every observed friction into either
  BRIEFING.md notes or problem tickets. It had no branch for the third valid
  output: codifying a recurring multi-step workflow as a new skill.

  Changes to `packages/retrospective/skills/run-retro/SKILL.md`:

  - Step 2 gains a skill-candidate reflection category: "What recurring
    workflow did I (or the assistant) perform that would be better as a
    skill?" with criteria (multiple invocations, deterministic sequence,
    cross-project reuse) and examples distinguishing skill candidates from
    problem tickets and BRIEFING notes.
  - New Step 4b (Recommend new skills) walks each candidate through an
    `AskUserQuestion` per ADR-013 Rule 1 with three options: create a new
    skill (record suggested name, scope, triggers, prior uses), track as a
    problem ticket, or skip. Non-interactive fallback per ADR-013 Rule 6:
    record candidates as "flagged — not actioned" so they remain visible.
  - Step 5 summary gains a "Skill Candidates" slot so recommendations
    appear alongside BRIEFING changes and problem tickets in the session
    audit.

  Scaffolding itself is deferred — the skill records candidates only.

  Adds `packages/retrospective/skills/run-retro/test/run-retro-skill-candidates.bats`
  (10 assertions) covering Step 2 category, Step 4b branch, ADR-013
  compliance, Rule 6 fallback, and Step 5 summary slot.

  Closes P044 pending user verification.

## 0.1.5

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.1.4

### Patch Changes

- 6eeef94: Rename `@windyroad/problem` → `@windyroad/itil` (plugin `wr-problem` → `wr-itil`, skill `/wr-problem:update-ticket` → `/wr-itil:manage-problem`). Makes room for peer ITIL skills (incident, change) under the same plugin. Hard rename, no shim — per ADR-010.

  **Migration**: if you had `@windyroad/problem` installed, uninstall it (`npx @windyroad/problem --uninstall`) then install `@windyroad/itil`. The skill command changes from `/wr-problem:update-ticket` to `/wr-itil:manage-problem`. `@windyroad/retrospective`'s dependency is updated automatically.

## 0.1.3

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
