# @windyroad/retrospective

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
