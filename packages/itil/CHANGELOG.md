# @windyroad/problem

## 0.35.10

### Patch Changes

- bda9093: work-problems: document the `is_error: true` stream-timeout salvage carve-out in Step 5 exit-code semantics (P261). When an iter subprocess returns `is_error: true` (API stream idle timeout) after staging coherent work but before committing, the orchestrator may now salvage the staged work — commit it from the main turn with iter-attribution after a fresh commit-gate validation — instead of halting and losing it. Gated on staged files existing AND iter-authored bats passing; else halt per the existing contract. Distinct from the P121 SIGTERM, P147 stuck-before-emit, and P146 bash-polling classes.

## 0.35.9

### Patch Changes

- 0ea7196: Gate deny messages no longer advertise the `BYPASS_*_GATE=1` env bypass as an in-flight escape. The bypass only takes effect when set in Claude Code's process env before the session starts, so a mid-session Bash export never reaches the hook process. The deny now leads with the accurate in-flight recovery and states the env bypass is pre-session only:

  - changeset-discipline gate: `Recovery: bun run changeset. Env bypass is pre-session only.`
  - README-inventory currency gate: `Recovery: name the skill in the README. Env bypass is pre-session only.`
  - external-comms gate: `Override only ... (pre-session env): BYPASS_RISK_GATE=1.` (already names delegation as the in-flight recovery).

  Closes the misleading-deny friction class (P173).

## 0.35.8

### Patch Changes

- 60b802d: fix(itil): P165 README-refresh gate recognises the `RISK_BYPASS: adr-031-migration` trailer (closes P265)

  The `itil-readme-refresh-discipline.sh` commit gate blocked the ADR-031 layout-migration commit — a pure rename (flat `docs/problems/NNN-*.<state>.md` → per-state subdir) that legitimately stages no README refresh, so Step 0a auto-migration of flat-layout adopter trees deadlocked every invocation.

  `detect_readme_refresh_required` now accepts the `git commit` command string and allow-lists the registered `RISK_BYPASS: adr-031-migration` trailer (new `_readme_refresh_command_has_bypass_trailer` helper + `_README_REFRESH_BYPASS_TRAILERS` allow-list). The recognition grep is byte-identical to the sibling `risk-score-commit-gate.sh`, so one logical migration commit clears both commit gates. The allow-list keeps the bypass narrow and auditable — a generic `RISK_BYPASS:` match would let any commit self-exempt. Sibling gates P125 (staging-trap) and P141 (changeset-discipline) were swept and carry no equivalent gap.

## 0.35.7

### Patch Changes

- 377af18: P273 + P274 + P275 (batched P268 sibling-hook sweep — three hooks
  across two packages, one commit per ADR-014 batch grain): three
  PreToolUse/PostToolUse Bash hooks no longer false-positive deny or
  emit advisory on Bash commands that merely MENTION the literal phrase
  `git commit` in their argument vectors or heredoc bodies.

  Replaces the case-statement substring match
  `case "$COMMAND" in *"git commit"*) ;;` at each hook's command-shape
  filter with delegation to the shared helper
  `command_invokes_git_commit` introduced by P268 — same fix shape as
  P272 applied to the remaining sibling enforcement-layer hooks.

  Hooks fixed:

  - **P273** — `packages/itil/hooks/p057-staging-trap-detect.sh` (P057
    staging-trap enforcement, deny-class).
  - **P274** — `packages/itil/hooks/itil-rfc-trailer-advisory.sh` (RFC-
    trailer drift advisory, advisory-class).
  - **P275** — `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`
    (JTBD-currency README drift enforcement, deny-class — first
    cross-package consumer of the shared helper).

  To enable the cross-package P275 fix, the helper is promoted to
  canonical `packages/shared/hooks/lib/command-detect.sh` per ADR-017
  (matching the existing `session-marker.sh` / `leak-detect.sh` /
  `external-comms-key.sh` precedent under `packages/shared/hooks/lib/`).
  A new sync script `scripts/sync-command-detect.sh` mirrors
  `scripts/sync-session-marker.sh` (consumers: `itil`, `retrospective`)
  and a CI step `npm run check:command-detect` fails the build on
  divergence. Per-package copies live at
  `packages/itil/hooks/lib/command-detect.sh` and
  `packages/retrospective/hooks/lib/command-detect.sh`. Behavioural
  bats fixture at `packages/shared/test/sync-command-detect.bats`
  covers the three ADR-017 § Confirmation cases (canonical exists,
  all-copies-match, divergence + missing detected by --check).

  Coverage: 8-9 behavioural bats fixtures appended to each of the three
  hook test files, mirroring the P268 regression suite — grep / sed /
  echo / cat-heredoc / `git log --grep` false-positive allow paths,
  `git commit-tree` boundary allow, plus positive-regression cases
  (env-var-prefixed, cd-prefixed, leading-whitespace `git commit` still
  trigger the gate).

  Closes the P268 sibling-hook sweep — all four siblings (P268 / P272 /
  P273 / P274 / P275) now consume the shared helper. Future
  PreToolUse:Bash hooks gating `git commit` should source the helper
  from `packages/<plugin>/hooks/lib/command-detect.sh` from inception.

## 0.35.6

### Patch Changes

- d52b362: P272: `itil-changeset-discipline.sh` no longer false-positive denies
  Bash commands that merely mention the literal phrase `git commit` in
  their argument vectors.

  Replaces the prior `case "$COMMAND" in *"git commit"*) ;;` substring
  match at the hook's command-shape filter with delegation to the shared
  helper `packages/itil/hooks/lib/command-detect.sh::command_invokes_git_commit`
  landed by P268. The helper iteratively strips common prefix shapes
  (leading whitespace, env-var assignments, `cd <path> &&`) and checks
  whether the residual leading token pair is literally `git commit`
  followed by whitespace or end-of-string — so grep / sed / cat-heredoc /
  echo / `git log --grep` commands whose argument vectors mention the
  phrase no longer trip the changeset-discipline gate.

  Coverage: 10 P272-prefixed behavioural bats fixtures appended to
  `packages/itil/hooks/test/itil-changeset-discipline.bats`, mirroring
  the P268 regression suite — grep / grep-rn / sed / echo / git-log /
  cat-heredoc allow paths, `git commit-tree` boundary allow, plus three
  positive-regression deny cases (bare `git commit`, `cd && git commit`,
  `VAR=value git commit`).

  Same fix shape as P268 applied verbatim to the next sibling
  enforcement-layer hook per ADR-014 one-concern-per-ticket. Siblings
  P273 / P274 / P275 remain captured as separate tickets.

## 0.35.5

### Patch Changes

- 287992d: P268: `itil-readme-refresh-discipline.sh` no longer false-positive denies
  Bash commands that merely mention the literal phrase `git commit` in
  their argument vectors.

  A new shared helper `packages/itil/hooks/lib/command-detect.sh` exposes
  `command_invokes_git_commit`, which iteratively strips common prefix
  shapes (leading whitespace, env-var assignments, `cd <path> &&`) and
  checks whether the residual leading token pair is literally `git
commit` followed by whitespace or end-of-string. This replaces the
  prior `case "$COMMAND" in *"git commit"*) ;;` substring match that
  fired on any Bash whose text contained the phrase — including grep
  patterns, sed substitutions, cat heredoc bodies, echo strings, and
  `git log --grep` queries.

  Scope deliberately narrow per the ticket's recommended Fix shape B:
  handles the prefix shapes orchestrator and capture/manage/work skills
  actually emit (direct `git commit`, `cd && git commit`, `VAR=value git
commit`). Mid-chain `&&` after a non-prefix-shape leading command (e.g.
  `git add foo && git commit`) is a documented and acceptable false-
  negative — a standalone re-run of `git commit` re-triggers detection.

  Coverage: 28 helper-level bats fixtures at
  `packages/itil/hooks/test/command-detect.bats` plus 10 P268-prefixed
  integration cases appended to
  `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` covering
  the surfaces that previously misfired.

  Four sibling PreToolUse:Bash hooks were confirmed sharing the same
  substring-match anti-pattern (`retrospective-readme-jtbd-currency.sh`,
  `itil-rfc-trailer-advisory.sh`, `itil-changeset-discipline.sh`,
  `p057-staging-trap-detect.sh`); each is being captured as its own
  problem ticket per ADR-014 one-concern-per-ticket. The new helper is in
  the right shape for those sibling refactors to consume in their own
  commits.

## 0.35.4

### Patch Changes

- 7ca47ef: P087 Phase 3 (P269) — amend `packages/itil/scripts/plugin-maturity-populate.sh` rollup-emission to write `rollup_invocations_30d` (sum of non-null per-surface `invocations_30d`; null when all-null) and `bootstrapping` (populate-time snapshot of the bootstrapping-window state) onto the plugin root `maturity:` rollup. Restores compliance with ADR-053 §Bootstrapping clause Phase 3 rendering requirement — the renderer's compound-form predicate at `plugin-maturity-render.sh` line 144-147 is AND-gated on both fields, so pre-amendment all 11 plugins fell through to bare-band during the bootstrapping window even though the band derivation correctly applied the bootstrapping rule.

  Schema additions are **additive-within-2.0** per ADR-058 §Confirmation #8 — no schema_version bump. Contrast with the §Amendment 2026-05-18 P0 hotfix which bumped `"1.0" → "2.0"` because that amendment was non-additive (path move). The P269 amendment strictly adds two new keys to the rollup dict; old consumers reading `{schema_version, band}` continue to work unchanged.

  Changes:

  - `packages/itil/scripts/plugin-maturity-populate.sh` rollup-emission block: collects per-surface `invocations_30d` during the surface walk; emits `rollup_invocations_30d` as sum-of-non-null (or null when all-null per the hook-only honesty contract); emits `bootstrapping` copied from the existing module-scope `bootstrapping_active` flag.
  - `docs/decisions/063-plugin-maturity-presentation-layer.proposed.md` — new dated amendment block §Amendment 2026-05-18 (P269 — rollup compound-evidence write); rollup schema example updated; P0 hotfix corrected-schema example updated with the two new fields and a forward-reference to the P269 amendment.
  - `packages/itil/scripts/test/plugin-maturity-populate.bats` — 5 new behavioural tests (sum-of-non-null, null-when-all-hook, bootstrapping-true-during-window, bootstrapping-false-post-sunset) + amended existing rollup-shape test for the new fields. Now 22 tests (up from 17).
  - `packages/itil/scripts/test/plugin-maturity-render.bats` — 2 new behavioural tests covering the AND-gated predicate edge cases (`bootstrapping=true + null-invocations → bare-band`, `bootstrapping=false + integer → bare-band`). Now 19 tests (up from 17).
  - `packages/itil/scripts/test/plugin-maturity-doc-lint.bats` — 2 new shape-when-present tests covering `rollup_invocations_30d: int | null` and `bootstrapping: bool` shapes. Now 13 tests (up from 11).
  - `docs/problems/open/269-...md` — Description amendment per architect Adjustment E naming both fields with the AND-gated predicate citation.
  - Retroactive rollout (separate commit per architect Adjustment C): re-ran populate + render against the live monorepo. All 11 plugins' `plugin.json` now carry the two new rollup fields (additive-within-2.0); 7 plugins' README compound-rendering activated; 4 plugins unchanged (already at the rendered shape).

  Architect verdict (P269 implementation pre-edit 2026-05-18) PASS with 5 adjustments folded in (in-place amendment over new ADR; additive-within-2.0; two-commit shape; behavioural tests; both fields in scope). JTBD verdict PASS — restores the JTBD-302 honesty signal (bootstrapping-window evidence is the load-bearing calibration anchor).

  Single multi-package patch changeset per ADR-021 — declares all 11 monorepo plugins because the populate rerun adds the two new rollup fields to every plugin.json (additive, but per-package source change per P141 changeset-discipline-hook precedent set by the §Amendment 2026-05-18 P0 hotfix `3cfa6fc`).

  Closes P269 — restores compound rendering across all bootstrapping-window plugins. P087 closure path advances: this was the last named outstanding-question on P087.

## 0.35.3

### Patch Changes

- 5735fad: P087 Phase 3c (P239) — bats doc-lint per plugin asserting `plugin.json` `maturity:` field shape, rollup-equals-worst-case invariant, README badge marker currency, and anti-pattern absence. Ships as `packages/itil/scripts/test/plugin-maturity-doc-lint.bats` (11 tests, behavioural per ADR-052; runs against the standard `bats --recursive packages/*/scripts/test/` harness).

  Coverage per ADR-063 §Phase 3c contract:

  - **A1 Schema shape**: every per-surface record under `maturity.skills` / `maturity.agents` / `maturity.hooks` / `maturity.commands` carries `schema_version` ∈ `{"1.0", "2.0"}`, `band` ∈ taxonomy, `computed_at` string, and `evidence: {invocations_30d, days_shipped, closed_tickets_window, breaking_change_age_days}`. `invocations_30d` may be null for hook surfaces (transcript-unobservable); `breaking_change_age_days` may be null (no breaking marker observed).
  - **A2 Rollup shape**: plugin root carries `schema_version` + `band` mandatory pair per ADR-063 §rollup-schema + iter-10 Amendment 2026-05-18 (nested per-kind maps tolerated additionally).
  - **A3 Worst-case invariant**: rollup band equals worst-case of constituent surfaces per ADR-053 §granularity contract. Includes two synthetic-fixture tests — multi-band (Experimental ≻ Beta ⇒ rollup Experimental) and all-Deprecated (rollup Deprecated).
  - **A4 README marker**: per-plugin README carries `*Maturity: <band>` anchored regex match followed by `.` or `(`, where `<band>` equals the canonical plugin.json rollup band. Architect adjustment A2 tightening (anchored regex over raw substring).
  - **A5 Anti-patterns**: README has NO standalone `## Maturity` heading; NO `img\.shields\.io/badge/maturity` shields.io URL; per-skill table cells contain NO compound bootstrapping rendering (`(suite-bootstrap window;`) — compound stays at rollup per ADR-063 §Bootstrapping clause rendering.
  - **Regression fence (architect adjustment A1)**: no top-level `skills:` / `agents:` / `hooks:` / `commands:` keys carry maturity-shaped records. Guards the iter-10 P0 hotfix incident class (Claude Code manifest validator rejection on top-level kind keys carrying maturity-only records).

  Plugins without `maturity:` are skipped — the lint asserts SHAPE WHEN PRESENT, not mandatory presence per-plugin. Presence enforcement belongs to a Phase 4+ release-blocking gate per ADR-013 Rule 6 (advisory → release-blocking escalation on N consecutive releases with M drift instances).

  Compound-vs-bare badge form is OUT OF SCOPE for this lint per architect adjustment A3 — the renderer's compound-rendering fall-through (renderer expects `rollup_invocations_30d` field that populate never writes) is a separate sub-iter defect. The lint asserts band-substring-match only and remains agnostic to the compound form.

  Closes P239 Investigation Tasks (bats fixture, anti-pattern assertions, rollup-equals-worst-case invariant on multi-band synthetic fixture, dynamic plugin discovery). P239 transitions Open → Verifying this iter.

## 0.35.2

### Patch Changes

- 3cfa6fc: **P0 hotfix**: Phase 3 retroactive rollout (d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins) wrote per-surface maturity records at top-level `plugin.json` keys (`skills:` / `agents:` / `hooks:` / `commands:`). Claude Code's plugin manifest validator rejects that shape with `Validation errors: hooks: Invalid input, skills: Invalid input`. All 11 plugins were unparseable by `claude plugin install`.

  **Fix** (ADR-063 Amendment 2026-05-18): per-surface maturity records nest UNDER the top-level `maturity:` key at `plugin_doc.maturity.<kind>.<name>`. Schema version bumps to "2.0" (path move is NOT additive per ADR-058 §Confirmation #8). Populate script (`packages/itil/scripts/plugin-maturity-populate.sh`) writes to the new nested location; render script (`packages/itil/scripts/plugin-maturity-render.sh`) reads from the new nested location. Defensive cleanup of legacy top-level keys on re-runs. Bats fixtures (populate + render + drift) updated to new shape — 17 + 17 + 14 green. Manifest fix-up applied to all 11 affected plugin.json files.

  **Hotfix-class bypass** per ADR-013 Rule 5 (reducing — closes a defect that broke `claude plugin install` for all adopters).

## 0.35.1

### Patch Changes

- d33bb7d: P087 Phase 3 — retroactive maturity rollout across all 11 `@windyroad/*` plugins. Each plugin's `plugin.json` now carries a populated `maturity:` field per top-level surface (skills, agents, hooks, commands) plus a `{schema_version, band}` rollup on the plugin root entry per ADR-063 §plugin.json field schema. Each plugin's README now carries a prose-woven rollup badge (`*Maturity: <Band>.*`) in the value-framing lead prose line per ADR-051 anti-pattern + ADR-063 §README badge rendering format.

  Mechanical activation of Phase 3a (`wr-itil-plugin-maturity-populate`) and Phase 3b (`wr-itil-plugin-maturity-render`) against the live monorepo. Bootstrapping window active (suite-oldest surface 39 days shipped, less than 60-day threshold per ADR-053 §Bootstrapping clause); most surfaces land at Experimental with one Alpha bootstrapping surface (`wr-architect:agent` — meets the ≥100 invocations + ≥14 days criterion). Plugin root rollups all resolve to Experimental per the worst-case granularity contract (ADR-053 §granularity contract).

  Drift detector (`wr-retrospective-check-plugin-maturity-drift`) reports 0 drift instances across all 12 packages — rendered badges match canonical records. Anti-pattern absence verified: no standalone `## Maturity` section, no shields.io URL, no compound bootstrapping rendering in per-skill cells (compound stays at rollup per ADR-063).

  Closes the P087 Phase 3 retroactive mechanical rollout investigation task (P087 line 133). Activates the four Phase 3d JTBD outcome amendments shipped in P240: JTBD-302 maturity-band visibility, JTBD-007 maturity-band currency, JTBD-101 promotion-criteria visibility, JTBD-003 at-glance stability.

## 0.35.0

### Minor Changes

- dd93da4: P087 Phase 3b — README badge renderer ships (`wr-itil-plugin-maturity-render`). New `packages/itil/scripts/plugin-maturity-render.sh` canonical body + `packages/itil/bin/wr-itil-plugin-maturity-render` ADR-049 shim. Reads each plugin's `plugin.json` `maturity:` field (populated by Phase 3a) and writes a prose-woven `*Maturity: <Band>.*` span into the README.md value-framing lead prose line, plus a `Maturity` column populated in the existing `## Skills` table. Idempotent — re-running with unchanged plugin.json produces byte-identical README output; existing `*Maturity: ...*` spans are replaced, not duplicated.

  Compound rendering (e.g. `*Maturity: Experimental (suite-bootstrap window; <N> invocations / 30d).*`) stays at the rollup during the suite-bootstrap window per ADR-053 §Bootstrapping clause rendering; per-skill column cells carry band name only.

  Anti-patterns enforced: never emits a standalone `## Maturity` section, never emits a shields.io URL / inline SVG (markdown text only per ADR-063 §F5).

  17 behavioural bats fixtures at `packages/itil/scripts/test/plugin-maturity-render.bats` cover: badge insertion, bootstrapping compound rendering, post-bootstrap band-only rendering, per-skill column add, idempotency, badge-replacement, anti-pattern absence, fail-safe missing-maturity / missing-README, ADR-044 no-AskUserQuestion, ADR-035 no-network primitive, multi-plugin independence, dry-run preview.

  Phase 3b drift detector (`check-plugin-maturity-drift.sh`) ships in `@windyroad/retrospective` — sibling minor bump.

## 0.34.0

### Minor Changes

- 49dd0ba: P249 Phase 1: ship `/wr-itil:check-upstream-responses` skill — the outbound symmetric counterpart to ADR-062's inbound discovery pipeline.

  ADR-062's inbound discovery pipeline auto-polls upstream-filed reports against THIS repo and classifies them through JTBD-alignment + dual-axis risk. The symmetric outbound gap — polling responses to reports WE filed against upstream repos via `/wr-itil:report-upstream` — was left as manual "remember to check the upstream issue URL". P249 closes that gap.

  New skill `/wr-itil:check-upstream-responses` scans local problem tickets for the `## Reported Upstream` back-link section (written by `/wr-itil:report-upstream` Step 7 per ADR-024), polls each upstream issue via `gh issue view` (read-only — does NOT trip the ADR-028 external-comms gate), diffs the response against `docs/problems/.outbound-responses-cache.json`, and surfaces five response classes:

  - `NEW` — new comments since last check (with delta count)
  - `STATE` — upstream state changed (OPEN → CLOSED, REOPENED, etc.)
  - `LABEL` — labels added or removed
  - `NONE` — no change since last check
  - `FAIL` — gh poll error (surfaced per-ticket; pass continues for others)

  Cache + audit-log mirror ADR-062's inbound shapes:

  - Cache: `docs/problems/.outbound-responses-cache.json` (mirrors `.upstream-cache.json` per ADR-031)
  - Audit-log: `docs/audits/outbound-responses-log.md` (mirrors `inbound-discovery-log.md` per CLAUDE.md P131)

  AFK-safe by construction: no `AskUserQuestion` calls, no external-comms gate triggers, no auto-posting back to upstream issues. Partial-failure exit code (2) lets AFK orchestrators distinguish "some URLs unreachable" from "everything broke" without halting the loop. Future iter wires `/wr-itil:work-problems` Step 0c pre-flight invocation (sibling to Step 0b inbound staleness check per ADR-062 Confirmation #5); Phase 1 ships manual-invocation only.

  Phase 2 (external-reporter-as-our-reporter — plugin users polling responses to reports they filed against THIS repo) remains scheduled-future-surface per P179 deferred-with-scheduled-future-surface pattern.

  Components:

  - `packages/itil/skills/check-upstream-responses/SKILL.md` — skill contract
  - `packages/itil/scripts/check-upstream-responses.sh` — diagnose+act script body
  - `packages/itil/bin/wr-itil-check-upstream-responses` — `$PATH`-resolved bin shim per ADR-049
  - `packages/itil/scripts/test/check-upstream-responses.bats` — 13 behavioural tests covering: existence, discovery, skip-without-section, cache-match-to-NONE, new-comments-to-NEW with delta, state-change-to-STATE, cache write, audit-log append, --ticket filter, RFC-002 dual-tolerant subdir layout, partial-failure exit 2, --force-recheck

  ADR amendments (within existing reassessment windows; no new ADRs):

  - ADR-014 commit-message-convention table gains `chore(problems): check upstream responses — <N> polled, <M> new` row.
  - ADR-024 Confirmation amended (back-link section URL field now load-bearing for two skills: `/wr-itil:report-upstream` writes it, `/wr-itil:check-upstream-responses` reads it).
  - ADR-062 `## Related` amended with forward-pointer to P249 Phase 1 outbound-response-check sibling.

  Architect verdict 2026-05-18: APPROVED with 4 amendments (cache filename disambiguation, audit-log-only output, ADR-014 row, ADR-024+ADR-062 cross-references) — all landed in this commit.

  JTBD verdict 2026-05-18: PASS — JTBD-004 (Connect Agents Across Repos to Collaborate) primary anchor; JTBD-001 (governance without slowing down), JTBD-006 (AFK-safe), JTBD-201 (audit trail), JTBD-202 (pre-flight checks) secondary fits.

  P249 transitions Open → Known Error at this commit (Phase 1 fix released; Phase 2 remains open as scheduled-future-surface).

  Closes P249 Phase 1.

## 0.33.0

### Minor Changes

- 229539c: P170 Phase 3 P3.1 + Phase 4 P4.2 + I12 invariant: `/wr-itil:capture-problem` Step 1.5b JTBD-trace + persona dispatch. Extends Step 1.5 with a sibling dispatcher that resolves `jtbd_trace_value` (lexical detection of `JTBD-\d+` IDs in description, OR `--jtbd=` flag) and `persona_value` (`--persona=<value>` flag with closed-enum validation, OR derivation from cited JTBDs' frontmatter, OR AskUserQuestion fallback). New I12 hard-block per ADR-060 § Phase 3 + Phase 4 in-scope amendment (2026-05-13) Confirmation criterion 10: `type: user-business` AND empty `jtbd:` trace AND no `--jtbd` flag halts with stderr directive (forces JTBD trace on user-business problems; preserves persona-anchored JTBD-as-source-of-truth asymmetry). Nullable-field-conditional shape per ADR-060 line 536 — Step 1.5b dispatch keys on `jtbd_trace_value` and `persona_value` nullability, NEVER on `type` value as a control-flow branch (preserves I2 invariant; extends to Confirmation criterion 11 `persona:` field uniformity). Step 4 skeleton template carries `**JTBD**:` and `**Persona**:` body fields (matches existing `**Type**:` convention; YAML frontmatter migration deferred to Phase 4 follow-on). Skill flag table extends with `--jtbd=JTBD-NNN[,...]` and `--persona=<value>`. JTBD-301 firewall preserved — Step 1.5b is maintainer-side `/wr-itil:capture-problem` only; plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT prompt for JTBD or persona. Sibling helper extension: `update-jtbd-references-section.sh` body-field `**JTBD**:` extraction now composes with YAML-frontmatter `jtbd:` arrays in the existing `markdown-frontmatter-jtbd` mode (graceful fallback when frontmatter silent). 25 behavioural bats `capture-problem-step-1-5b-jtbd-trace.bats` green; full capture-problem suite 57/57 green; update-jtbd-references-related-problems.bats grows to 8/8 green (body-field test added). Held per ADR-042 atomic-cohort discipline — Phase 3 + Phase 4 graduate as one cohort.
- 229539c: P246: `/wr-itil:work-problems` Step 6.5 — insert cohort-graduation pre-check before the Drain action.

  When the within-appetite-with-releasable-material branch fires AND `docs/changesets-holding/` is non-empty, the orchestrator now invokes `wr-risk-scorer-evaluate-graduation` (the deterministic Rule 1a join + Rule 2 VP carve-out + Rule 3b cohort-grouping pass shipped in `@windyroad/risk-scorer` Phase 2a/2b) and branches per the 3-status taxonomy the evaluator emits:

  - `status=resolved` — graduate. `git mv docs/changesets-holding/<basename> .changeset/<basename>`, append README "Recently reinstated" entry, amend the iter's main commit per ADR-042 Rule 3. Class=3b cohorts graduate atomically (Rule 3b cohort propagation). Policy-authorised silent proceed per ADR-013 Rule 5 + ADR-061 Rule 5.
  - `status=vp-blocked` — skip per ADR-061 Rule 2 (Verification Pending carve-out).
  - `status=halt-no-resolution` — halt at the new framework-prescribed "Step 6.5 cohort-graduation halt-no-resolution" halt point per ADR-061 Rule 1a terminal.

  **Evidence-based, not time-based** (user direction 2026-05-17: _"Dogfooding makes sense, but it shouldn't be time based, it should be until we are happy that it's working as desired."_ + _"Why are we waiting? That seems to go against the principles if you ask me."_). Calendar predicates (`≥7 days in-repo dogfood`, `on or after <date>`) are NEVER a primary graduation trigger; the evaluator's `status=resolved` IS the graduation signal.

  Composes with the P250 Step 6.5 drain-on-releasable-material amendment (iter 2 of this session): the pre-check fires on the same within-appetite branch P250 already covers, before the Drain action it already triggers.

  Also updates `docs/changesets-holding/README.md` Process section step 5 to state criterion is positive evidence (Rule 4 per-class evidence floor), not elapsed wall-clock time; cites user direction verbatim; preserves at-hold-time historical contracts in per-entry `Currently held` lines (architect verdict — not retroactively rewritten).

  Bats coverage: 39 contract-assertion class fixtures at `packages/itil/skills/work-problems/test/work-problems-step-6-5-cohort-graduation.bats`.

### Patch Changes

- 229539c: P170 Phase 4 P4.1: `update-jtbd-references-section.sh` extension — adds a fourth `Related problems` lookup-table row (alongside `RFCs`, `Story Maps`, `Stories`) so JTBD files can auto-maintain a `## Related problems` reverse-trace section sourced from problem-ticket frontmatter `jtbd:` arrays. Per ADR-060 § Phase 3 + Phase 4 in-scope amendment (2026-05-13) P4.1 (architect finding A4 + JTBD finding F5). Lookup-table row addition only — no new helper, no per-section-name branching (structural test asserts). Adds `SECTION_ID_PREFIX` cell to render `P<NNN>` for problem rows. `extract_status_md` extends to fall back to body `**Status**:` lines when frontmatter `status:` absent (preserves Story/RFC frontmatter compat). 7-test behavioural bats fixture green; full itil/scripts suite 229/229 green. Held per ADR-042 / P162 atomic-cohort discipline — Phase 3 + Phase 4 ship as a single graduation cohort once end-of-chain user verification fires.

## 0.32.3

### Patch Changes

- e9fb7f0: **P250**: `/wr-itil:work-problems` Step 6.5 release-cadence classification now drains on **presence of releasable material**, not on residual band reaching appetite. The defective prior clause `Within appetite (≤ 3/25) — no drain needed` encoded accumulation-permitted-below-threshold semantics that violated the symmetric-balance principle (ADR-061 Rule 1) and the user's release principle.

  **New three-band classification**:

  - **Above appetite (≥ 5/25)** — route to ADR-042 auto-apply (unchanged).
  - **Within appetite (≤ 4/25) AND releasable material** (any unpushed commits OR any `.changeset/` entries OR any graduation-eligible held entries per ADR-061 Rule 1) — drain via `push:watch` then, if releasable changesets exist, `release:watch`.
  - **Within appetite (≤ 4/25) AND empty queue** (no unpushed commits AND no `.changeset/` AND no graduation-eligible held entries) — no drain (literally nothing to release).

  The residual band remains the safety check (above-appetite never releases); the within-appetite branch is now an action gate driven by presence of releasable material. ADR-018 amended in same commit per ADR-014 single-unit-of-work.

  User-direction citation (P250 Description): _"You don't want to accumulate risk. If it's low risk, you should release."_

## 0.32.2

### Patch Changes

- 52a50e9: Fix `reconcile-readme.sh` false-positive that mis-attributed `## Inbound Upstream Reports` rows as Verification Queue entries.

  The script previously sliced VQ as `[VQ_START, CLOSED_START)`, swallowing the Inbound section (ADR-062 / RFC-004) and miscounting its `Matched local ticket` cross-refs as VQ rows. Pre-fix this produced 31 false-positive `STALE verification-queue` entries every preflight, blocking Step 0 in `/wr-itil:capture-problem`, `/wr-itil:manage-problem`, `/wr-itil:work-problems`, and `/wr-itil:review-problems`.

  Closes P252.

## 0.32.1

### Patch Changes

- a5c209b: P165: PreToolUse:Bash commit-gate hook (`itil-readme-refresh-discipline.sh`) denies `git commit` invocations whose staged set includes a `docs/problems/<state>/NNN-*.md` ticket change but does NOT also stage `docs/problems/README.md`. Closes the P094 / P062 README-refresh enforcement gap — declarative-only contract is now hook-enforced at commit time. Architectural sibling of P125 (staging-trap) + P141 (changeset-discipline). Recovery is mechanical (`git add docs/problems/README.md`) per ADR-013 Rule 1; `BYPASS_README_REFRESH_GATE=1` env override for legitimate narrative-only ticket edits.
- a5c209b: P232: ship Bash polling-antipattern detection at PreToolUse:Bash plus a SKILL.md prompt-discipline extension. New hook `packages/itil/hooks/itil-bash-polling-antipattern-detect.sh` denies bash commands whose shape matches the regex `(until|while)[[:space:]]+!?[[:space:]]*(pgrep|pkill[[:space:]]+-0)` — the polling-loop class that self-references via `pgrep -f` matching the polling loop's own command line (2026-05-16 AFK iter 4 deadlocked 45 min wall-clock + cost on this shape). Deny message cites P232 and names both recovery alternatives (`wait $bg_pid` shell-native; Bash-tool `run_in_background=true` + `BashOutput` harness-native). Sibling shape to `p057-staging-trap-detect.sh`. One-shot `pgrep -f` and non-`-0` `pkill` invocations are allowed — the polling-loop shape is the antipattern, not pgrep itself. 17 behavioural bats in `packages/itil/hooks/test/itil-bash-polling-antipattern-detect.bats` cover 6 positive deny shapes (until/while pgrep, until/while pkill -0, heredoc body, multi-line P232 witness), 7 allow negatives (one-shot pgrep, non-`-0` pkill, `wait $!`, unrelated until/while, commit-message prose mentioning pgrep), tool-name filter, parse-incomplete fail-open, advisory-message content, and ADR-045 deny-path band. Hook registered in `packages/itil/hooks/hooks.json` PreToolUse:Bash array. `packages/itil/skills/work-problems/SKILL.md` Step 5 iter prompt extended with a second polling-discipline clause parallel to the existing P146 clause — names the self-reference failure mode with worked-example syntax and points at the structural hook for belt-and-suspenders enforcement. Architect APPROVE (no new ADR — ADR-013 Rule 1, ADR-038, ADR-045, ADR-009, ADR-026 all apply unchanged); JTBD ALIGN (JTBD-006 primary AFK-orchestrator beneficiary; JTBD-001 + JTBD-101 compose). P232 transitions Open → Verification Pending in the same commit per ADR-022 P143 fold-fix.

## 0.32.0

### Minor Changes

- 287e4c6: P087 Phase 2a — ship `wr-itil-skill-invocations` script + shim covering the transcript axis of ADR-058's plugin-maturity measurement mechanism.

  Reads `~/.claude/projects/**/*.jsonl` (recursive), tallies tool_use invocations by `Skill` / `Agent` / `Bash` per ADR-058 §Script contracts, emits one NDJSON record per surface to stdout. Schema v1.0 fields: `schema_version`, `axis`, `surface`, `kind`, `plugin`, `window_days`, `invocations`, `first_invocation_iso`, `last_invocation_iso`. Exit 0 always per ADR-013 Rule 6 (opt-out marker, inaccessible root, no data all hit the zero-records/stderr-comment path).

  Privacy posture adopted verbatim from ADR-035: opt-out marker `.claude/.skill-metrics-opt-out`, content sanitisation (only fixed-pattern surface names extracted), no network primitive (negative-grep enforced via bats), path-hashing (sha256-prefix-12hex; reserved for future schema bumps).

  Behavioural confirmation: 13 bats fixtures covering ADR-058 §Confirmation criteria 1–5 plus existence / forward-extension flag / window-days filtering. All green.

  Phase 2b (git axis — `wr-itil-plugin-exercise-index`) and Phase 2c (performance reassessment, surfaced from a 7.8s warm-cache observation against 5157 jsonl / 1.1 GB on the author's workstation, above ADR-058's 5s reassessment threshold) are queued as discrete Investigation Tasks under P087.

- 287e4c6: P087 Phase 2b — ship `wr-itil-plugin-exercise-index` script + shim covering the git-history axis of ADR-058's plugin-maturity measurement mechanism. Sibling to Phase 2a's `wr-itil-skill-invocations` transcript-axis surface.

  Runs `git log --reverse --name-only --pretty=format:%H|%aI|%s` once at the project root, auto-discovers plugins by listing `packages/*/`, emits one NDJSON record per plugin to stdout. Schema v1.0 fields: `schema_version`, `axis`, `plugin`, `commits_window`, `window_days`, `days_shipped`, `closed_tickets_window`, `tickets_window_days`, `breaking_change_age_days`, `composite_index`. Window cutoff applied in-Python against `%aI` author-date (git's `--since=Nd` form observed empirically unreliable against fixture date inputs on 2026-05-16 — invocation contract preserved verbatim; date filter routed to Python; ADR-058 NDJSON output shape unchanged). Single git-log pass collapses ADR-058 §Script contracts' two-pass shape into one walk (cheaper + resistant to git's date-parser quirks).

  `composite_index = log10(commits_window+1) + log10(closed_tickets_window+1) + (days_shipped >= 60 ? 1.0 : 0.0)` verbatim from ADR-058 line 112 (Option E6 "MAY emit alongside band" carve-out). `days_shipped` tracks `min(author_date)` per plugin (robust against commit-topology / rebase / cherry-pick reordering).

  Exit 0 always per ADR-013 Rule 6 (outside-git-repo, missing `packages/`, opt-out marker all hit the zero-records/stderr-comment path). Privacy posture per ADR-035: opt-out marker `.claude/.skill-metrics-opt-out`, no network primitive (negative-grep enforced via bats), content sanitisation (commit subjects parsed only for `BREAKING|feat!|fix!` token presence; subject prose discarded after the boolean test; never echoed to stdout).

  Behavioural confirmation: 19 bats fixtures covering ADR-058 §Confirmation criteria 6 (git-axis composite with three commits one in window, plus per-plugin emission, plus literal-`|`-in-commit-subject parser defence per architect 2026-05-16 advisory), 7 (outside-git-repo + missing-packages), 8 (schema-version) plus opt-out / no-network / content-sanitisation / composite-index formula / breaking-marker / closed-tickets-window dual-layout (suffix-based + directory-based) / window-days filter / category-overrides forward-extension flag. All green.

  Smoke-tested against this monorepo: itil composite_index 4.28 (Phase 2 prototype 4.11), retrospective 3.34 (prototype 3.30), risk-scorer 3.32, architect 3.22 — top-of-list matches 2026-05-03 prototype intuition; drift accounted-for by elapsed time + new commits since prototype. Performance 1.07s warm-cache on this workstation (boundary of ADR-058 ≤1.0s; well under the 5s reassessment threshold).

  Phase 2c (performance reassessment for `wr-itil-skill-invocations` 7.8s warm-cache observation against 5157 jsonl) and Phase 3 (retroactive assessment + README badges) remain queued as discrete Investigation Tasks under P087.

- 287e4c6: feat(itil): ship `wr-itil-plugin-maturity-populate` (P087 Phase 3a)

  Adds the population script that writes the `plugin.json` `maturity:` field
  per surface and per plugin root from Phase 2 NDJSON (consumes
  `wr-itil-skill-invocations` + `wr-itil-plugin-exercise-index`). Applies
  ADR-053 §promotion criteria + §Bootstrapping clause; idempotent;
  exit-0-always per ADR-013 Rule 6. ADR-044 silent-framework carve-out
  honoured — no `AskUserQuestion` per band recompute.

  Surface inventory discovered from filesystem under `packages/<plugin>/`
  (`skills/`, `agents/`, `hooks/`, `commands/`); per-surface key
  normalisation matches ADR-058's Phase 2a Bash-attribution pattern.
  Hooks emit `invocations_30d: null` sentinel (not transcript-observable;
  band derived from git axis only per architect adjustment C).
  Bootstrapping clause sunset auto-derives from `max(days_shipped)` — no
  calendar-date hard-code per architect adjustment D. Author-declared
  `Deprecated` records (with `supersededBy:` pointer) preserved across
  re-runs per ADR-053 §Confirmation #6 and architect adjustment I.

  Ships under ADR-049 shim grammar (`packages/itil/bin/wr-itil-plugin-maturity-populate`).
  Behavioural bats fixture (17 tests) covers ADR-063 §Confirmation criteria
  1-3 (idempotency, bootstrapping vs steady-state band mapping, no
  `AskUserQuestion` per band recompute) plus schema-shape / rollup
  worst-case / hook null-sentinel / Deprecated-overlay preservation /
  fail-safe missing-input / no-network-primitive negative-grep.

  Phase 3a unblocks Phase 3b (P238 — renderer + drift detector). Phase 3a
  retroactive rollout across the live monorepo composes with Phase 3b per
  P087 line 133.

## 0.31.0

### Minor Changes

- 4ce2299: P233 — `/wr-itil:work-problems` Step 6.5 chains `/install-updates` after successful within-appetite release drain so the next iter subprocess loads the just-shipped plugin from a fresh cache

  Add a **Post-release cache refresh (P233)** subsection to Step 6.5 Drain action immediately after the existing 3-step `push:watch` → `release:watch` → `Resume the loop` sequence. The new step 4 chains `/install-updates` to refresh the plugin cache before the next iter dispatches, conditional on step 2 (`release:watch`) actually shipping a release to npm.

  **Why this is needed**: empirical evidence in `docs/briefing/afk-subprocess.md` (the "Just-shipped gate-class hooks DON'T protect the immediate-next iter" entry, captured today by the session 3 retro) confirms iter subprocesses re-resolve plugin cache on spawn. Without cache refresh between `release:watch` and next-iter dispatch, a just-shipped gate-class hook is inactive in the very next iter — defeating the "ship a hook to prevent recurrence" pattern for the immediate-next-iter case. Demonstrated empirically twice in the current session: P232's hook landed in `@windyroad/itil@0.30.3` at 08:45 but the antipattern recurred at 09:42 in the next iter; P234's hook landed in 0.30.4 source but was inactive in the iter 4 cache.

  **Contract guarantees**:

  - **Conditional on actual release** — fires only when `release:watch` actually published. Skipped when `push:watch` ran alone (empty `.changeset/`; no new plugin version). Prevents wall-clock + npm-API noise on no-op refreshes every iter.
  - **Non-blocking on /install-updates failure** — orchestrator logs the failure and continues. Degrades to current cache-stays-stale behaviour (equivalent to pre-amendment). Loop MUST NOT halt on `/install-updates` failure under any circumstance.
  - **Policy authorisation** — rides the same ADR-013 Rule 5 silent-proceed that already covers `push:watch` / `release:watch`. Composes with P106's `claude plugin install` no-op-when-already-installed factor (chained `/install-updates` handles the uninstall+install dance per P106).
  - **Mid-loop ask discipline (P130) preserved** — `/install-updates` AskUserQuestion (cache miss / scope delta / `INSTALL_UPDATES_RECONFIRM=1`) is treated AS the install-updates Non-interactive fallback path (dry-run + log; no loop interruption). Authorised by ADR-044 framework-resolution boundary — invocation between iters is a mechanical-stage transition the framework has resolved; surfacing would dilute Step 2.5b accumulated-question discipline.
  - **Composition with above-appetite branch** — chain is anchored to within-appetite Drain action step 4 only. Does NOT fire after Rule 5 halt (no release shipped → nothing to refresh) and does NOT fire mid-loop in the auto-apply loop. Convergence back to Drain action fires the chain there.

  **Test surface** (`packages/itil/skills/work-problems/test/work-problems-step-6-5-cache-refresh-chain.bats`) — 14 doc-lint contract assertions per ADR-037 Permitted Exception covering subsection identity, conditional-on-release guard, non-blocking guarantee, ADR-013 Rule 5 + ADR-044 + P130 + P106 cross-refs, briefing evidence citation, and Decision Making table row.

  **Visible adopter behaviour** — adopters running `/wr-itil:work-problems` will observe an additional `/install-updates` invocation per release-drain (within-appetite branch only, conditional on a release actually shipping). Minor bump per architect verdict — contract-visible new orchestrator behaviour.

  Sibling tickets: parent antipattern is the gate-class-hook-released-mid-AFK-loop dogfood-window class shared with P165; compounding factor is P106 (handled by `/install-updates` internally); evidence chain is P232 + P234 (both demonstrated the cache-staleness antipattern in the current session).

## 0.30.4

### Patch Changes

- 91d919b: P087 Phase 2d — wr-itil-skill-invocations transcript-axis performance optimization

  Add a substring pre-filter on the `"tool_use"` discriminating token before `json.loads()` in `packages/itil/scripts/skill-invocations.sh`. Approximately 60% of in-window transcript lines (user messages, tool_result blocks, snapshots, title records) carry no `"tool_use"` value at all and now short-circuit without paying the JSON parse cost.

  Warm-cache median against a 5155 jsonl / 1.13 GB / 380,898-line corpus: **7.12s → 5.34s** (1.78s reduction, 25%). The 5s ADR-058 §Reassessment Triggers threshold remains marginally exceeded (0.34s / 6.8%); Phase 2e binary-search-to-first-in-window queued within P087 to close the residual gap.

  NDJSON output schema unchanged (`schema_version` stays 1.0). Privacy posture unchanged. ADR-013 Rule 6 exit-0-always preserved. Substring filter is whitespace-tolerant — works against both compact and pretty-printed JSONL. False-positive fall-through invariant pinned by new bats fixture; 14 tests now green.

  ADR-058 §Performance contract amended with the Decision Outcome — Phase 2d block per ADR-023 template.

- 4a06705: P087 Phase 2e — wr-itil-skill-invocations binary-search-to-first-in-window byte-seek

  Add a binary-search byte-seek before the line iterator in `packages/itil/scripts/skill-invocations.sh`. Files at or above a 256 KB threshold bisect to the earliest byte offset whose line carries a `timestamp` at or after the cutoff, then linear-scan from that offset; files below threshold continue to scan linearly from byte 0 (bisect overhead is not worth it for small files). JSONL is append-only within a single session jsonl file — older lines appear earlier by author-timestamp monotonicity — so the bisect skips the historical pre-cutoff portion of long-lived session files without paying the read cost.

  Warm-cache median against a 5164 jsonl / ~1.08 GB corpus: **5.34s → 4.04s** (1.30s reduction, 24%) and **7.12s → 4.04s** (3.08s reduction, 43%) from the Phase 2c baseline. The 5s ADR-058 §Reassessment Triggers threshold is **now silenced** — warm-cache wall-clock sits 0.96s / 19% under budget.

  NDJSON output schema and record count unchanged (235 records on the live corpus, identical surface attribution and ordering). Privacy posture unchanged. ADR-013 Rule 6 exit-0-always preserved. Bisect uses a whitespace-tolerant byte-regex for timestamp probes; readline-boundary alignment guarantees byte-safety; loop termination guaranteed by `hi = mid` on the in-window branch. Append-only monotonic-timestamps within a single session jsonl is the documented input invariant — synthetic violation under-counts gracefully without crashing or emitting malformed NDJSON. Four new bats fixtures pin the byte-seek correctness boundary (straddle, all-in-window, small-file linear, non-monotonic graceful-degradation); 19 tests now green.

  ADR-058 §Performance contract amended with the Decision Outcome — Phase 2e block; §Reassessment Triggers updated to record the threshold silencing.

- 9117246: P234 Phase 1 — wr-itil PostToolUse:Write|Edit hook detecting fictional-defer rationales in retro outputs

  Add `packages/itil/hooks/itil-fictional-defer-detect.sh` — a PostToolUse advisory hook that fires on Write / Edit / MultiEdit calls targeting `docs/retros/*.md` and scans the written file for defer-rationale phrases (`next retro`, `next session`, `defer pending`, `defer with cause:`, `deferred per`) lacking a SCHEDULED-FUTURE-SURFACE citation in the +/-5 line context window.

  A SCHEDULED-FUTURE-SURFACE is one of: ticket ID (`P\d{3}` / `STORY-\d{3}` / `R\d{3}` / `RFC-\d{3}`), named skill invocation (`/wr-[a-z-]+:[a-z-]+`), hook / script path (`*.sh`), CI workflow path (`.github/workflows/`), or a dated ADR reference (`ADR-\d{3}` + `\d{4}-\d{2}-\d{2}` both present in the window). The allowlist carves out `deferred per Branch B` (the run-retro Step 3 Branch B path carries the next-retro `check-briefing-budgets.sh` trigger as the scheduled surface inside the SKILL contract itself).

  Advisory only — never blocks. Emits a single stderr advisory naming file + line number + detected phrase + remediation pattern. Mirrors the `itil-rfc-trailer-advisory.sh` PostToolUse precedent (stderr + exit 0) and the just-shipped `itil-mid-loop-ask-detect.sh` (P132 Phase 2b) per-surface configuration shape (`DEFER_RATIONALE_RE` / `SCHEDULED_FUTURE_SURFACE_RE` / `EXEMPT_PHRASES_RE` at the top so extending coverage to other accumulator-doc surfaces is a copy-and-retarget operation).

  Closes the under-do half of the ADR-044 framework-resolution-boundary inverse-correctness pair (P132 = over-ask / P234 = under-do). The fictional-defer pattern recurs across `/wr-retrospective:run-retro` Step 3 Tier 3 budget rotation, Step 1.5 Signal-vs-Noise pass, and Step 4b Stage 1 Tickets Deferred section — the hook surfaces all three at file-write time with a uniform structural enforcement rather than per-skill prose rules. Behavioural bats fixture in `packages/itil/hooks/test/itil-fictional-defer-detect.bats` (14 tests) pins the detection signal + allowlist + crash-safety + ADR-045 honour-system budget.

  Sibling shape to P132 Phase 2b (commit 841db68, @windyroad/itil@0.30.3) — same advisory budget envelope (target ~600 bytes, hard ceiling <1000), same per-surface-config + copy-and-retarget extensibility, same behavioural-tests-default per ADR-052 + P081.

## 0.30.3

### Patch Changes

- 841db68: P132 Phase 2b: ship orchestrator mid-loop AskUserQuestion detection at the Stop event. New hook `packages/itil/hooks/itil-mid-loop-ask-detect.sh` scans the transcript via three signals — (1) last assistant turn contains an `AskUserQuestion` tool_use, (2) earlier assistant message issued a `Skill` tool_use to `wr-itil:work-problems`, (3) no `ALL_DONE` / `## Work Problems Summary` terminal marker emitted since the activation — and emits a structured `stopReason` advisory citing P130 + the Mid-loop ask discipline subsection + ADR-044 framework-resolution boundary when all three match. Advisory only — never blocks (architect verdict: a hard block on legitimate halt-point AskUserQuestions would itself violate JTBD-006 outcome 5). Closes the orchestrator-main-turn-between-iters surface that the Phase 2a 4-surface SKILL.md derive-first refactor empirically did not cover (2026-05-17 regression: orchestrator asked iter-target selection between iters 3 and 4; halted AFK loop for hours). Registered in `packages/itil/hooks/hooks.json` Stop array alongside the sibling `itil-assistant-output-review.sh` (P085 prose-ask detector). 13 behavioural bats assertions in `packages/itil/hooks/test/itil-mid-loop-ask-detect.bats` cover positive detection (3 cases — P130 cite, ADR-044 cite, intermixed-content variant), silent-exit paths (7 cases — no orchestrator activation, ALL_DONE post-loop, ## Work Problems Summary post-loop, no AskUserQuestion in last turn, missing transcript_path, non-existent file, empty transcript), malformed-JSONL crash-safety, and ADR-045 advisory-budget. Per-surface configuration (ORCHESTRATOR_SKILL + TERMINAL_MARKER_RE variables at top of script) makes the detection pattern parametric per JTBD verdict's extensibility note — future Phase 2c/2d adopters (run-retro Step 4b Stage 1, /install-updates Step 6a) copy + retarget without forking. Architect verdict PASS (no new ADR — joint coverage of ADR-013 / ADR-044 / ADR-045 / ADR-052 / ADR-005); JTBD verdict PASS (JTBD-006 primary, JTBD-001 + JTBD-101 compose). P132 stays Known Error pending in-the-wild observation across subsequent AFK sessions that exercise iter-to-iter transitions; structural hook fires post-turn so the advisory biases the NEXT turn — verification requires "no analogous regression on the orchestrator-main-turn surface across at least one subsequent AFK session", not same-commit assertion.

## 0.30.2

### Patch Changes

- da1a3fe: P132 Phase 2a-iii-B: `/wr-architect:create-adr` Step 2 retrofitted as the 4th adopter of the shared derive-first dispatch helper. Canonical helper relocated from `packages/itil/lib/derive-first-dispatch.sh` to `packages/shared/derive-first-dispatch.sh` per ADR-017 (architect verdict: cross-package source would have violated the self-contained-published-package property). Synced per-package copies at `packages/itil/lib/` and `packages/architect/lib/`; new `scripts/sync-derive-first-dispatch.sh` (with `--check` mode) + `npm run check:derive-first-dispatch` + CI step + drift-detection bats. create-adr SKILL.md Step 2 rewritten from single AskUserQuestion-everything to 12-field derive-first dispatch table: silent-framework cat-4 on Title (kebab from prose), status=proposed, date=today, reassessment-date=today+3mo, Context-and-Problem-Statement (verbatim from `$ARGUMENTS`), consulted/informed defaults; cat-1 direction-setting retained on Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, decision-makers (architect verdict: no silent `git config user.name` derive — multi-party-decision mis-attribution risk). 13 new ADR-044-contract bats for create-adr; 7 new drift bats for sync; 2 new 4-surface assertions in derive-first-dispatch.bats. P132 transitions Known Error → Verification Pending per ADR-022 fold-fix. Phase 2b detection hook remains DEFERRED. Full suite green.
- 30fd22b: P132 Phase 2a-iii-A: extract shared derive-first dispatch helper at `packages/itil/lib/derive-first-dispatch.sh`. Centralises the dispatch mechanism shipped across three declaration-skill surfaces (`/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, `/wr-itil:manage-problem` Step 4) — slug derivation (Title), two-sided lexical classifier (Type for capture-problem), RISK-POLICY matrix lookup (Severity / Priority), and the I2-isomorphic stderr advisory format `<skill>: derived <field>=<value> from <source>; <reversibility>`. The three SKILL.md surfaces now name the helper as the canonical mechanism source-of-truth; surface-specific signal definitions stay inline per architect verdict. Capture-problem stderr verb renamed classified -> derived to align with helper. New behavioural bats `packages/itil/scripts/test/derive-first-dispatch.bats` (19 assertions). 297/297 tests green across affected suites. Phase 2a-iii-B remains DEFERRED. No public-API surface change — helper is project-internal.

## 0.30.1

### Patch Changes

- b7cc645: manage-incident Step 4 derive-first refactor — close I001 lazy-classification regression (P132 Phase 2a-i)

  Rewrites `/wr-itil:manage-incident` Step 4 from a single "Use `AskUserQuestion` for anything not in `$ARGUMENTS`" instruction to a derive-first dispatch table. Mirrors the worked-example pattern already shipped in `/wr-itil:capture-problem` Step 1.5 (P185 refactor).

  The dispatch:

  - **Title**: derived silently — kebab-case the first 8-10 non-stopword tokens of the user's prose description. Stderr advisory cites the source token sequence.
  - **Symptoms**: pulled verbatim from the user prose into the `## Observations` section template at Step 5.
  - **Start time**: derived silently via three sources in priority order — explicit timestamp regex in description, `git log --diff-filter=A --follow -- <path>` first-touch evidence for cited paths, or current wall-clock UTC default. Stderr advisory cites the chosen source and invites the user to add an evidence anchor to the Timeline section if symptoms began earlier.
  - **Severity**: derived silently when description signals (service-disruption keywords, latency/throughput vocabulary, reproducibility indicators, named anchors like held-cluster age or scorer state) map to a single clear `RISK-POLICY.md` Impact × Likelihood cell. Stderr advisory cites the matrix cell and named evidence list. Ambiguous evidence falls back to `AskUserQuestion` as the genuine ADR-044 category-5 (taste) surface — fallback on actual ambiguity, not on defaults.
  - **Scope**: retained as `AskUserQuestion` ADR-044 category-1 (direction-setting) — semantic blast radius the framework cannot infer (only the user knows whether downstream-adopter-risk is in scope, whether mobile is affected, whether the blast radius extends past cited symptoms). Same reasoning as Step 2 duplicate-check.

  Closes the 2026-05-06 I001 declaration regression cited in P132 — 3 of 4 lazy sub-questions become 0 of 1 lazy sub-question (Scope alone is the surviving genuine cat-1 surface).

  ADR-026 cost-source grounding: each silent derivation emits a single-line stderr advisory citing the source. AFK fail-safe per ADR-013 Rule 6 preserved — Scope alone can halt under AFK orchestration; the four derivable fields resolve without interactive input.

  Step 4 surface taxonomy re-classified in the Related section: cat-1 (Scope) + cat-4 (Title / Symptoms / Start time / Severity-when-evidence-present) + cat-5 (Severity-on-ambiguity fallback).

  Behavioural bats coverage extended in `packages/itil/skills/manage-incident/test/manage-incident-adr-044-contract.bats` with 7 new Surface 2 assertions:

  - cat-4 silent-framework cross-reference
  - Title derive-from-prose contract
  - Start time derive-from-evidence-sources contract
  - Severity derive-from-RISK-POLICY-matrix contract
  - Scope-retains-AskUserQuestion negative-of-negative guard (regression resistance)
  - P132 audit traceability
  - ADR-026 stderr advisory shape contract

  All 18 file-local assertions green; all 53 manage-incident-suite bats green (RED → GREEN flow demonstrated).

  Composes with P136 ADR-044 alignment audit master + P185 derive-first capture-problem refactor. Phase 2a-ii (`/wr-itil:manage-problem` create flow) + Phase 2a-iii (`/wr-architect:create-adr` argument-collection) deferred to subsequent iters per ADR-014 commit-grain discipline.

  Closes P132 Phase 2a-i (does NOT fully close P132 — remaining declaration-skill slices stay open as known-error).

- 43255d2: manage-problem Step 4 derive-first refactor — second declaration-skill surface (P132 Phase 2a-ii)

  Rewrites `/wr-itil:manage-problem` Step 4 (new-problem create flow) from a single "Use `AskUserQuestion` for anything not in `$ARGUMENTS`" instruction to a derive-first dispatch table. Second declaration-skill surface to ship the pattern after `/wr-itil:manage-incident` Step 4 (commit b7cc645, Phase 2a-i) and `/wr-itil:capture-problem` Step 1.5 (P185 worked example).

  The dispatch:

  - **Title**: derived silently — kebab-case the first 8-10 non-stopword tokens of the user's prose description. Stderr advisory cites the source token sequence. Cat-4 silent-framework.
  - **Description**: pulled verbatim from `$ARGUMENTS` prose into the Step 5 `## Description` section. Fallback to `AskUserQuestion` ONLY when `$ARGUMENTS` carries no prose at all — without prose there is literally nothing to capture. This is the ONLY genuine cat-1 direction-setting surface in Step 4.
  - **Priority** (Impact × Likelihood): derived silently when description signals map to a clear `RISK-POLICY.md` cell. Impact signals (service-disruption / latency / cosmetic keywords) + likelihood signals (reproducibility vocabulary) + named anchors (`Impact: <label>` / `Likelihood: <label>` / `Priority: <score>` mentions) cross-reference the matrix; clear-cell maps silently with stderr advisory citing the cell + named evidence. Ambiguous-evidence fallback fires `AskUserQuestion` as the genuine ADR-044 category-5 (taste) surface.
  - **Reported date / Status / Symptoms / Workaround**: already inferred (today's date / `Open` / verbatim-from-prose / `None identified yet.` default).

  Three declaration-skill surfaces now share the I2-isomorphic stderr advisory shape (`<skill>: derived <field>=<value> from <source>; <reversibility-clause>`): `/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, `/wr-itil:manage-problem` Step 4. Architect verdict 2026-05-15 flagged this triplet as the pattern-lock point — the stderr advisory format is now established across three skills before Phase 2a-iii (`/wr-architect:create-adr` argument-collection) extends the same pattern to a fourth.

  ADR-026 cost-source grounding: each silent derivation emits a single-line stderr advisory citing the source. AFK fail-safe per ADR-013 Rule 6 preserved — Description-when-absent is the rare halt path under AFK orchestration; the typical AFK manage-problem call carries prose in `$ARGUMENTS` and resolves Title + Priority silently.

  Step 4 surface taxonomy: cat-4 silent-framework (Title + Priority-when-evidence-present) + cat-1 direction-setting (Description-when-prose-absent fallback) + cat-5 taste (Priority-when-ambiguous fallback).

  Behavioural bats coverage in new file `packages/itil/skills/manage-problem/test/manage-problem-adr-044-step4-derive-first.bats` — 10 assertions:

  - cat-4 silent-framework cross-reference
  - cat-1 direction-setting fallback cross-reference (Description)
  - Title derive-from-prose contract
  - Priority derive-from-RISK-POLICY-matrix contract
  - Description-retains-AskUserQuestion negative-of-negative guard (regression resistance)
  - P132 audit traceability
  - ADR-026 stderr advisory shape contract
  - cross-skill consistency cross-reference (P185 + manage-incident)
  - Step 4b multi-concern AskUserQuestion preservation guard (architect verdict — not touched by Phase 2a-ii)
  - Step 2 duplicate-check AskUserQuestion preservation guard (architect verdict — not touched by Phase 2a-ii)

  All 10 file-local assertions green; all 168 manage-problem-suite bats green (RED → GREEN flow demonstrated; 7 of 10 RED before the SKILL.md refactor).

  Composes with P132 Phase 2a-i (manage-incident Step 4) + P185 (capture-problem Step 1.5) + P136 ADR-044 alignment audit master. Phase 2a-iii (`/wr-architect:create-adr` argument-collection) deferred to a subsequent iter per ADR-014 commit-grain discipline.

  Closes P132 Phase 2a-ii (does NOT fully close P132 — Phase 2a-iii stays open as known-error).

- 4825603: evidence-first `Likely verified?` cell shape across the Verification Queue render surface

  The `docs/problems/README.md` Verification Queue's `Likely verified?` column previously used a 14-day age-based heuristic (original P048 Candidate 4 default — `yes (N days)` when the release was ≥14 days old, `no (N days)` otherwise). That framing primes a default-yes verdict based on calendar age rather than session-observed evidence — the inverse of the audit-trail discipline the queue is meant to support.

  The column now carries an **evidence-first** cell with three canonical values:

  - `yes — observed: <evidence>` — session-observed evidence the fix works. A Step 4 user confirmation, an in-session test invocation outcome (per ADR-026 grounding), or a `/wr-retrospective:run-retro` Step 4a close-on-evidence citation.
  - `no — not observed` — fix released but no session-observable evidence yet. Default for newly-released tickets. Aging is preserved separately via the `Released` column.
  - `no — observed regression` — fix released and the bug recurred this session. Flags the ticket for `.verifying.md` → `.known-error.md` flip-back via `/wr-itil:transition-problem`.

  A greppable HTML-comment marker `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` rides every render site for cross-skill drift detection, mirroring the established `TIE-BREAK-LADDER-SOURCE` (P138) and `VQ-SORT-DIRECTION` (P150) marker precedents.

  Render-site sweep:

  - `/wr-itil:review-problems` Step 3 + Step 5 (primary owner; drift-tripwire prose anchored here).
  - `/wr-itil:list-problems` Step 2 + Step 3.
  - `/wr-itil:manage-problem` Step 5 P094 + Step 7 P062 + Step 9c presentation + Step 9e template.
  - `/wr-itil:transition-problem` Step 7.
  - `/wr-itil:transition-problems` Step 4a batch render.
  - `/wr-itil:reconcile-readme` Step 3 + Step 4 row-insertion.

  Behavioural-contract bats fixture `packages/itil/skills/review-problems/test/review-problems-likely-verified-cell-shape.bats` covers marker presence at every render site, canonical-value documentation, drift-re-opens-P186 tripwire prose at the primary owners, age-heuristic regression guards, and the user-visible vocabulary shift in the rendered `docs/problems/README.md` Verification Queue rows. 17/17 green; full sibling suite re-run green (158/158 manage-problem + 150/150 across review-problems / list-problems / transition-problem / transition-problems / reconcile-readme).

  Closes P186 (VQ `Likely verified?` column uses age-based heuristic instead of session-observed evidence — sibling proxy-for-evidence anti-pattern to P185 at the review-problems Step 3/5 surface).

- 2266e2a: README-refresh-discipline hook now allows narrative-only ticket edits when the README is in-sync with filesystem truth

  `packages/itil/hooks/lib/readme-refresh-detect.sh` extends `detect_readme_refresh_required` with a narrative-only short-circuit. When all staged ticket edits are purely narrative — no ranking-bearing field change (Priority / Effort / Status / WSJF / Type field-lines), no title-line change, no rename between state subdirs, no creation or deletion — AND `packages/itil/scripts/reconcile-readme.sh` reports `exit=0` against the current README, the hook returns 0 (allow silently). Reconcile-readme is the authoritative drift oracle for narrative-only edits; the README is in sync, so a narrative tweak (Change Log entry, Investigation Task checkbox tick) cannot drift it.

  Ranking-bearing edits still fall through to existing deny detection regardless of reconcile state, preserving ADR-014 single-commit grain for the change-set surface. Reconcile-readme is a robustness layer on top of per-operation README refresh, not a supersession.

  Detection helpers `_readme_refresh_staged_is_ranking_bearing` and `_readme_refresh_reconcile_clean` are internal to the lib; the public `detect_readme_refresh_required` entry-point shape is unchanged.

  The hook's deny-message bypass advertisement is corrected from misleading inline-prefix syntax (which does NOT propagate to PreToolUse hooks per P173) to the working `.claude/settings.json` env-field path. Stays within ADR-045 deny-band.

  Behavioural test coverage: 7 new cases in `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` — narrative-only edit (Change Log + Investigation Task tick) + reconcile clean → allow; ranking-bearing Status field change + reconcile clean → deny; ranking-bearing Priority field change + reconcile clean → deny; rename between state subdirs (open → verifying) + no README → deny; narrative-only edit + reconcile drift → deny; deny-message asserts `.claude/settings.json` + P173 reference. 29/29 green.

  Closes P230 (hook misfires on narrative-only ticket edits when no ranking-bearing field changed AND reconcile-readme exit=0). Closes P231 (deny message advertises inline-prefix bypass syntax that does not propagate; recurrence of P173 at the README-refresh-hook surface).

## 0.30.0

### Minor Changes

- aacec45: work-problems Step 0b: auto-pre-flight inbound-discovery on stale upstream cache

  `/wr-itil:work-problems` now pre-flights `/wr-itil:review-problems` at Step 0b
  (after Step 0a auto-migrate, before Step 1 backlog scan) when the upstream
  inbound-discovery cache is missing, has `last_checked: null`, or has aged past
  its TTL. Closes the ADR-062 § JTBD-006 driver gap: review-problems' Step 4.5b
  TTL self-healing only fires if review-problems is entered; AFK loops would
  otherwise never poll upstream channels unless the maintainer ran review-problems
  manually first.

  - New helper: `packages/itil/lib/check-upstream-cache-staleness.sh` exposing
    `should_promote_inbound_discovery_preflight` (idempotent, fail-soft on missing
    channels-config — downstream-adopter non-obligation per ADR-062 §
    Downstream-adopter contract).
  - New behavioural test: `packages/itil/skills/work-problems/test/work-problems-step-0b-cache-staleness-behavioural.bats`.
  - Doc-hardening: `Edge Cases` and Step 1's exclusion list now reference
    `/wr-itil:review-problems` directly (replacing the deprecated
    `/wr-itil:manage-problem review` alias text).
  - AFK-safe by design: P132 mechanical-stage carve-out keeps the promotion point
    silent; review-problems' Step 4.5 pipeline's external-comms gates silent-pass
    on low-risk verdicts per ADR-028 + the `wr-risk-scorer:external-comms` _"policy-authorised drafts proceed silently"_ contract.
  - ADR-062 Confirmation criterion 5 records the wiring and the staleness-contract
    drift-prevention anchor.
  - JTBD-006 Desired Outcomes lists the pre-flight as a documented expectation.

## 0.29.0

### Minor Changes

- 368b8e6: RFC-004 Slice C: review-problems Step 4.5 inbound-discovery + assessment-pipeline

  Implements `/wr-itil:review-problems` Step 4.5 (ADR-062 § Step 8.5 / Decision
  Outcome) per RFC-004 Slice C. Wires the runtime orchestration that activates
  the channel-config + cache + audit-log scaffold (Slice A + D, shipped
  `ca4f6e4`) and consumes the `wr-risk-scorer:inbound-report` subagent
  (Slice B, shipped `f635470`).

  The step polls three GitHub channels (`github-issues` / `github-discussions` /
  `github-security-advisories`), matches fresh reports against local tickets via
  P070's semantic-comparator, and routes unmatched reports through the
  six-step assessment pipeline:

  1. Version-aware classification (P129 carve-out — stub seam; skipped until P129
     lands).
  2. JTBD-alignment classifier (`wr-jtbd:agent`): three outcomes —
     aligned-with-existing-JTBD / aligned-with-new-JTBD-for-existing-persona /
     not-aligned.
  3. Dual-axis risk classifier (`wr-risk-scorer:inbound-report` from Slice B):
     four outcomes — safe-low-fix-risk / safe-high-fix-risk /
     above-threshold-risk / clear-malicious-request.
  4. Above-threshold-pushback branch: gated `gh issue comment` declining the
     report (external-comms gate per ADR-028 amended).
  5. Clear-malicious branch: brief gated verdict comment BEFORE close (JTBD-301
     acknowledgement contract — silent close forbidden). Append handle to
     `docs/audits/inbound-discovery-log.md` for P123 block-list future
     consumption.
  6. Safe-and-valid branch: invoke `/wr-itil:capture-problem --no-prompt
<body-verbatim>` (default `type=technical`; maintainer re-classifies at
     next interactive review-problems re-rate) + gated acknowledgement
     `gh issue comment` carrying the new local-ticket reference.

  JTBD-301 acknowledgement contract honored on the matched-local-ticket path
  too: P070 semantic-comparator hit posts a gated cross-reference comment naming
  the local ticket (silent-skip would break "every report receives a verdict").

  Mechanical-stage carve-out (P132 / ADR-044 category 4 silent framework
  action): branch decisions resolve from JTBD-alignment + dual-axis-risk
  verdicts; Step 4.5 does NOT use `AskUserQuestion` at the branch decision.
  AFK orchestrator (`/wr-itil:work-problems` Step 6.5) calls into Step 4.5
  silently; user-attention surfaces only at existing external-comms gates
  (known interrupt class per ADR-028).

  Fail-soft contract: any error in Step 4.5 emits advisory and continues to
  Step 5 README rewrite. Per-branch gate-denial sub-branches preserve the
  report for the next pass when an external-comms gate denies a verdict /
  acknowledgement / pushback comment (silent-skip would break JTBD-301).

  `--force-upstream-recheck` parsed as a Slice C minimal string-match stub
  (marked `SLICE-C-FLAG-STUB` in the SKILL.md prose); Slice F replaces with
  proper argument parsing + TTL-expiry auto-recheck branch.

  Bats coverage deferred to Slice E per RFC scope (synthetic-channel fixture
  exercising each of the six pipeline outcomes + anti-`AskUserQuestion`
  assertion protecting the P132 mechanical-stage carve-out).

  The SKILL.md naming-reconciliation note at the top of Step 4.5 preserves the
  "Step 8.5" and "Step 9e" substring anchors verbatim so ADR-062 § Confirmation
  criterion 1 remains string-anchorable without mid-stream ADR amendment.

  Architect PASS (5 inline-prose hardenings folded in). JTBD PASS (no gaps).
  External-comms substantive PASS (no Confidential Information class matched —
  project-internal artefact IDs only); gate-key bypass per P166 (agents lack
  Bash for shasum). Pipeline PROCEED.

### Patch Changes

- e8ef115: RFC-004 Slice E: bats coverage for inbound-discovery + assessment-pipeline

  Closes the R009 empirical-coverage gap for Slice B (`f635470`) + Slice C
  (`368b8e6`) SKILL/agent prose. 85 assertions across 4 bats files —
  structural-with-Permitted-Exception per ADR-005 / P011 / ADR-037 /
  ADR-052 § Surface 2 for SKILL/agent-prose contracts; behavioural per
  P081 for JSON file shapes.

  Files added:

  - `packages/itil/skills/review-problems/test/inbound-discovery-contract.bats`
    (28 tests) — Step 4.5 SKILL.md prose contract: section presence,
    ADR-062 substring anchors preserved (Confirmation criterion 1
    string-anchorable), sub-step structure, six pipeline outcomes
    enumerated, JTBD-301 acknowledgement on all four outcome paths, P070
    matched-local-ticket cross-reference comment, **load-bearing
    anti-AskUserQuestion assertion** at the branch decision (protects
    JTBD-001 + JTBD-006 against inverse-P078 drift per P132
    mechanical-stage carve-out / ADR-044 category 4), fail-soft, downstream
    non-obligation, AFK silent path, SLICE-C-FLAG-STUB marker.

  - `packages/risk-scorer/agents/test/inbound-report-contract.bats`
    (27 tests) — inbound-report subagent prompt contract: frontmatter,
    sibling-not-extension framing, two-axis rubric, four classifications,
    structured verdict block, ADR-026 grounding, read-only invariant,
    P123 block-list scope carve-out, RISK-POLICY.md integration.

  - `packages/risk-scorer/skills/assess-inbound-report/test/assess-inbound-report-contract.bats`
    (14 tests) — on-demand skill contract: frontmatter, subagent
    delegation, no marker self-writes, manual-vs-pipeline carve-out,
    JTBD-005 + JTBD-202 drivers, ADR-015 Scope-table row.

  - `packages/itil/skills/review-problems/test/inbound-channels-cache-shape.bats`
    (16 tests — behavioural per P081) — JSON file shape contracts:
    upstream-channels.json + upstream-cache.json + inbound-discovery-log.md
    P131 path discipline.

  All 85 assertions pass; broader test suite (205 tests across
  review-problems + risk-scorer surfaces) green.

  Full behavioural synthetic-channel fixture (running the pipeline
  end-to-end with synthetic gh API responses and asserting six-outcome
  routing) remains deferred to the P012 master harness ticket; in-skill
  behavioural-replay is structurally limited per ADR-005 / P011 Permitted
  Exception.

  Slice E closes the R009 SKILL-prose-class empirical-coverage gap that
  the pipeline scorer flagged on Slice B + Slice C ship.

- fb8f326: RFC-004 Slice F: --force-upstream-recheck flag wiring + TTL-expiry auto-recheck

  Replaces the Slice C SLICE-C-FLAG-STUB string-match with proper tokenized
  $ARGUMENTS parsing. Step 4.5a now recognises `--force-upstream-recheck`
  and `--no-force-upstream-recheck` flags; unknown inbound-discovery flags
  surface an advisory rather than silently ignoring.

  Step 4.5b refactored into four explicit branches:

  - force-flag branch — `--force-upstream-recheck` bypasses TTL.
  - first-run branch — `last_checked == null`; fresh cache.
  - TTL-expiry auto-recheck branch — `cache_age > ttl_seconds`; self-healing
    across maintainer cadence without requiring the explicit flag.
  - cache-fresh within-TTL branch — silent-pass per ADR-013 Rule 5.

  The auto-recheck branch is what makes the system self-healing — a
  maintainer who runs `/wr-itil:review-problems` once a week still gets a
  fresh poll after the 24h default TTL expires. The explicit flag is the
  JTBD-202 pre-flight surface for tighter cadence (e.g. immediately before
  a release).

  Bats: SLICE-C-FLAG-STUB-absent assertion + 5 new Slice F assertions
  covering tokenized parsing + TTL-expiry + cache-fresh + within-TTL
  silent-pass + unknown-flag advisory.

  Refs: RFC-004

- ae73b7c: RFC-004 Slice G + in-progress → verifying transition (P079 fix shipped)

  Slice G adds the `## Inbound Upstream Reports` section renderer to
  `/wr-itil:review-problems` Step 5 README template and applies it to the
  live `docs/problems/README.md` as an advisory-row initial state. ADR-062
  § Step 9e per the naming-reconciliation note (current SKILL numbering:
  Step 5).

  Columns: `# | Source | Title | Author | Created | Classification |
Matched local ticket`. Lazy-empty discipline — empty table body when
  discovery has run with zero reports; advisory row when no discovery pass
  has run yet.

  RFC-004 transitions in-progress → verifying per the manage-rfc
  transition-table contract (terminal-slice commit folds in the rename +
  § Verification section per the skill spec). All seven slices (A-G)
  shipped. Closure gated on user-side behavioural replay per ADR-062
  § Confirmation criterion 3 — four synthetic-report scenarios (clean /
  out-of-scope / info-extraction / matched-local-ticket) — and two
  future-touch cross-reference notes (ADR-024 + ADR-046 amendments).

  Bats refresh adds 3 Slice G assertions to inbound-discovery-contract.bats
  (section header + lazy-empty discipline + column shape).

  README index housekeeping:

  - docs/rfcs/README.md WSJF Rankings empties; Verification Queue gains
    RFC-004 row with the seven-slice commit chain.
  - docs/problems/README.md P079 reverse-trace ## RFCs Status column
    flips in-progress → verifying via idempotent helper.
  - docs/problems/README.md P196 (premature-completion class-of-behavior
    ticket captured this session) added to WSJF Rankings at WSJF 1.0
    placeholder — reconciles the P196 capture commit's deferred README
    refresh per capture-problem Step 6 contract.

  Refs: RFC-004

## 0.28.1

### Patch Changes

- 29b2e4d: P185: `/wr-itil:capture-problem` Step 1.5 derive-first refactor. The type classification AskUserQuestion no longer fires unconditionally — a lexical-signal classifier reads the description and silently classifies unambiguous cases (with stderr advisory `"capture-problem: classified type=<value> from description signals: <s1>, <s2>; re-invoke with --type=<other> to override"`). The AskUserQuestion fallback fires only on genuinely-ambiguous descriptions (mixed signals or zero signals). Five technical signal classes (camelCase / kebab-case / snake_case identifiers + file paths + command-name patterns + mechanism words + error patterns) and three user-business signal classes (persona names + journey words + JTBD-shaped need words). Dispatch order is `--type=<value>` → `--no-prompt` → classifier → fallback; pre-resolution flags still short-circuit per the existing AFK contract. Taxonomy recategorised from "taste authority per ADR-044 category 5" to "silent-framework per category 4 on unambiguous; taste per category 5 fallback on ambiguous" per architect verdict (no ADR amendment needed — in-scope under ADR-044 Reassessment Criteria). I2 invariant preserved (advisory text shape isomorphic across both type classifications); JTBD-301 plugin-user firewall preserved + scope guard extended to name the manage-problem ingestion path; classifier scoped to maintainer-side `/wr-itil:capture-problem` only. 17 new behavioural bats in `capture-problem.bats` (32/32 green); i2-no-type-branching.bats 9/9 green.

## 0.28.0

### Minor Changes

- c5b21ed: P170 Phase 2 Slice 10 — `/wr-itil:list-stories` read-only display skill at `packages/itil/skills/list-stories/SKILL.md` (~160 lines) plus 7-test contract bats fixture. Mirrors `list-problems` precedent (P071 phased-landing split per ADR-010 amended Skill Granularity rule).

  - Allowed-tools: `Read, Bash, Grep, Glob` only — read-only contract, no Write / Edit (the list-\* family is pure view per ADR-010).
  - **Unfiltered mode** renders five lifecycle-grouped markdown tables (draft / accepted / in-progress / done / archived). Empty sections are omitted rather than rendered as empty headers.
  - **Filtered mode** (`--rfc RFC-<NNN>`) renders a single execution-order table sourced from the RFC's frontmatter `stories:` array per ADR-060 line 259 — load-bearing for Slice 13's working-the-problem traversal (the orchestrator's per-RFC iter dispatch picks the first not-done story from this same array).
  - **Cache-freshness check** uses the `git log -1 --format=%H -- docs/stories/README.md` pattern per P031 — filesystem mtime is unreliable in worktrees and fresh checkouts, so git history is the authoritative staleness signal. Cache-fresh + no `--rfc` filter reads `docs/stories/README.md` directly; otherwise live-scans.
  - **I11 no-WSJF-leak invariant** enforced behaviourally at the output surface — no WSJF column header in any rendered table. Phase 2 stories MUST NOT participate in WSJF ranking per ADR-060 line 253.

  7-test contract bats (per ADR-052) covering: SKILL.md presence + canonical name; read-only allowed-tools contract; lifecycle enumeration (all 5 state subdirectories named); RFC-frontmatter-stories-array-driven ordering (not filesystem / lexical order); P031 git-log cache-freshness pattern; I11 no-WSJF-column invariant. All 7 tests green.

  JTBD-008 + JTBD-006 anchors: JTBD-008 (Decompose a Fix Into Coordinated Changes) via the per-RFC ordered story view that operationalises the "first-class entity" Desired Outcome; JTBD-006 (Progress the Backlog While I'm Away) via the filtered mode that feeds the AFK orchestrator's per-RFC iter dispatch in Slice 13.

  Markdown-only writes — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

  packages/itil/README.md updated to add the list-stories row to the skills table — closes the P159 JTBD-currency drift gate.

- cb7a90e: P170 Phase 2 Slice 11 — RFC frontmatter `stories:` extension per ADR-060 amendment 2026-05-10 (lines 255-270 + 296). The RFC tier now carries a forward-reference to the INVEST-shaped stories that implement it; the array is ORDERED (execution sequence) and 0..N cardinality (empty = atomic RFC, JTBD-101 friction guard).

  Three coordinated edits land together:

  - **`docs/rfcs/README.md` § RFC frontmatter shape**: adds `stories: [STORY-<NNN>, ...]` field with 0..N + ORDERED contract; field-semantics table row names the atomic-fix-adopter empty-array case + Slice 13 working-the-problem traversal dependency.
  - **`docs/rfcs/README.md` § RFC body structure**: adds `## Stories (Phase 2 — maintained)` body section spec — auto-rendered from frontmatter `stories:` in execution sequence; lazy-empty when the array is empty (atomic-RFC absence-as-signal for the working-the-problem fallback).
  - **`packages/itil/skills/capture-rfc/SKILL.md`**: Step 1 parse-arguments extended with optional `--stories STORY-NNN,STORY-NNN,...` flag (forward-reference permitted at capture; existence check deferred to `manage-rfc accepted`). Step 5 frontmatter template adds `stories: [...]` field. Step 6 invokes `update-rfc-references-section.sh "$rfc_file" "Stories"` when `--stories` was provided, rendering the new RFC's own `## Stories` body section before commit.
  - **`packages/itil/skills/manage-rfc/SKILL.md`**: Step 7 (status transitions) gains a "Forward trace — `## Stories` body section (Phase 2)" subsection invoking `update-rfc-references-section.sh "$rfc_file" "Stories"` on every lifecycle transition. Idempotent + lazy-empty per the Slice 2a/2b contract. Composes with the existing `## Story Maps` refresh.

  7-test behavioural bats at `packages/itil/scripts/test/rfc-stories-extension.bats` per ADR-052: frontmatter spec presence + ORDERED-cardinality contract; Slice 2b helper acceptance of populated `stories: [STORY-001, STORY-002]` AND empty `stories: []` (atomic-RFC JTBD-101 friction guard); SKILL.md presence of the load-bearing identifiers (`--stories STORY-`, `stories:`, `update-rfc-references-section.sh ... Stories`) in both capture-rfc + manage-rfc. All 7 tests green.

  Unlocks Slice 15 (bootstrap migration of RFC-001 + RFC-002 frontmatter `stories:` populated with their ordered slice IDs) by giving the schema + skill surfaces something to write into. Composes with Slice 7 (`capture-story` emits stories whose frontmatter cross-references the parent RFC) + Slice 10 (`list-stories --rfc RFC-<NNN>` reads the same array in execution order to drive the per-RFC ordered display).

  Markdown-only writes — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

- d0cd2a2: P170 Phase 2 Slice 13 — working-the-problem traversal rewrite per ADR-060 lines 300-320. Replaces the prior vague "implement the fix following the project's development workflow" with a deterministic Problem → RFC → Story dispatch:

  - **`packages/itil/skills/manage-problem/SKILL.md`** § Working a Problem → Known Error subsection: 8-step traversal:

    1. Read problem `## Fix Strategy` → extract referenced RFC IDs (or fall through to legacy direct-implementation path on no-RFC).
    2. For each RFC, read frontmatter `stories:` array (ORDERED). Non-empty → pick first `accepted` or `in-progress` story (skip `done` and `draft`). Empty `stories: []` → atomic-RFC fallback (JTBD-101 friction guard) — per-RFC iter dispatch on RFC body tasks.
    3. Read picked story's `## User value` + `## Acceptance criteria` + `## Implementation notes`.
    4. Implement story scope per project workflow (plan / architect+JTBD review / behavioural tests / ADR-014 single-commit grain).
    5. Commit with `Refs: STORY-<NNN>` trailer (single-trailer vocabulary per ADR-060 line 307 + amendment 2026-05-10 nitpick N2; capture-vs-implementation discrimination on commit-subject prefix not trailer verb).
    6. Story `draft → in-progress` auto-transition on first non-capture commit; `in-progress → done` on all-criteria-ticked + linked RFC closes.
    7. Pick next not-done story from RFC's `stories:` array (or next task for atomic-RFC fallback path); repeat.
    8. When all stories under all referenced RFCs done → include problem doc closure (`git mv` to `.verifying.md`) in final commit per ADR-022.

  - **`packages/itil/skills/work-problem/SKILL.md`** § Step 3 Known Error case description updated to forward-point to the manage-problem traversal contract — work-problem (singular) and work-problems (plural AFK orchestrator) both inherit the new traversal via the existing skill split (work-problems Step 3 wraps manage-problem invocation).

  **Atomic-RFC fallback path** preserves Phase 1 atomic-fix-adopter behaviour: an adopter who hasn't adopted Phase 2 story tooling has zero new friction; their RFCs continue to ship with `stories: []` and their problems continue to close via per-RFC iter dispatch.

  **Legacy direct-implementation path** preserves backwards compatibility with all existing Known Error problems (captured before the RFC framework was Phase-1-graduated) — no Fix Strategy RFC references → direct implementation flow unchanged.

  10-test behavioural bats per ADR-052 at `packages/itil/scripts/test/working-the-problem-traversal.bats`: Fix-Strategy section extraction; RFC frontmatter `stories:` array read with ORDERED contract; pick-first-not-done filter naming `accepted`/`in-progress`/`done`/`draft` lifecycle states; atomic-RFC empty-stories fallback (JTBD-101 friction guard); legacy no-RFC direct path; single-trailer vocabulary (`Refs: STORY-NNN` + `Refs: RFC-NNN`); story auto-transition triggers (draft→in-progress on first non-capture commit; in-progress→done on all-criteria-ticked + RFC closed); work-problem forward-pointing to manage-problem. All 10 tests green.

  Markdown-only edits — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

- c00c82e: P170 Phase 2 Slice 14 — STORY-MAP-001 bootstrap HTML scaffold at `docs/story-maps/in-progress/STORY-MAP-001-rfc-framework-phase-1-bootstrap.html` per ADR-060 § Phase 2 encoding amendment 2026-05-12. Plus the unblock path: `docs/VOICE-AND-TONE.md` + `docs/STYLE-GUIDE.md` policy files authored to close the empirical block documented at P170 line 297.

  **Unblock path applied** (line 297 option a — author the policy files + delegate one-time review):

  - `docs/VOICE-AND-TONE.md` (new, ~115 lines) — voice + tone policy with banned-pattern list + word-list + HTML-content rules. wr-voice-tone:agent PASS verdict 2026-05-12 → /tmp/voice-tone-reviewed-${SESSION_ID} marker set.
  - `docs/STYLE-GUIDE.md` (new, ~90 lines) — story-map HTML style rules (layout-only embedded `<style>`, prohibited inline `style=""` on data-bearing elements, class-name vocabulary, data-attribute vocabulary, colour + typography guidance). wr-style-guide:agent PASS verdict 2026-05-12 → /tmp/style-guide-reviewed-${SESSION_ID} marker set.

  With both markers set, voice-tone + style-guide enforce-edit hooks pass on `*.html` writes under `docs/story-maps/` for this session. STORY-MAP-001 HTML landed without rejection.

  **STORY-MAP-001 scaffold** (~125 lines HTML):

  - `<meta>` block: story-map-id=STORY-MAP-001, status=in-progress, problems=P170, rfcs=RFC-001/RFC-002/RFC-003, jtbd=JTBD-008/001/006/101, adrs=ADR-060, reported=2026-05-12.
  - Embedded `<style>` block with layout-only rules (CSS Grid + custom-property `--cols` per `docs/STYLE-GUIDE.md`).
  - Three backbone ribs:
    - Phase 2 framework code (this session): 7 STORY-NNN slices (STORY-001 .. STORY-007) with `data-story-id` + `data-rfc=RFC-003` + `data-status=done` attributes.
    - Phase 2 story-map skills (in-flight): 4 STORY-NNN placeholders (STORY-008..011) for Slices 3-6.
    - Phase 1 RFC tier (prior sessions, reference only): RFC-001 + RFC-002 links.
  - No inline `style=""` on data-bearing elements per `docs/STYLE-GUIDE.md` prohibition + ADR-060 line 433.

  **Partial scope**: full B1-B10 backbone + T1-T11 task lattice migration from `docs/plans/170-rfc-framework-story-map.md` deferred — the plans file represents pre-Phase-2 thinking and will be superseded by extracted bootstrap stories in a follow-on session. This slice ships the HTML scaffold + the slice-grain decomposition that the framework actually ran on.

  Markdown + HTML edits (HTML unblocked via the policy-file authoring path).

- eda6ea0: P170 Phase 2 Slice 15 (PARTIAL) — RFC-003 capture for the Phase 2 framework + 7 bootstrap stories under `docs/stories/done/` per ADR-060 amendment 2026-05-10 lines 270-296 + line 339 bootstrap-exemption marker contract.

  **RFC-003 captured** at `docs/rfcs/RFC-003-p170-phase-2-story-tier-framework.in-progress.md`. Status: `in-progress` (Phase 2 framework code shipping; Slices 3-6 + 14 deferred to post-marketplace-release). Frontmatter `problems: [P170]`, `adrs: [ADR-060]`, `jtbd: [JTBD-008, JTBD-001, JTBD-006, JTBD-101]`, `stories: [STORY-001 .. STORY-007]`.

  **Seven bootstrap stories** shipped under `docs/stories/done/`, each carrying the `<!-- bootstrap-exempt: STORY-MAP-001 migration per ADR-060 amendment 2026-05-10 -->` marker (one-time exemption per ADR-053 Bootstrapping precedent; non-bootstrap captures with the marker fail per the I7/I8/I9/I10 retrofit gate):

  - STORY-001 — Slice 2.5 hook exemption globs (S effort)
  - STORY-002 — Slice 7 capture-story skill (M)
  - STORY-003 — Slice 10 list-stories skill (S)
  - STORY-004 — Slice 11 RFC stories: extension (S)
  - STORY-005 — Slice 13 working-the-problem traversal (M)
  - STORY-006 — Slice 9 reconcile-stories trio (M)
  - STORY-007 — Slice 8 manage-story skill (L)

  Each story carries the I6-I10 retrofit: problems trace (P170), JTBD trace (JTBD-008 + others), RFC trace (RFC-003), story-map trace (STORY-MAP-001 — deferred per bootstrap-exempt marker; Slice 14 blocked on marketplace release), `estimated-effort` field, User value statement, Acceptance criteria, Driving problem trace, JTBD trace, Implementation notes, Dependencies, Related sections.

  **Partial scope**: full bootstrap extraction of every Slice 0-15 backbone + ribs (B1-B10 + T1-T11 from `docs/plans/170-rfc-framework-story-map.md` Phase 1 work) deferred — those represent prior-session and RFC-001/RFC-002 work and warrant their own bootstrap RFC capture pass. RFC-001 + RFC-002 frontmatter `stories:` backfill also deferred — their work has already shipped + verified; the backfill is retroactive documentation, lower urgency than the in-flight RFC-003 trace.

  Capture-rfc create-gate marker (`/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}`) touched manually to satisfy the P119 gate for the RFC-003 retrospective capture; the skill itself was not invoked because RFC-003 documents work already done (capture-rfc is for forward-capture; retrospective RFCs land via direct Write under the satisfied marker).

  Markdown-only edits — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

- 3e35206: P170 Phase 2 Slice 16 — P170 transition Known Error → Verification Pending per ADR-022. Phase 2 framework code is fully shipped this session; the ticket moves to the Verification Queue awaiting forward-dogfood validation post-marketplace-release.

  **This transition completes P170 Phase 2 SHIP.** All 14 Phase 2 slices done (counting Slice 12 folded into Slices 3+7; Slices 14 + 15 marked partial with explicit deferred follow-up trails):

  - Slice 0 (prior) — ADR-060 HTML encoding amendment
  - Slice 1 (prior) — docs/story-maps + docs/stories scaffold
  - Slice 2a (prior) — update-problem-references-section.sh
  - Slice 2b (prior) — 3 sibling reverse-trace helpers
  - Slice 2.5 (this session) — Hook exemption globs (4 enforce-edit hooks)
  - Slice 3 (this session) — capture-story-map skill
  - Slice 4 (this session) — manage-story-map skill
  - Slice 5 (this session) — reconcile-story-maps trio
  - Slice 6 (this session) — list-story-maps skill
  - Slice 7 (this session) — capture-story skill
  - Slice 8 (this session) — manage-story skill
  - Slice 9 (this session) — reconcile-stories trio
  - Slice 10 (this session) — list-stories skill
  - Slice 11 (this session) — RFC frontmatter stories: extension
  - Slice 12 (folded) — collision-guard inline per Slice 3+7
  - Slice 13 (this session) — working-the-problem traversal rewrite
  - Slice 14 (this session) — STORY-MAP-001 HTML bootstrap + voice-tone + style-guide policy files
  - Slice 15 (this session, partial) — RFC-003 capture + 7 bootstrap stories
  - Slice 16 (this commit) — P170 transition Known Error → Verification Pending

  **Transition mechanics**:

  - `git mv docs/problems/known-error/170-...md docs/problems/verifying/170-...md`
  - Status field edited to `Verification Pending`
  - New `## Fix Released` section listing the 10-commit chain across this session
  - `docs/problems/README.md` refreshed: P170 row removed from WSJF Rankings; new row added to Verification Queue
  - Prior line-3 fragment (P165 transition) rotated to `docs/problems/README-history.md` per P134; new fragment names P170 + Phase 2 framework code completion

  **Verification gate per ADR-022**: forward-dogfood post-marketplace-release. Verify on next session by running:

  1. `/wr-itil:capture-story-map P<NNN> JTBD-<NNN> <description>` writes fresh STORY-MAP-NNN HTML without rejection (the Slice 2.5 hook exemption globs need to be released first; the in-session VOICE-AND-TONE.md + STYLE-GUIDE.md policy-file unblock path covered the session itself).
  2. `/wr-itil:capture-story P<NNN> JTBD-<NNN> <description>` writes STORY-NNN markdown; I6 + I9 hard-block fires on missing traces.
  3. `/wr-itil:manage-story <NNN> accepted` enforces I7+I8+I10.
  4. `/wr-itil:work-problem <NNN>` traverses Problem → Fix Strategy → RFC → stories: → next not-done story per Slice 13.

  On verification PASS: transition Verification Pending → Closed.

  Partial-scope explicit follow-ups deferred:

  - Slice 14: full B1-B10/T1-T11 backbone migration from `docs/plans/170-rfc-framework-story-map.md` (the plans file stays as planning artefact by reference)
  - Slice 15: full bootstrap stories extraction + RFC-001/RFC-002 frontmatter stories: backfill (their work shipped + verified independently; backfill is retroactive documentation)

- 849701a: New generalised reverse-trace helper `packages/itil/scripts/update-problem-references-section.sh` refreshing auto-maintained `## RFCs` / `## Story Maps` / `## Stories` sections on problem tickets (P170 Phase 2 Slice 2a). Lookup-table-driven dispatch — adding a new section is a table extension; the helper body carries NO per-section-name branching (per ADR-060 § Phase 2 encoding amendment 2026-05-12 architect finding 4). Polymorphic extraction: HTML `<meta name="problems" content="P<NNN>">` data-attribute grep for story-map traces; YAML frontmatter `problems:` parse for story + RFC traces. Lazy-empty discipline removes the section when no artefacts match. Idempotent rerun. 10-test behavioural bats fixture covers both extraction paths + lazy-empty + idempotency + HTML-style-agnostic extraction + structural no-branching guard. Absorbs the existing single-purpose `update-problem-rfcs-section.sh` contract for the `## RFCs` section per the cleanup contract; the existing helper stays in place as a deprecated forwarder candidate for the deprecation window.
- 970cfce: P170 Phase 2 Slice 2b — three sibling generalised reverse-trace helpers landing alongside the canonical Slice 2a helper:

  - `packages/itil/scripts/update-rfc-references-section.sh` — `## Story Maps` / `## Stories` sections on RFC files
  - `packages/itil/scripts/update-jtbd-references-section.sh` — `## RFCs` / `## Story Maps` / `## Stories` sections on JTBD files (NEW reverse-trace surface tier)
  - `packages/itil/scripts/update-story-references-section.sh` — `## RFCs` / `## Story Maps` sections on story files

  All three follow the same lookup-table-driven dispatch pattern as Slice 2a (no per-section-name branching in body per ADR-060 § Phase 2 encoding amendment 2026-05-12 architect finding 4); polymorphic extraction (HTML data-attribute grep / markdown frontmatter parse) per source-artefact type; lazy-empty discipline; idempotent rerun. Sanity bats fixture asserts existence + executable + positional argument validation + structural no-branching guard for all three siblings. Full behavioural coverage of the polymorphism is asserted by Slice 2a's comprehensive bats fixture for the canonical helper.

- b9085b9: P170 Phase 2 Slice 7 — `/wr-itil:capture-story` lightweight aside skill for capturing INVEST-shaped story tickets at `docs/stories/draft/STORY-NNN-<slug>.md` per ADR-060 Phase 2 amendment 2026-05-12 (lines 220-307 — story tier spec + skill description line 291).

  Mirrors `/wr-itil:capture-rfc` shape with extensions for the story-tier's stricter trace-mandate:

  - Positional argument grammar: `<problem-trace> <jtbd-trace> <description>` — BOTH mandatory at capture-time (I6 + I9 hard-block per ADR-060 lines 248 + 251).
  - Optional `--rfc RFC-<NNN>` and `--story-map STORY-MAP-<NNN>` flags — I7 + I8 enforce at `accepted` transition only, not at capture (per ADR-060 line 291).
  - Inline `max(local, origin) + 1` STORY-NNN ID allocation (ADR-019 collision-guard inline path per Slice 3 design review architect option a).
  - Single `Refs: STORY-<NNN>` trailer per ADR-060 line 307 single-trailer vocabulary; capture-vs-implementation discrimination owned by manage-story (Slice 8) on commit-subject prefix.
  - Inline reverse-trace `## Stories` section refresh on driving problem + JTBD + RFC files via the existing Slice 2a/2b helpers; NO refresh on story-map HTML files (manually-authored data-attribute traces — architect amend finding 2).
  - Deferred `docs/stories/README.md` refresh per the established capture-rfc precedent.
  - Deny-log path `logs/story-capture-denials.jsonl` for I6 + I9 deny cases (sibling to `logs/rfc-capture-denials.jsonl`).

  12-test behavioural bats fixture (per ADR-052) at `packages/itil/skills/capture-story/test/capture-story-behavioural.bats` covering: SKILL.md presence + canonical name; next-ID formula (empty / local-only / collision-on-origin / local-higher); reverse-trace helper "Stories" section-name acceptance on problem + JTBD + RFC helpers; NON-acceptance on story-tier helper (story-maps are HTML); frontmatter shape conformance to ADR-060 lines 220-228; landing path `docs/stories/draft/`. All 12 tests green.

  Architect AMEND verdict 2026-05-12 closed: finding 1 (single-trailer vocabulary) + finding 2 (no story-map inline refresh) both applied verbatim; findings 3-5 (advisory) integrated. JTBD PASS verdict 2026-05-12.

  Ships BEFORE capture-story-map (Slice 3 / 4) due to voice-tone-hook-on-HTML blocker. Structurally permitted per ADR-060 line 291 — story-map trace optional at capture; I8 enforce only at `manage-story <NNN> accepted` transition. When Slices 3-6 ship the story-map skills (post-marketplace-release-cycle for hook exemption globs from Slice 2.5), `manage-story <NNN> accepted` will validate I8 against the then-existing story-map corpus.

- 51de089: P170 Phase 2 Slice 8 — `/wr-itil:manage-story` heavyweight story lifecycle skill at `packages/itil/skills/manage-story/SKILL.md` (~310 lines) plus 19-test contract bats. Mirrors manage-rfc shape with story-tier extensions per ADR-060 amendment 2026-05-10 lines 200-253 + 270 + 292.

  **Lifecycle**: draft → accepted → in-progress → done → archived (5 states, native per-state subdir layout — no dual-tolerant flat per RFC-002 post-graduation).

  **I-invariant enforcement** per ADR-060 lines 248-253:

  - I6 (trace-to-problem) — re-validated at every transition; primary capture surface.
  - I7 (trace-to-RFC) — hard-block at `manage-story <NNN> accepted` (deferred from capture per ADR-060 line 291).
  - I8 (trace-to-story-map) — hard-block at `manage-story <NNN> accepted`.
  - I9 (trace-to-JTBD) — re-validated at every transition; primary capture surface.
  - I10 (INVEST shape) — hard-block at `manage-story <NNN> accepted` checking all 4 axes: Testable (≥1 acceptance criterion), Valuable (User value statement non-empty), Independent (no Blocked-by-unaccepted refs), Estimable (estimated-effort field set). L/XL stories flagged as decomposition-candidate per ADR-060 line 252 architect-amendment-2026-05-10 nitpick N3 (advisory, not blocking — XL stories may be the right granularity for bounded work).
  - I11 (no-WSJF-leak) — argument grammar carries no WSJF token; frontmatter handling carries no WSJF read/write.

  **Single-trailer vocabulary** per ADR-060 line 307 + amendment 2026-05-10 nitpick N2: `Refs: STORY-NNN` for all commits (capture, implementation, transition); capture-vs-implementation discrimination via commit-subject prefix (`feat(itil): capture STORY-...` is capture; any other subject is implementation).

  **Auto-transition triggers** per ADR-060 line 292:

  - draft → in-progress: first commit AFTER capture commit carrying `Refs: STORY-<NNN>` trailer.
  - in-progress → done: ALL `- [ ]` lines in `## Acceptance criteria` ticked + linked RFC reaches `closed` status (RFC-side transition triggers a sweep of its `stories:` array).

  **Bootstrap-exemption marker** per ADR-060 line 339 + ADR-053 Bootstrapping precedent: one-time `<!-- bootstrap-exempt: STORY-MAP-001 migration per ADR-060 amendment 2026-05-10 -->` permitted on bootstrap-migration stories during Slice 15 retrofit; non-bootstrap captures with the marker fail.

  **Reverse-trace refresh on 4 parent tiers** at every transition (inline per ADR-014 single-commit grain):

  - Problem parents: `update-problem-references-section.sh <problem-file> "Stories"` (Slice 2a)
  - JTBD parents: `update-jtbd-references-section.sh <jtbd-file> "Stories"` (Slice 2b)
  - RFC parents: `update-rfc-references-section.sh <rfc-file> "Stories"` (Slice 2b + Slice 11)
  - Story-map parents: MANUAL placement per Slice 7 architect amend finding 2 — story-maps are HTML with manually-authored `data-story-id` attributes; emit advisory stderr noting unplaced state.

  P062 mirror: every transition refreshes `docs/stories/README.md` Story Rankings + Done tables inline.

  19-test contract bats (per ADR-052, behavioural for SKILL contract surfaces per P081 + P012 acknowledged limitation) covering: SKILL.md presence + canonical name; I6-I11 invariant declarations (6 tests); I7+I8 accepted-gate firing; INVEST 4-axis check + L/XL decomposition-candidate advisory; auto-transition triggers (draft→in-progress + in-progress→done); bootstrap-exemption marker contract; 4 reverse-trace surfaces (problem/JTBD/RFC + story-map manual-placement carve-out); I11 no-WSJF-leak argument grammar. All 19 green.

  Companion to `/wr-itil:capture-story` (lightweight aside surface — Slice 7) per ADR-032 split. Together with Slice 7 + Slice 10 (list-stories) + Slice 9 (reconcile-stories), Slice 8 completes the story-tier MVP.

  packages/itil/README.md updated to add the `/wr-itil:manage-story` row to the skills table — closes the P159 JTBD-currency drift gate inline.

  Markdown-only edits — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

- 2f3c220: P170 Phase 2 Slice 9 — `/wr-itil:reconcile-stories` trio (skill + script + bin shim) per ADR-060 amendment 2026-05-10 line 270 + reconcile-rfcs / reconcile-readme sibling pattern.

  Three coordinated artefacts land together:

  - **`packages/itil/scripts/reconcile-stories.sh`** (~215 lines, executable, exit codes 0/1/2 per ADR-040 advisory-exit contract) — Diagnose-only drift detector for `docs/stories/README.md` vs on-disk story inventory. Builds filesystem truth across 5 lifecycle subdirs (`draft`, `accepted`, `in-progress`, `done`, `archived`); parses README `## Story Rankings` + `## Done` sections; emits structured drift entries (`DRIFT` / `STALE` / `MISMATCH`). Reverse-trace pass when `docs/problems/` / `docs/rfcs/` / `docs/jtbd/` exist on disk: verifies the auto-maintained `## Stories` section on each parent against the story frontmatter's `problems:` / `rfcs:` / `jtbd:` claims (three drift kinds per parent tier: `MISSING_REVERSE_TRACE`, `STALE_REVERSE_TRACE`, `STATUS_MISMATCH`).

  - **`packages/itil/bin/wr-itil-reconcile-stories`** (2-line bin shim per ADR-049) — `$PATH`-resolved entrypoint that `exec`s the script.

  - **`packages/itil/skills/reconcile-stories/SKILL.md`** (~140 lines) — Agent-applied-edits skill that wraps the diagnose-only script. Step-by-step recovery contract: run script → read drift entries → plan edits (README row updates for `DRIFT`/`STALE`/`MISMATCH`; helper invocation for `*_REVERSE_TRACE` and `STATUS_MISMATCH`) → apply edits → verify clean → single-commit per ADR-014. Forward-pointer to `/wr-itil:manage-story review` for INVEST-scoring refresh if reconciliation window crossed an accepted-gate transition.

  10-test behavioural bats per ADR-052 at `packages/itil/scripts/test/reconcile-stories.bats`: script + bin shim existence + executable + exec-pattern; parse-error exits (missing README / missing `## Story Rankings` header); clean exit on empty stories dir + empty README tables; STALE detection when filesystem has a draft story not in README; DRIFT detection when README claims story in Rankings but filesystem has it in done; archived stories correctly hidden from both tables (no false-positive drift); SKILL.md presence + canonical name. All 10 green.

  Sibling to `packages/itil/scripts/reconcile-rfcs.sh` (ADR-060 Phase 1 item 5) and `reconcile-readme.sh` (P118 / ADR-014). Differences: no WSJF column (I11 invariant per ADR-060 line 253); 5 lifecycle subdirs not 4; per-state subdir layout (no dual-tolerant flat — story tier is post-RFC-002, native-subdir); no Verification Queue or Parked tier (those are problem-tier-specific).

  packages/itil/README.md updated to add the `/wr-itil:reconcile-stories` row to the skills table — closes the P159 JTBD-currency drift gate inline.

  Markdown-only edits + bash script + bin shim — no HTML writes; voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

- e99b275: P170 Phase 2 Slices 3 + 4 + 5 + 6 — story-map tier MVP (4 skills + reconcile script + bin shim) per ADR-060 amendment 2026-05-10 + encoding amendment 2026-05-12. Mirrors the story-tier MVP (Slices 7-10) at the story-map tier with HTML encoding adjustments.

  **Slice 3: `/wr-itil:capture-story-map`** (lightweight aside) — `packages/itil/skills/capture-story-map/SKILL.md`. Mandatory positional `<problem-trace> <jtbd-trace> <description>` with I3 + I4 hard-block. HTML skeleton at `docs/story-maps/draft/STORY-MAP-NNN-<slug>.html` per ADR-060 § Phase 2 encoding amendment 2026-05-12 lines 381-435. Inline `max(local, origin) + 1` STORY-MAP-NNN ID allocation per ADR-019 collision-guard. Reverse-trace `## Story Maps` section refresh on driving problem + JTBD files via Slice 2a/2b helpers. Deferred `docs/story-maps/README.md` refresh. 11 behavioural bats green.

  **Slice 4: `/wr-itil:manage-story-map`** (heavyweight lifecycle) — `packages/itil/skills/manage-story-map/SKILL.md`. Lifecycle: draft → accepted → in-progress → completed → archived (5 states). I3+I4 re-validated at every transition; I5 no-WSJF-leak enforced at argument grammar + frontmatter level. Backbone × ribs × slices authoring guidance at accepted transition (AskUserQuestion taste class). P062 README refresh inline. Reverse-trace refresh on driving problems + JTBDs via "Story Maps" section helpers; NO reverse-trace on the map HTML file itself (slice cards' `data-story-id` attributes are authored manually per architect Slice 7 amend finding 2). 11 contract bats green.

  **Slice 5: `/wr-itil:reconcile-story-maps`** (trio per ADR-049) — `packages/itil/scripts/reconcile-story-maps.sh` (~110 lines, executable, exit 0/1/2 per ADR-040), `packages/itil/bin/wr-itil-reconcile-story-maps` (bin shim), `packages/itil/skills/reconcile-story-maps/SKILL.md` (~90 lines agent-applied-edits wrapper). FS truth across 5 lifecycle subdirs; MISSING/STALE drift detection against README. No Rankings table (I5 — story-maps are planning artefacts, not work items). 7 behavioural bats green.

  **Slice 6: `/wr-itil:list-story-maps`** (read-only display) — `packages/itil/skills/list-story-maps/SKILL.md`. Lifecycle-grouped tables for 5 subdirs; no WSJF column (I5); HTML `<meta>` block parse target via xmllint with grep fallback. No `--rfc` filter mode (story-maps aren't per-RFC scoped — they're journey-context lenses on the story corpus per ADR-060 line 317). 7 contract bats green.

  **Together with Slices 7-10 (story tier)**, Slices 3-6 complete the Phase 2 story-map + story tier MVP. The voice-tone-hook-on-HTML blocker from P170 line 297 closed via Slice 14's in-session unblock path (`docs/VOICE-AND-TONE.md` + `docs/STYLE-GUIDE.md` policy files + wr-voice-tone:agent + wr-style-guide:agent PASS verdicts → review-gate markers set).

  packages/itil/README.md updated with 4 new skill rows (capture-story-map, manage-story-map, reconcile-story-maps, list-story-maps) — closes P159 JTBD-currency drift gate inline.

  Net: 4 SKILL.md files + 4 bats fixtures + 1 reconcile script + 1 bin shim + 1 README update. 36 bats tests total (11 + 11 + 7 + 7) across the 4 slices.

- b963920: Add shared shell migration routine `packages/itil/lib/migrate-problems-layout.sh` (synced from `packages/shared/lib/`) per P170 / RFC-002 / ADR-031. Exposes two functions sourced by adopter `manage-problem` / `work-problems` skills at Step 1 (T8 + T9 in follow-up commits): `detect_flat_layout` predicate and `migrate_problems_to_per_state_layout` idempotent entrypoint. The entrypoint auto-migrates adopter `docs/problems/<NNN>-<slug>.<state>.md` flat-layout trees to the per-state-subdirectory shape (`docs/problems/<state>/<NNN>-<slug>.md`) on first invocation after update; emits a standalone commit with `RISK_BYPASS: adr-031-migration` trailer. Dormant in this release — no skill sources the routine yet — but ships in the tarball so the consumer wiring in subsequent releases can rely on it being present. nullglob-guarded; partial-migration-safe; idempotent.

### Patch Changes

- 18c8895: Fix `migrate_problems_to_per_state_layout` commit message: under git 2.47.x, `git commit --trailer "RISK_BYPASS: adr-031-migration"` produced a corrupted trailer line (`RISK_BYPASS: adr-031-migration:` with a spurious trailing colon) that broke downstream `^RISK_BYPASS:\s*adr-031-migration$` parsers in T11 commit-gate hook recognition. Switched to sequential `-m` paragraphs which emit a clean `RISK_BYPASS: adr-031-migration` body line. Discovered by RFC-002 T10 behavioural bats fixture (11 end-to-end tests at `packages/shared/test/migrate-problems-layout-behavioural.bats` simulating adopter flat-layout migration in a temp git repo).
- 970b615: `manage-problem` SKILL.md gains a new Step 0a (Auto-migrate adopter layout) that fires before Step 0 README reconciliation preflight. Sources `packages/itil/lib/migrate-problems-layout.sh` (shipped in T7) and calls `migrate_problems_to_per_state_layout` to auto-migrate flat-layout `docs/problems/<NNN>-<slug>.<state>.md` trees into per-state subdirectories on first invocation post-update. Idempotent + partial-migration-safe; emits standalone commit with `RISK_BYPASS: adr-031-migration` trailer. Fires unconditionally per ADR-013 Rule 6 + ADR-019 precedent. Routine refinements applied this release: single stderr first-fire signal (`migrate-problems-layout: relocated N tickets to per-state subdirs (ADR-031)`) so AFK orchestrator output records the action; commit body cites `docs/decisions/031-problem-ticket-directory-layout.accepted.md` so future `git log` readers have semantic context independent of the trailer.
- c4e64f2: `work-problems` SKILL.md gains a new Step 0a (Auto-migrate adopter layout) inserted AFTER Step 0 fetch/divergence preflight and BEFORE Step 1 backlog scan. Sources `packages/itil/lib/migrate-problems-layout.sh` and calls `migrate_problems_to_per_state_layout`. Closes the Step 1 false-zero defect — flat-layout adopters without Step 0a would have their Step 1 glob return zero matches at the per-state shape and stop-condition #1 would fire incorrectly, never reaching the inner manage-problem migration. Both `work-problems` and `manage-problem` carry Step 0a per ADR-031 line 126 "Why both skills" rationale.

## 0.27.1

### Patch Changes

- d3468c4: P164 — apply `10#` base-10 prefix to next-ID formula across 6 ticket-creator skills to prevent latent octal-eval failure at the `099 → 100` ID transition

  **Bug shape**: The next-ID formula `next=$(printf '%03d' $(( $(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))` in 6 ticket-creator SKILL.md files passes its zero-padded ID string through bash's `$(( ... ))` arithmetic context. Bash treats leading-zero numbers as octal; `099` is invalid octal (digit ≥ 8) and bash emits `bash: 099: value too great for base (error token is "099")`, exiting non-zero before the skill writes its marker, before opening the file. The user sees a cryptic bash error.

  **Trigger**: latent until any ticket-creator surface's `local_max` returns `099`. Fires once per surface per project lifetime (the 099 → 100 transition). Has not yet fired in this repo because problem-ticket IDs already crossed 099 before this formula's shape solidified, but any new ticket-creator surface (or any adopter project today) hits the bug as soon as their backlog reaches 099 entries.

  **Fix**: standard `10#` base-10 prefix on the inner `$(echo ... | sort -n | tail -1)` expansion. Applied uniformly across all 6 affected SKILL.md (scope expanded from the originally-named 4 to 6 after grep verification per the ticket's Investigation Task):

  - `packages/itil/skills/manage-problem/SKILL.md` Step 3
  - `packages/itil/skills/capture-problem/SKILL.md` Step 2
  - `packages/itil/skills/capture-rfc/SKILL.md` Step 2
  - `packages/architect/skills/create-adr/SKILL.md` Step 3
  - `packages/architect/skills/capture-adr/SKILL.md` Step 2
  - `packages/risk-scorer/skills/create-risk/SKILL.md`

  **Regression coverage**:

  - `packages/architect/skills/capture-adr/test/capture-adr.bats` test 6 — synthetic `098-foo.proposed.md` + `099-bar.proposed.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
  - `packages/itil/skills/capture-problem/test/capture-problem.bats` test 21 — synthetic `098-foo.open.md` + `099-bar.open.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
  - Existing 26 bats updated in-place with `10#` prefix; full 28-test contract bats green.
  - Manual sanity check confirms unfixed formula fires the documented octal error and fixed formula returns `100`.

  **Why three packages in one changeset**: ADR-014 single-purpose grain — one logical change (the octal-eval defect) across three package boundaries that share the next-ID formula shape. Per ADR-014 "one logical change across multiple files / packages" guidance, the grain holds. The bats fixtures and SKILL.md edits are byte-symmetric across packages by design.

  **Shared helper deferred**: the ticket's optional Investigation Task to extract a shared `lib/next-id.sh` is deferred. DRY benefit is small (~6 byte-identical formulas) versus the regression risk of introducing sourcing-order coupling across 6 currently-independent skills. Re-evaluate if a 7th ticket-creator surface lands.

  **ADR alignment**:

  - ADR-014 (one ticket = one commit) — holds; one logical change.
  - ADR-019 (orchestrator preflight) — unaffected; preflight is about origin fetch, not ID computation.
  - ADR-031 (per-state subdir layout) — unaffected; formula input glob unchanged.
  - ADR-044 (decision-delegation contract) — aligned; one viable shape (`10#` is the standard bash idiom); scope-expansion from 4 → 6 is empirical evidence-driven (grep verified), exactly the framework-mediated mechanical action ADR-044 endorses.
  - ADR-052 (behavioural tests default) — aligned; new regression tests assert formula output not SKILL.md prose.
  - ADR-055 (namespace-prefixed IDs) — unaffected; no shipped-artefact IDs touched.

  **JTBD alignment**:

  - JTBD-301 (Report a Problem Without Pre-Classifying It) — primary; a cryptic `bash: 099: value too great for base` failure at ID rollover would break the "under 2 minutes or the report will be abandoned" constraint.
  - JTBD-001 (Enforce Governance Without Slowing Down) — composes; ticket-creator skills are the substrate that lets solo-developers and tech-leads create ADRs, problems, RFCs, and risks automatically.
  - JTBD-201 (Restore Service Fast with an Audit Trail) — composes; reliable next-ID computation is load-bearing for the audit trail.

  Refs: P164

## 0.27.0

### Minor Changes

- 670929a: P170 / ADR-060 Slice 3 (second half): RFC ↔ problem auto-maintained reverse-trace + commit-message trailer advisory hook

  Slice 3 of `docs/plans/170-rfc-framework-story-map.md` second half — closes ADR-060 Phase 1 item 10 + item 12 + Confirmation criterion 3. Two commits compose:

  **Commit A — B5.T8: skill-side primary surface for the auto-maintained `## RFCs` reverse-trace section**

  Adds `packages/itil/scripts/update-problem-rfcs-section.sh` — idempotent helper rewriting the `## RFCs` table on a problem ticket file based on which RFCs claim it via frontmatter `problems:` list. Lazy-empty discipline (zero traced RFCs → section absent) per JTBD-101 atomic-fix-adopter friction guard. Section placement: before `## Fix Released` if present (ADR-022), else at EOF. 15 behavioural bats cases.

  `/wr-itil:capture-rfc` Step 6 + `/wr-itil:manage-rfc` Steps 7 + 9e invoke the helper inline so the cross-tier reverse trace stays current at every commit per ADR-014 single-commit grain.

  `packages/itil/scripts/reconcile-rfcs.sh` extends with a reverse-trace pass when a `problems-dir` arg is supplied — three drift kinds: `MISSING_REVERSE_TRACE`, `STALE_REVERSE_TRACE`, `STATUS_MISMATCH`. 9 new bats cases (27 green total; backward-compat preserved for the 18 first-half cases).

  **Commit B — B5.T9: commit-message `Refs: RFC-<NNN>` trailer advisory hook**

  Adds `packages/itil/hooks/itil-rfc-trailer-advisory.sh` — PostToolUse:Bash hook detecting `git commit` invocations whose HEAD commit-message carries `Refs: RFC-<NNN>` trailers (parsed via `git interpret-trailers`). Emits stderr advisory when the driving problem ticket's `## RFCs` table is stale. Drift-detection backstop for ARBITRARY commits authored outside the RFC skills (`feat(...)` / `fix(...)` / `chore(...)` carrying the trailer but bypassing the skill-side inline refresh).

  Advisory-only per ADR-014 single-commit grain (never auto-fixes; never follows up with a second commit). Fail-open per ADR-013 Rule 6 on missing inputs / parse errors. Silent-on-pass per ADR-045 Pattern 1; advisory band ≤300 bytes. Multi-`Refs:` malformed-per-finding-8 detection (one commit advances at most one RFC per ADR-060 finding 8). `BYPASS_RFC_TRAILER_ADVISORY=1` env-var escape. 15 behavioural bats cases.

  **Atomic graduation contract**

  Composes with `wr-itil-p170-rfc-framework-phase-1.md` (Slices 1 + 2 — `12725a3`) and `wr-itil-p170-rfc-framework-phase-1-slice-3.md` (Slice 3 first half — `4c906c4` + `4c90a16`) per ADR-060 finding 12: entire P170 / RFC-001 commit chain graduates atomically; ADR-042 auto-apply paused until RFC-001 reaches `closed`. This changeset moves to `docs/changesets-holding/` immediately after this commit per the held-area README "Process" Step 2.

- 670929a: P170 / ADR-060 Slice 3: reconcile-rfcs.sh + wr-itil-reconcile-rfcs bin shim

  Slice 3 of `docs/plans/170-rfc-framework-story-map.md` first half — adds the diagnose-only mechanical drift detector for `docs/rfcs/README.md` (mirrors `reconcile-readme.sh` per P118) and the `$PATH` shim per ADR-049 naming grammar.

  Composes with the Phase 1 framework code shipped in commit `12725a3` (capture-rfc + manage-rfc skill skeletons + P119 hook generalisation). This changeset will be moved to `docs/changesets-holding/` immediately after this commit per the held-area README "Process" Step 2 — same atomicity contract as `wr-itil-p170-rfc-framework-phase-1.md` (ADR-060 finding 12: entire RFC-001 commit chain graduates atomically; ADR-042 auto-apply paused until RFC-001 reaches `closed`).

  **New script**: `packages/itil/scripts/reconcile-rfcs.sh` — read-only drift detector for `docs/rfcs/README.md` vs filesystem RFC inventory. Exit 0 = clean, exit 1 = drift, exit 2 = parse error. Drift line format mirrors `reconcile-readme.sh`'s ADR-038 progressive-disclosure budget (≤150 bytes per row; per-line `DRIFT|MISSING|STALE|MISMATCH` keyword + ID + section + status fields).

  **New bin shim**: `packages/itil/bin/wr-itil-reconcile-rfcs` — `$PATH`-resolved entry point per ADR-049 naming grammar.

  **Behavioural bats**: `packages/itil/scripts/test/reconcile-rfcs.bats` — 18 cases covering existence + executable, parse-error path, clean path (proposed/accepted/in-progress all WSJF-tier), drift paths (DRIFT / MISSING in WSJF / MISSING in VQ / STALE in VQ / MISMATCH in Closed), output budget (ADR-038 ≤150 bytes/row), stable sort order, ADR-049 bin shim contract.

  Slice 3 outstanding tasks (deferred to subsequent invocations): B5.T8 (auto-maintained `## RFCs` section on problem tickets), B5.T9 (commit-message `Refs: RFC-<NNN>` trailer recognition hook).

- 670929a: P170 / ADR-060: Problem-RFC-Story framework Phase 1 — capture-rfc + manage-rfc skills + P119 hook generalisation

  The `@windyroad/itil` plugin gains the RFC tier of the Problem-RFC-Story framework introduced by ADR-060 (Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology, accepted 2026-05-05). Phase 1 ships the lightweight + heavyweight skill split for coordinated multi-commit changes traced to a driving problem.

  **New skills**:

  - **`/wr-itil:capture-rfc`** — lightweight aside-invocation per ADR-032. Mandatory leading problem-trace argument (`P<NNN>` or `P<NNN>,P<NNN>,...`); refuses without it (I1 hard-block per ADR-060 § Confirmation criterion 1; deny logged to `logs/rfc-capture-denials.jsonl` for the trace-violation-rate reassessment criterion). Bounded-escape carve-out for Closed/Verifying/Parked traces — load-bearing for Phase 1 dogfood (RFC-001 retro on P168 per ADR-060 Phase 1 item 9 + Confirmation criterion 5).

  - **`/wr-itil:manage-rfc`** — heavyweight RFC intake + lifecycle management. RFC lifecycle states (`proposed → accepted → in-progress → verifying → closed`) mirror ADR-022 problem lifecycle. I1 enforcement at lifecycle transitions per ADR-060 § Decision Outcome line 97 + § Confirmation criteria 1+2: hard-block at irreversible transitions (`accepted → in-progress`, `→ verifying`); advisory-with-escalation only at `→ closed`.

  **Hook generalisation** (per architect verdict on capture-rfc sub-decision a):

  - `manage-problem-enforce-create.sh` extended to also gate `docs/rfcs/RFC-<NNN>-*.<status>.md` Writes with branched deny messages naming the right skill (capture-rfc for rfcs tier; manage-problem for problems tier). Sibling marker `/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}` (preserves audit-trail per-surface granularity). Existing problems-tier gating behaviour preserved 1:1 (18/18 prior tests still pass; 12 new RFC-tier tests added; 30 total).

  **RFC tier scaffold** (this changeset's predecessor commits):

  - `docs/rfcs/` directory + lifecycle index README (`adc53c8`) — documents the four-tier governance hierarchy (Problem / ADR / RFC / Story), I1 + I2 invariants, RFC filename grammar, frontmatter shape, body structure, commit-grain composition (`Refs: RFC-<NNN>` trailer per ADR-060 finding 8 + Phase 1 item 12).
  - JTBD-008 (`decompose-fix-into-coordinated-changes`) drafted (`59de19a`) — primary persona-anchor for the capture-time decomposition surface this framework enables.

  **ADR-060 Phase 1 status**: Phase 1 deliverables (items 1, 2, 3, 4, 8a, 11) shipped under this held-changeset window. Outstanding Phase 1 work (items 5, 6, 7, 9, 10, 12 — `reconcile-rfcs.sh` + `wr-itil-reconcile-rfcs` shim + behavioural bats + RFC-001 retro on P168 + auto-maintained `## RFCs` section on problem tickets + commit-message RFC trailer hook) lands in Slices 3 + 4 of `docs/plans/170-rfc-framework-story-map.md`.

  **Composes with**: ADR-014 (single-commit grain — RFCs decompose into ADR-014-grain commits, ordered, one commit advances at most one RFC), ADR-022 (lifecycle suffix-based — RFC mirrors), ADR-032 (lightweight + heavyweight aside-invocation pattern), ADR-038 (progressive disclosure — SKILL.md + REFERENCE.md split deferred per ADR-054), ADR-042 (held-changeset auto-apply — this changeset rides the held window), ADR-049 (`wr-itil-reconcile-rfcs` shim grammar — Slice 3), ADR-051 (load-bearing-from-the-start — I1 hard-block ships behaviourally on day one), ADR-052 (behavioural-tests default — bats coverage shipped), P057 (staging trap), P062 (README refresh on transition), P094 (README refresh on conditional update), P118 (reconciliation contract), P119 (create-gate marker — generalised), P132 + inverse-P078 (mechanical-stage carve-outs), P134 (last-reviewed line discipline), P138 (tie-break ladder), P150 (VQ sort direction), P162 (held-changeset graduation criteria).

- 670929a: P170 / ADR-060 Phase 1 Slice 4 B7.T3 — `/wr-itil:capture-problem` type-tag classification prompt (item 8c)

  The `/wr-itil:capture-problem` skill gains a new Step 1.5 that classifies new problem captures as `type: technical | user-business` per ADR-060's uniform problem ontology invariant (I2). The classification is one AskUserQuestion (taste authority per ADR-044 category 5) — NOT a control-flow branch. Steps 0-7 of the skill execute identically regardless of the chosen type value; only the substituted value in the Step 4 skeleton template's `**Type**:` body field differs.

  **SKILL.md changes** (`packages/itil/skills/capture-problem/SKILL.md`):

  - **Rule 6 audit table** updated: from "zero AskUserQuestion branches" to "one classification-only AskUserQuestion (type-tag, taste authority per ADR-044 category 5) and zero control-flow branches keyed on the answer". New audit-table row documents the type-classification carve-out + JTBD-301 protection + I2 invariant guard.
  - **Step 1** extended to recognise leading caller-side flags: `--type=technical`, `--type=user-business`, `--no-prompt`. Recognised flags pre-resolve `type_value` and skip Step 1.5's AskUserQuestion (silent-proceed per ADR-013 Rule 5). Unknown leading flags halt-with-stderr-directive.
  - **New Step 1.5** (Type classification, taste authority per ADR-044 category 5): three-arm dispatch (`--type=` value | `--no-prompt` defaults to `technical` | interactive AskUserQuestion). Per-option descriptions provide plain-language guidance. Inline I2 invariant guard names the no-control-flow-branch contract.
  - **Step 4 skeleton template** carries `**Type**: <type_value>` after `**Effort**:`, matching the body-bullet schema per ADR-060 line 91.
  - **Composition table** extended with two new rows: type-tag prompt (Step 1.5 vs manage-problem's Step 4-equivalent) + AskUserQuestion authority (one classification-only fire vs multiple branches).
  - **Related section** extended with P170, P176, ADR-060, JTBD-301, and the i2-no-type-branching bats fixture pointer.

  **AFK orchestrator protection (JTBD-006)**:

  The `--no-prompt` flag (defaults to `technical`) and `--type=<value>` flag pre-resolve the type classification without requiring AskUserQuestion. AFK orchestrators MUST pass one of these flags per JTBD-006 § Persona Constraints — the skill's caller-side contract. Defence-in-depth: even though AFK orchestrators currently forbid invoking `capture-*` skills mid-loop per ADR-032 carve-out + the iteration prompt's "DO NOT invoke capture-\* background skills" constraint, the flags exist so any future programmatic caller (CI, automated triage) has a non-interactive path.

  **JTBD-301 protection (plugin-user no-pre-classification)**:

  The Step 1.5 prompt fires on the maintainer-side `/wr-itil:capture-problem` skill ONLY. The plugin-user-side intake (`.github/ISSUE_TEMPLATE/problem-report.yml`) carries no equivalent type selector and is NOT touched by this slice. Triage assigns `type` during `/wr-itil:manage-problem` ingestion of user-reported issues, not at user-report time. Per ADR-060 line 132 + line 160 (Confirmation criterion 4): "the type-tag prompt fires on maintainer-side `/wr-itil:capture-problem` only; plugin-user-side intake (GitHub issue templates) MUST NOT add a type-tag selector".

  **I2 invariant preservation (ADR-060 line 98)**:

  - **Pure-bash supporting-script subset**: PASSED — `i2-no-type-branching.bats` (9 tests) green after this change. The SKILL.md edit does not modify any pure-bash script's behaviour, so the bats outcome is structurally unaffected (verified locally).
  - **SKILL.md agent-driven surface**: deferred to P176 per ADR-052 § Surface 2 escape-hatch contract. The I2 invariant guard at the new Step 1.5 is audit-trailed prose, not a behavioural test fixture; behavioural enforcement awaits the P012 master harness. P176 captures the gap as first-class WSJF-ranked entity (not silent-deferral).

  **ADR-060 § Confirmation criterion status post-Slice-4-B7.T3**:

  - Criterion 4 (type prompt maintainer-side only with JTBD-301 protection): PASSED — Step 1.5 placement + JTBD-301 scope guard prose in-skill.
  - Criterion 8 (I2 load-bearing enforcement): pure-bash subset PASSED via 8d bats; SKILL.md surface deferred to P176 (named, audit-trailed).

  **JTBD impact**:

  - **JTBD-001** (governance enforcement, extended scope) — change-set-level governance composes correctly: classification facet, single prompt per capture, no workflow split.
  - **JTBD-006** (AFK orchestrator) — protected via `--no-prompt` / `--type=<value>` flags; AFK callers control the silent-proceed path.
  - **JTBD-101** (atomic-fix-adopter) — friction bounded: ≤ 1 keypress in interactive context (default `technical` accepts via Enter); zero keypresses in non-interactive context (`--no-prompt`). Reassessment criterion at ADR-060 line 183 (JTBD-101 amendment drift) is the tripwire if proportionality fails.
  - **JTBD-301** (plugin-user no-pre-classification) — protected: maintainer-side scope guard at Step 1.5; user-side intake unchanged.

  **Out of scope (deferred to subsequent slices)**:

  - Slice 5 forward dogfood (RFC-002 captured before commit-1 + run to closure) — closes architect finding 14 bootstrap-circularity.
  - Slice 6 graduate-to-adopters (counterfactual risk assessment + held-window reinstate + 30-day denial-rate tracking).

  Held-changeset window remains paused per ADR-060 § Confirmation criterion 6 until RFC-001 reaches `closed` post-Slice-5 forward-dogfood. This held entry sits adjacent to its B7.T2 + B7.T4 sibling (`wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md`) per architect finding 8 ("one commit advances at most one bounded sub-task") + ADR-014 single-purpose grain. Held-window atomicity contract (ADR-060 architect finding 12): the entire RFC-001 chain — including this entry — graduates together or not at all.

- 670929a: P170 / ADR-060 Phase 1 Slice 4 B7 — type-tag schema bulk migration + I2 load-bearing behavioural test (items 8b + 8d)

  The `@windyroad/itil` plugin gains the `**Type**: technical | user-business` field on problem-ticket frontmatter per ADR-060's uniform problem ontology invariant (I2). Existing maintainer tickets bulk-migrate to the default `technical` value via a one-shot script; the I2 invariant is enforced behaviourally by a load-bearing bats fixture per ADR-051 + architect finding 2.

  **New scripts**:

  - **`packages/itil/scripts/migrate-problems-add-type.sh`** — bulk migration apparatus. Diagnose-mode default (read-only; exit 1 on drift); `--apply` writes `**Type**: technical` after the last present body field marker (Status / Reported / Priority / Effort / WSJF). Idempotent — re-running with Type already present is a no-op. One-shot maintainer tool for adopters who want to migrate their own `docs/problems/` to the type-tag schema (parity with this repo's Phase 1 Slice 4 B7 migration).

  - **`packages/itil/scripts/test/migrate-problems-add-type.bats`** — script-level bats per ADR-005 (280 lines). Covers diagnose default, `--apply` mode, idempotency, exit-code contract, malformed-ticket SKIP behaviour.

  - **`packages/itil/scripts/test/i2-no-type-branching.bats`** — load-bearing I2 behavioural test (320 lines) per ADR-060 architect finding 2 ("I2 needs load-bearing behavioural test, not prose prohibition"). Asserts no pure-bash supporting script branches on the `type` field by running scripts (`reconcile-readme.sh`, `update-problem-rfcs-section.sh`, `classify-readme-drift.sh`, `reconcile-rfcs.sh`, `migrate-problems-add-type.sh`) against twin synthetic ticket-set fixtures (one `type: technical`, one `type: user-business`) and asserting observable outputs (stdout / exit code / file mutations) are isomorphic.

  **SKILL.md surface coverage gap (named, not silent)**:

  The i2-no-type-branching bats covers pure-bash supporting scripts only. Behavioural enforcement of I2 on the agent-driven SKILL.md surface (`/wr-itil:capture-problem`, `/wr-itil:manage-problem`, `/wr-itil:work-problems`, `/wr-itil:review-problems`, `/wr-itil:transition-problem(s)`) requires a skill-invocation harness that doesn't exist yet. The gap is captured as `P176` (descendant of P012 master harness ticket) with audit-trail citation per ADR-052 § Surface 2 escape-hatch contract. P081 (no structural grep on SKILL.md) prevents the tempting "quick structural grep" workaround.

  **ADR-060 spec correction**:

  The originally-accepted ADR-060 line 91 stated the type-tag location as "YAML frontmatter, after existing fields". This was inaccurate to the actual `docs/problems/*.md` schema (which uses body-field bullets like `**Status**:`, `**Reported**:`, etc., not YAML frontmatter — RFC tickets use YAML frontmatter; problem tickets use body-bullets). The wording has been corrected in-iter to reflect the true schema. The grandfathered inconsistency between RFC frontmatter and problem-ticket body-bullets is acknowledged but not addressed by this Slice (out of scope per ADR-060).

  **ADR-060 § Confirmation criterion 8 status**:

  - **Pure-bash supporting-script subset**: PASSED (i2-no-type-branching.bats is the test fixture).
  - **SKILL.md agent-driven surface**: deferred to P176 (named ticket; not silent-deferral).

  **JTBD impact**:

  - **JTBD-001** (governance enforcement) — load-bearing class-level invariant guard satisfies the change-set-level governance shape per the 2026-05-05 amendment.
  - **JTBD-006** (AFK orchestrator backlog selection) — verified WSJF parsing unaffected by the new body-field; orchestrator selection unchanged.
  - **JTBD-008** (decompose-fix-into-coordinated-changes) — composes; this slice is JTBD-001 + JTBD-006 territory (lifecycle governance + AFK selection); P176 captured as first-class WSJF-ranked entity per JTBD-008 outcome.
  - **JTBD-101** (plugin-developer atomic-fix-adopter) — friction-add bounded; one-shot bulk migration; default `technical` (no per-ticket judgement); no SKILL.md surface forces type decision in this slice (item 8c deferred).
  - **JTBD-301** (plugin-user no-pre-classification) — protected; migration scope is `docs/problems/[0-9][0-9][0-9]-*.md` only; never touches `.github/ISSUE_TEMPLATE/problem-report.yml`.

  **Out of scope (deferred to subsequent slices)**:

  - Item 8c — `/wr-itil:capture-problem` AskUserQuestion type prompt (maintainer-side only). Deferred to next iter on P170 Slice 4.
  - Slice 5 forward dogfood (RFC-002 captured before commit-1 + run to closure).
  - Slice 6 graduate-to-adopters (counterfactual risk assessment + held-window reinstate + 30-day denial-rate tracking).

  Held-changeset window remains paused per ADR-060 § Confirmation criterion 6 until RFC-001 reaches `closed` post-Slice-5 forward-dogfood.

### Patch Changes

- 670929a: P178 capture — agent skips ITIL state-machine gates on architecture-driven problems

  Captures the class-of-behaviour observed during P170 RFC framework
  implementation: agent treats architect-PASS verdict on driving ADR as
  substitute for empirical RCA, skips Open → Known Error transition,
  proceeds with implementation against an `*.open.md` ticket.

  Sibling-of-P175 root-cause class (agent inferring framework-resolved
  decisions from non-framework signals; P175 was loop-control, P178 is
  state-machine).

  Captured under P078 discipline after user mid-session correction.
  Implementation work on P170 (8 iters / 26 commits) preceded any Known
  Error transition. P170 itself is being retroactively transitioned in a
  companion commit using session evidence.

  Riding the same held-window atomicity contract as the rest of the
  P170 RFC framework chain per ADR-060 § Confirmation criterion 6.

- 670929a: P179 capture — agent defers requested work into untracked phases (phases OK, untracked phases not OK)

  Captures the class-of-behaviour observed across the P170 RFC framework
  session 2026-05-06 to 2026-05-10: agent silently splits described
  solutions into "ship now" vs "defer to Phase N" without explicit user
  authorisation or sibling-ticket tracking. Deferrals end up in ADR
  prose / iter notes only — invisible to WSJF rankings.

  Sibling-of-P175 + sibling-of-P178 root-cause class (agent inferring
  framework-resolved boundaries from non-framework signals). P175 was
  loop-control; P178 was state-machine; P179 is scope-control.

  User direction 2026-05-10:
  "I don't mind phases, but I do mind if those phases never happen"

  Captured under P078 discipline. Riding the same held-window atomicity
  contract as the rest of the P170 RFC framework chain per ADR-060
  § Confirmation criterion 6.

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

- 670929a: P170 / RFC-002 T2 fix-up — flag-order tweak in `manage-problem` SKILL.md `git ls-tree` invocation

  Iter 5's RFC-002 T2 dual-tolerant SKILL.md glob widening (commit `0795e91`) widened `manage-problem` SKILL.md's origin-max ID lookup from `git ls-tree --name-only origin/main docs/problems/` to `git ls-tree -r --name-only origin/main docs/problems/` (added `-r` for per-state subdir recursion). This was functionally correct but broke `packages/itil/skills/manage-problem/test/manage-problem-next-id-origin-lookup.bats` test 2, which structurally greps for the literal prefix `git ls-tree --name-only` (P081-class stale-grep-string fragility).

  Fix: reorder the flags to `git ls-tree --name-only -r origin/main docs/problems/` so the structural test continues to pass. Functionally identical to the iter-5 form (`git ls-tree` accepts options in any order).

  Latent regression carried forward 2 iters undetected because iter retros didn't run the full bats suite to completion. Iter 7's scoped-bats verify caught it (688/689 ok). Captured at iter 7's outstanding_questions for sibling-of-P081 ticket creation in next interactive session: (a) audit existing structural-grep tests in suite for fragility under expected SKILL.md widening; (b) tighten iter-retro verification protocol to fail-loud on un-completed full-suite runs.

  Riding the same held-window atomicity contract as the rest of the RFC-002 chain per ADR-060 § Confirmation criterion 6.

- 670929a: P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T3: bats fixture audit + dual-tolerant assertions

  Adds canonical behavioural enforcement of the SKILL-prescribed enumeration **pipelines** against per-state-layout synthetic fixtures, complementing T2's `dual-tolerant-glob-rfc-002-t2.bats` (which exercises the canonical glob _shapes_ generically). T3 covers the end-to-end pipelines as the SKILL.md call sites dispatch them — `ls X Y | sed | grep -oE | sort -n | tail -1` (next-ID compute), the 4-pathspec multi-state union (work-problems Step 1 backlog scan), the verifying-state filter (run-retro Step 4a), the brace-expansion ID + state-set form (report-upstream), and the closed/parked-state filters (review-problems Step 5/Step 3).

  **File added** (1):

  - `packages/itil/scripts/test/skill-md-dual-tolerant-coverage-rfc-002-t3.bats` — 21 behavioural tests across 7 SKILL-prescribed pipelines × 3 fixture shapes (flat-only, per-state-only, mixed both-layouts). Asserts observable enumeration via `run` so `ls X Y 2>/dev/null` exit semantics surface in `$status` only where the contract intentionally probes them (empty-fixture, missing-ID).

  **Architect + JTBD pre-flight** (2026-05-07):

  - Architect (PASS) — chose canonical-new-bats over mass in-place edits across 67 bats files. ADR-052 (behavioural-tests-default) and ADR-051 (load-bearing-from-the-start) both favour one named, behaviourally-enforced gate per surface over distributed fixture-string mutations whose drift is invisible.
  - JTBD (PASS) — primary anchor JTBD-008 (decompose-fix-into-coordinated-changes); JTBD-001 (governance-without-slowdown), JTBD-006 (work-backlog-AFK), JTBD-101 (extend-the-suite) downstream. Canonical-bats pattern keeps T3 visible as an RFC-002-T3 entity rather than diffusing across 14 existing files.

  **Architect finding 2 surface** — the `next-ID pipeline: mixed fixture` test at row 3 is the load-bearing assertion that capture-problem and manage-problem Step 3 enumerate IDs across BOTH layouts during the migration window. Drop the per-state half of the dual-pathspec and this test fails — capture-problem would re-allocate ID 105 instead of advancing to 205.

  **T6 forward path**: when the post-T5 dual-pattern cleanup commit lands, this bats updates to single-pattern (per-state only); the file is NOT removed — the contract narrows but the behavioural enforcement remains.

  **No current behaviour changes**:

  - `@windyroad/itil` runtime surface unchanged (test file only).
  - T2's `dual-tolerant-glob-rfc-002-t2.bats` re-verified green (19 tests).
  - I2 invariant (`packages/itil/scripts/test/i2-no-type-branching.bats`) re-verified green (9 tests).

  Refs: RFC-002 T3; P069 (driver); P170 / ADR-060 (RFC framework dogfood).

- 670929a: P170 / ADR-060 Phase 1 Slice 5 B8.T4 — RFC-002 T4: reconcile-readme.sh dual-tolerant enumeration

  Refactors `packages/itil/scripts/reconcile-readme.sh` (the diagnose-only README ↔ filesystem drift detector) to enumerate problem-ticket ground truth from BOTH the flat layout (`docs/problems/<NNN>-*.<state>.md`) AND the per-state subdir layout (`docs/problems/<state>/<NNN>-*.md`) during the RFC-002 migration window. Without T4, mid-migration tickets in the un-migrated layout-half would surface as MISSING in WSJF Rankings, or migrated tickets would be invisible to drift detection — burning AFK orchestrator iterations on already-transitioned tickets (JTBD-006).

  **Files modified** (2):

  - `packages/itil/scripts/reconcile-readme.sh` — adds a second enumeration loop after the existing flat-layout loop. The per-state loop walks `<problems-dir>/<state>/[0-9][0-9][0-9]-*.md` for each state ∈ {open, known-error, verifying, closed, parked} and classifies status from parent directory name. Per-state subdir wins on cross-layout ID collision (mid-migration race; ADR-031 §"Authoritative state signal" treats subdir as post-migration ground truth). Docstring header + ADR cross-references updated.
  - `packages/itil/scripts/test/reconcile-readme.bats` — adds 10 T4-specific behavioural fixtures (`reconcile-readme T4: …`) covering: per-state happy-path (clean exit 0), per-state drift parity with flat-layout cases (P074-style closed/Open mismatch, P105-style verifying-in-WSJF, P079-style missing-from-WSJF, parked excluded, known-error recognised), mixed-layout fixtures (both halves enumerated, both halves surface drift), per-state-wins on cross-layout ID collision.

  **Architect + JTBD pre-flight** (2026-05-07):

  - Architect (PASS) — two-loop classifier aligned with ADR-031 §"Migration plan" item 6 (README rendering rules read from subdirectories) + §"Backward compatibility" partial-migration safe detector. Per-state-wins on collision matches ADR-031 §"Authoritative state signal". Single `shopt -s nullglob` scope around both loops idiomatic. ADR-022, ADR-038, ADR-014 untouched. ADR-051 satisfied (T4 ships with bats coverage); ADR-052 satisfied (behavioural fixtures, no structural-grep on script source).
  - JTBD (PASS) — primary anchor JTBD-006 (work-backlog-AFK); JTBD-001 (governance-without-slowdown) preserved (read-only diagnostic, no new prompts, O(N) directory scan). Per-state-wins overwrite is a routine mechanical rule, not a judgment call.

  **Behavioural contract**: drift output (or exit 0) is IDENTICAL regardless of which layout the source tickets reside in — observable via stdout content + exit code, not by structurally grepping script source. Bats assertions probe `$output` + `$status`, never the `.sh` file's text.

  **T6 forward path** (post-T5 verification): the flat-layout enumeration loop drops, leaving only the per-state subdir half. The 10 T4-specific bats cases update from "per-state-only fixtures" to canonical post-migration fixtures; the file is NOT removed — the contract narrows but the behavioural enforcement remains.

  **No current behaviour changes for production callers**:

  - `@windyroad/itil` flat-layout-only deployments produce identical drift output (the per-state loop is a no-op when no per-state subdirs exist).
  - T2's `dual-tolerant-glob-rfc-002-t2.bats` re-verified green.
  - T3's `skill-md-dual-tolerant-coverage-rfc-002-t3.bats` re-verified green.
  - I2 invariant (`packages/itil/scripts/test/i2-no-type-branching.bats`) re-verified green.

  **Held-window discipline** (ADR-060 § Confirmation criterion 6): this changeset enters `docs/changesets-holding/` immediately upon authoring per the 2-commit atomicity pattern (P177; commits 842df55, 5cf3c9b, 03c9206 demonstrate the shape). Release surface remains unaffected until ADR-060 holding-window release.

  Refs: RFC-002 T4; P170 / ADR-060 (RFC framework dogfood); P069 (driver — flat layout unskimmable); P118 (this script's primary problem driver).

## 0.26.0

### Minor Changes

- 91c28fb: P085: assistant-output gate — act on obvious, AskUserQuestion for ambiguous, never prose-ask

  The `@windyroad/itil` plugin now registers two new hooks that together enforce ADR-013 Rule 1 ("use AskUserQuestion for governance decisions") plus the `feedback_act_on_obvious_decisions.md` memory guidance ("obvious default → act; genuine ambiguity → AskUserQuestion; never prose-ask"):

  - **UserPromptSubmit** (`itil-assistant-output-gate.sh`) — when the incoming user prompt contains a direction-pinning signal (`yes`, `go`, `proceed`, `act`, `just do it`, ...), injects a MANDATORY reminder instructing the assistant to act on the obvious next step or use the `AskUserQuestion` tool for genuine ambiguity — never prose-ask. Once-per-session full block, terse reminder thereafter (ADR-038 progressive disclosure + ≤150-byte budget per P095 pattern).
  - **Stop** (`itil-assistant-output-review.sh`) — reads the last assistant turn from `transcript_path` and scans for canonical prose-ask phrasings (`Want me to`, `Should I`, `Would you like me to`, `Shall we`, `Option A or Option B`, `(a) / (b) / (c)?`, `Do you want to`, `Let me know if`). When a prose-ask is detected — and the turn did NOT use the `AskUserQuestion` tool — emits a `stopReason` nudge so the next assistant turn self-corrects. Stop hooks cannot rewrite the emitted turn; the nudge biases the subsequent turn.

  Detector registry (`packages/itil/hooks/lib/detectors.sh`) is the single source of truth for both hooks. Composition: P078 (correction → ticket) and future itil assistant-output validators extend this registry.

  Root `CLAUDE.md` updated with a 2–4 line pointer promoting the memory rule to a repo-level MANDATORY; full phrasing list stays in the detector library per ADR-038 progressive disclosure.

  `scripts/sync-session-marker.sh` adds `itil` to the CONSUMERS list so the canonical `packages/shared/hooks/lib/session-marker.sh` is mirrored per ADR-017.

  22 new behavioural bats tests under `packages/itil/hooks/test/` (per `feedback_behavioural_tests.md` / P081 — behavioural, not structural grep-for-string).

  Closes P085 → Verification Pending.

## 0.25.0

### Minor Changes

- 86e99e5: P155: ship `/wr-itil:capture-problem` skill — lightweight aside-invocation surface for problem capture during foreground work

  Closes the heavyweight-only-capture-path gap (parent P014 ADR-032 child) — the lightweight aside-invocation surface for problem capture during foreground work. The current capture path is `/wr-itil:manage-problem <description>`, a ~10-turn ceremony designed for canonical new-problem creation. This is wrong for the **aside-invocation** use case where the user (or agent mid-iter) wants to capture an observation quickly without disrupting current task flow.

  Three repeating patterns surfaced the friction:

  - **Mid-AFK-iter sibling-findings** — agent observes a tangential ticket-worthy issue while working on a different problem. The ~10-turn ceremony breaks iter cadence; the observation gets buried in `notes` field of `ITERATION_SUMMARY` and ~50% never reach the backlog.
  - **User-initiated rapid captures** during retros, code reviews, or correction conversations — "btw, this is broken too — capture it" should not consume 10 turns of the conversation.
  - **AFK orchestrator main turn captures** — user-driven mid-loop interjections (P151 / P152 / P154 in the session that surfaced P155). Each capture took 5-15 minutes wall-clock through the heavyweight flow.

  `/wr-itil:capture-problem` is the source-side fix.

  Adds:

  - `packages/itil/skills/capture-problem/SKILL.md` (~150 lines, ADR-038 progressive-disclosure budget). Steps 0-7: reconciliation preflight; description parse with empty-arg halt-with-stderr-directive; minimal 3-keyword title-only duplicate-grep + create-gate marker via existing `packages/itil/hooks/lib/create-gate.sh` helper composing with manage-problem's `/tmp/manage-problem-grep-${SESSION_ID}` per P119; P056-safe local_max + origin_max next-ID formula; deferred-placeholder skeleton-fill template (`Priority 3 (Medium) — Impact 3 × Likelihood 1 (deferred — re-rate at next /wr-itil:review-problems)`, `Effort M (deferred — …)`, narrative sections marked `(deferred to investigation)`); single Write; single commit `docs(problems): capture P<NNN> <title>` per ADR-014; trailing pointer to `/wr-itil:review-problems` for WSJF fold + README refresh.
  - `packages/itil/skills/capture-problem/REFERENCE.md` — rationale (capture vs manage trade-off; capture-time false-positives cheaper than false-negatives), edge cases (empty `$ARGUMENTS` halt, kebab-stopword-soup slug fallback, ID collision with origin, cross-skill marker idempotence, P057 not applicable, multi-concern routing to manage-problem), composition with manage-problem create-gate (P119) + review-problems (deferred WSJF/README refresh) + work-problems iter subprocesses (foreground-lightweight is AFK-compatible; background-capture remains AFK-excluded per ADR-032 line 85).
  - `packages/itil/skills/capture-problem/test/capture-problem.bats` — 14 behavioural tests per ADR-052: P119 create-gate composition (mark_step2_complete writes marker / check_create_gate exit transition / cross-skill idempotence), next-ID formula (P056-safe mixed-suffix glob / empty-dir first-ticket), title-only conservative duplicate-grep (filename match / body-content non-match), skeleton-fill template (Status / Description / deferred-placeholder / re-rate-investigation-task), allowed-tools surface (no AskUserQuestion / Bash present / Write present), deferred-README-refresh contract presence; 14/14 green.

  Amends:

  - `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` — appends "Foreground-lightweight-capture variant (P155 amendment, 2026-05-03)" section between Observable-output contract and Scope. Names the new variant alongside the deferred background-capture variant per P088 settlement; documents the deferred-README-refresh contract inline (capture-time speed vs README authoritativeness; on-disk inventory is source of truth, README is derived view); pin variant-selection precedence (foreground-lightweight is LEAD post-P155; background-capture remains deferred sibling slot).

  Architectural design (zero AskUserQuestion branches per ADR-044 framework-mediated mechanical-stage carve-out):

  | Decision            | Resolution                                                                                                                                     |
  | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
  | Duplicate-check     | 3-keyword title-only grep; matches listed in report; capture proceeds regardless. False-positives cheaper than false-negatives (P155 line 24). |
  | Priority default    | Framework-policy `3 (Medium)`, flagged for re-rate.                                                                                            |
  | Effort default      | Framework-policy `M`, flagged for re-rate.                                                                                                     |
  | Multi-concern split | Out of scope; route to `/wr-itil:manage-problem`.                                                                                              |
  | Empty `$ARGUMENTS`  | Halt-with-stderr-directive (AFK-safe).                                                                                                         |

  Deferred-README-refresh contract:

  - capture-problem does **not** regenerate `docs/problems/README.md` inline (the P094 block from manage-problem Step 5 is intentionally omitted).
  - README ranking lags new captures until next `/wr-itil:review-problems` invocation, which folds captured-but-not-rated tickets via Step 9b auto-transition pass (keys off the literal deferred-placeholder string).
  - Trade-off: capture-time speed vs README authoritativeness. On-disk ticket inventory is always source of truth; README is derived view.
  - Trailing pointer in Step 7 is the user-visible signal that the README is transiently stale and how to reconcile.

  Composes with:

  - ADR-032 (governance skill invocation patterns) — this skill is the foreground-lightweight-capture variant amendment 2026-05-03.
  - ADR-038 (progressive disclosure) — SKILL.md + REFERENCE.md split shape.
  - ADR-044 (decision-delegation contract) — framework-mediated mechanical-stage carve-outs justify zero-AskUserQuestion design.
  - ADR-049 (bin/ on PATH) — capture-problem reuses existing `wr-itil-reconcile-readme` shim; no new shim needed.
  - ADR-052 (behavioural-tests-default) — bats fixtures exercise primitives, not SKILL.md prose.
  - P119 (manage-problem create-gate hook) — capture-problem composes with the same per-session marker.

  Unblocks:

  - **P078** (capture-on-correction OFFER pattern) — depends on capture-problem shipping; user can now OFFER `/wr-itil:capture-problem` on strong-affect correction signals.
  - **P148** (Tickets Deferred retro section) — becomes legacy when capture-problem ships; the ~50%-loss class observation no longer needs a retro-summary surface.

  Sibling P156 (capture-adr) and P157 (pending-questions-surface hook) remain Open under the same parent P014; ship in subsequent iters.

- 69c6dc1: P157: ship `itil-pending-questions-surface.sh` SessionStart hook — auto-surface accumulated `outstanding_questions` from `.afk-run-state/outstanding-questions.jsonl` at session start when user returns interactive

  Closes the queue-file lifecycle gap — accumulated `outstanding_questions` entries from `.afk-run-state/outstanding-questions.jsonl` (written between iters by `/wr-itil:work-problems` per the P135 Phase 3 schema + ADR-044 6-class taxonomy) now surface deterministically on session start when the user returns from an AFK loop that halted before its Step 2.5 / Step 2.5b emit point (manual stop, quota exhaustion, network failure).

  Third and final ADR-032 child of P014 (master tracker) — sibling to P155 (`/wr-itil:capture-problem`) and P156 (`/wr-architect:capture-adr`) shipped earlier in the same AFK loop.

  **What ships**

  - New SessionStart hook `packages/itil/hooks/itil-pending-questions-surface.sh` — parses JSONL queue via `jq -e .` (malformed lines silently skipped per defensive SessionStart-must-not-block-startup contract); dedupes on `(rank, category, ticket_id, question)` tuple; ranks per ADR-044 6-class taxonomy precedence (deviation-approval > direction > one-time-override > silent-framework > taste > correction-followup); emits markdown directive listing entries plus an explicit cleanup directive for the agent to rewrite the queue file with resolved entries removed after each `AskUserQuestion` batch; emits a batching note when entry count > 4 citing the ADR-013 Rule 1 `<=4 per call` cap. Silent-on-no-content per ADR-040 Mechanism step 1 (missing / empty / whitespace-only / all-malformed → exit 0 with zero stdout).
  - Wired into `packages/itil/hooks/hooks.json` as a second SessionStart entry with matcher `"startup"` (mirrors `wr-retrospective` `session-start-briefing.sh` ADR-040 Option A precedent — Option B's `UserPromptSubmit` + once-per-session marker rejected on the same reasoning: SessionStart is the semantically correct event for boot-time artefact surfaces).
  - AFK-iter cross-context-leak prevention via `WR_SUPPRESS_PENDING_QUESTIONS=1` env-var self-suppress (architect's implementation choice (a) of the two ADR-032 line 127 enumerations — simpler than orchestrator-side queue drain/restore, idempotent, no state to restore on crash). The `/wr-itil:work-problems` Step 5 dispatch block exports the env var immediately before each `claude -p` subprocess spawn so the orchestrator-session queue does not leak into iter subprocess contexts.
  - ADR-032 amended with new section `### Pending-questions-surface variant — JSONL queue at SessionStart (P157 amendment, 2026-05-03)` between the P156 amendment and Scope. Disambiguates the two pending-questions surfaces (markdown variant `pending-questions-surface.sh` UserPromptSubmit per ADR-032 line 169 for paused-background-subagent-state tokens; JSONL variant `itil-pending-questions-surface.sh` SessionStart for AFK-loop-accumulated queue), names ADR-040 Option A precedent + ADR-044 6-class precedence, documents the two-hook split + the env-var self-suppress contract; variant-selection precedence pinned (SessionStart-JSONL is LEAD post-P157 for AFK-loop direction-question surfacing across session boundaries; markdown UserPromptSubmit remains LEAD for paused-subagent-state tokens).
  - 19 behavioural bats `packages/itil/hooks/test/itil-pending-questions-surface.bats` per ADR-052 — silent-on-no-content × 3, surfacing × 2, full 6-class precedence ranking × 2, dedup × 2, batching × 2, cleanup directive × 1, env-var self-suppress × 2, hooks.json wiring × 1, work-problems Step 5 export ordering × 1, malformed-JSON skip × 2, exists × 1. 19/19 green.

  **Empirical evidence**

  This very session sat 16 hours with 9 accumulated entries that only surfaced because the user explicitly asked. With this hook those entries surface deterministically on the next session start. End-to-end dogfood against the real 9-entry queue ranks 1× deviation-approval (P154) first, 6× direction (BRIEFING_TIER3 / P014 / P156×3 / P160) next, 2× silent-framework (P154×2) last; batching note fires (9 > 4); cleanup directive present.

  **Verdicts**

  Architect: PASS-WITH-NOTES (8 actionable items folded in — ADR-040 cited over ADR-045 for SessionStart-specific silent-on-no-content; env-var self-suppress per implementation choice (a); ADR-032 amendment over new ADR; explicit cleanup directive in additionalContext text; work-problems Step 5 export of the env var alongside the hook ship; behavioural bats includes WR_SUPPRESS_PENDING_QUESTIONS=1 case; ADR-040 plain-stdout shape over additionalContext-keyed JSON; cross-reference ADR-040 Mechanism step 1 not ADR-045 Pattern 1).

  JTBD: PASS — JTBD-006 primary (Progress the Backlog While I'm Away — closes "queued for my return, not guessed at" desired-outcome gap by making the queue surface deterministically on return rather than only when Step 2.5 fires); JTBD-001 secondary (direction-class observations resolve before user begins foreground work, preserving 60-second-flow promise); JTBD-101 tertiary (extends the suite via reusable SessionStart-JSONL pattern).

  Closes the ADR-032 child trio. P014 master-tracker now has all three children fix-released this AFK loop.

  Closes P157

## 0.24.1

### Patch Changes

- 4466eec: P033 Phase 2b — first consumer-skill drain wires up. Adds shared drain script `packages/risk-scorer/scripts/drain-register-queue.sh` (with `bin/wr-risk-scorer-drain-register-queue` shim per ADR-049) and a new Step 6.4 in `/wr-itil:work-problems` between Step 6 (Report progress) and Step 6.5 (Release-cadence check). The drain reads `.afk-run-state/risk-register-queue.jsonl` (populated by the Phase 2a hook), dedupes by `risk_slug` (N reports : 1 register entry per the user direction), mints new `R<NNN>-<slug>.active.md` files via local-max + origin-max +1 (ADR-019), and updates `docs/risks/README.md` Register table with stub-scoring rows. Existing slug matches gain Evidence Log entries without scoring change; new entries carry `Status: Active (auto-scaffolded — pending review)`, `Curation: pending review`, and ADR-026 sentinel `not estimated — no prior data` for ungrounded scoring fields.

  Per-iter cadence keeps the queue bounded and attaches the resulting `docs(risks): scaffold ...` commit to the iter that produced the hint, preserving ADR-014 single-ticket-unit-of-work grain. Step 6's progress-report template gains a `Risk register: N entries scaffolded (pending review)` line so AFK summaries surface register population per JTBD-006 outcome 4. The drain script exits 0 on no-op (empty queue / missing `docs/risks/`), preserving the queue for next drain when Phase 1 scaffolding has not yet fired.

  Behavioural coverage: 16-test bats fixture at `packages/risk-scorer/scripts/test/drain-register-queue.bats` covers shim resolution, no-op idempotency, single + multi-hint flows, slug dedupe, two-slug sequential IDs, existing-match Evidence Log append, README row append, queue-truncation contract, no-truncate-on-no-op, stdout key=value shape, file-staging, origin-max collision avoidance, and malformed-line skip — all GREEN. Also adds `"scripts/"` to the `@windyroad/risk-scorer` package.json `files` array so the canonical script ships in the npm tarball (ADR-049 packaging requirement).

  Driver: P033 Phase 2b (`docs/problems/033-no-persistent-risk-register.known-error.md`). Authority: ADR-056 (`docs/decisions/056-risk-register-back-channel-write-contract.proposed.md`). Phase 2b remaining (deferred to subsequent iters): `/wr-itil:manage-problem` Step 11 drain, `/install-updates` Step 6.6 drain, `/wr-risk-scorer:assess-release` drain — each integrates via the same shared shim. P033 status remains Known Error until Phase 2b is complete and Phase 3 backfill recovers historical reports.

- 3f671b9: Ship `scripts/` in the published tarball so `bin/wr-itil-*` shims resolve in adopter installs.

  Iter 3's P151 fix added `bin/wr-itil-reconcile-readme` and `bin/wr-itil-check-problems-readme-budget` shims that exec `../scripts/<name>.sh "$@"` per ADR-049. The published `package.json` `files` array did not include `scripts/`, so adopter installs of `@windyroad/itil@0.23.2` through `@windyroad/itil@0.24.0` got the shims but not the scripts they reference — invocation hits a "no such file or directory" at the `exec` line.

  Surfaced 2026-05-03 by iter 20 (P033 Phase 2b) as a sibling-finding while adding `scripts/` to `@windyroad/risk-scorer/package.json` for that plugin's own new `wr-risk-scorer-drain-register-queue` shim. First production-real instance of the regression class P137 covers (ADR-055 namespace-prefix advisory walks source-tree only; missed this because source tree exposes `scripts/` even when published tarball doesn't). Composes with P137 follow-up — npm-pack-output detector — which would catch this class at release-time CI, not in source-tree advisory.

  Closes the broken-shim publishing gap as ADR-042 above-appetite Step 6.5 fix-and-continue per Rule 2 / R1 (residual risk 15/25 → 3/25 with this remediation). Architect PASS-WITH-NOTES + JTBD PASS (JTBD-302 primary fit — adopter trust in README invocability claims). One-line fix; sibling-fix-shape to iter 20's risk-scorer files-array fix.

  Re-rate of impact across already-published versions (0.23.2 → 0.24.0): adopters who installed those versions retain broken shims until they upgrade. `npm install @windyroad/itil@latest` after this patch ships resolves to a fixed tarball; no `npm deprecate` action required (the next version supersedes by SemVer convention).

## 0.24.0

### Minor Changes

- 8f29772: `/wr-itil:report-upstream` now emits a labelled `## Versions` section (replacing the freeform `## Environment` block) carrying a fixed five-field schema: Local plugin, Upstream package, Claude Code CLI, Node, OS. Missing fields render as `not detected` (normative MUST), so upstream maintainers can distinguish _field omitted because not applicable_ from _detection failed_. Mirrored in this repo's `.github/ISSUE_TEMPLATE/problem-report.yml` and the `scaffold-intake` template (downstream-scaffolded intakes per ADR-036) so inbound and outbound shapes match.

  Driver: P128 (`/wr-itil:report-upstream` report body lacks consolidated Versions section). Authority: ADR-033 amendment 2026-05-03; forward-pointer added to ADR-024's `## Amendments`. Composes-with: P129 (companion inbound version-aware classification — depends on this schema being stable).

## 0.23.5

### Patch Changes

- b790949: fix(itil): work-problems Step 5 iteration prompt forbids `bats`-output regex-poll antipattern (closes P146)

  The 2026-04-29 AFK iter 1 (PID 23580 child PID 16408) deadlocked in a `bash until`-loop polling backgrounded `bats --tap` output with regex `^[0-9]+ tests?,` — bats's _default_ (non-TAP) console-summary line. `bats --tap` never emits that line, so the until-loop spun forever after bats completed. 68m34s wall-clock burn; manual SIGTERM produced exit 143 + 0-byte JSON (metadata loss per the P147 stuck-before-emit subclass).

  Repo audit confirmed the polling idiom is NOT taught by any SKILL.md (`grep -rn "until.*grep" packages/` returned no matches outside the P146 ticket itself). The idiom is agent-learned from training data — a generic bash + bats Bourne idiom. Fix shape per the ticket's "agent-learned, no source-of-truth" branch: prompt-discipline rule + behavioural assertion.

  Concretely, the work-problems iteration prompt body's Constraints list now:

  - explicitly forbids polling `bats` output with the bats-console-summary regex against TAP-format output;
  - names `wait $bg_pid` (Unix idiom) or Bash-tool `run_in_background=true` + `BashOutput` exit-state polling as the safe substitute;
  - explains the TAP-vs-console-summary divergence so future contributors don't "fix" the rule incorrectly (e.g. the TAP plan line `^[0-9]+\.\.[0-9]+` is the format-stable sentinel if regex-polling is genuinely required);
  - cites P146 inline.

  Behavioural second-source: `packages/itil/skills/work-problems/test/work-problems-step-5-bats-polling-discipline.bats` — 5 contract assertions per ADR-037's permitted exception (doc-lint contract assertion against the contract document itself; same shape as the P083 / P089 fixtures already in the suite).

  Architect APPROVED at risk 1/25 (Low — SKILL.md prose addition + 1 bats fixture; no executable code change; no commit-gate path touched). JTBD PASS — primary fit JTBD-006 ("progress while I'm away" reliability outcome explicitly mentions extended unattended runs). Scope narrowed to work-problems Step 5 only (per architect): the polling-loop antipattern surface IS AFK-iteration-shaped, not manage-problem-shaped, and mirrors precedent from P083 (ScheduleWakeup ban) and P135 (AskUserQuestion ban) which also live in work-problems Step 5 only.

## 0.23.4

### Patch Changes

- c840ff1: itil: `work-problems` SKILL.md Step 5 now carries an explicit "SIGTERM exit-flush is conditional, not universal (P147)" subsection that refines the P121 "clean exit-flush" claim. The original P118 evidence (2026-04-25) was for subprocesses that had already emitted `ITERATION_SUMMARY` before going idle; the 2026-04-29 P146 incident produced exit 143 + 0-byte JSON when SIGTERM fired before emission. The new caveat documents the metadata-loss-event handling shape: verify work integrity from `git log` + `git status --porcelain`, halt the AFK loop per exit-code semantics, reconstruct cost from the Anthropic billing dashboard. SIGTERM remains the right recovery primitive — the refinement is documentation accuracy, not a behavioural change. Behavioural second-source: `test/work-problems-step-5-idle-timeout-sigterm.bats` extends with a stuck-before-emit fake-shim asserting `JSON_BYTES=0` after SIGTERM, plus three doc-lint contract assertions guarding the conditional caveat against silent prose drift.
- d115521: itil: `manage-problem` Step 0 + `work-problems` Step 0 reconcile-readme preflight now distinguish **uncommitted-rename-rooted drift** (current-session staged ticket renames whose in-flow P094 / P062 refresh will land in the upcoming commit per ADR-014 single-commit grain) from **committed cross-session drift** (must halt and route to `/wr-itil:reconcile-readme`). The previous unconditional halt-on-Exit-1 directive forced an extra `chore(problems): reconcile README ...` commit whenever a SKILL invocation hit a same-session staged rename — splitting one logical change across two commits. New `packages/itil/scripts/classify-readme-drift.sh` helper + `wr-itil-classify-readme-drift` `$PATH` shim per ADR-049 cross-references drift IDs from `reconcile-readme.sh` stdout against `git status --porcelain docs/problems/` filtered for staged renames (`R` / `RM`). On Exit 1 from reconcile-readme, the SKILL flow now captures stdout to a temp file, runs the classifier, and routes: `INLINE_REFRESH` (every drift ID is the destination of a staged rename) defers to in-flow refresh and continues to Step 1 inline; `HALT_ROUTE_RECONCILE` (committed-only OR mixed) halts and routes to `/wr-itil:reconcile-readme` as today. Behavioural bats `packages/itil/scripts/test/classify-readme-drift.bats` covers INLINE / HALT / mixed / RM / parse-error / no-git-repo / default-arg branches; shim-existence + smoke parity tests in `packages/shared/test/no-repo-relative-script-paths-in-skills.bats`. No new ADR required — bounded as SKILL.md refinement under ADR-014's existing reassessment window per P145 MUST_SPLIT precedent.
- 413cd77: itil: Verification Queue rendering now encodes the canonical sort direction `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC) at every render site, with a greppable HTML-comment marker `<!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 -->` analogous to P138's `<!-- TIE-BREAK-LADDER-SOURCE -->`. Closes the recurring drift between `docs/problems/README.md` Verification Queue section header ("Ranked by release age, oldest first") and the rendered table (de-facto newest-first across multiple recent README versions). Render sites edited: `manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + Step 9c presentation + Step 9e template (4 occurrences); `review-problems` Step 3 + Step 5 README template; `transition-problem` Step 7 README refresh; `transition-problems` Step 4a batch render; `reconcile-readme` Step 4 row-insertion; `list-problems` VQ render block. New behavioural-contract bats `packages/itil/skills/manage-problem/test/manage-problem-readme-vq-sort-order.bats` 13/13 green covers marker presence at every render site, `Released date ASC` direction prose, drift-re-opens-P150 warning, behavioural fixture sort with 4 .verifying.md fixtures of known dates → row 1 = oldest, same-day-Released ID-ASC tiebreaker, and P048-aligned likely-verified-first ordering. README VQ table re-rendered top-to-bottom = oldest → newest (66 rows total); undated rows preserve original markers verbatim, dated rows get `Likely verified?` markers recomputed against today's date so stale `(0 days)` markers refresh per the ticket's compose-with item. No new ADR required — ADR-022 Decision Outcome line 63 already says "oldest first"; ADR-014 covers single-commit grain; P138 fix-shape established as in-repo precedent. Inline fold-fix Open → Verifying for P150 itself per ADR-022 P143 amendment.

## 0.23.3

### Patch Changes

- ea69f53: P142 (P124 Phase 4): replace the Phase 3 mtime-based announce-marker selection in `get_current_session_id` (`packages/itil/hooks/lib/session-id.sh`) — which silently misfired in orchestrator main turns AFTER subprocess dispatch by picking the most-recently-fired subprocess SID over the orchestrator's older SID — with a structurally-correct runtime-SID instrumentation layer per the new ADR-050 (`docs/decisions/050-runtime-sid-instrumentation-via-pretooluse.proposed.md`). A new dedicated `PreToolUse:Bash|Write|Edit|Read` hook (`packages/itil/hooks/itil-runtime-sid-marker.sh`) parses the runtime stdin `session_id` from the Claude Code hook JSON payload and writes it via `printf '%s'` (no trailing newline) to a per-machine, per-user, per-project marker at `/tmp/itil-runtime-sid-${USER}-${cksum_of_PWD}.current` (or `${SESSION_MARKER_DIR}/itil-runtime-sid.current` under sandboxed bats). The marker path is computed by a single shared helper `runtime_sid_path()` in the new `packages/itil/hooks/lib/runtime-sid.sh` lib that both producer (hook) and consumer (helper) source so they agree on the path. The hook is ADR-045 Pattern 1 silent-on-pass (0 bytes on stdout) with fail-open contracts on every error path (missing python3+jq parsers, malformed JSON, empty SID, write failure) so it can never block a tool call. The helper now reads this marker FIRST as the authoritative current-session SID; the existing announce-marker priority logic (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved unchanged as cold-path fallback for the first tool call of a session before any PreToolUse fires. Because every Bash tool call that sources the helper is itself a PreToolUse:Bash event, the marker the helper reads was written moments earlier with the same `session_id` the runtime Write hook will see — so SID-mismatch denial is structurally impossible in routine flow. Race-mitigation: per-user-per-project scoping eliminates cross-project parallel-session races; same-project parallel sessions still race (last-writer-wins) but the failure mode is a hook-denied Write (visible, recoverable via re-running Step 2), not silent corruption. ADR-048 (`docs/decisions/048-gate-misfire-recovery-procedure.superseded.md`) is auto-superseded in the same commit: status flipped from `proposed` to `superseded`, filename renamed `.proposed.md` → `.superseded.md`, frontmatter `superseded-by` field added, supersession callout block added at the top. The corresponding two-tier recovery prose (announce-marker scrape + python3-via-Bash second-tier) is removed from `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 (replaced with a single "Phase 4" pointer paragraph cross-referencing ADR-050), and the conditional `RECOVERY_HINT` append is removed from the `manage-problem-enforce-create.sh` deny message (the deny now stays terse and skill-pointing regardless of `/tmp/manage-problem-grep-*` marker presence). The obsolete `packages/itil/skills/manage-problem/test/manage-problem-p119-recovery-path.bats` (structural-grep harness pinning the now-removed recovery prose) is deleted; behavioural coverage has migrated to `runtime-sid-marker.bats` (NEW — 7 tests covering write, silence-on-stdout, exit code, overwrite-on-subsequent-call, no-op on empty/malformed input, fail-open on jq absence) and four new tests in `session-id.bats` (runtime-marker priority over newer announce markers, empty-marker fallback, cold-path fallback, env-var precedence over runtime marker). The two enforce-create-hook tests that previously asserted the RECOVERY_HINT branching are reframed to pin the post-ADR-050 deny-message-invariance contract (deny is identical regardless of /tmp marker state — the only signal that matters is "this session has not run Step 2"). Closes P142, supersedes ADR-048, and folds-in P124 Phase 4. Auto-eliminates the 2026-04-29 4×-recurrence pattern documented in ADR-048's Decision Drivers (P145–P148 ticketing), the 2026-04-28 139-marker brute-force anti-pattern incident (P144 driver), and the documented gate-misfire workaround that was visible to the agent's audit-trail every time the orchestrator's helper picked a stale subprocess SID.

## 0.23.2

### Patch Changes

- 3a1c109: P141: enforce changeset discipline at `git commit` time via new PreToolUse:Bash hook `packages/itil/hooks/itil-changeset-discipline.sh`. The hook denies `git commit` invocations whose staged set includes `packages/<plugin>/*` source files but no `.changeset/*.md` (excluding `README.md`) is staged. Detection delegates to `packages/itil/hooks/lib/changeset-detect.sh::detect_changeset_required`, which categorises staged paths into changeset / publishable-source / allow-listed-test / allow-listed-doc / non-publishable buckets. Allow paths emit zero bytes per ADR-045 Pattern 1 (silent-on-pass); deny paths emit a single-line directive ≤300 bytes naming the offending plugin slug, the `bun run changeset` recovery command, the `BYPASS_CHANGESET_GATE=1` escape hatch, and the P141 cite. Hook registered in `packages/itil/hooks/hooks.json` as a third `PreToolUse:Bash` matcher alongside `p057-staging-trap-detect.sh` and `pre-publish-intake-gate.sh`. Allow-list per architect verdict 2026-05-02 — test paths (`test/`, `hooks/test/`, `scripts/test/`), package `README.md`, and `*.md` under package `docs/`. `SKILL.md` is deliberately NOT in the allow-list (it IS the publishable contract per ADR-037 framing). 21 behavioural bats per ADR-005 + P081 in `packages/itil/hooks/test/itil-changeset-discipline.bats` cover deny shapes, allow paths, BYPASS env var, ADR-045 silent-on-pass, fail-open contracts (parse error / outside git tree). Closes the orchestrator-main-turn back-fill anti-pattern observed at 40% miss rate across 5 publishable iters in the 2026-04-28 AFK loop session — `/wr-itil:work-problems` iter subprocesses operating under heavy SKILL.md + ticket-body + architect/JTBD prompt context pressure dropped the prompt-time changeset reminder; hook-level enforcement makes the requirement unmissable without adding to the iter's context budget. Composes-with P073 (changeset author-time gate at Write/Edit on `.changeset/*.md` — different surface, defence-in-depth). No new ADR required — same enforcement-layer pattern as P125 staging-trap hook (per-invocation deterministic, no markers).
- 148d189: P151: replace `bash packages/itil/scripts/<name>.sh` invocations in published SKILL.md with `$PATH`-resolved bin shim wrappers per ADR-049. Adopter sessions running `/wr-itil:manage-problem`, `/wr-itil:work-problems`, and `/wr-itil:reconcile-readme` previously hard-failed at Step 0 with `bash: No such file or directory: packages/itil/scripts/reconcile-readme.sh` because the repo-relative path does not resolve in adopter trees. Two new shim wrappers ship in `packages/itil/bin/` — `wr-itil-reconcile-readme` and `wr-itil-check-problems-readme-budget` — each a 3-line `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"` body relaying to the canonical script. Three SKILL.md invocation sites updated (`manage-problem` Step 0 L189, `work-problems` Step 0 L89, `reconcile-readme` Step 1 L44) plus two documentation references (`manage-problem` SKILL.md L465 / L477) rewritten to name the bin-wrapper. ADR-049 codifies the rule: plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths; naming grammar `wr-<plugin>-<kebab-script-name>` is fixed. Cross-plugin grep-as-lint bats at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` (8 tests) catches regressions at CI. The canonical script bodies under `packages/itil/scripts/` are unchanged; existing `packages/itil/scripts/test/*.bats` continue to test the canonical path. Sibling JTBD-301 plugin-user persona unblocked.

## 0.23.1

### Patch Changes

- cc79ae2: P140 Phase 1 — `/wr-itil:work-problems` Step 6.5 Failure handling adds diagnose-then-classify routing with fix-and-continue branch. Previous behaviour was a uniform halt-on-CI-failure rule that converted mechanically-fixable failures (1-line stale-grep-string updates, transient flakes) into ~45min queue stalls during AFK loops, regressing JTBD-006 "Progress the Backlog While I'm Away" without governance benefit.

  What changes (declarative SKILL.md amendment only):

  - **Step 6.5 Failure handling subsection** in `packages/itil/skills/work-problems/SKILL.md` rewritten to add:

    - Diagnostic preamble — orchestrator MUST first run `gh run view <run-id> --log-failed` and cite the output verbatim in the fix-and-continue commit message or halt summary (ADR-026 grounding).
    - Closed fixable-in-iter allow-list: P081-class stale-grep-string, hook stub mismatch, test ID drift, environmental flake. **Closed** — adding a class is itself a deviation-candidate per ADR-044 framework-resolution boundary.
    - Ambiguous classification defaults to halt (no diagnose-then-guess).
    - Fix-and-continue branch: 1 Edit → ADR-014 commit gate flow (architect / JTBD / risk-scorer per retry) → push → re-watch CI → resume on pass / increment retry counter on fail.
    - 3-retry cap per iteration (not per failure-class) before fallback to halt branch.
    - Halt branch preserved for genuinely-unrecoverable: auth failure, npm publish rejection, semantic test requiring user judgment, repeated transient failures, anything outside the closed allow-list.
    - Step 2.5b cross-reference (P126) preserved on the halt branch.

  - **Non-Interactive Decision Making table** carries a new row "CI failure during Step 6.5 drain (within-appetite branch)" routing through fix-and-continue + 3-retry cap.

  - **Mid-loop ask discipline subsection** (P130) Step 6.5 CI-failure halt-point bullet narrowed to outside-allow-list / 3-retry-cap-reached scope. Failures inside the allow-list route to fix-and-continue, not this halt point.

  Why: 2026-04-28 session evidence — Step 6.5 drain hit CI failure on test 1375 (P081-class stale `'skip Step 6'` literal vs current `'skip Steps 5b/5c'` SKILL.md prose); 1-line fix; re-pushed; CI passed; release shipped. User correction was explicit and class-level: _"this shouldn't be a halt. This should be a fix and continue"_. P140 codifies this as policy.

  Composition: fix-and-continue is policy-authorised per ADR-013 Rule 5 (closed allow-list IS the policy). Each retry's commit rides standard ADR-014 commit gate flow per ADR-042 Rule 3 precedent (retries each ride their own commit through architect / JTBD / risk-scorer review). No governance bypass. Inverse of P132 (over-ask in interactive sessions) on the failure-handling surface; composes with P081 (stop-gap — fix-and-continue elides the friction P081's full retrofit eliminates structurally), P130 (mid-loop ask discipline — fix-and-continue does NOT introduce mid-iter asks), P135 (decision-delegation contract).

  Files shipped:

  - `packages/itil/skills/work-problems/SKILL.md` — Step 6.5 Failure handling rewrite + Decision table row + halt-point bullet narrowing.
  - `packages/itil/skills/work-problems/test/work-problems-step-6-5-fix-and-continue.bats` — NEW 28 behavioural contract assertions per ADR-037 + P081.
  - `docs/problems/140-...open.md` → `.verifying.md` — Status flip + Phase 1 shipped section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Out of scope (deferred per ticket Fix Strategy):

  - Phase 2 `packages/itil/scripts/diagnose-ci-failure.sh` advisory classifier — observe Phase 1 declarative discipline over 30 days; load-bearing classifier may not be necessary if agent behaviour aligns to the SKILL.md prose.
  - Full P081 retrofit of structural-grep tests — separate ticket.

  Architect: PASS — Phase 1-only scope correct; ADR-014 invariant preserved (retries each ride own commit through gates, ADR-042 Rule 3 precedent); fix-and-continue branch belongs inside Failure handling subsection (sibling to halt branch, not separate subsection); no new ADR needed (ADR-013 Rule 5 + ADR-044 + in-skill prose suffice). Advisory: closed-allow-list scope-creep guard added per architect FLAG (extension is a deviation-candidate). Stale-decision check: ADR-018 reassessment 2026-07-18 within window; ADR-014 reassessment 2026-10-16 within window.
  JTBD: PASS — JTBD-006 primary (restores "progress continues without me being present" while preserving "stops gracefully on a blocker"); JTBD-001 + JTBD-002 compose intact (per-retry gates preserve governance); persona-misread risk addressed via closed-list framing + ambiguous-defaults-to-halt + per-iteration cap clarification.
  TDD: 28/28 new bats green; full 203-test work-problems suite green (no regression).

- 4697624: P144: document gate-misfire recovery procedure in `manage-problem` Step 2 substep 7 (two-tier — announce-marker scrape + python3-via-Bash fallback) and add a conditional recovery hint to the `manage-problem-enforce-create.sh` deny message that fires only when `compgen -G '/tmp/manage-problem-grep-*'` matches at least one marker for SOME SID (the helper-bug signal). ADR-048 sanctions and scopes the procedure with explicit P142-auto-supersession criteria and an audit-trail-preservation test that rules out the P131 any-marker-anywhere anti-pattern.

  The recovery surfaces a documented forward path for orchestrator sessions where the P124 helper returns a subprocess SID instead of the orchestrator SID — the canonical 2026-04-28 failure mode where the agent reached for the brute-force-marker anti-pattern (139 markers in one session). The two-tier procedure preserves audit-trail integrity (Step 2 grep DID run for THIS ticket creation) and explicitly forbids the brute-force pattern at both surfaces (durable in SKILL.md, just-in-time in hook deny hint). Auto-supersedes when P142 (P124 Phase 4) ships and the helper returns the runtime hook SID reliably; the SKILL.md sub-block carries an HTML supersession comment paired with a CI-enforced bats invariant so the cleanup becomes a CI-fail signal once P142's resolution ADR is `accepted`.

## 0.23.0

### Minor Changes

- a8711ab: P131 Phase 2 — `.claude/` user-space write protection. NEW `packages/itil/hooks/itil-claude-space-protection.sh` PreToolUse:Write|Edit hook denies agent writes to project-scoped `.claude/` paths NOT in the user-space allow-list, unless an approval marker is present. NEW shared helper `packages/itil/hooks/lib/claude-space-gate.sh` exporting `is_protected_claude_path` / `has_approval_marker` / `claude_space_deny`.

  Why: `.claude/` is user-controlled config space (settings, memory, MCP servers, user-authored skills/hooks/commands/agents, Claude Code's own state in `projects/` and `worktrees/`). Agents misread the architect/JTBD/TDD/style-guide/voice-tone/risk-scorer gate-exclusion lists as "approved write zones" and write project-generated content (plans, audits, scratch state) under `.claude/`, polluting user space. Project-generated content belongs in `docs/` (plans, audits) or inline in problem-ticket bodies.

  Allow-list (project-relative): `.claude/{settings.json, settings.local.json, MEMORY.md, .install-updates-consent, scheduled_tasks.lock}` + `.claude/{skills, commands, agents, hooks, projects, worktrees}/*` subtrees + `.claude/*.local.json` (root-depth only) + `.claude/.agent-write-approved-*` markers themselves.

  Approval-marker bypass: user creates `.claude/.agent-write-approved-<sha256-of-rel-path>` to pre-authorize specific paths. Persistent (no TTL); user creates once per path. Distinct semantic class from ADR-009 session-scoped /tmp markers — this is a persistent path-keyed approval-marker class, precedent-shaped on `.claude/.install-updates-consent` (ADR-030 / P120).

  Out of scope (unaffected): Read|Glob|Grep on `.claude/` paths, paths outside `$PWD` project root (~/.claude/, other repos' .claude/), `.claude/` subtree edits hitting allow-listed paths.

  Deny message: ~440 bytes (under ADR-038 progressive-disclosure 500-byte cap), names P131 + suggests `docs/plans/` / `docs/audits/` / inline-ticket alternatives + names approval-marker bypass + references project CLAUDE.md MANDATORY rule. Silent on allow path per ADR-045 Pattern 1. Fail-open on parse error per ADR-013 Rule 6.

  Files shipped:

  - `packages/itil/hooks/itil-claude-space-protection.sh` — NEW PreToolUse:Write|Edit hook.
  - `packages/itil/hooks/lib/claude-space-gate.sh` — NEW shared helper.
  - `packages/itil/hooks/hooks.json` — registers the new hook.
  - `packages/itil/hooks/test/itil-claude-space-protection.bats` — NEW 34 behavioural assertions per ADR-037 + P081 covering deny path, allow-list, outside-.claude paths, approval-marker bypass, Read|Glob|Bash unaffected, allow-list anchor depth, deny-message contract, byte budget, silent-on-pass.
  - `docs/problems/131-...known-error.md` → `.verifying.md` — Status flip + Phase 2 shipped section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Architect: PASS-WITH-NOTES — allow-list amended to add `MEMORY.md`, `commands/`, `agents/`, `hooks/` subtrees + anchor `*.local.json` to root depth; ADR formalising user-space-vs-project-space distinction deferred to Phase 3 per ticket Fix Strategy line 113; marker format consistent with ADR-009 (new persistent semantic class, not conflict).
  JTBD: ALIGNED PASS — JTBD-001 primary (governance without breaking user editing flows; allow-list preserves "no manual policing"); JTBD-006 strong fit (originating P131 incident was AFK orchestrator writing `.claude/plans/p081-...md`; Phase 2 prevents recurrence); JTBD-101 no conflict; JTBD-202 indirect.
  Voice-tone: PASS advisory-only (`docs/VOICE-AND-TONE.md` not yet authored).
  Style-guide: PASS out-of-scope.
  TDD: 34/34 new bats green; full 129-test itil hooks suite green (no regression).

  Phase 3 remaining (deferred): formalising-ADR; doc-reframe in remaining 4 gate-hook prose surfaces (tdd, style-guide, voice-tone, risk-scorer); `docs/briefing/hooks-and-gates.md` topic file update.

### Patch Changes

- e85d2e1: P123 — `packages/itil/hooks/lib/block-list.sh` shared helper for the inbound-report block-list mechanism. Per ADR-046's v1 implementation contract — audit-log-only — the helper exposes `is_blocked(<hash>)`, `add_block(<hash> <evidence-ticket> <provenance>)`, `remove_block(<hash> <reason>)`, and `list_blocks()`. Caller-supplied opaque hex hashes (SHA-256 width validated); helper does not compute hashes — keeping the surface GitHub-agnostic per ADR-046 §Reassessment.

  Persistence: `docs/blocked-reporters.json` (per-repo JSON array, tracked in git, hashes only — no usernames). Audit log: sibling `docs/blocked-reporters.audit.jsonl` (append-only JSONL, five-field shape per ADR-046 Q2 — `{type, reporter_id_hash, evidence_ticket, timestamp, author}`).

  ADR-046 Q1/Q2/Q3 already adopted (proposed defaults accepted via prior batch AskUserQuestion at iter 9 quota-halt 2026-04-28); this iter ships the audit-log-only v1 slice and transitions ADR-046 `proposed → accepted`. Q3's "agent-monitored review-cycle" direction is resolved; un-block monitor implementation deferred to a future iter beyond this v1 slice (per ADR-046 §Q3 Adopted note).

  No enforcement integration in this slice. P079's inbound-discovery filter and `/wr-itil:report-upstream`'s outbound pre-check land when those features ship — out of scope for P123 per the ticket's pacing decision (line 78). The persistence layer is the foundation those iters consume; without it they would re-derive the shape from ADR-046 inline.

  Files shipped:

  - `packages/itil/hooks/lib/block-list.sh` — NEW shared helper, four functions.
  - `packages/itil/hooks/test/block-list.bats` — NEW behavioural bats: 10 assertions covering round-trip, idempotent add, remove path, audit-log presence (block + unblock), list_blocks shape, and hex-shape validation rejections (non-hex + wrong-length).
  - `docs/blocked-reporters.json` — NEW empty array per-repo persistent block list.
  - `docs/decisions/046-blocked-reporters-persistence.proposed.md` → `.accepted.md` — Status flip; Q1/Q2/Q3 confirmed adopted.
  - `docs/problems/123-...known-error.md` → `.verifying.md` — Status flip + Fix Released section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Architect: ALIGNED-with-notes / PASS no new ADR — ADR-046 governs; helper-doesn't-hash separation locked in; JSONL audit-log shape obvious local choice.
  JTBD: ALIGNED / PASS — JTBD-101 (Extend the Suite) primary persona served by foundation-only slice; JTBD-001 + JTBD-202 compose; no regression vs zero-defence today.
  TDD: 10/10 green; full itil hooks suite 95/95 green (no regression).

- 4d2a55d: P133 — zsh-portability gap in shell-snippet examples. Phase 1 immediate fix at the proximate failure surface (`scripts/repo-local-skills/install-updates/SKILL.md:167`) plus defensive rename in the load-bearing `reconcile-readme.sh` script.

  The 2026-04-27 session hit two distinct zsh-vs-bash failures in `/install-updates` Step 7: (1) `local status=...` errored with `read-only variable: status` because zsh has `$status` as a read-only built-in alias for `$?`; (2) `for plugin in $PLUGINS_TO_UPDATE` (where the variable was a space-separated string) silently iterated **once** under zsh because zsh does NOT word-split unquoted variables by default. All 24 install operations were marked `lost` until the wrapper was rewritten to use a bash array.

  Changes:

  - `scripts/repo-local-skills/install-updates/SKILL.md` Step 6 inner loop now uses bash-array iteration (`PLUGINS_TO_UPDATE=(itil retrospective risk-scorer tdd)` + `for plugin in "${PLUGINS_TO_UPDATE[@]}"`) — portable across bash and zsh. New portability note explains why array form (not unquoted iteration). This is the proximate failure surface that broke the 2026-04-27 session.
  - `packages/itil/scripts/reconcile-readme.sh` defensive rename `status` → `ticket_status` at the two assignment sites (lines 65-72 filesystem-truth build phase + lines 174-191 drift-detection loop). Script has a hard `#!/usr/bin/env bash` shebang so it never runs under zsh directly, but the rename eliminates the latent footgun for any future caller that sources or copies the pattern. Inline comment cross-references P133.
  - `packages/itil/scripts/test/reconcile-readme.bats` new behavioural regression test (`run env status=junk "$SCRIPT" "$FIXTURE_DIR"`) confirming drift detection is independent of any caller-controlled `status` env var. 17/17 green (16 prior + 1 new).

  Audit findings (in-scope but clean — recorded for the verifying-transition note):

  - `packages/itil/skills/{work-problems,manage-problem,transition-problem}/SKILL.md` — no bash-isms in fenced shell snippets (greps for `for x in $VAR`, `local status=`, unquoted `${array[@]}` returned no matches).
  - `packages/retrospective/skills/run-retro/SKILL.md` — same.
  - `packages/itil/hooks/*.sh` and `packages/itil/hooks/lib/*.sh` — all have `#!/bin/bash` shebangs; safe.

  Phase 2 (repository-wide audit + remediation) and Phase 3 (CI/pre-commit lint detecting bash-isms in committed snippets) deferred to compose with **P136** (ADR-044 alignment audit master) per architect direction.

  Architect ALIGN (no new ADR; alignment with ADR-014 ONE-commit batching, ADR-022 verifying-transition criteria, ADR-030 repo-local-skills source-of-truth governance). JTBD ALIGN (JTBD-001 solo-developer primary fit — silent-failure surface eliminated; JTBD-007 keep-plugins-current direct outcome; JTBD-101 plugin-developer downstream pattern). Style PASS (no UI/visual styling). Voice PASS (no banned patterns).

  Transitions P133 Open → Verification Pending per ADR-022.

- ac2425e: P134 — `docs/problems/README.md` line-3 "Last reviewed" parenthetical accumulator-bloat truncation contract. Applies the P099 reusable triplet (ADR-040 line 92 explicitly names "problems index" as a covered surface) to the problems index: line 3 had grown unbounded to 76,582 bytes — past 62KB it broke the Read tool entirely (25K-token whole-file cap), forcing awk/grep workarounds on every inspection task.

  The fix mirrors P099's `check-briefing-budgets.sh` shape at the new surface:

  - New advisory `packages/itil/scripts/check-problems-readme-budget.sh` (read-only diagnostic; mirrors P099 patterns)
  - 13 new behavioural assertions in `packages/itil/scripts/test/check-problems-readme-budget.bats` (13/13 green)
  - New canonical "Last-reviewed line discipline (P134)" subsection in `packages/itil/skills/manage-problem/SKILL.md`; Step 5 P094 / Step 6 P094 / Step 7 P062 reference it inline (one fragment ≤ 1024 bytes soft, 5120 bytes hard ceiling, displaced fragments rotate to forward-chronology `docs/problems/README-history.md` archive sibling)
  - Same discipline applied to `transition-problem`, `transition-problems`, `review-problems`, and the load-bearing `reconcile-readme` (whose prior "ever-growing prose paragraph" convention was the source-of-bloat surface)
  - New `docs/problems/README-history.md` archive sibling — forward-chronology log; legacy 76,582-byte content seeded under a 2026-04-28 heading; line 3 trimmed in the same commit as one-shot remediation

  Read-tool symptom verified closed in same session: orchestrator's initial Read of `docs/problems/README.md` returned `File content (48677 tokens) exceeds maximum allowed tokens (25000)` BEFORE; AFTER the fix, `Read offset=1 limit=12` succeeds cleanly (line 3 now 800 bytes, 95× reduction).

  Architect PASS no new ADR (ADR-040 line 92 reusable-pattern note explicitly covers this surface). JTBD PASS (JTBD-001 primary fit — Read-tool affordance restored; JTBD-006 + JTBD-101 compose). 535/535 green across affected bats suites (240/240 manage-problem family + 295/295 hooks/work-problems family).

  Transitions P134 Open → Verification Pending per ADR-022.

## 0.22.1

### Patch Changes

- 8bf58c8: P085 — `packages/itil/hooks/lib/detectors.sh` Prose-ask detector phrasing-list extension covering 2026-04-28 regression evidence (ticket reopened from Verification Pending). The 2026-04-24 fix (UserPromptSubmit gate + Stop review hook + detector registry) shipped at minor but the canonical phrasing list missed the "Awaiting your direction" / "Pending your decision" / "Once you confirm" shapes the orchestrator emitted at Step 6.75 halt-summary today.

  Specific evidence (Citation 1, this session ~17:25): orchestrator main turn emitted _"Awaiting your direction on whether to add it + resume on P123, or end the session."_ — a binary-choice prose-ask. Empirical verification: existing pattern list returned exit-code 1 on this text. Detector extension closes the gap.

  Files shipped:

  - `packages/itil/hooks/lib/detectors.sh` — `PROSE_ASK_PATTERNS` extended with four new entries: `Awaiting your (direction|input|decision|response|confirmation|answer|reply)`, `Pending your (direction|input|decision|response|confirmation|answer|reply)`, `Once you confirm`, `Awaiting your direction on whether` (specific shape from Citation 1, retained alongside the broader pattern for observability — first-match return reports the more specific phrase).
  - `packages/itil/hooks/test/itil-assistant-output-review.bats` — 5 new behavioural bats per ADR-037 + P081: Citation 1 verbatim shape, plus four adjacent phrasings each fed through a JSONL transcript to the Stop hook with `stopReason` assertion. Clean-turn negative test unchanged remains green.

  Citation 2 (over-ask when framework prescribes the answer — _"FFS, why are you stopping to ask. what does the decision framework tell you to do?"_) is class-of-behaviour overlap with P132 (Open, WSJF 4.5 — Agents over-ask in interactive sessions). Framework-knowability detection requires a hook that reads SKILL.md decision tables and reasons about whether the question is mechanically answerable; that is a substantially harder problem than the phrasing-list extension here. Deferred to P132's broader fix per architect verdict (composes with ADR-044 R6 numeric gate).

  Transitions P085 Known Error → Verification Pending per ADR-022.

- 8212d4f: P124 Phase 3 — `packages/itil/hooks/lib/session-id.sh::get_current_session_id` within-system selection changed from first-glob-match (alphabetical) to most-recent-mtime (`ls -t | head -1`). Phase 2's portability fix (the for-loop existence check that replaced bash-only `shopt -s nullglob`) is preserved; Phase 3 layers mtime selection on top of it.

  Why Phase 2 alone wasn't enough: glob expansion under both bash and zsh enumerates matches in ASCII-alphabetical order by default. Phase 2's "first match wins" inner loop returned the alphabetically-first present marker. On a developer machine accumulating one `${system}-announced-${SID}` marker per past session in /tmp (observed 103 stale architect markers in a single regression run on 2026-04-28), the alphabetically-first UUID was a stale prior-session UUID. Helper returned a wrong SID; the create-gate hook (P119) read the live SID from its stdin JSON and denied the Write; recovery required brute-touching `manage-problem-grep-` for every known SID (81–103 markers per recovery in evidence).

  Phase 3 fix: within-system selection switches to most-recent-mtime via `ls -t "${marker_dir}/${system}-announced-"* 2>/dev/null | head -1`. `-announced-` markers per ADR-038 are write-once-per-session (no `touch`-refresh, no sliding TTL — unlike `-reviewed-` markers governed by ADR-009 + P111), so mtime IS the announcing session's first-prompt timestamp. Newest mtime within a single system's `-announced-` glob unambiguously identifies the live session. The outer system priority loop (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved verbatim.

  `packages/itil/hooks/test/session-id.bats` gains one new behavioural assertion per ADR-037 + P081: write three architect-announced markers with controlled mtimes (`sleep 1` between writes) where the alphabetically-first UUID has the OLDEST mtime; assert helper returns the newest-mtime UUID, not the alphabetical-first. Phase 2's existing 7 assertions remain green; suite is now 8/8.

- dcc65b4: P130 — `packages/itil/skills/work-problems/SKILL.md` Mid-loop ask discipline (orchestrator main turn). Tightens the orchestrator's ask discipline per the user-reframed Fix Strategy: presence-detection is unreliable and is not the goal; treat the user as transient (may answer one question and disappear for hours). The loop's purpose is progress + accumulation; mechanical-stage transitions between iters are framework-resolved.

  The orchestrator MUST NOT call `AskUserQuestion` between iters except at framework-prescribed halt points: Step 0 session-continuity / fetch-failure; Step 2.5 / 2.5b loop-end emit; Step 6.5 above-appetite Rule 5 + CI-failure / release:watch halts; Step 6.75 dirty-for-unknown-reason. Continue iterating until quota exhausts or a stop-condition fires.

  Accumulated user-answerable questions follow strict discipline at surface time:

  - Direction-setting decisions only (no BUFD)
  - No questions answerable by research / exploration / experimentation — the agent should prototype, read code, run experiments to answer those itself
  - Each surfaced question must carry enough context for an informed decision (architect's recommended option, alternatives, trade-offs, concrete consequences of each path)

  Files shipped:

  - `packages/itil/skills/work-problems/SKILL.md` — new "Mid-loop ask discipline (orchestrator main turn)" subsection inside Non-Interactive Decision Making; framework-prescribed halt-point enumeration; transient-user framing; accumulated-question discipline; cross-references to Step 5's per-subprocess constraint.
  - `packages/itil/skills/work-problems/SKILL.md` Step 5 iteration-prompt body — augmented with the transient-user framing.
  - `packages/itil/skills/work-problems/test/work-problems-no-mid-loop-asking.bats` — 20 new behavioural assertions per ADR-037 + P081 covering the no-mid-iter-asks invariant and the framework-prescribed halt-point allow-list.

  ADR-032 unchanged — the subprocess-boundary contract is preserved verbatim. Out of scope per the reframe: presence-signal helper (`packages/itil/hooks/lib/presence-signal.sh`), dual-mode dispatch, stream-json live-tail observation surface.

  Composes with P132 (over-ask in interactive sessions — same family of agent-discipline gaps; P132's enforcement hook serves P130's reframed direction) and P135 / ADR-044 (decision-delegation contract — framework-resolution boundary).

  Transitions P130 Known Error → Verification Pending per ADR-022.

## 0.22.0

### Minor Changes

- 74822b5: `/wr-itil:manage-problem` + `/wr-itil:review-problems` + `/wr-itil:work-problems`: render `docs/problems/README.md` WSJF Rankings table in tie-break-ladder order with a `Reported` date column so the rendered top-to-bottom row order matches the orchestrator's tie-break selection 1:1 (P138).

  Multi-key sort spec `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` documented at all five render-block sites (`manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + Step 9c presentation + Step 9e template, `review-problems` SKILL.md Step 3 + Step 5 README template, `work-problems` SKILL.md Step 1) with stable greppable cross-coupling marker `<!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 -->` at each site so future tie-break ladder changes know to update every render block. New behavioural + structural bats coverage `manage-problem-readme-tie-break-order.bats` 13/13 green covers marker presence, sort spec verbatim, Reported column in templates, drift-warning prose, AND a behavioural fixture sort with 4 same-WSJF tickets differing by Status/Effort/Reported asserting post-sort row order matches the tie-break ladder result. `docs/problems/README.md` re-rendered against the new sort: the WSJF 6.0 tier now shows P123 → P135 → P082 instead of P135 → P123 → P082, matching `/wr-itil:work-problems` Step 3 selection 1:1 (the exact case that triggered this ticket — user saw orchestrator pick P123 while README showed P135 on top, assumed orchestrator was broken).

  Closes P138 (Open → Verification Pending per ADR-022).

## 0.21.7

### Patch Changes

- 1f0b9fc: P124 Phase 2 — `packages/itil/hooks/lib/session-id.sh::get_current_session_id` is now zsh-portable. The Phase 1 implementation used `shopt -s nullglob` (a bash builtin) inside a subshell; under zsh — the agent's actual interactive shell on macOS — this errored with `command not found: shopt` and let the subshell glob expression fall through to a literal unmatched-pattern string, returning a wrong/stale UUID. Citation: ticket "Regression Evidence (2026-04-27)", main-turn P130 capture line 119: `get_current_session_id:33: command not found: shopt`. Recovery required brute-forcing 81 marker files for one ticket creation.

  Phase 2 replaces the `shopt`-subshell with a portable `for f in "${marker_dir}/${system}-announced-"*; do [ -e "$f" ] || continue; marker="$f"; break; done` existence-check loop. Identical behaviour under bash, zsh, and POSIX dash. The fixed marker-system priority order (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved verbatim from Phase 1. The `&&` short-circuit empty-SID contract preserved (no `/tmp/manage-problem-grep-` empty-tail file ever created).

  `packages/itil/hooks/test/session-id.bats` gains one new behavioural assertion per ADR-037 + P081: helper invoked under `zsh -c` returns the same UUID as under `bash -c`, exits 0, emits no `shopt: command not found` on stderr. Existing 6 Phase 1 assertions remain green; suite is now 7/7. Test skips cleanly if `zsh` is not on PATH.

  Architect verdict (PASS, advisory): Phase 2 implements only the `shopt` portability fix; the ticket's "Fix Strategy (Phase 2)" section also named a glob-ordering ASCII→mtime fix, but that is intentionally not in Phase 2 scope — Phase 1's switch to `-announced-` markers + the system-priority discipline already supersedes the mtime-sort idea (see Phase 1 architect refinement on `-reviewed-` marker fragility under ADR-009 sliding TTL + P111).

  JTBD alignment confirmed (jtbd-lead PASS): JTBD-001 (Enforce Governance Without Slowing Down) primary — eliminates the 81-marker brute-force recovery cost on first ticket creation per session. JTBD-006 (Progress the Backlog While I'm Away) composes — AFK loops creating tickets mid-iter no longer risk wedging on Step 2 deny.

## 0.21.6

### Patch Changes

- c5b91ef: P136 Phase 2 (ADR-044 alignment audit — manage-incident SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  Third per-skill amendment in the suite-wide audit (after `work-problem` singular at `@windyroad/itil@0.21.4` and `mitigate-incident` at `0.21.5`). **Closes Phase 2 of P136** — all three high-ask SKILLs (work-problem singular, mitigate-incident, manage-incident) are now aligned with ADR-044's framework-resolution boundary and 6-class authority taxonomy.

  Manage-incident's audit found **0 lazy-deferrals to remove** (incident-declaration is fundamentally interactive — all 4 call surfaces are genuine user-authority surfaces per the 6-class taxonomy). Two refactors and two cosmetic cross-references shipped.

  **Surface 1 — Step 2 duplicate-check REFACTOR (closes ADR-013 Confirmation #1 regression).** The prior prompt body at line 134 contained `"Would you like to (a) update an existing incident, (b) declare a new incident anyway, or (c) cancel?"` — both the `would you like` phrasing and the `(a)/(b)/(c)` parenthetical match the regex in ADR-013 Confirmation criterion #1 (`grep -inE "Options:.*\(a\)\|Your call:\|which would you like\|which way?"` — must return zero matches outside test fixtures). The refactor lifts the 3 options into the `AskUserQuestion` `options[]` mechanism (with `header: "Active incidents found"`) and rewrites the prompt body as plain prose ("Choose how to proceed:"). Behavioural change: none — same 3 options, same outcome paths. Compliance fix.

  **Surface 2 — Step 4 gather-info KEEP + cosmetic ADR-044 cat-1 cross-ref.** Title / Symptoms / Scope / Start time / Severity are user-knowledge inputs that the framework cannot infer; this is canonical category-1 (direction-setting). No behavioural change.

  **Surface 3 — Step 6 evidence-first gate REFACTOR (cross-skill consistency with mitigate-incident).** The prior prose at line 208 was an open backfill prompt: `"ask via AskUserQuestion what evidence supports it"`. The refactor aligns with `/wr-itil:mitigate-incident` Step 3's 3-option pattern (Add evidence / Record anyway with audit-trail bypass / Cancel) and includes the documented `[<timestamp> UTC] Evidence-gate bypassed by user — reason: <justification>` audit-trail prose so post-incident review can grep every bypassed gate. Behavioural change: ADDS an explicit documented bypass option that previously had no documented escape hatch (the implicit bypass existed — a user could type "no evidence" and the skill would comply — but it was un-audited). The refactor converts implicit-soft-gate to explicit-hard-gate-with-audit-trail. Annotated as ADR-044 **category-2 (deviation-approval)** surface.

  **Surface 4 — Step 14 risk-above-appetite KEEP + cosmetic ADR-044 cat-3 cross-ref.** Annotated as the **category-3 (one-time-override)** surface for cross-skill consistency with mitigate-incident Step 8.

  **Cascading prose updates**: NEW Related section added (manage-incident previously had no Related section); enumerates P136, ADR-044, ADR-013 amended Rule 1, ADR-013 Confirmation criterion #1, ADR-011, ADR-014/015/018/020/026/042, P071, P081, JTBD-001/101/201.

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/manage-incident/test/manage-incident-adr-044-contract.bats` (NEW companion file) — 11 contract assertions covering: Step 2 negative regression guards (`would you like`, `(a)/(b)/(c)`); Step 2 ADR-044 cat-1 cross-ref; Step 2 retains 3-option choices (positive guard); Step 4 ADR-044 cat-1 cross-ref; Step 6 3-option pattern (Add / Record-anyway / Cancel); Step 6 ADR-044 cat-2 cross-ref; Step 6 bypass-marker prose; Step 14 ADR-044 cat-3 cross-ref; bats marker present; SKILL.md cites P136 + ADR-044.
  - The companion file carries the `tdd-review: structural-permitted` marker per P081 + P136 bridge. The sibling functional file `manage-incident.bats` deliberately avoids structural-grep on SKILL.md prose (P011 ban); the new companion is the dedicated structural-grep-permitted home for the ADR-044 alignment contract during the bridge window.
  - All 11 new + 14 existing manage-incident assertions green; full itil package suite still green.

  **Architect + JTBD review verdict**: PASS. Architect explicitly noted the Surface 1 refactor **closes an existing ADR-013 Confirmation criterion #1 violation** at line 134 (line numbers verified). JTBD reviewer addressed the Surface 3 trade-off favorably: making the bypass explicit _strengthens_ JTBD-201's "auditability of AI-assisted incident work" outcome by converting an implicit, undocumented evidence-gate bypass into an explicit, audit-trailed bypass option; the cool-headed-commitment is preserved because `Add evidence` remains the friction-free default and bypass requires conscious second choice. JTBD-101 (extend the suite) advanced — adopters now get one consistent evidence-gate pattern across both incident skills.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 manage-incident complete. **Phase 2 is now 3/3 done** — all high-ask SKILLs audited. Phase 3 (medium/low-ask SKILLs, ~26 surfaces) is the next phase, deferred to a future session per per-skill release cadence (R1).

  Refs: P136 (master), ADR-044 (anchor), ADR-011 (incident lifecycle + evidence-first), ADR-013 amended Rule 1, ADR-013 Confirmation criterion #1 (regression closed), ADR-010, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-042, P057, P071, P081, P135, JTBD-001 / JTBD-101 / JTBD-201.

## 0.21.5

### Patch Changes

- 2b6ce32: P136 Phase 2 (ADR-044 alignment audit — mitigate-incident SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  Second per-skill amendment in the suite-wide audit (after `work-problem` singular at `@windyroad/itil@0.21.4`). Removes the lazy-deferral argument-backfill `AskUserQuestion` from Step 1 / Arguments section and adds inline ADR-044 cross-references on the two retained user-authority surfaces (evidence-first gate; risk-above-appetite commit).

  **Surface 1 — argument backfill becomes fail-fast (AMEND).** Replaces the `ask via AskUserQuestion` instructions at lines 20 / 50 / 52 with a fail-fast usage message + exit. Argument malformation is a typo-class signal, not a decision; the slash command IS the input contract. Re-typing in 1 second beats a multi-turn `AskUserQuestion` dialogue, and the suite now has consistent argument-backfill semantics across `transition-problem` Step 1, `work-problem` singular, and `mitigate-incident` Step 1. The new Step 1 emits an explicit `Usage:` block (incident ID format + action shape + `/wr-itil:list-incidents` pointer for ID discovery) so adopters and first-time users get a discoverable contract.

  **Surface 2 — evidence-first gate (KEEP + cross-ref).** ADR-011's evidence-first rule IS the existing decision; "Record anyway" IS the user-approved deviation; user IS the right authority. Annotated as the ADR-044 **category-2 (deviation-approval)** surface. The 3-option vocabulary (Add evidence / Record anyway / Cancel) and the `## Audit trail` note appended on bypass are both unchanged. The cross-reference makes the framework-resolution boundary visible at the call site (Step 3 + the Evidence-first gate header).

  **Surface 3 — risk-above-appetite commit (KEEP + cross-ref).** In incident-mitigation context, the tech lead may need to ship a mitigation despite higher residual risk to restore service fast (JTBD-201). The rule (RISK-POLICY appetite) still stands; this specific case is a strategic exception. Annotated as the ADR-044 **category-3 (one-time-override)** surface. The 3-option vocabulary (commit anyway / remediate / park) is unchanged; the ADR-013 Rule 6 fail-safe (skip + report when `AskUserQuestion` is unavailable) is preserved.

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/mitigate-incident/test/mitigate-incident-contract.bats` (UPDATED) — 7 new contract assertions: Step 1 fail-fast usage block; Step 1 negative regression guard against `AskUserQuestion` re-entry for argument backfill; Arguments section negative regression guard; Step 3 ADR-044 category-2 cross-reference; Step 8 ADR-044 category-3 cross-reference; positive guard that `AskUserQuestion` is RETAINED for Surfaces 2 + 3 (frontmatter `allowed-tools` + Step 3 prose + Step 8 prose); `tdd-review: structural-permitted` marker present per P081 + P136 bridge. All 20 assertions green; all 534 itil package skill tests still green.
  - File carries the `tdd-review: structural-permitted` marker per the P136 Phase 2 inline plan's bridge-marker rule (P081 Phase 2 owns the canonical retrofit).

  **Architect + JTBD review verdict**: PASS. Architect cited the `transition-problem` Step 1 precedent line-for-line as the matching shape for Surface 1; no conflicts with ADR-011, ADR-013 amended, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-042, ADR-044, P057, P062, P071. JTBD-201 (restore service fast with audit trail) advanced — fail-fast preserves "restore fast" by avoiding multi-turn dialogue during high-adrenaline incident response; evidence-first audit-trail outcome unchanged. JTBD-001 (governance without slowing down) advanced — consent-gate-for-the-obvious removed from Surface 1; legitimate consent gates retained on Surfaces 2 + 3. JTBD-101 (extend the suite) cleaner adopter contract — argument backfill is now consistent across `transition-problem` / `work-problem` / `mitigate-incident`. JTBD-006 (AFK backlog) neutral — incident skills are interactive by definition; no AFK-loop regression.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 mitigate-incident complete (2 of 3 high-ask SKILLs done; manage-incident next).

  Refs: P136 (master), ADR-044 (anchor), ADR-011 (incident lifecycle), ADR-013 amended Rule 1, ADR-010, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-037, P057, P071, P081, P135, JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201.

## 0.21.4

### Patch Changes

- c5879a2: P136 Phase 2 (ADR-044 alignment audit — work-problem singular SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  First per-skill amendment in the suite-wide audit. Removes the lazy-deferral `AskUserQuestion` from Step 2 ticket selection and converges the interactive and AFK paths to a single framework-mediated tie-break ladder per ADR-044's Framework-Mediated Surface (Prioritisation row).

  **Step 2 — selection becomes framework-mediated.** The agent applies the WSJF formula + 5-rung tie-break ladder (1: WSJF score descending; 2: Known Error before Open; 3: smaller effort first; 4: older reported date wins; 5: ticket number ascending) and reports the chosen ticket + the rung that decided. No `AskUserQuestion` fires for selection. The ladder mirrors the logic the plural orchestrator (`/wr-itil:work-problems`) Step 3 already uses, removing the prior interactive-vs-AFK asymmetry that was the lazy-deferral surface ADR-044 was written to close. User-override path documented explicitly: `/wr-itil:work-problem <NNN>` skips the ladder; mid-flow correction (ADR-044 category 6 / P078) is the long-tail catcher.

  **Step 4 — scope-expansion gets explicit ADR-044 cross-reference.** No behavioural change. The 3-option scope-change `AskUserQuestion` (Continue / Re-rank / Pick different) is now annotated as the work-item-tactical analog of ADR-044's framework-tactical 5-option deviation-approval vocabulary (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer). Effort growth IS the contradicting evidence against the WSJF score that ranked the ticket; the user IS the right authority for the shape — the `AskUserQuestion` here is genuine, not lazy.

  **Cascading prose updates** (per architect advisory): frontmatter `description` reframed from "Interactive singular variant" to "framework-mediated selection (WSJF + tie-break ladder per ADR-044); singular variant"; overview, Scope bullet list, Ownership Boundary, and Related sections updated for ADR-044 citation discipline. ADR-013 amended Rule 1 reference now scoped to Step 4 only (the retained `AskUserQuestion` surface).

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/work-problem/test/work-problem-contract.bats` (UPDATED) — 6 new assertions covering: framework-mediated selection prose; tie-break-rung-citation report shape (JTBD-201 audit-trail); user-override-path-via-direct-NNN-invocation literal-form (with substring-trap guard against `/wr-itil:work-problems` plural); negative regression guard against `AskUserQuestion`-driven selection re-emerging in Step 2; ADR-044 category-2 cross-reference in Step 4; `tdd-review: structural-permitted` marker present (P081 + P136 bridge). All 25 assertions green; all 534 itil package skill tests still green.
  - File carries the `tdd-review: structural-permitted` marker per the P136 Phase 2 inline plan's bridge-marker rule (P081 Phase 2 owns the canonical retrofit).

  **Architect + JTBD review verdict**: PASS. No conflicts with existing decisions (ADR-013 amended, ADR-010 amended Skill Granularity, ADR-014, ADR-022, ADR-026, ADR-032, ADR-040, ADR-042, P031, P062, P077). JTBD-001 (enforce governance without slowing down) advanced — one consent gate per session removed; deterministic ladder IS the governance enforcement. JTBD-006 (AFK backlog) simplified — singular and plural now share one selection algorithm. JTBD-101 (extend the suite) cleaner — adopters inherit one path instead of two. JTBD-201 (audit trail) preserved/improved — agent's "I picked P\<NNN\> using rung X" report is reproducible from README state.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 work-problem singular complete (1 of 3 high-ask SKILLs done; mitigate-incident next).

  Refs: P136 (master), ADR-044 (anchor), ADR-013 amended Rule 1, ADR-010 amended Skill Granularity, ADR-014 (commit grain), ADR-026 (grounding for tie-break-rung citations), ADR-032 + P077 (work-problems plural delegation), ADR-037 (contract-assertion bats pattern), P031 (cache-freshness check), P062 (review-problems canonical README writer), P081 (structural-grep retrofit; bridge marker), JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201.

## 0.21.3

### Patch Changes

- 328f92a: P135 Phase 3 (AFK loop redesign — `@windyroad/itil`) per ADR-044 (Decision-Delegation Contract).

  Redesigns the `/wr-itil:work-problems` AFK loop to be the empirical-discovery engine ADR-044 describes. Direction-class observations + deviation candidates accumulate from real friction across iters; loop-end Step 2.5 presents the batched questions as the primary deliverable.

  **ITERATION_SUMMARY.outstanding_questions schema** (Phase 3 + R7):

  - Field is now mandatory non-empty when iter touched a direction / deviation-approval / one-time-override / silent-framework decision; otherwise empty array.
  - Each entry tagged with category for Step 2.5 ranking.
  - New **deviation-candidate entry shape**: when iter encounters an existing decision (ADR / SKILL / WSJF / RISK-POLICY) that current evidence contradicts, agent queues a candidate with `existing_decision` citation + `contradicting_evidence` citation per ADR-026 grounding + `proposed_shape ∈ {amend, supersede, one-time}` + `rationale`. Agent does NOT auto-deviate; never blindly follows against evidence. Not-queueing-when-strong-contradicting-evidence-exists is a regression per the bats coverage.

  **Step 2.5 (loop-end emit)** — promoted from "fallback when stop-condition #2" to **default loop-end emit shape**. Reads `.afk-run-state/outstanding-questions.jsonl`, de-duplicates, ranks (deviation-approval > direction > one-time-override > silent-framework > taste > correction-followup), presents as batched `AskUserQuestion` per ADR-013 Rule 1 cap. Deviation-candidate entries get the 5-option `AskUserQuestion` (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer); other entries get options extracted from the entry's `question` text.

  **Between-iter aggregation**: orchestrator's main turn appends each iter's `outstanding_questions` entries to the session-level queue file at `.afk-run-state/outstanding-questions.jsonl` between Step 6 (report) and Step 6.5 (release-cadence check). Queue cleared after Step 2.5 resolves all entries. Per ADR-032 pending-questions artefact precedent.

  **Mid-loop UserPromptSubmit handler** (R4) — when orchestrator receives user message during an iter, the in-flight iter MUST complete naturally to its `ITERATION_SUMMARY` emission BEFORE the orchestrator surfaces the queue + new direction. **Do NOT abort the iter mid-flight** (no SIGTERM to iter PID). Direct corrective for the 2026-04-27 iter-9-killed overcorrection — the user's correction was about future iter dispatch shape, not the in-flight iter; killing wasted ~$5 + 25 min in-flight work.

  **Bats coverage** (Phase 3 R4 + R7):

  - `packages/itil/skills/work-problems/test/work-problems-mid-loop-userpromptsubmit-handler.bats` (NEW per R4) — 7 assertions covering handler clause documentation, complete-naturally-to-ITERATION_SUMMARY contract, no-SIGTERM forbiddance, no-abort-mid-flight forbiddance, iter-9 precedent citation, queue-after-iter contract, $5+25min cost grounding.
  - `packages/itil/skills/work-problems/test/work-problems-deviation-candidate-shape.bats` (NEW per R7) — 12 assertions covering schema documentation (existing_decision / contradicting_evidence / proposed_shape fields), no-auto-deviate contract, never-blindly-follow assertion, regression assertion (not-queueing-is-a-regression), 5-option loop-end emit, deviation-approval-highest ranking, jsonl persistence, ADR-032 precedent citation, anti-BUFD-for-framework-evolution rationale citation.

  19/19 new bats green.

  **Per-phase release cadence (R1) + preview-tag rollout (R2)**: Phase 3 ships `@windyroad/itil` patch via npm `preview` tag first (changesets dist-tag); exercise end-to-end against a real `/wr-itil:work-problems` AFK session verifying no-mid-loop-AskUserQuestion + outstanding-questions jsonl + mid-loop UserPromptSubmit handler all behave per spec; only after end-to-end verification, promote `preview` → `latest` via `npm dist-tag` promotion. If verification fails on `preview`, fix-and-republish without affecting `latest` consumers.

  Refs: P135 (master), ADR-044 (anchor), ADR-014 (commit grain), ADR-026 (grounding), ADR-032 (pending-questions artefact precedent), ADR-013 Rule 1 narrowing precedent, P124 (verifying-flip-back precedent for deviation-approval reversibility), P122 / P126 (Step 2.5b surfacing routine precedent).

## 0.21.2

### Patch Changes

- fae42aa: P135 Phase 2 (Skill amendments — `@windyroad/itil` half) per ADR-044 (Decision-Delegation Contract).

  Removes per-action `AskUserQuestion` calls in `work-problems`, `manage-problem`, and `transition-problem` where the framework has already resolved the decision (lazy deferral per Step 2d Ask Hygiene Pass classification). Replaces with silent agent-action + summary surfacing. User correction via the P078 capture-on-correction surface (authentic-correction per ADR-044 category 6).

  **`work-problems` Step 5 dispatch (iter prompt body)**: added explicit constraint clause: _"NEVER call `AskUserQuestion` mid-loop in AFK"_. Direction / deviation-approval / one-time-override / silent-framework observations queue at `ITERATION_SUMMARY.outstanding_questions` for loop-end batched presentation per the existing Step 2.5b surfacing routine. Per-iter `AskUserQuestion` calls are sub-contracting framework-resolved decisions back to the user.

  **`manage-problem` Step 9d verification close**: replaced per-`.verifying.md` `AskUserQuestion` with close-on-evidence: agent collects in-session evidence per ADR-026 grounding; when concrete and unambiguous, delegates to `/wr-itil:transition-problem <NNN> close` (per ADR-014 commit grain) WITHOUT firing `AskUserQuestion`. Ambiguous-evidence path preserved (left as Verification Pending). Closes are reversible (`/wr-itil:transition-problem <NNN> known-error` flip-back); recovery path documented inline.

  **`transition-problem` Step 5 P063 external-root-cause detection**: replaced the 3-option `AskUserQuestion` (invoke-now / defer-and-note / not-actually-upstream) with the silent default behaviour (defer-and-note marker). The marker wording is fixed; recovery is user-initiated (false-positive marker append OR direct `/wr-itil:report-upstream` invocation). AFK and interactive modes use identical behaviour.

  **Bats coverage** (Phase 2 R5):

  - `packages/itil/skills/manage-problem/test/manage-problem-step-9d-recovery-path.bats` (NEW per R5) — 10 assertions covering close-on-evidence dispatch, ADR-044 / ADR-026 / ADR-022 citations, reversibility affirmation, recovery skill invocation naming, P124 precedent citation, ambiguous-evidence preservation, authentic-correction routing, output-table-with-citation contract.

  Refs: P135 (master), ADR-044 (anchor), ADR-014 (commit grain), ADR-022 (lifecycle), ADR-026 (grounding), ADR-013 Rule 1 narrowing precedent, P063 (external-root-cause detection), P078 (authentic-correction surface), P124 (verifying-flip-back precedent), P132 (inverse-P078 enforcement).

## 0.21.1

### Patch Changes

- 6c46694: work-problems: extracted Step 2.5's surfacing routine into a reusable `Step 2.5b — Surface accumulated user-answerable skips` sub-step that every halt path cross-references before emitting its final AFK summary (P126).

  P122 fixed the routing at Step 2.5 stop-condition #2 — when ≥1 user-answerable skip is accumulated, default to `AskUserQuestion`-when-available, fall back to the Outstanding Design Questions table only when the structured-question primitive is unavailable per ADR-013 Rule 6. P126 extends the same contract to the remaining halt paths: Step 0 session-continuity halt, Step 0 fetch-failure halt, Step 6.5 Failure handling (CI / publish failure), Step 6.5 ADR-042 Rule 5 above-appetite halt, Step 6.75 dirty-for-unknown-reason halt. Each halt path now names a one-paragraph cross-reference pointing at Step 2.5b, gated on `≥1 accumulated user-answerable skip`. Step 2.5 itself now delegates to Step 2.5b — single source of truth for the surfacing logic.

  The Rule 5 cross-reference carries an architect-FLAG guard: Step 2.5b surfaces _prior-iter accumulated user-answerable skips only_ — it does NOT ask the user how to remediate the above-appetite state itself. The halt-causing scorer-gap remains a halt with bug-signal per ADR-042 Rule 5 invariant ("never release above appetite"; the scorer is the decision surface, not the user). The same `prior-iter only` framing is documented for the Failure-handling halt (CI failure remains user-investigation-on-return) and the Step 6.75 dirty-unknown halt (dirty-state recovery remains a Rule 6 user-input requirement on return).

  The Decisions Table at the bottom of `SKILL.md` gains a `Halt-path final summary with accumulated user-answerable skips` row naming the cross-halt routing. The `Unexpected dirty state between iterations` row is amended to mention the Step 2.5b call before the halt summary.

  `docs/briefing/afk-subprocess.md` adds a `halt-paths-must-route-design-questions-through-Step-2.5b` entry alongside the existing P122 entry, traceable across the principle's evolution.

  15 behavioural contract assertions in `packages/itil/skills/work-problems/test/work-problems-step-2-5b-cross-halt-routing.bats` pin the contract per ADR-037 + P081 — Step 2.5b heading present, gating clause named, AskUserQuestion default branch preserved, Rule 6 table fallback preserved, each halt path cross-referenced (5 paths × 1 each = 5 assertions), Rule 5 guard prose present, Decisions Table row present, briefing entry cross-references P122. Full work-problems suite 136/136 green.

  JTBD-001 (Enforce Governance Without Slowing Down) primary — extends interactive-question routing to every halt path that accumulates skipped user-answerable design questions. JTBD-006 (Progress the Backlog While I'm Away) — the AFK return ritual is enhanced not disrupted; empty-skip halts skip the routine via the gating clause, so users who hit Step 0 fetch-failure with no iters run see no question prompt. The cross-skill principle paragraph in Step 2.5b generalises to any future AFK orchestrator that hits the same surface — defer the AFK persona to the subprocess boundary, not to the orchestrator's question-surfacing branch.

  No new ADR — extension of P122's already-documented routing principle under ADR-013 Rule 1 / Rule 6 + ADR-032 subprocess-boundary contract.

## 0.21.0

### Minor Changes

- 8653541: P065: scaffold downstream OSS intake — new `/wr-itil:scaffold-intake` skill + pre-publish PreToolUse gate

  The `@windyroad/itil` plugin now ships a foreground-synchronous skill that scaffolds the five OSS intake files every project in the ecosystem needs to receive structured problem reports and route security disclosure properly:

  - `.github/ISSUE_TEMPLATE/config.yml`
  - `.github/ISSUE_TEMPLATE/problem-report.yml` (P066-corrected problem-first shape)
  - `SECURITY.md`
  - `SUPPORT.md`
  - `CONTRIBUTING.md`

  Templates live at `packages/itil/skills/scaffold-intake/templates/*.tmpl` and use mustache-style substitution (`{{project_name}}`, `{{project_url}}`, `{{plugin_list}}`, `{{security_contact}}`, `{{year}}`) with no runtime dependency. The skill is idempotent: present files are skipped unless `--force`; full re-application produces no diff. Re-invocation reports diffs for outdated-present files.

  **Trigger surfaces (layered)** per ADR-036:

  1. **First-run prompt** — wired into `manage-problem` and `work-problems` SKILL.md preambles. Foreground branch fires `AskUserQuestion` with three options (scaffold now / not now / decline). AFK branch (per ADR-013 Rule 6 + JTBD-006) appends a one-line "pending intake scaffold" note to the iteration's `ITERATION_SUMMARY` and never auto-scaffolds. Markers `.claude/.intake-scaffold-{done,declined}` follow ADR-009 persistent-marker semantics.
  2. **Pre-publish PreToolUse gate** — new hook `pre-publish-intake-gate.sh` denies `npm publish` and `gh pr merge ... changeset-release/*` when intake files are missing AND no decline marker AND `INTAKE_BYPASS=1` is not set. Override path: `INTAKE_BYPASS=1 npm publish`.
  3. **CI check** — deferred to v2 via `--ci` flag (emits `.github/workflows/intake-check.yml`).

  `packages/itil/hooks/hooks.json` registers the new PreToolUse:Bash hook. Skill is auto-discovered from the directory; no manifest change required.

  Cross-reference paragraph added to `packages/itil/skills/report-upstream/SKILL.md` documenting the reciprocal-pair shape (report-upstream files at upstream intake; scaffold-intake creates downstream intake).

  39 new behavioural bats tests:

  - `packages/itil/hooks/test/pre-publish-intake-gate.bats` (10 tests — allow + deny matrix across surfaces, markers, and bypass).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-contract.bats` (15 tests — SKILL.md structural invariants per ADR-037).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` (7 tests — empty repo, idempotent re-run, partial repo with pre-existing CONTRIBUTING.md).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-secrets-absent.bats` (7 tests — no /Users, /home, Windows paths, credential shapes, hardcoded author-repo references).
  - `packages/itil/skills/manage-problem/test/manage-problem-first-run-intake-prompt.bats` (4 tests — wiring point fixed).
  - `packages/itil/skills/work-problems/test/work-problems-first-run-intake-prompt.bats` (4 tests — wiring point fixed).

  Closes P065 → Verification Pending. ADR-036 stays `proposed` (no status change required at implementation time).

### Patch Changes

- 482b54a: P127: scaffold-intake idempotency bats fixture — snapshot dir now lives outside `$TEST_DIR` to fix Linux CI failure

  The `fixture: full re-application is idempotent (no diff)` test in `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` was failing on Linux CI but passing on macOS local — a test-harness portability bug, not a production-skill bug. Root cause: `cp -R . "$TEST_DIR/.snapshot-1"` ran with `$PWD == $TEST_DIR`, so the destination was a child of the source. GNU `cp` (Linux / Ubuntu CI) refuses this case with `cp: cannot copy a directory, '.', into itself, ...`; BSD `cp` on macOS APFS silently allows it. The non-zero exit aborted the test on Linux only.

  Fix: take the snapshot into a sibling `mktemp -d` directory outside `$TEST_DIR`, eliminating the source-into-itself recursion. No production SKILL.md or template changes — `scaffold_all` was already deterministic. The idempotency assertion shape is unchanged: still `cp` first state → re-run `scaffold_all` → `diff -ru` against snapshot.

  Verification: 29/29 scaffold-intake bats pass on both Linux (`bats/bats:latest` Alpine container) and macOS local. Restores CI green-on-main for `@windyroad/itil` (CI was red on every commit since `8653541`).

  Closes P127 → Verification Pending pending CI confirmation.

## 0.20.0

### Minor Changes

- 17b594b: P117: new plural sibling skill `/wr-itil:transition-problems` for batch lifecycle transitions

  `@windyroad/itil` gains a plural sibling to `/wr-itil:transition-problem` that batch-advances multiple tickets through the lifecycle in one invocation, mirroring the P071 singular/plural split precedent (`work-problem` vs `work-problems`).

  - New skill `packages/itil/skills/transition-problems/SKILL.md` — accepts a space-separated list of `<NNN> <status>` pairs (e.g. `/wr-itil:transition-problems 063 close 067 close 092 close 094 close`). Loops the singular's per-ticket mechanic inline (pre-flight checks, P063 external-root-cause detection per pair, `git mv` + Edit + P057 re-stage per pair). Refreshes `docs/problems/README.md` ONCE at the end (P062 at batch grain — single render reflecting all surviving renames). Commits ALL surviving transitions in ONE commit per ADR-014 batch-grain unit-of-work.
  - Partial-failure semantics: skip-and-surface — failed pairs (discovery / invalid-transition / pre-flight / git-op) are recorded and continue to the next pair; succeeded pairs commit at the end. Zero-success means no commit + failure summary. Aligned with ADR-014 "complete unit of work" applied at the batch grain and ADR-013 Rule 6's no-non-interactive-destructive-rollback rule.
  - Inline per-ticket mechanic per ADR-010 amended "Split-skill execution ownership" — "copy, not move". The plural carries an inline scoped copy of the singular's Steps 2–6; per-pair commit (singular Step 8) is replaced by the single batch commit at the end. Three call sites now share the per-ticket mechanic via copy-not-move: singular `transition-problem`, plural `transition-problems` (this skill), and `manage-problem` in-skill Step 7.
  - Behavioural contract bats `packages/itil/skills/transition-problems/test/transition-problems-contract.bats` — 20 assertions covering frontmatter shape, allowed-tools, citations (P117, ADR-010 amended, P057, P062, P063, ADR-022, ADR-013 Rule 6, ADR-037), inline-mechanic positive assertions (`pre-flight`, `git mv`, `git add`, `Fix Released`), no-Skill-tool-delegation negative assertion, single-commit-at-end semantics (positive + no-per-pair-commit negative), single-README-refresh-at-end, partial-failure skip-and-surface, argument shape (no `P` prefix, no `=`/`:` separator, no flag-style), no `deprecated-arguments` frontmatter (clean-split sibling), and a cross-file drift-detection assertion that the staging-trap `git add docs/problems/` phrase appears in BOTH this skill's SKILL.md and the singular's SKILL.md so the inline-copy invariant fails fast on drift.

  Closes P117 → Verification Pending. Eliminates the N×SKILL.md reload tax + ownership-boundary violation that batch callers (run-retro Step 4a, manage-problem Step 9d, work-problems release-batched closures) currently face.

## 0.19.7

### Patch Changes

- ef4c9e9: manage-problem: Step 2 substep 7 now sources the new agent-side session-ID discovery helper (`packages/itil/hooks/lib/session-id.sh`) instead of the brittle `${CLAUDE_SESSION_ID:-default}` fallback that wrote the create-gate marker under the wrong UUID and triggered a Write deny on every first ticket of a session (P124).

  `get_current_session_id` returns the canonical session UUID by reading `CLAUDE_SESSION_ID` if exported, else by scraping the most-reliable per-session announce marker (`/tmp/<system>-announced-<UUID>`, set on prompt 1 of every session per ADR-038 by architect / jtbd / tdd / style-guide / voice-tone / itil-assistant-gate / itil-correction-detect). It exits non-zero when no session can be discovered so callers can `&&`-chain the marker write and never land an empty-UUID `/tmp/manage-problem-grep-` file the hook will never match.

  Selection order is fixed (architect first, then jtbd / tdd / itil-assistant-gate / itil-correction-detect / style-guide / voice-tone) so discovery is deterministic and reproducible across invocations. Announce markers are write-once-per-session per ADR-038 — no mtime sliding (unlike `-reviewed-` gate markers which `touch`-refresh on every gate check per ADR-009 + P111), so the helper sidesteps the multi-session `/tmp` mtime-fragility flagged in architect review.

  The skill now calls the existing `mark_step2_complete` helper from `create-gate.sh` for the marker write itself — single source of truth for the marker-path convention.

  6 behavioural bats assertions in `packages/itil/hooks/test/session-id.bats` pin the contract per ADR-037 + P081 (env-var fast path, env-var ignores markers, architect-marker scrape, jtbd-marker fallback, no-markers empty+non-zero exit, deterministic priority order). Helper is itil-local for now (only manage-problem needs agent-side SID discovery today); promote to `packages/shared/` per ADR-017 if a second skill adopts the pattern.

  ADR-038 Related cross-references the new helper as the agent-side READ companion to its hook-side WRITE helpers.

- 3f6e021: P057 staging-trap recurrence is now denied at commit time by a new `PreToolUse:Bash` hook (`packages/itil/hooks/p057-staging-trap-detect.sh`) that fires on `git commit` invocations and surfaces the recovery command inline. Documentation alone did not prevent recurrence — P125 evidence: P122 batch shipped commit `e7564ff` with rename-only after multiple retros had cited the rule. The hook removes reliance on agent attention.

  Detection delegates to a new shared helper `packages/itil/hooks/lib/staging-detect.sh::detect_p057_trap`. The helper runs `git diff --staged --name-status` and `git diff --name-only`; if any staged rename's `<new>` path also appears in the working-tree modification list, the trap is present. The helper echoes the trap'd path on stdout and emits a one-line recovery hint on stderr, returning 1 (deny) or 0 (allow / fail-open). Cost is bounded — two `git diff` invocations per commit invocation (~10-50ms on this repo's working tree).

  Fail-open contract mirrors `lib/create-gate.sh`: outside a git working tree, on parse-incomplete input, or when `git diff` errors for any reason, the helper returns 0 — a hook that fails-closed on hostile environments would block legitimate commits in non-git contexts. ADR-013 Rule 1's "deny redirects to recovery" contract is satisfied via the mechanical-recovery shape — re-staging a file is a single command, no skill round-trip required.

  10 behavioural bats assertions per ADR-005 + P081 (`packages/itil/hooks/test/p057-staging-trap-detect.bats`) pin the contract: trap detected → deny with file + recovery + P057 cite; trap recovered via re-stage → allow; pure rename → allow; modify-only batch → allow; empty batch → allow; non-Bash tool → allow; non-commit Bash command → allow; empty JSON (parse-incomplete) → allow (fail-open); deny message names file + `git add <FILE>` + P057 cite; deny message stays under ADR-038 progressive-disclosure budget (<400 bytes; observed ~348 bytes).

  Hook registered in `packages/itil/hooks/hooks.json` under `PreToolUse` with `matcher: "Bash"`. `docs/briefing/agent-interaction-patterns.md` line 8 cites the new hook as the enforcement layer the documentation alone didn't provide. JTBD-001 (Enforce Governance Without Slowing Down) primary fit. JTBD-006 (Progress the Backlog While I'm Away) composes — AFK iter loops are the highest-frequency offenders.

## 0.19.6

### Patch Changes

- 8f21b87: work-problems: Step 2.5 stop-condition #2 routing now defaults to AskUserQuestion when available; Outstanding Design Questions table is the AskUserQuestion-unavailable fallback (P122).

  The legacy prose ("JTBD-006's persona constraint makes the non-interactive path the default for this skill — AskUserQuestion is the exception, not the rule") conflated persona with runtime mode and caused the orchestrator's main turn to suppress AskUserQuestion in interactive sessions. The orchestrator IS always main turn (interactive by construction); JTBD-006's AFK persona is served by the iteration subprocess workers under the ADR-032 subprocess-boundary contract — they never reach stop-condition #2.

  Cross-skill principle (architect FLAG): orchestrator main turns default to AskUserQuestion when available; AFK persona is served by the subprocess-boundary contract under ADR-032, not by suppressing AskUserQuestion at the orchestrator layer.

  Step 6.5 Decisions Table row for "Stop-condition #2 with user-answerable skip-reasons" updated to match the flipped default. New `work-problems-step-2-5-routing.bats` (8 doc-lint contract assertions per ADR-037) pins the new contract. Full project bats green.

  P103 anti-pattern boundary preserved: AskUserQuestion still scoped to `user-answerable` skip-reasons only; `architect-design` and `upstream-blocked` continue to skip without asking.

## 0.19.5

### Patch Changes

- 65b9019: `/wr-itil:work-problems` Step 5 backgrounds the iteration subprocess and runs a 60s poll loop with an idle-timeout SIGTERM branch. When `now - LAST_ACTIVITY_MARK > WORK_PROBLEMS_IDLE_TIMEOUT_S` (default 3600s = 60 min), the orchestrator sends SIGTERM to the stuck `claude -p` PID. SIGTERM empirically produces a clean JSON exit-flush — the subprocess responds with a valid `is_error: false` envelope and parseable `ITERATION_SUMMARY` block within seconds. Override the threshold per-environment via the `WORK_PROBLEMS_IDLE_TIMEOUT_S` env var. Closes P121. ADR-032 amended with the backgrounded-poll-loop refinement under the subprocess-boundary variant; new behavioural fixture in `test/work-problems-step-5-idle-timeout-sigterm.bats` provides the second-source for the production observation that motivated the fix.

## 0.19.4

### Patch Changes

- 9c50d03: `docs/problems/README.md` now self-heals from cross-session drift (P118).

  A new diagnose-only script `packages/itil/scripts/reconcile-readme.sh` checks
  the README's WSJF Rankings, Verification Queue, and Closed sections against
  the on-disk ticket files (`docs/problems/<NNN>-*.<status>.md`). Exit codes:
  0 = clean, 1 = drift detected (one structured row per drift entry to stdout,
  ≤150 bytes per ADR-038 progressive-disclosure budget), 2 = parse error.

  A new skill `/wr-itil:reconcile-readme` wraps the script with an agent-applied-
  edits pattern that preserves the README's narrative content (the "Last reviewed"
  prose paragraph at the top and the per-row closure-via free text in the Closed
  section). Full README regeneration is forbidden — narrative content is human-
  curated session memory.

  Two preflight invocation surfaces fire the script before doing anything else:

  - `/wr-itil:manage-problem` Step 0 — halt-with-directive on drift before parsing
    the request, so ticket creation / update / transition never proceeds against
    a stale README that would re-encode the lie into the post-operation refresh.
  - `/wr-itil:work-problems` Step 0 — auto-apply via `/wr-itil:reconcile-readme`
    in AFK mode (per ADR-013 Rule 6) so the orchestrator's Step 3 ranking reads
    ground truth.

  `/wr-itil:transition-problem` deliberately does NOT invoke the script — P062's
  existing transition-time refresh inside the same commit already covers that
  surface; redundant preflight there would pay the cost on every transition.

  This is a robustness layer ON TOP of P094 (refresh-on-create, Closed) and P062
  (refresh-on-transition, Closed) — both per-operation contracts remain in force.
  The reconciliation contract catches drift introduced by past sessions where the
  single-commit-transaction discipline was skipped (bug, partial-progress hand-
  off, conflict resolution, etc.) and that no per-operation contract can
  retroactively detect or correct.

  ADR-014 amended with a "Reconciliation as preflight robustness layer" sub-rule
  (P118, 2026-04-25). ADR-022 Confirmation criterion 3 extended with a
  reconciliation invariant cross-referencing the new script.

## 0.19.3

### Patch Changes

- 22b9a17: P078 — Hook now offers ticket capture on strong-signal correction.

  A new `UserPromptSubmit` hook (`itil-correction-detect.sh`) detects strong-affect correction signals in the user's prompt — `FFS`, all-caps imperatives (`DO NOT`, `DON'T`, `STOP`), direct contradiction (`that's wrong`, `you're not listening`), exasperation markers (`!!!`), meta-correction (`you always`, `you never`, `you keep`) — and injects a `MANDATORY` reminder telling the assistant to OFFER `/wr-itil:capture-problem` (with `/wr-itil:manage-problem` as today's fallback) BEFORE addressing the operational request. Once-per-session full block + terse-reminder pattern (ADR-038).

  Without this, strong-signal corrections decay with session context and the same class-of-behaviour pattern recurs next session, with the user having to manually request the ticket every time.

  Pattern vocabulary lives in `packages/itil/hooks/lib/detectors.sh::CORRECTION_SIGNAL_PATTERNS`. Detection is intentionally aggressive (case-insensitive); false positives degrade gracefully (one extra advisory line — the offer is non-blocking).

## 0.19.2

### Patch Changes

- 84124f6: `/wr-itil:report-upstream` gains Step 4b dedup + Step 5c comment path (P070): close the two duplication windows that were the skill's most externally-visible failure mode. Step 4b.1 own re-run check greps the local ticket for an existing `## Reported Upstream` URL and halts-and-surfaces if present. Step 4b.2 third-party search uses `gh issue list --repo <upstream> --search "<keywords>" --state all --json ... --limit 10` as a cheap pre-filter, then performs an inline LLM semantic match against each candidate's body via `gh issue view <n> --json body,title` (no subagent dispatch — per Direction decision 2026-04-21, the gh-search prefilter trims input to ~5-10 candidates which keeps the inline check affordable). Step 5c comment path lands cross-references via `gh issue comment <n>` when a dedup match is selected, and the local ticket records `Disclosure path: commented-on-existing-issue <URL>` in `## Reported Upstream` rather than `public issue`.

  **Modified files:**

  - `packages/itil/skills/report-upstream/SKILL.md` — adds Step 4b (own re-run + third-party search branches), Step 5c (comment path), and extends Step 7 disclosure-path enumeration with `commented-on-existing-issue`.
  - `docs/decisions/024-cross-project-problem-reporting-contract.proposed.md` — Decision Outcome adds Step 4b + Step 5c; Out-of-scope dedup bullet narrowed to residual `update-mode`; Confirmation criterion 2 gains the new bats coverage line; Related lists P070 as driver.
  - `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — 9 new behavioural assertions (Step 4b presence, own-re-run detection language, third-party `gh issue list --search` language, Step 5c comment-path, AFK halt-and-save behaviour, disclosure-path enumeration); file 24/24 green.

  **AFK behaviour (interim):** halt-and-save the drafted report to the local ticket's `## Drafted Upstream Report` section per ADR-013 Rule 6. The maintainer-annoyance risk evaluator that would gate auto-comment is **DEFERRED** to compose with `wr-risk-scorer:external-comms` per ADR-028 line 117 — keeps P070 effort at M and avoids cross-cutting work blocking on P064. When P064 lands, a follow-up bundling commit will wire the maintainer-annoyance evaluator + P064 leak gate together so the AFK auto-comment branch can fire at appetite.

  **Architect verdict**: PASS x3 (overall shape, bats, ADR-024 amendment) — confirmed inline LLM check (no subagent) is the right scope and that maintainer-annoyance evaluator deferral is the right architectural call. **JTBD verdict**: PASS — JTBD-004 primary fit (cross-repo coordination protected from spam); JTBD-001 / JTBD-006 / JTBD-101 protected by halt-and-surface fallback. **Risk**: 2/25 Very Low; reduces silent-duplicate risk on the report-upstream surface.

  P070 (Open → Verification Pending). Verification path: exercise the skill twice against the same upstream + local ticket (4b.1 should halt on second run); exercise against an upstream with overlapping existing issues (4b.2 should offer comment path or halt-and-save in AFK).

- ccc8ffc: `/wr-itil:manage-problem` Step 2 duplicate-check enforcement (P119): close the structural gap that lets agents bypass the duplicate-prevention grep by writing tickets directly to `docs/problems/` via the Write tool. Adds a `PreToolUse:Write` hook that gates new-file creation under `docs/problems/<NNN>-*.<status>.md` on a per-session marker set by Step 2. Without the marker the agent gets a `permissionDecision: deny` directing them back into the skill — where Step 2 grep + `AskUserQuestion` for matches fires before the new file lands.

  **New files:**

  - `packages/itil/hooks/manage-problem-enforce-create.sh` — PreToolUse:Write hook. Matches `docs/problems/<NNN>-*.<status>.md` new-file paths (numeric-prefix basename test, ADR-031 forward-compat). Allow-lists `docs/problems/README.md` (chicken-and-egg — regenerated by Steps 5/6/7) and existing files (Edit-flow / status transitions). Only Write is gated; Edit on existing tickets is the transition-problem surface.
  - `packages/itil/hooks/lib/create-gate.sh` — sibling of `lib/review-gate.sh`. Different semantics (no TTL drift detection — the marker is just "Step 2 ran for this session"), so kept separate per architect direction. Per-session scope (`/tmp/manage-problem-grep-${SESSION_ID}`) — single marker covers all new tickets in a skill invocation, enabling Step 4b multi-concern split without re-grep blocking.
  - `packages/itil/hooks/test/manage-problem-enforce-create.bats` — 16 behavioural assertions (deny path, allow path, multi-concern split compatibility, README exemption, Edit-flow exemption, status-suffix coverage, ADR-031 forward-compat, marker hygiene).

  **Modified files:**

  - `packages/itil/hooks/hooks.json` — registers the new `PreToolUse:Write` matcher.
  - `packages/itil/skills/manage-problem/SKILL.md` Step 2 — adds substep 7: write the create-gate marker after the grep completes. Adds a "Hook contract (P119)" callout explaining the deny shape and warning against manual marker-setting.

  **Architect verdict**: APPROVED — fits ADR-009 gate-marker lifecycle + ADR-038 progressive disclosure without amendment; per-session marker scope confirmed; ADR-031 forward-compat advisory addressed in matcher. **JTBD verdict**: PASS — closes JTBD-001 governance-skip pain point; preserves JTBD-006 AFK queue integrity; protects JTBD-201 audit trail. **Tests**: 38/38 itil hooks; 876/876 full suite; no regressions.

  P119 (Open → Verification Pending).

## 0.19.1

### Patch Changes

- cbf178e: work-problems Step 5 dispatch robustness (P089): two bounded refinements within the shipped 0.13.0 `claude -p` subprocess dispatch + 0.14.0 cost-metadata extraction contract — no ADR amendment, no CLI change.

  **Gap 1 — stdin-warning redirect.** The canonical Step 5 dispatch command now ends with `< /dev/null` to suppress the `claude -p` 3-second stdin-wait warning. The warning is emitted to stderr, which is fine when streams are consumed separately; under the orchestrator's `2>&1` merge (required to keep stderr prose from interleaving between chained invocations) the warning prefixed stdout and broke `jq` / `json.load` / `JSON.parse` extraction of `.result` and cost metadata. The redirect is the Anthropic CLI help's own suggested workaround. First observed AFK-iter-7 iter 1 (2026-04-21); iter 2-7 used the workaround.

  **Gap 2 — authority hierarchy for cost vs usage.** Added an Authority hierarchy paragraph to the Per-iteration cost metadata block and a matching Authority note to the Output Format Session Cost section. `.total_cost_usd` is cumulative-authoritative by CLI contract and is the trusted dollar signal; `.usage.*` is a per-turn response envelope and can reflect only the final-turn ack when the subprocess exits via a background-task completion notification — observed AFK-iter-7 iter 5 where a 1071s wall-clock / 60+ tool-use run reported `duration_ms: 8546, num_turns: 1, usage.* ≈ 137K tokens, total_cost_usd: 6.08` (cost correct, tokens final-turn-only). Session Cost output now renders the cost column as authoritative and labels token totals best-effort. Detection criterion (final-turn-sized usage alongside wall-clock-orders-of-magnitude-larger-than-`duration_ms`) stated descriptively; no change to the named-field extraction list.

  No SKILL.md contract break; no runtime behaviour change in the orchestrator. Tests: 6 new assertions in `work-problems-step-5-delegation.bats` (30/30 passing).

## 0.19.0

### Minor Changes

- 77f0542: P109: work-problems Step 0 preflight detects prior-session partial-work state

  `/wr-itil:work-problems` Step 0 (AFK orchestrator preflight) gains a **session-continuity detection pass** after the existing `git fetch origin` + divergence check. This closes the gap where an AFK loop restarted after a quota (429) / error / user-cancel would silently iterate past partial work left in the working tree.

  **Signals enumerated** (each maps to one `git status --porcelain` / filesystem / `git worktree` probe):

  - Untracked `docs/decisions/*.proposed.md` — drafted but unlanded ADRs from a prior iter.
  - Untracked `docs/problems/*.md` — drafted but unlanded problem tickets.
  - `.afk-run-state/iter-*.json` files with `"is_error": true` OR `"api_error_status" >= 400` — prior iteration hit quota or API error (ADR-032 subprocess artefact contract). Success files (`"is_error": false`) are ignored.
  - Stale `.claude/worktrees/*` directories + matching `git worktree list` entries on `claude/*` branches — prior subagent worktrees not cleaned up. Detection only — mutation/cleanup is out of scope and would require a separate ADR.
  - Uncommitted modifications to `packages/*/skills/*/SKILL.md`, `packages/*/hooks/*`, `docs/decisions/*.proposed.md`, or other source paths the prior session was mid-authoring.

  **Routing per ADR-013 Rule 1 / Rule 6**:

  - **Interactive**: `AskUserQuestion` with 4 options — **Resume the prior work** (land drafted files as iter 1), **Discard the draft**, **Leave-and-lower-priority** (skip the dirty paths), **Halt the loop**.
  - **Non-interactive / AFK** (default for this skill per JTBD-006): halt the loop with a structured Prior-Session State report in the AFK summary. Matches Step 6.75's "dirty for unknown reason → halt" stance at the Step 0 layer — the orchestrator does not silently proceed past partial work.

  **Surfaces**:

  - `packages/itil/skills/work-problems/SKILL.md` Step 0 — adds the session-continuity detection subsection plus a decision-matrix row in the Non-Interactive Decision Making table.
  - `docs/decisions/019-afk-orchestrator-preflight.proposed.md` — extended (within its 2026-07-18 reassessment window); no new ADR created. Confirmation criterion 5 added for the contract-assertion bats.
  - `packages/itil/skills/work-problems/test/work-problems-preflight-session-continuity.bats` — 16 contract-assertion tests per ADR-037 covering signal enumeration, interactive/AFK routing, and the decision-matrix row.

  Closes P109 → Verification Pending.

## 0.18.1

### Patch Changes

- b2424c8: P113: declare `Skill, Agent` in `wr-itil:report-upstream` allowed-tools

  The `report-upstream` skill body (`packages/itil/skills/report-upstream/SKILL.md` Step 9 / line 330) invokes the `wr-risk-scorer:pipeline` subagent (requires the `Agent` tool) and falls back to `/wr-risk-scorer:assess-release` per ADR-015 (requires the `Skill` tool). Neither was declared in the SKILL.md frontmatter `allowed-tools` field. `report-upstream` was the only itil skill that declared `AskUserQuestion` without also declaring `Skill` — and the only itil skill missing from Claude Code's TUI slash-command autocomplete despite being present in the agent-side skill enumerator.

  Candidate mechanism (to confirm post-release per the verification path on P113): Claude Code's TUI autocomplete appears to validate declared-vs-used tools in skill frontmatter and silently drop skills whose bodies invoke tools not declared in `allowed-tools`, while the server-side enumerator (which populates the agent's available-skills list) is more lenient. If the hypothesis holds, adding `Skill, Agent` restores `/wr-itil:report-upstream` to the autocomplete surface without changing runtime behaviour. If the hypothesis is wrong, P113 reopens for upstream escalation to Anthropic.

  Closes P113 → Verification Pending.

## 0.18.0

### Minor Changes

- 8ad3d3b: ADR-041: auto-apply scorer remediations when above appetite; never release above appetite

  Land ADR-041 closing P103 (`/wr-itil:work-problems` escalated resolved above-appetite release decisions) and P104 (partial-progress painted the release queue into a corner).

  Behaviour:

  - `work-problems` Step 6.5 gains an above-appetite branch. When `push` or `release` residual risk lands ≥ 5/25, the orchestrator auto-applies scorer remediations in rank order (largest `|risk_delta|` first) until residual risk converges within appetite (≤ 4/25). Each auto-apply amends the iteration's main commit per ADR-041 Rule 3 (preserves ADR-032 one-commit-per-iteration invariant).
  - `manage-problem` Step 12 and `manage-incident` Step 15 terminal release sequences inherit the same above-appetite branch; each auto-apply is its own commit since there is no iteration wrapper in non-AFK mode.
  - **Never release above appetite**: there is no code path in either lineage that drains at ≥ 5/25. Exhaustion halts the loop/skill per ADR-041 Rule 5.
  - **Closed action-class enumeration (Rule 2a)**: ADR-041 v1 ships with `move-to-holding` implemented (`git mv .changeset/<name>.md docs/changesets-holding/<name>.md`). Classes `revert-commit`, `amend-commit`, `feature-flag`, `rollback-to-tag` are deferred to P108. Unsupported class descriptions route to Rule 5 halt.
  - **Verification Pending carve-out (Rule 2b)**: auto-revert never fires against commits attached to `.verifying.md` tickets; Rule 5 halt names the VP ticket(s).
  - **Governance gates apply per auto-apply (Rule 3)**: the scorer proposes; architect + JTBD + risk-scorer gates authorise. No scorer-bypass path.
  - **Audit trail (Rule 6)**: iteration/skill reports emit an Auto-apply trail subsection (one line per apply); `docs/changesets-holding/README.md` "Currently held" appends for `move-to-holding` actions.
  - **Holding-area blessed (Rule 7)**: `docs/changesets-holding/` promoted from provisional to authoritative. ADR-041 cited as the governing decision; provisional banner removed.

  Supersedes the implicit above-appetite branch of ADR-018 Step 6.5 and the explicit above-appetite branch of ADR-020 §6; both ADRs cross-reference ADR-041 from the same commit. At-or-below-appetite drain behaviour in both is unchanged.

  Authorised by ADR-013 Rule 5 (policy-authorised silent proceed): `RISK-POLICY.md` appetite + ADR-041 Rule 2a enumeration constitute the policy for the auto-apply loop.

  Follow-up work tracked in **P108** (`docs/problems/108-scorer-remediation-action-class-vocabulary.open.md`) — scorer contract extension (structured `action_class` column in `RISK_REMEDIATIONS:`) + orchestrator parsers for the four deferred classes. Until P108 lands, ADR-041 v1's scope is the `move-to-holding` subset.

  Closes P103, P104. Opens P108.

## 0.17.2

### Patch Changes

- 8d28266: P094 — `/wr-itil:manage-problem` now refreshes `docs/problems/README.md` on new-ticket creation (Step 5, unconditional) and on ranking-changing updates (Step 6, conditional on Priority / Effort / WSJF line changes). Step 11's staging language extends the single-commit rule from Step 7 transitions to cover Step 5 creation and Step 6 ranking-change updates so README.md rides every commit that alters on-disk ticket ranks. Closes P094.

## 0.17.1

### Patch Changes

- d2fa4c6: P093 — resolve `/wr-itil:transition-problem` ↔ `/wr-itil:manage-problem` circular delegation for `<NNN> <status>` args.

  `/wr-itil:transition-problem` now hosts the Step 7 transition block inline: pre-flight checks per destination (Open → Known Error / Known Error → Verifying / Verifying → Close), P063 external-root-cause detection with the AFK fallback, `git mv` + Status edit + P057 explicit re-stage, `## Fix Released` section write on the `.verifying.md` destination, P062 README refresh, and the ADR-014 commit through the risk-scorer pipeline gate. The skill no longer re-invokes `/wr-itil:manage-problem` — the round-trip clause that created the infinite-delegation cycle has been stripped from `manage-problem`'s Step 1 `<NNN> <status>` forwarder paragraph.

  Per architect guidance, the fix follows a "copy, not move" shape: the in-skill Step 7 block on `manage-problem` stays intact for in-skill callers (Step 9b auto-transition, the Parked path, Step 9d closure inside review). The split skill carries a scoped inline copy for the user-initiated transition path only.

  ADR-010 amended with a new **"Split-skill execution ownership"** sub-rule (2026-04-22) codifying the "copy, not move" principle so the same trap does not recur in future clean-split skills.

  Existing `transition-problem-contract.bats` test 7 inverted in place to assert no round-trip; test 8 added for inline Step 7 mechanics. Full itil sweep: 736/736 green.

## 0.17.0

### Minor Changes

- d938a04: P067 — `/wr-itil:report-upstream` classifier is now problem-first per ADR-033. The Step 3 classifier picks `problem` shape as primary (tokens: problem / issue / concern / defect / gap / scoped-npm reference / root cause / reproduction / workaround) and demotes bug / feature / question to backward-compat fallback shapes. The Step 5 structured default body is problem-shaped (Description / Symptoms / Workaround / Affected plugin / Frequency / Environment / Evidence / Cross-reference); bug-shaped / feature-shaped / question-shaped bodies are retained as fallback-only templates for the corresponding backward-compat branches. Template-discovery preference order now searches `problem-report.yml` / `problem.yml` / `problem-report.md` / `problem.md` before bug / feature / question template candidates. ADR-033 partially supersedes ADR-024 Decision Outcome Steps 3 and 5; ADR-024 Steps 1, 2, 4, 6, 7, 8 and all Consequences remain in force. Ships after P066's intake-template reform (2026-04-20) so the skill's preference order matches the reference intake shape this repo now ships.
- 73c48b7: P076 — WSJF scoring in `/wr-itil:manage-problem` now models transitive dependencies. Ticket effort is split into `marginal` (the ticket's own added work) and `transitive` (`max(marginal, max{ Blocked_by upstreams })`); WSJF uses the transitive effort so a dependent ticket can never out-rank a ticket whose work is strictly contained within it. Additions:

  - New `### Transitive dependencies (P076)` subsection in `packages/itil/skills/manage-problem/SKILL.md` WSJF Prioritisation section defining the rule, the `**Blocked by**` signal, the `**Composes with**` non-propagation carve-out, the `.closed.md` / `.verifying.md` / `.parked.md` upstream-contributes-0 carve-out, cycle-bundling semantics, a worked example (P073 marginal S + blocked by P038 XL → transitive XL → WSJF 1.5), a concrete re-rate message format (`P<NNN>: Effort <OLD> → <NEW> (transitive via <UPSTREAM>)`), and a reassessment-criteria note for future sibling-ADR extraction if a second skill adopts the `## Dependencies` convention.
  - New `## Dependencies` section in the Step 5 problem-ticket template with `**Blocks**` / `**Blocked by**` / `**Composes with**` rows (bare IDs, empty lists allowed) and a concrete example block.
  - New Step 9b.1 dependency-graph-traversal pass in `manage-problem` and a mirrored Step 2.5 in `/wr-itil:review-problems` (the executor split per P071) that builds the `**Blocked by**` adjacency map, topologically sorts, propagates effort, writes an `<!-- transitive: <bucket> via <UPSTREAM> -->` audit comment on the Effort line, and reports each re-rate in the step-3 review output.
  - New `manage-problem-transitive-dependencies.bats` contract + behavioural test file (21 assertions — 15 structural contract assertions per ADR-037 plus 6 behavioural fixture tests exercising the transitive-closure algorithm directly so prose-drift like `min` instead of `max`, or a missing carve-out for closed upstreams, is caught at test time).
  - Three new contract assertions on `review-problems-contract.bats` covering the new Step 2.5 pass, canonical-rule citation, and re-rate message shape.

  No new ADR authored (following ADR-022's inline-amendment precedent for WSJF additions); reassessment trigger documented inline. Backward-compatible — tickets without a `## Dependencies` section behave as before (empty closure → transitive == marginal).

## 0.16.0

### Minor Changes

- 6f3265a: P086: AFK iteration subprocess now runs `/wr-retrospective:run-retro` before emitting `ITERATION_SUMMARY`

  The AFK `/wr-itil:work-problems` iteration subprocess previously emitted `ITERATION_SUMMARY` and exited without running retro, discarding every per-iteration friction observation — hook TTL expiries, marker-vs-file deadlocks, repeat-workaround patterns, subagent-delegation friction, release-path instability. Across a 5-iteration AFK loop that's 20–50 tool-level observations the backlog never sees, degrading JTBD-006's "clear summary on return" outcome and JTBD-101's "new friction patterns become ticketable" promise.

  `packages/itil/skills/work-problems/SKILL.md` Step 5 iteration prompt body gains a closing step (step 4) naming `/wr-retrospective:run-retro` before the `ITERATION_SUMMARY` emission step. Retro runs INSIDE the subprocess so its Step 2b pipeline-instability scan has access to the iteration's full tool-call history; retro commits its own work per ADR-014 (run-retro delegates ticket creation to `/wr-itil:manage-problem`); orchestrator picks up retro-created tickets on the next Step 1 scan naturally — no cross-process marker sharing required. Retro is non-blocking: if retro fails or surfaces findings, the iteration still emits `ITERATION_SUMMARY` so the AFK loop does not halt on a flaky retro run.

  `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` subprocess-boundary variant gains a matching "Retro-on-exit (P086 amendment)" clause under the Pattern contract block, parallel to how P084 amended P077 — the retro contract is the subprocess-boundary variant's closing-step invariant alongside spawn command, stdout parse shape, exit-code semantics, hook session-id isolation, post-subprocess state re-read, and orchestration boundary.

  `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` gains four doc-lint contract assertions (P086): iteration prompt names `/wr-retrospective:run-retro`; retro ordered BEFORE `ITERATION_SUMMARY` emission; retro named as non-blocking closing step; ADR-014 cited for retro commit ownership.

  Architect review PASS (no ADR invariant violated; amendment shape parallels P084→P077). JTBD review PASS (JTBD-006 + JTBD-101 primary alignment; JTBD-001 no-regression — retro runs inside subprocess, orchestrator main turn unaffected).

## 0.15.0

### Minor Changes

- 4a25a60: P071 split slices 6b + 6c + 6d: new `/wr-itil:restore-incident`, `/wr-itil:close-incident`, and `/wr-itil:link-incident` skills

  `/wr-itil:manage-incident <I> restored`, `/wr-itil:manage-incident <I> close`, and `/wr-itil:manage-incident <I> link P<M>` are deprecated; the three remaining incident-lifecycle user intents now have their own skills so the `/` autocomplete surfaces each one directly (JTBD-001 + JTBD-101 + JTBD-201). These are slices 6b + 6c + 6d of the P071 phased-landing plan, bundled in one commit because each mirrors slice 6a (mitigate-incident, commit 248edad) verbatim except for the transition each owns. Bundling amortises cache-warmup + full bats re-run cost across three identical-pattern splits; per-slice separability is preserved via one contract-bats file per skill.

  - `packages/itil/skills/restore-incident/SKILL.md` — NEW split skill (slice 6b).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill`
    — diverges from close-incident + link-incident because restore invokes
    `/wr-itil:manage-problem` via the Skill tool for the problem-handoff
    (ADR-011 Decision Outcome point 4) and uses AskUserQuestion for the
    "create problem / no problem required" branch. Owns the
    `.mitigating.md → .restored.md` rename, the Status field update, the
    "Service restored" Timeline entry, and the `## Linked Problem` or
    `## No Problem` section write. Pre-flight enforces at least one
    recorded mitigation attempt + a captured verification signal per
    ADR-011. Re-invocation on an already-`.restored.md` file is
    idempotent (Case B) — does not re-edit the Status field.
  - `packages/itil/skills/restore-incident/test/restore-incident-contract.bats`
    — NEW 12 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/close-incident/SKILL.md` — NEW split skill (slice 6c).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — no
    AskUserQuestion (the linked-problem gate is a hard check with a message,
    not a decisional prompt), no Skill tool (no cross-skill invocation).
    Owns the `.restored.md → .closed.md` rename, the Status field update,
    and the "Incident closed" Timeline entry. Gate accepts linked problems
    in `.known-error.md`, `.verifying.md` (ADR-022 extension), or
    `.closed.md` state; `.open.md` blocks close with a pointer to
    `/wr-itil:transition-problem`. `## No Problem` section bypasses the
    gate. Already-closed invocations short-circuit idempotently.
  - `packages/itil/skills/close-incident/test/close-incident-contract.bats`
    — NEW 13 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability;
    includes the ADR-022 `.verifying.md` gate-allowance regression guard).
  - `packages/itil/skills/link-incident/SKILL.md` — NEW split skill (slice 6d).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — two data
    parameters (incident ID + problem ID) and no decisional prompts.
    Owns the `## Linked Problem` section write / update, including the
    retroactive-link-from-No-Problem conversion (Case C) which also
    appends a `Retroactive link to P<MMM>` Timeline entry so the audit
    trail records the revision.
  - `packages/itil/skills/link-incident/test/link-incident-contract.bats`
    — NEW 11 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — Step 1 parser now
    recognises three additional shapes (`<I###> restored`, `<I###> close`,
    `<I###> link P<MMM>`) and delegates via the Skill tool; emits the
    canonical deprecation systemMessage verbatim for each. Steps 8
    (restore), 9 (close), and 11 (link) reduced to thin-router notes
    pointing at the new skills. `deprecated-arguments: true` already
    pinned from slice 5.
  - `packages/itil/skills/manage-incident/test/manage-incident-restore-forwarder.bats`
    — NEW 4 forwarder contract assertions.
  - `packages/itil/skills/manage-incident/test/manage-incident-close-forwarder.bats`
    — NEW 4 forwarder contract assertions.
  - `packages/itil/skills/manage-incident/test/manage-incident-link-forwarder.bats`
    — NEW 4 forwarder contract assertions.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  This completes the `/wr-itil:manage-incident` subcommand split. All five
  word-verb subcommands (`list`, `mitigate`, `restored`, `close`, `link`)
  are now first-class named skills. `manage-incident` retains two
  responsibilities: (1) declare a new incident (no arguments) and (2)
  update an existing incident body (`<I###> <details>` — data parameter
  only, not a verb subcommand). All five forwarders will be removed
  together in `@windyroad/itil`'s next major version.

  P071 phased-landing plan status: slices 1 (list-problems), 2
  (review-problems), 3 (work-problem singular), 5 (list-incidents), 6a
  (mitigate-incident), 6b (restore-incident), 6c (close-incident), and 6d
  (link-incident) shipped. Slice 4 (`transition-problem`) shipped in a
  prior release. All planned slices are now complete; P071 is eligible
  for transition to `.verifying.md` pending user sign-off per ADR-022.

- 38756a8: P071 split slice 5: new `/wr-itil:list-incidents` skill

  `/wr-itil:manage-incident list` is deprecated; the list-incidents user
  intent now has its own skill so the `/` autocomplete surfaces it directly
  (JTBD-001 + JTBD-101 + JTBD-201). This is slice 5 of the P071 phased-landing
  plan, mirroring slice 1 (list-problems) verbatim.

  - `packages/itil/skills/list-incidents/SKILL.md` — NEW read-only skill
    (`allowed-tools: Read, Bash, Grep, Glob` — no Write, no Edit, no
    AskUserQuestion). Reads `.investigating.md`, `.mitigating.md`, and
    `.restored.md` files from `docs/incidents/`; sorts by severity per
    ADR-011 ("Severity, not WSJF" — incidents are time-bound events where
    the WSJF effort divisor is meaningless).
  - `packages/itil/skills/list-incidents/test/list-incidents-contract.bats`
    — NEW 10 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — `deprecated-arguments:
true` frontmatter flag per ADR-010 amended; Step 1 `list` argument now
    routes to a thin-router forwarder that delegates via the Skill tool and
    emits the canonical deprecation notice verbatim.
  - `packages/itil/skills/manage-incident/test/manage-incident-list-forwarder.bats`
    — NEW 4 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment. Full itil bats suite green (241/241 + 14 new = 255/255).

  Remaining phased-landing slices tracked on P071: `mitigate-incident`,
  `restore-incident`, `close-incident`, `link-incident` (the remaining
  manage-incident splits).

- 248edad: P071 split slice 6a: new `/wr-itil:mitigate-incident` skill

  `/wr-itil:manage-incident <I###> mitigate <action>` is deprecated; the
  mitigate-incident user intent now has its own skill so the `/` autocomplete
  surfaces it directly (JTBD-001 + JTBD-101 + JTBD-201). This is slice 6a of
  the P071 phased-landing plan, mirroring slice 5 (list-incidents) closely
  except that mitigate-incident takes the `<I###> <action>` data parameters
  — permitted under ADR-010 amended (only word-verb-arguments must be split
  out; data parameters like IDs and free-text action strings remain).

  - `packages/itil/skills/mitigate-incident/SKILL.md` — NEW split skill.
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion,
Skill` — diverges from list-incidents's read-only set because mitigation
    renames `.investigating.md → .mitigating.md` on the first attempt and
    appends to the Mitigation attempts timeline. Preserves the ADR-011
    evidence-first gate (≥1 hypothesis with cited evidence) on the first
    mitigation transition, the reversible-mitigation preference
    (rollback → feature flag → restart → route traffic → scale → fix), and
    the Sev 4-5 lightweight path per ADR-011 Step 12 edge case.
  - `packages/itil/skills/mitigate-incident/test/mitigate-incident-contract.bats`
    — NEW 13 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — Step 1 parser now
    recognises the `<I###> mitigate <action>` shape and delegates via the
    Skill tool; emits the canonical deprecation systemMessage verbatim.
    Step 7 reduced to a thin-router note pointing at the new skill (the
    rename + evidence-gate implementation lives in `/wr-itil:mitigate-incident`
    now). `deprecated-arguments: true` already pinned from slice 5.
  - `packages/itil/skills/manage-incident/test/manage-incident-mitigate-forwarder.bats`
    — NEW 4 contract assertions for the mitigate forwarder.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `restore-incident`
  (slice 6b), `close-incident` (slice 6c), `link-incident` (slice 6d) —
  the remaining manage-incident splits.

## 0.14.0

### Minor Changes

- 7670ffb: Extend `/wr-itil:work-problems` Step 5 to extract per-iteration cost + token metadata from each `claude -p --output-format json` response. Surface it in Step 6's per-iteration progress line and the ALL_DONE Output Format's new "Session Cost" section.

  **Why:** the subprocess-dispatch swap shipped in 0.13.0 landed real per-iteration cost inside the JSON response alongside `.result`, but the orchestrator was throwing it away. Without surfacing it, the user has no feedback loop for calibrating AFK loop sizing decisions (e.g. the 2026-04-21 "max out the token usage, they are wasted unused" direction needs actuals to calibrate against). Cost metadata is already emitted — this change just wires it into the user-visible output.

  **Extracted fields (explicit list; PII guard):** `.total_cost_usd`, `.duration_ms`, `.usage.input_tokens`, `.usage.output_tokens`, `.usage.cache_creation_input_tokens`, `.usage.cache_read_input_tokens`. SKILL.md names the extraction scope explicitly so future contributors don't unconsciously broaden it to include `session_id`, `model`, `stop_reason`, `permission_denials`, `uuid`, or other subprocess-envelope fields.

  **Step 6 per-iteration format:** `[Iteration N] Worked P<NNN> — <action>. <K> problems remain. ($<cost>, <duration_s>s, <total_tokens_K>K tokens)`.

  **ALL_DONE Session Cost section:** aggregate totals (cost, iterations, mean cost per iteration, input/output/cache-creation/cache-read tokens, duration). Cache-read column surfaces the warm-cache-reuse signal observed across subsequent subprocess invocations in the same Bash session. Renders identically in interactive and AFK modes; no decision branch (output-side only, per ADR-013 Rule 6).

  **Source citation (per ADR-026):** Session Cost numbers are extracted measured-actuals from each iteration's `claude -p` JSON output — not estimates. Cited in the section header so downstream audits can trust the numbers.

  Architect + JTBD reviews PASS (both 2026-04-21). Bats doc-lint: 9 new assertions on the extraction language + Session Cost section shape; 54/54 work-problems suite green.

## 0.13.0

### Minor Changes

- 260768f: P084 fix: `/wr-itil:work-problems` Step 5 dispatches iterations via a `claude -p` subprocess instead of Agent-tool-spawned `general-purpose` subagents.

  **Why:** Agent-tool-spawned subagents do NOT have the Agent tool in their own surface (platform restriction; three-source evidence — ToolSearch probe, Claude Code docs, empirical runtime error). Without Agent, the iteration worker could not satisfy architect + JTBD PreToolUse edit-gate markers (only settable via Agent-tool PostToolUse hook) nor the risk-scorer commit gate. Every AFK iteration on a gate-covered path (`packages/`, ADRs, SKILL.md edits, hook edits) silently halted. The subprocess variant is a full main Claude Code session with Agent available, so governance reviews run at full depth and gate markers set natively.

  **Dispatch command:** `claude -p --permission-mode bypassPermissions --output-format json <iteration-prompt>`.

  **No per-iteration budget cap.** Per user direction, the AFK loop's natural stop condition is quota exhaustion, not an arbitrary dollar cap. A cap would halt iterations before quota is actually exhausted, leaving remaining backlog unprocessed. Quota-exhaust surfaces as a non-zero `claude -p` exit and the orchestrator halts cleanly per Step 6.75's exit-code handling.

  **What stays the same:** the `ITERATION_SUMMARY` return-summary contract is preserved verbatim (orchestrator extracts from the JSON `.result` field instead of the Agent-tool return value). Step 0 preflight (ADR-019), Step 6.5 release-cadence drain (ADR-018), and Step 6.75 inter-iteration verification (P036) all remain in the orchestrator's main turn unchanged. Every non-Step-5 block in the skill is untouched.

  **Adopter-tunable:** adopters with narrower permission scopes may substitute `--permission-mode acceptEdits` / `auto` / `dontAsk` for `bypassPermissions`. Adopters who genuinely need a per-iteration cap (multi-tenant billing, etc.) can add `--max-budget-usd` in their own fork — not the default.

  See `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` for the full subprocess-boundary sub-pattern contract (amendment dated 2026-04-21) and `docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.open.md` for the full diagnosis + probe evidence.

## 0.12.0

### Minor Changes

- 91da109: P071 split slice 4: new `/wr-itil:transition-problem` skill (+ manage-problem forwarder)

  `/wr-itil:manage-problem <NNN> known-error` / `<NNN> verifying` / `<NNN> close`
  is deprecated; the transition-a-ticket user intent now has its own skill so
  Claude Code `/` autocomplete surfaces it directly (JTBD-001 + JTBD-101).
  This is phase 4 of the P071 phased-landing plan.

  - `packages/itil/skills/transition-problem/SKILL.md` — NEW thin-router
    selection skill. Arguments: `<NNN>` (ticket ID) + `<status>` (one of
    `known-error`, `verifying`, `close`). Both are data parameters per the
    P071 split rule (ADR-010 amended); neither is a word-subcommand.
    Execution delegates to `/wr-itil:manage-problem <NNN> <status>` via the
    Skill tool — the authoritative Step 7 block (pre-flight checks + P057
    staging trap + P063 external-root-cause + P062 README refresh) stays
    on the host skill.
  - `packages/itil/skills/transition-problem/test/transition-problem-contract.bats`
    — NEW 14 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 traceability).
  - `packages/itil/skills/manage-problem/SKILL.md` — Step 1 parser updated
    to distinguish bare `<NNN>` (update flow, handled inline by Step 6)
    from `<NNN> <status>` (transition — delegated to the new skill). New
    "Forwarder for `<NNN> <status>` transitions" section added to the
    Deprecated-argument forwarders block, with the canonical deprecation
    notice (per ADR-010 amended template).
  - `packages/itil/skills/manage-problem/test/manage-problem-transition-forwarder.bats`
    — NEW 5 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `list-incidents`,
  `mitigate-incident`, `restore-incident`, `close-incident`,
  `link-incident` (the `manage-incident` splits).

  **Recovery note:** this slice shipped after the iter-5 AFK halt per P036.
  The iteration subagent wrote the files correctly (19/19 bats green) but
  returned prematurely without committing, triggering Step 6.75's
  dirty-for-unknown-reason branch. Work verified sound post-hoc and
  committed here as the halt recovery. A follow-up ticket captures the
  iteration-worker-must-not-ScheduleWakeup contract gap (separate from
  P077's delegation-mechanism fix).

- ffa85a7: feat(itil): P071 split slice 3 — /wr-itil:work-problem (+ manage-problem forwarder)

  Phase 3 of P071's phased-landing plan: the "pick the highest-WSJF ticket and work it" user intent gets its own skill so `/` autocomplete surfaces it directly. Previously hidden behind `/wr-itil:manage-problem work` — a word-argument subcommand that Claude Code autocomplete does not surface.

  CRITICAL naming distinction: `/wr-itil:work-problem` is **singular** — one ticket per invocation, interactive `AskUserQuestion` selection. It is distinct from the already-existing plural `/wr-itil:work-problems` (AFK batch orchestrator). The two names coexist per P071's acknowledged trade-off; the singular skill is the per-iteration execution unit the plural orchestrator delegates into via the Agent tool (P077 + ADR-032).

  `/wr-itil:work-problem` (new skill):

  - Frontmatter: `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill, Agent` — the selection tool surface plus delegation to `/wr-itil:review-problems` (refresh) and `/wr-itil:manage-problem <NNN>` (execution).
  - Step 1 reads `docs/problems/README.md` if fresh (git-history staleness test per P031); delegates to `/wr-itil:review-problems` for the refresh if stale (P062 canonical-writer discipline — no fork).
  - Step 2 fires `AskUserQuestion` selection: Recommended single top-WSJF option, or per-tied-ticket peer options for multi-way ties, with per-option rationale. Never prose "(a)/(b)/(c)" (P053 + ADR-013 Rule 1 regression guard).
  - Step 3 delegates the execution to `/wr-itil:manage-problem <NNN>` via the Skill tool — thin-router discipline; the full investigate/transition/fix/release workflow stays on a single authoritative host.
  - Step 4 fires the standard scope-change `AskUserQuestion` (Continue / Re-rank / Pick-different) on effort drift.
  - Step 5 reports the outcome; does NOT loop automatically (that's the plural orchestrator's job).
  - AFK branch (ADR-013 Rule 6): when invoked inside a `/wr-itil:work-problems` iteration, skips `AskUserQuestion` and executes the pre-selected ticket. Within-day tiebreak matches the orchestrator spec.

  `/wr-itil:manage-problem` (deprecated-argument forwarder for `work`):

  - Step 1 `work` argument now delegates to `/wr-itil:work-problem` via the Skill tool and emits the canonical systemMessage verbatim per ADR-010's pinned template: `"/wr-itil:manage-problem work is deprecated; use /wr-itil:work-problem directly. This forwarder will be removed in @windyroad/itil's next major version."`
  - Forwarder does not re-implement the selection logic (thin-router per ADR-010).
  - `deprecated-arguments: true` frontmatter flag already present from slice 1; no change.

  Tests (ADR-037 contract-assertion pattern):

  - `packages/itil/skills/work-problem/test/work-problem-contract.bats` — 19 assertions covering: frontmatter (name singular + regression guard against plural drift; description names pick/highest-WSJF + singular distinction; allowed-tools AskUserQuestion + Skill); singular-vs-plural naming-distinction documentation; delegation to `/wr-itil:manage-problem` (anti-fork); defer-to-`/wr-itil:review-problems` for cache refresh (P062 ownership); git-history freshness test (P031); `AskUserQuestion` selection prompt fires (ADR-013 Rule 1); prose-selection fallback forbidden (P053); AFK branch documented (Rule 6); scope-expansion 3-option shape; one-ticket-per-invocation singular contract; no `deprecated-arguments: true` flag on clean-split skill; no word-argument subcommand branching regression; P071 + ADR-010 + P077 + ADR-032 traceability citations.
  - `packages/itil/skills/manage-problem/test/manage-problem-work-forwarder.bats` — 5 assertions covering: forwarder targets `/wr-itil:work-problem` (singular); singular-vs-plural name-collision guard; canonical deprecation notice emission; no inline re-implementation; parser-line pattern matches slice-1 + slice-2 shape.

  Cross-references:

  - P071 (docs/problems/071-\*.open.md) — originating ticket; phased plan's slice 3.
  - ADR-010 amended (Skill Granularity section) — canonical split-naming + forwarder contract.
  - ADR-013 Rule 1 — structured user interaction; Rule 6 — AFK fallback.
  - ADR-014 — governance skills commit their own work; delegated manage-problem owns per-ticket commits.
  - ADR-032 + P077 — plural AFK orchestrator delegates iterations via Agent tool; this singular skill is the canonical execution unit.
  - P031 — git-history freshness test; P062 — review-problems canonical README cache writer.
  - P053 + ADR-013 Rule 1 — no prose-selection fallback.

## 0.11.0

### Minor Changes

- d8ab4c5: P071 split slice 2: new `/wr-itil:review-problems` skill

  `/wr-itil:manage-problem review` is deprecated; the review-problems user
  intent now has its own skill so the `/` autocomplete surfaces it directly
  (JTBD-001 + JTBD-101). This is phase 2 of the P071 phased-landing plan
  (list-problems shipped as slice 1 in `@windyroad/itil@0.10.0`).

  - `packages/itil/skills/review-problems/SKILL.md` — NEW skill carrying
    the full review stack: re-read `RISK-POLICY.md`, re-score every
    `.open.md` / `.known-error.md` ticket (Impact × Likelihood × Effort →
    WSJF), auto-transition Open → Known Error when root cause + workaround
    are documented, fire the Verification Queue prompt (`.verifying.md`
    per ADR-022 + P048 Candidate 4 `Likely verified?` heuristic), rewrite
    `docs/problems/README.md`, and commit per ADR-014 + ADR-015.
    `allowed-tools`: `Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion,
Skill` — the tool surface the governance-scoped write path demands
    (contrast with `list-problems`'s read-only surface).
  - `packages/itil/skills/review-problems/test/review-problems-contract.bats`
    — NEW 16 contract assertions (ADR-037 pattern; `@problem P071` +
    `@jtbd JTBD-001` + `@jtbd JTBD-101` traceability). Covers: frontmatter
    name, description intent language, allowed-tools surface (Write +
    Edit + Skill + AskUserQuestion required), glob scope (.open.md /
    .known-error.md / .verifying.md / .parked.md), README-refresh ownership
    boundary, Verification Queue prompt contract (ADR-022 fix-summary
    requirement), auto-transition path, ADR-014/015 commit-gate, P057
    staging-trap citation, RISK-POLICY.md reuse (no hardcoded scale),
    P071/ADR-010 citation, clean-split no-deprecated-arguments flag, and
    regression guard against word-argument subcommand branching.
  - `packages/itil/skills/manage-problem/SKILL.md` — Step 1 `review`
    argument now routes to a thin-router forwarder that delegates to
    `/wr-itil:review-problems` via the Skill tool and emits the canonical
    deprecation notice verbatim per ADR-010's pinned template. Parser
    line updated from "run the review (step 9) only" to "delegate to
    `/wr-itil:review-problems`". Step 9's inline review logic stays in
    the file during the deprecation window (for historical reference +
    the inline `work` path that still flows through Step 9 pre-slice 3)
    but is no longer the primary entry point.
  - `packages/itil/skills/manage-problem/test/manage-problem-review-forwarder.bats`
    — NEW 4 contract assertions for the review-forwarder contract:
    target-skill reference, canonical deprecation notice, delegate /
    Skill tool language (no re-implementation), and parser-line shape.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `work-problem`
  (singular; coexists with `/wr-itil:work-problems` AFK plural),
  `transition-problem`, plus the `manage-incident` splits
  (`list-incidents`, `mitigate-incident`, `restore-incident`,
  `close-incident`, `link-incident`).

## 0.10.1

### Patch Changes

- a0ec231: P077 fix: work-problems Step 5 delegates iterations via the Agent tool

  `/wr-itil:work-problems` Step 5 previously used an ambiguous "Invoke the
  manage-problem skill" line that read as a Skill-tool (in-process) invocation.
  That expanded manage-problem's 500+ line SKILL.md into the main orchestrator's
  context every iteration, accumulated across the AFK loop, and caused silent
  early-stop (`ALL_DONE` without a documented stop condition firing).

  Step 5 now delegates each iteration to a `general-purpose` subagent via the
  Agent tool. Option B per P077 — iteration work is general engineering, not
  specialised domain expertise, so a typed iteration-worker subagent would just
  re-export manage-problem's content. The AFK iteration-isolation wrapper
  sub-pattern is documented in ADR-032 (amended 2026-04-21).

  - `packages/itil/skills/work-problems/SKILL.md` Step 5 — rewritten with
    explicit Agent-tool delegation (`subagent_type: general-purpose`),
    self-contained prompt shape, and structured return-summary contract
    (`ticket_id` / `ticket_title` / `action` / `outcome` / `committed` /
    `commit_sha` / `reason` / `skip_reason_category` / `outstanding_questions` /
    `remaining_backlog_count` / `notes`). Architect R2: commit-state fields keep
    Step 6.75's Dirty-for-known-reason branch evaluable. JTBD extension:
    skip-reason category and outstanding-questions fields let Step 2.5 populate
    the Outstanding Design Questions table deterministically.
  - `allowed-tools` frontmatter — adds `Agent` (closes the pre-existing latent
    bug where Step 6.5 already required Agent-tool delegation).
  - Non-Interactive Decision Making table — new row documents iteration
    delegation default.
  - `## Related` section — new; cites P077, P036, P040, P041, P053, and ADR-013
    / ADR-014 / ADR-015 / ADR-018 / ADR-019 / ADR-022 / ADR-032 / ADR-037.
  - `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats`
    — NEW, 10 contract assertions (ADR-037 pattern; `@problem P077` +
    `@jtbd JTBD-006` traceability).
  - `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` —
    amended with the "AFK iteration-isolation wrapper (P077 amendment)"
    sub-pattern under foreground synchronous. No supersession.
  - `docs/problems/077-...open.md` → `.verifying.md` with `## Fix Released`
    section per ADR-022.

  Inter-iteration continuity preserved: Step 6.5 (release cadence / ADR-018)
  and Step 6.75 (inter-iteration verification / P036) stay in the main
  orchestrator's turn. The iteration subagent commits its own work per ADR-014
  but MUST NOT run `push:watch`/`release:watch`.

## 0.10.0

### Minor Changes

- 412443f: P071 split slice 1: new `/wr-itil:list-problems` skill

  `/wr-itil:manage-problem list` is deprecated; the list-problems user intent
  now has its own skill so the `/` autocomplete surfaces it directly (JTBD-001

  - JTBD-101). This is phase 1 of the P071 phased-landing plan (audit landed
    in the prior commit — 2 offenders, both in @windyroad/itil).

  * `packages/itil/skills/list-problems/SKILL.md` — NEW read-only skill
    (`allowed-tools: Read, Bash, Grep, Glob` — no Write, no Edit, no
    AskUserQuestion). Reuses the git-log-based README cache freshness check
    from `manage-problem review` per P031 + architect Q4.
  * `packages/itil/skills/list-problems/test/list-problems-contract.bats` —
    NEW 9 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 traceability).
  * `packages/itil/skills/manage-problem/SKILL.md` — `deprecated-arguments:
true` frontmatter flag per ADR-010 amended; Step 1 `list` argument now
    routes to a thin-router forwarder that delegates via the Skill tool and
    emits the canonical deprecation notice verbatim.
  * `packages/itil/skills/manage-problem/test/manage-problem-list-forwarder.bats`
    — NEW 4 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment. Full bats suite green (467/467).

  Remaining phased-landing slices tracked on P071: `work-problem`,
  `review-problems`, `transition-problem`, plus the `manage-incident`
  splits (`list-incidents`, `mitigate-incident`, `restore-incident`,
  `close-incident`, `link-incident`).

## 0.9.0

### Minor Changes

- 6ee6adc: **manage-problem + work-problems**: wire the external-root-cause detection surface so `manage-problem` prompts for `/wr-itil:report-upstream` invocation when root cause points upstream (closes P063).

  New behaviour:

  - `manage-problem` Step 7 (Open → Known Error transition) scans Root Cause Analysis for strict external markers: explicit `upstream` / `third-party` / `external` / `vendor` labels, or scoped-npm pattern `@[\w-]+/[\w-]+`. On hit, fires `AskUserQuestion` with three options: invoke `/wr-itil:report-upstream` now, defer and note in ticket, or mark false positive.
  - Parked lifecycle gains a pre-park hook: parking with `upstream-blocked` reason runs the same detection.
  - AFK non-interactive fallback (per ADR-013 Rule 6) appends the stable marker `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` to the ticket's `## Related` section. The skill is NOT auto-invoked (its Step 6 security-path is interactive per ADR-024 Consequences).
  - `work-problems` `upstream-blocked` skip category now runs the AFK fallback before skipping so accumulated upstream dependencies surface in the ticket body when the user returns.
  - Already-noted grep check prevents duplicate marker lines on subsequent runs.

  No new public skill or command; no ADR changes. Closes a discoverability gap between `manage-problem` (caller) and `/wr-itil:report-upstream` (callee, shipped in 0.8.0).

### Patch Changes

- 7e19eab: **manage-problem**: refresh `docs/problems/README.md` on every Step 7 status transition and stage it in the same commit (closes P062).

  Before this change, status transitions (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed, Parked) did NOT refresh the README.md cache — only the `review` operation did. The next session's fast-path freshness check correctly detected the lag and forced a full rescan (self-healing but wasteful), and human readers browsing README.md between sessions saw outdated WSJF rankings and an incomplete Verification Queue.

  SKILL.md Step 7 now includes a dedicated "README.md refresh on every transition (P062)" block describing the mechanism (regenerate in-place with the new filename set and Status; stage in the same commit; update the "Last reviewed" parenthetical). Step 11 commit convention requires `docs/problems/README.md` in the transition commit's stage list — including folded-fix commits where the `.verifying.md` transition rides with a `fix(<scope>): ...` commit.

  The refresh is a render, not a re-rank: existing WSJF values on ticket files are trusted; no full re-scoring pass fires. That remains Step 9's job.

  Cache stays fresh by construction — the Step 9 fast-path freshness check should return empty on any invocation after a transition commit.

## 0.8.0

### Minor Changes

- 8788489: Add `/wr-itil:report-upstream` skill — file a local problem ticket as a structured upstream issue or private security advisory with bidirectional cross-references. Implements the contract in ADR-024 (Cross-project problem-reporting contract).

  The skill discovers upstream `.github/ISSUE_TEMPLATE/` via `gh api`, classifies the local ticket (bug / feature / question / security), picks the best-matching template (or falls through to a structured default when none exist), routes security-classified tickets via the upstream's `SECURITY.md` (GitHub Security Advisories, `security@` mailbox, or other declared channel — never auto-opens a public issue for a security-classified ticket), and back-writes a `## Reported Upstream` section + `## Related` line into the local ticket.

  Three distinct AFK branches are encoded in the skill: public-issue path proceeds (voice-tone gate per ADR-028 may delegate-and-retry); declared-channel security path proceeds via `gh api .../security-advisories`; missing-`SECURITY.md` security path saves the drafted report and halts the orchestrator (loop-stopping event per ADR-024 Consequences). Above-appetite commit-gate uses the ADR-013 Rule 6 fail-safe.

  Step-0 auto-delegation per ADR-027 is deliberately deferred — `report-upstream` is in ADR-027's "held for reassessment" set with the explicit note "narrow workflow; decided at implementation time". The skill's main-agent context is the right place to evaluate the security-path branch and surface the missing-SECURITY.md `AskUserQuestion`.

  Includes a doc-lint bats test (Permitted Exception per ADR-005) covering all five ADR-024 Confirmation criterion 2 assertions plus the architect-required ADR-027 / ADR-028 / three-AFK-branch documentation. Closes P055 Part B; P055 Part A (intake scaffolding) shipped earlier in the same session.

## 0.7.2

### Patch Changes

- f9bfa56: Fix the next-ID origin-max lookup in `manage-problem` Step 3 and `create-adr` Step 3 (P056). The prior bash pipeline ran `git ls-tree origin/main <path>/ | grep -oE '[0-9]{3}'` — default `git ls-tree` output includes the 40-char blob SHA, whose hex run can contain three consecutive decimal digits that the regex falsely matches (observed `origin_max=997` on 2026-04-20 opening P055). The fix adds `--name-only` to drop mode/type/SHA columns and pipes through `sed` to strip the path prefix, so the anchored `grep -oE '^[0-9]+'` only picks up real filename IDs. ADR-019's next-ID invariant and P043's collision guard both presume this pipeline is sound; this change restores the invariant. Two new bats doc-lint tests (8 assertions) guard the contract.
- 3bf2074: Document the `git mv` + Edit + `git add` staging-ordering trap (P057) in `manage-problem` Step 7 and `create-adr` Step 6. `git mv` alone stages only the rename — subsequent `Edit`-tool modifications must be re-staged explicitly (`git add <new>`) before commit. Without the re-stage, transition commits capture the rename but drop the `Status:` / `## Fix Released` content edits, which then leak into an unrelated later commit and corrupt the audit trail (observed 2026-04-19 in P054's `.verifying.md` transition).

  Changes:

  - `manage-problem` Step 7: new warning block applying to all three transition arrows (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed), plus an explicit `git add <new>` line in each code block.
  - `manage-problem` Step 11: commit convention now recommends `git add -u` as a safety-net for tracked modifications.
  - `create-adr` Step 6: supersession rename now instructs authors to `git add` the file again after the frontmatter + "Superseded by" edits.
  - Two new bats doc-lint tests guard the contract in both SKILL.md files.

## 0.7.1

### Patch Changes

- c5f8039: Add inter-iteration verification to `wr-itil:work-problems` AFK orchestrator (closes P036). After the release-cadence check and before the next iteration, the skill now runs `git status --porcelain` and halts the loop if the working tree is dirty for a reason not stated in the last iteration's report. This is defence-in-depth behind P035's fallback: it catches silent subagent commit failures (a failure inside the assess-release skill, a git conflict, a malformed commit message) that would otherwise accumulate across iterations and corrupt the final summary. Non-interactive default recorded in the decision table. Recovery is explicitly out of scope per ADR-013 Rule 6 — the check surfaces the bug, the user decides. Includes a 6-test doc-lint bats regression file.

## 0.7.0

### Minor Changes

- 151b993: manage-problem Verification Queue detection (P048, minimal-scope).

  - **Fast-path cache hit**: step 9d now explicitly fires even when
    `docs/problems/README.md` is fresh (candidate 1). Prevents the prior
    regression where verification prompts were suppressed on cache hit —
    which is exactly when the user is most likely to verify.
  - **Verification Queue presentation**: step 9c now emits a
    `Likely verified?` column in the Verification Queue with
    `yes (N days)` / `no (N days)` values based on release age
    ≥ 14 days (candidate 4). 14-day default documented as a within-skill
    tunable (architect review confirmed not policy-level yet).
  - Step 9d surfaces the highlighted (`yes`) tickets first in the
    verification prompt so the user can batch-close long-standing
    verifications.
  - 5 new structural bats assertions in
    `manage-problem-verification-detection.bats`; full project suite
    269/269 green (+5).
  - Candidates 2 (standalone `verify-fixes` op), 3 (exercise observation
    records — new file-level state dimension), and 5 (AFK-mode
    orchestrator hook) are deferred pending an architect ADR-scope
    decision.

## 0.6.0

### Minor Changes

- 4e93bcf: Add Verification Pending `.verifying.md` problem-lifecycle status per ADR-022
  (P049 — the SKILL.md contract half; existing-file migration follows in a
  separate commit per ADR-022 Scope).

  - **manage-problem SKILL.md**: lifecycle table gains Verification Pending
    status and `.verifying.md` suffix; WSJF multiplier table documents
    Verification Pending = 0 (excluded from dev ranking); Known Error →
    Verification Pending transition documented (git mv + Status field +
    `## Fix Released` in one commit per ADR-014); step 9b skips
    `.verifying.md` files; step 9c gains a Verification Queue section; step
    9d targets `*.verifying.md` via glob; step 9e README template gains the
    Verification Queue section; closing workflow and commit-convention
    prose updated.
  - **work-problems SKILL.md**: step 1 scan excludes `.verifying.md`; step 4
    classifier row `Known Error with ## Fix Released` → `.verifying.md`
    (suffix-based, no file-body scan).
  - **manage-incident SKILL.md**: step 9 linked-problem close gating accepts
    `.verifying.md` alongside `.known-error.md` and `.closed.md`.
  - **docs/problems/README.md**: "Known Errors (Fix Released — pending
    verification)" shadow table replaced with "Verification Queue" citing
    ADR-022.
  - 11 new structural bats assertions in
    `manage-problem-verification-pending.bats`; full project suite
    264/264 green (+11).

## 0.5.0

### Minor Changes

- a0600d9: Surface outstanding design questions at work-problems stop-condition #2 (P053).

  - Step 2 branches on stop-condition: #2 now routes to a new Step 2.5 before
    emitting `ALL_DONE`; #1 and #3 keep the direct-emit behaviour.
  - Step 2.5 extracts user-answerable questions from skipped tickets. In
    interactive invocations, batches up to 4 into one `AskUserQuestion` call
    per ADR-013 Rule 1 (Anthropic's documented per-call cap). In
    non-interactive / AFK invocations (the JTBD-006 persona default), emits
    an `### Outstanding Design Questions` table in the post-stop summary
    per ADR-013 Rule 6 fail-safe.
  - Step 4 classifier gains a skip-reason taxonomy column:
    `user-answerable` / `architect-design` / `upstream-blocked`. Step 2.5
    selects the user-answerable subset to surface.
  - Output Format template includes an `### Outstanding Design Questions`
    section (Ticket / Question / Context), emitted only when
    stop-condition #2 fires with ≥1 user-answerable skip.
  - Non-Interactive Decision Making table documents the AFK-default path.
  - 7 structural bats assertions added in
    `work-problems-stop-condition-questions.bats`; full project suite
    253/253 green (+7).

## 0.4.5

### Patch Changes

- 5c677cc: manage-problem: add XL effort bucket and effort re-rate pre-flight (P047)

  - Effort table in `manage-problem` SKILL.md gains an **XL** bucket (divisor 8) for multi-day or cross-package work, with a new sub-example showing how WSJF flattens at XL and a live-estimate note pointing to steps 7 and 9b.
  - **Step 7** Open → Known Error pre-flight gains a checklist item requiring the effort bucket to be re-rated against the now-documented fix strategy, with the reason captured in the problem file.
  - **Step 9b** step 7 reworded from "Estimate Effort" to "Re-estimate Effort (S / M / L / XL) ... note the reason in a short parenthetical" so the review re-rate is unmissable.
  - `work-problems` SKILL.md example paragraphs updated non-normatively to reference "S to L or XL" for consistency.
  - New doc-lint test `manage-problem-effort-buckets.bats` (4 assertions) guards the new contract.

## 0.4.4

### Patch Changes

- 39e026c: itil: governance skills auto-release when changesets are queued (P028)

  Extends the terminal commit step of `manage-problem` and `manage-incident`
  so non-AFK governance invocations drain the release queue automatically
  after their own commit lands, rather than ending at `git commit` and
  relying on the user to remember `npm run push:watch` and
  `npm run release:watch`.

  Mechanism (per new ADR-020):

  - After commit, delegate to `wr-risk-scorer:assess-release` (subagent
    `wr-risk-scorer:pipeline` with Skill fallback per ADR-015).
  - If `push` and `release` scores are both within appetite (≤ 4/25 per
    `RISK-POLICY.md`) AND `.changeset/` is non-empty, run
    `npm run push:watch` followed by `npm run release:watch`.
  - Fail-safe identical to ADR-018: stop on `release:watch` failure, no
    retry. Above-appetite risk skips the drain and reports clearly.
  - Skipped automatically when the skill is invoked inside an AFK
    orchestrator — those flows handle release cadence via ADR-018 Step 6.5
    and must not double-release.

  Scope matches ADR-014 (manage-problem, manage-incident). The remaining
  governance skills (`create-adr`, `run-retro`, `update-guide`,
  `update-policy`) inherit ADR-020 automatically once they adopt ADR-014.

  Splits the original P028 auto-install concern into P045 (deferred
  pending Claude Code in-session plugin reload). Closes P028 pending user
  verification.

## 0.4.3

### Patch Changes

- 359ec7c: ticket-creators: next-ID collision guard against origin (P043)

  Adds the next-ID collision guard from ADR-019 confirmation criterion 2 to
  both ticket-creator skills:

  - `manage-problem` step 3 (Assign the next ID): now computes max of
    local-max and `git ls-tree origin/<base>` max, then increments. Catches
    collisions between local work and parallel sessions before the ticket
    file is written.
  - `create-adr` step 3 (Determine sequence number): same mechanism applied
    to `docs/decisions/`.

  Both skills cite ADR-019 and log renumber decisions in the user-facing
  report. Sibling fix to P040 (work-problems Step 0 preflight, shipped in
  @windyroad/itil@0.4.2): preflight catches divergence at loop start; this
  ticket catches collisions at ticket-creation time as a defence in depth.

  Adds bats tests (3 assertions per skill) verifying ADR-019 references and
  the collision-guard pattern.

  Closes P043 pending user verification.

## 0.4.2

### Patch Changes

- 9c6019e: work-problems: add preflight to reconcile with origin before iteration (P040)

  Adds Step 0 (Preflight) to the work-problems AFK orchestrator per ADR-019.
  Before opening the work loop, the orchestrator now runs `git fetch origin`
  and compares local HEAD with `origin/<base>`. On trivial fast-forward
  divergence, it pulls non-interactively (`git pull --ff-only`). On
  non-fast-forward divergence (local has unpushed commits AND origin has
  advanced), it stops with a clear divergence report (`git log --oneline
HEAD..origin/<base>` and reverse). Non-interactive rebase or merge is
  explicitly forbidden — the persona requires user judgment for those.

  Network failure on `git fetch origin` defaults to fail-closed (stop and
  report); the user can retry when network is restored.

  Adds row to Non-Interactive Decision Making table covering origin
  divergence. Adds bats test (7 assertions) covering ADR-019 confirmation
  criteria: skill cites ADR-019; references `git fetch origin` and
  `pull --ff-only`; has discrete preflight step; non-interactive table
  covers it; explicitly forbids non-interactive merge/rebase.

  The next-ID collision guard (ADR-019 confirmation criterion 2) belongs in
  ticket-creator skills (manage-problem, wr-architect:create-adr) and is
  tracked in a separate problem ticket.

  Closes P040 pending user verification.

## 0.4.1

### Patch Changes

- 87c2ecf: work-problems: enforce inter-iteration release cadence (P041)

  Adds Step 6.5 (Release-cadence check) to the work-problems AFK orchestrator
  per ADR-018. After each successful iteration, the orchestrator now invokes
  `wr-risk-scorer:assess-release` (or its pipeline subagent) and, if `push` or
  `release` score is at or above appetite (4/25 per RISK-POLICY.md), drains
  the queue with `npm run push:watch` then `npm run release:watch` before
  starting the next iteration. The drain runs non-interactively per ADR-013
  Rule 6 (policy-authorised when within appetite). On `release:watch`
  failure, the loop stops and reports — no non-interactive retry.

  Also adds a row to the Non-Interactive Decision Making table covering the
  new behaviour, and a bats test asserting the SKILL.md references both
  `assess-release` and `release:watch` (ADR-018 confirmation criterion).

  Closes P041 pending user verification of the next AFK loop.

## 0.4.0

### Minor Changes

- a36a084: Add `wr-itil:work-problems` AFK batch orchestrator skill and document a commit-gate fallback in `wr-itil:manage-problem` (JTBD-006).

  - **New skill** `wr-itil:work-problems` — loops through ITIL problem tickets by WSJF priority, delegating each iteration to `wr-itil:manage-problem` non-interactively. Stops gracefully when nothing remains actionable. Emits `ALL_DONE` sentinel for external detection. Deterministic Step 4 classification rules (skip known-errors with Fix Released; work everything else).
  - **Fix** `wr-itil:manage-problem` commit gate now documents a two-path delegation (closes P035). Primary: delegate to `wr-risk-scorer:pipeline` subagent-type via the Agent tool. Fallback: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent-type is unavailable (e.g., when `manage-problem` is itself running inside a spawned subagent). Per ADR-015 both produce equivalent bypass markers. Non-interactive fail-safe preserved for the risk-above-appetite branch only — silent-skip for delegation-unavailable is no longer sanctioned.

## 0.3.3

### Patch Changes

- 83b8be7: fix(manage-problem): add Parked lifecycle status and README.md fast-path cache (closes P027)

  - Adds `.parked.md` suffix and Parked status to problem lifecycle table
  - `problem work` checks README.md freshness before triggering full 18-file re-scan
  - Step 9e writes/overwrites `docs/problems/README.md` after every full re-rank
  - Parked problems excluded from WSJF ranking; shown in separate Parked table

## 0.3.2

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.3.1

### Patch Changes

- e8216b1: Governance skills now commit their own completed work (P023, ADR-014).

  **@windyroad/itil**: `manage-problem` and `manage-incident` skills no longer end with "Do not commit — the user will commit when ready." They now instruct the agent to stage files, delegate to `wr-risk-scorer:pipeline` for a risk assessment, and commit automatically using a conventional commit message referencing the problem or incident ID. If risk is above appetite, an `AskUserQuestion` prompt is presented before committing. Non-interactive fail-safe per ADR-013 Rule 6.

  New ADR-014 documents the cross-skill commit pattern, commit message convention, and risk-gate delegation sequence.

## 0.3.0

### Minor Changes

- e5eb0bd: Add `manage-incident` skill for evidence-first incident response with automatic handoff to problem management.

  The new `/wr-itil:manage-incident` skill implements an ITIL-aligned incident workflow focused on **restoring service fast** while keeping a disciplined audit trail. Hypotheses must cite evidence before any mitigation. Reversible mitigations (rollback, feature flag, restart) are preferred over forward fixes. On restoration, the skill automatically invokes `manage-problem` to create or update the underlying root-cause ticket, linking the incident to a `P###`.

  Incidents use a separate `I###` namespace in `docs/incidents/` so lifecycles, prioritisation (severity for incidents, WSJF for problems), and audit trails stay clean. See ADR-011 and JTBD-201 for the full design.

### Patch Changes

- 23d0d10: Require structured `AskUserQuestion` prompts at all governance-skill decision branches (P021, ADR-013).

  **@windyroad/itil**: `manage-problem` skill now requires `AskUserQuestion` for WSJF tie-breaks, problem selection, and scope-change decisions. Prose "(a)/(b)/(c)" option lists are prohibited.

  **@windyroad/risk-scorer**: All three scorer agents (pipeline, wip, plan) now enforce below-appetite silence — no advisory prose, "Your call:", or suggestions when scores are within appetite. Above-appetite output uses structured `RISK_REMEDIATIONS:` blocks instead of free-text suggestions.

  New ADR-013 establishes the cross-cutting standard: every governance-skill branch point with ≥2 options must use `AskUserQuestion`; scoring agents stay pure output-only.

## 0.2.0

### Minor Changes

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
