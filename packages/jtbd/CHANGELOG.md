# @windyroad/jtbd

## 0.8.4

### Patch Changes

- 115b2f2: JTBD review flags changes built on an unratified persona or job (ADR-068 surface 3, RFC-011, P323).

  The jtbd agent now emits a new [Unratified Dependency] verdict: when a change or plan explicitly cites, implements, or serves a persona or job that lacks `human-oversight: confirmed` (unratified, and not superseded), it reports ISSUES FOUND with the action "ratify it via /wr-jtbd:confirm-jobs-and-personas before this lands." This is the JTBD twin of the architect side's surface-3 control (RFC-010 / P318).

  - Keyed on the human-oversight marker, NOT on `status:` — building on a ratified job is fine even when its status is still `proposed` (status and oversight are orthogonal axes).
  - The agent runs the new `wr-jtbd-is-job-or-persona-unconfirmed` predicate by exit code (the jtbd agent has Bash) — the single-artifact sibling of the architect's `is-decision-unconfirmed`, resolving `persona: <name>` and `JTBD-NNN` refs over the ADR-008 layout and keeping its marker grammar in sync with `detect-unoversighted`.
  - Bounded to explicit cite/implement (not ambient alignment); the inverse-P078 over-fire guard. Unlike the architect surface, the JTBD unratified set is currently large (P288 drain in progress), so this fires more often until that drain completes — the intended forcing function.
  - Closes the JTBD-surface half of the build-on-unratified gap (the ADR-surface half is P318/RFC-010); completes the JTBD oversight surface-set (surfaces 1 & 2 shipped via ADR-068/P288).

## 0.8.3

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

## 0.8.2

### Patch Changes

- 3cfa6fc: **P0 hotfix**: Phase 3 retroactive rollout (d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins) wrote per-surface maturity records at top-level `plugin.json` keys (`skills:` / `agents:` / `hooks:` / `commands:`). Claude Code's plugin manifest validator rejects that shape with `Validation errors: hooks: Invalid input, skills: Invalid input`. All 11 plugins were unparseable by `claude plugin install`.

  **Fix** (ADR-063 Amendment 2026-05-18): per-surface maturity records nest UNDER the top-level `maturity:` key at `plugin_doc.maturity.<kind>.<name>`. Schema version bumps to "2.0" (path move is NOT additive per ADR-058 §Confirmation #8). Populate script (`packages/itil/scripts/plugin-maturity-populate.sh`) writes to the new nested location; render script (`packages/itil/scripts/plugin-maturity-render.sh`) reads from the new nested location. Defensive cleanup of legacy top-level keys on re-runs. Bats fixtures (populate + render + drift) updated to new shape — 17 + 17 + 14 green. Manifest fix-up applied to all 11 affected plugin.json files.

  **Hotfix-class bypass** per ADR-013 Rule 5 (reducing — closes a defect that broke `claude plugin install` for all adopters).

## 0.8.1

### Patch Changes

- d33bb7d: P087 Phase 3 — retroactive maturity rollout across all 11 `@windyroad/*` plugins. Each plugin's `plugin.json` now carries a populated `maturity:` field per top-level surface (skills, agents, hooks, commands) plus a `{schema_version, band}` rollup on the plugin root entry per ADR-063 §plugin.json field schema. Each plugin's README now carries a prose-woven rollup badge (`*Maturity: <Band>.*`) in the value-framing lead prose line per ADR-051 anti-pattern + ADR-063 §README badge rendering format.

  Mechanical activation of Phase 3a (`wr-itil-plugin-maturity-populate`) and Phase 3b (`wr-itil-plugin-maturity-render`) against the live monorepo. Bootstrapping window active (suite-oldest surface 39 days shipped, less than 60-day threshold per ADR-053 §Bootstrapping clause); most surfaces land at Experimental with one Alpha bootstrapping surface (`wr-architect:agent` — meets the ≥100 invocations + ≥14 days criterion). Plugin root rollups all resolve to Experimental per the worst-case granularity contract (ADR-053 §granularity contract).

  Drift detector (`wr-retrospective-check-plugin-maturity-drift`) reports 0 drift instances across all 12 packages — rendered badges match canonical records. Anti-pattern absence verified: no standalone `## Maturity` section, no shields.io URL, no compound bootstrapping rendering in per-skill cells (compound stays at rollup per ADR-063).

  Closes the P087 Phase 3 retroactive mechanical rollout investigation task (P087 line 133). Activates the four Phase 3d JTBD outcome amendments shipped in P240: JTBD-302 maturity-band visibility, JTBD-007 maturity-band currency, JTBD-101 promotion-criteria visibility, JTBD-003 at-glance stability.

## 0.8.0

### Minor Changes

- b60f576: P170 Phase 2 Slice 2.5 — hook exemption globs for the governance-managed story-map + story surfaces (ADR-060 § Phase 2 amendment 2026-05-12 lines 481-496). Adds path-based exemptions for `docs/story-maps/**/*.html` and `docs/stories/**/*.md` across four PreToolUse enforce-edit hooks:

  - `packages/architect/hooks/architect-enforce-edit.sh` — case-statement exemption alongside existing `docs/problems/` and `docs/jtbd/` entries
  - `packages/jtbd/hooks/jtbd-enforce-edit.sh` — same case-statement exemption pattern
  - `packages/style-guide/hooks/style-guide-enforce-edit.sh` — exemption short-circuit BEFORE the `*.css|*.html|*.jsx|...` opt-in extension check
  - `packages/voice-tone/hooks/voice-tone-enforce-edit.sh` — exemption short-circuit BEFORE the `*.html|*.jsx|...` opt-in extension check; closes the empirical block documented at P170 line 297 (STORY-MAP-001 bootstrap rejected on first HTML write)

  `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh` left untouched — it gates only `RISK-POLICY.md` and never fires on story-maps/stories paths, so no exemption is needed (the ADR's "5 hooks" framing is structurally inaccurate at this surface; documented in commit body).

  Behavioural bats coverage (per ADR-052) across all four hooks: 6 new test cases each in architect-enforce-scope + jtbd-enforce-scope (extending existing files); new style-guide-enforce-scope.bats (5 cases) + new voice-tone-enforce-scope.bats (6 cases). 159 total tests across the four affected plugins' hook suites pass with zero regressions.

  Unblocks Phase 2 Slices 3-6 (story-map skills) and Slice 14 (STORY-MAP-001 bootstrap migration) per architect finding 1 on the P170 Phase 2 Slice 3 design review 2026-05-12 — these slices were blocked because their behavioural bats fixtures must perform HTML writes that the unmodified hooks rejected outright. Takes effect for adopters (including this repo) after the next marketplace release cycle + `/install-updates` + session restart.

## 0.7.3

### Patch Changes

- 670929a: P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T1: dual-pattern hook glob widening for `docs/problems/` migration

  `packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` gain a sibling exemption pattern (`docs/problems/*/*.md` + `*/docs/problems/*/*.md`) alongside the existing flat-layout pattern (`docs/problems/*.md` + `*/docs/problems/*.md`). The dual-pattern shape is forward-compatible: the new pattern matches zero files today (the per-state subdirs do not exist yet); the existing pattern continues to exempt the current flat-layout ticket files.

  **Why this is the first sub-task of RFC-002**:

  ADR-031 § Hook exemption glob contract notes that the flat-layout pattern matches zero files post-migration (shell `*` does not cross `/`), so any subsequent commit that migrates ticket files would immediately trigger architect+jtbd edit-gate denials on its own transition bookkeeping (`git mv` + Edit + re-stage on a ticket file). ADR-031 originally required hook update + migration in ONE big landing commit to bridge this gap.

  ADR-014 single-purpose grain dominates that single-shot framing. T1 lands the dual-pattern as a separate ADR-014-grain commit BEFORE the migration; T6 (post-migration cleanup) drops the flat-layout half once T5's bulk migration verifies. The dual-pattern window spans T1 → T6 and bounds the transient layout-coexistence exposure flagged in JTBD-001 amendment-drift (per ADR-060 Reassessment criterion).

  **No current behaviour changes**:

  - Flat-layout ticket-edits continue to skip the architect+jtbd gate (existing pattern matches).
  - Per-state subdir ticket-edits (none today) would also skip the architect+jtbd gate (new pattern would match if such files existed).
  - All other file paths continue to enter the gate as before.

  **ADR-014 single-purpose grain check**: the commit changes one logical thing — the exemption-glob shape on the two enforce-edit hooks — across two package boundaries that share the same exemption contract. Per ADR-014 § "single-purpose" guidance, "one logical change across multiple files" satisfies the grain when the files share the contract being changed.

  **JTBD impact**:

  - **JTBD-001** (governance without slowing down) — neutral now; enables the directory-skimmability win when T5 ships.
  - **JTBD-101** (atomic-fix-adopter friction guard) — neutral; no new gate, no new prompt; dual-pattern preserves existing adopter behaviour.
  - **JTBD-006** (AFK orchestrator) — neutral; the hooks remain idempotent.
  - **JTBD-201** (tech-lead audit trail) — neutral now; enables the directory-as-audit-trail win when T5 ships.
  - **JTBD-301** (plugin-user no-pre-classification) — untouched.

  **Held-changeset window scope**:

  This entry lands under the ADR-060 § Confirmation criterion 6 atomicity contract — held alongside the Slice 4 entries (`wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md` + `wr-itil-p170-slice-4-b7-capture-problem-type-prompt.md`) and the Slice 2-3 entries (`wr-itil-p170-rfc-framework-phase-1.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md`). The full chain graduates atomically per architect finding 12 once RFC-001 reaches `closed` post-Slice-5 forward-dogfood (which RFC-002 itself drives to closure).

  **Out of scope (deferred to subsequent T-tasks)**:

  - T2: dual-tolerant SKILL.md glob updates across `manage-problem`, `work-problems`, `manage-incident`, `report-upstream`, `run-retro` (plus forward audit on `capture-rfc` + `manage-rfc` per architect advisory 2026-05-07).
  - T3: bats fixture audit + dual-tolerant assertions.
  - T4: `docs/problems/README.md` generation logic dual-tolerant.
  - T5: bulk migration commit (rename + ADR-031 proposed→accepted + ADR-022 / ADR-016 / ADR-024 amendments).
  - T6: drop dual-pattern compatibility post-verification.
  - T7-T11: Slice B adopter auto-migration (shared routine, manage-problem + work-problems integration, bats, ADR-014 commit-gate marker).

  Refs: RFC-002

## 0.7.2

### Patch Changes

- 1fe2cad: Gate markers now survive long-running Agent and Bash subprocesses (P111).

  A new PostToolUse hook (`*-slide-marker.sh`) fires on Agent and Bash tool
  completion in the parent session. If the parent already holds a valid gate
  marker, the hook touches it — sliding the TTL window forward — so the wall-
  clock time spent inside an Agent-tool subagent or a `claude -p` iteration
  subprocess no longer counts against the parent's TTL.

  The slide is bounded:

  - The hook only TOUCHES an existing marker. It NEVER creates one — creation
    still requires a real gate review with verdict parsing in
    `*-mark-reviewed.sh`.
  - The hook skips the touch when `tool_response.is_error` is true. A failed
    subprocess does not extend the parent's trust window.
  - For risk-scorer, only the score files (`commit`, `push`, `release`) are
    slid. The `*-born` markers are deliberately invariant under sliding so
    the 2×TTL hard-cap from P090 still bounds total marker life.

  This replaces the symptom-treatment of P107 (TTL bumped 1800s → 3600s) with
  the architectural fix per ADR-009's new "Subprocess-boundary refresh"
  subsection. Adopters who configured a non-default `ARCHITECT_TTL` /
  `REVIEW_TTL` / `RISK_TTL` envvar do not need to change anything.

## 0.7.1

### Patch Changes

- 5d367e9: P100 slice 1 — `jtbd-enforce-edit.sh` + `jtbd-eval.sh` extended to exempt `docs/briefing/*` from the JTBD edit gate, alongside the existing `docs/BRIEFING.md` exemption. Mirrors the architect plugin update so the new per-topic briefing layout works with both governance plugins installed. Scope bats test added.

## 0.7.0

### Minor Changes

- db104da: P095 — UserPromptSubmit hooks across all five windyroad plugins now emit the full MANDATORY instruction block only on the first prompt of a session; subsequent prompts emit a ≤150-byte terse reminder. Reclaims ~120KB / ~30k tokens per 30-turn session in a 3-active-hook project (~80% of the prior per-prompt hook preamble). Detection and enforcement semantics are unchanged — the `PreToolUse` edit gate remains the enforcement surface; only the reminder prose is gated.

  **New:**

  - Canonical helper `packages/shared/hooks/lib/session-marker.sh` with `has_announced` + `mark_announced` functions (empty-SESSION_ID fallback: no-op, never crashes).
  - Five per-plugin byte-identical copies at `packages/<plugin>/hooks/lib/session-marker.sh` for `architect`, `jtbd`, `tdd`, `style-guide`, `voice-tone`. Distributed via `scripts/sync-session-marker.sh` with `--check` mode + `npm run check:session-marker` + CI step per ADR-017 / ADR-028.
  - ADR-038 "Progressive disclosure + once-per-session budget for UserPromptSubmit governance prose" codifies the pattern, the marker-path convention (`/tmp/${SYSTEM}-announced-${SESSION_ID}`), the ≤150-byte per-prompt budget, the four-element terse-reminder shape (MANDATORY signal word + gate name + trigger artifact + delegation affordance), and the `tdd-inject.sh` dynamic-state carve-out.

  **Changed:**

  - `packages/architect/hooks/architect-detect.sh` — gates the full MANDATORY ARCHITECTURE CHECK block behind `has_announced "architect" "$SESSION_ID"`; subsequent prompts emit `MANDATORY architecture gate active (docs/decisions/ present). Delegate to wr-architect:agent before editing project files.` Absent-`docs/decisions/` branch unchanged.
  - `packages/jtbd/hooks/jtbd-eval.sh` — same pattern for the JTBD CHECK; terse reminder cites `docs/jtbd/ present` and `wr-jtbd:agent`. Absent-`docs/jtbd/README.md` branch unchanged.
  - `packages/tdd/hooks/tdd-inject.sh` — special case per ADR-038 carve-out: static prose (STATE RULES table, WORKFLOW, IMPORTANT) is gated; dynamic TDD state (IDLE/RED/GREEN/BLOCKED) and tracked test files list emit every prompt. No-test-script fallback branch unchanged.
  - `packages/style-guide/hooks/style-guide-eval.sh` — same pattern; terse reminder cites `docs/STYLE-GUIDE.md present` and `wr-style-guide:agent`.
  - `packages/voice-tone/hooks/voice-tone-eval.sh` — same pattern; terse reminder cites `docs/VOICE-AND-TONE.md present` and `wr-voice-tone:agent`.

  **Tests (bats):**

  - `packages/shared/test/session-marker.bats` — 9 unit tests for the helper.
  - `packages/shared/test/sync-session-marker.bats` — 6 drift-check tests.
  - `packages/architect/hooks/test/architect-detect-once-per-session.bats` — 8 behavioural tests.
  - `packages/jtbd/hooks/test/jtbd-eval-once-per-session.bats` — 8 behavioural tests.
  - `packages/tdd/hooks/test/tdd-inject-once-per-session.bats` — 8 behavioural tests, including the dynamic-state carve-out assertion.
  - `packages/style-guide/hooks/test/style-guide-eval-once-per-session.bats` — 7 behavioural tests.
  - `packages/voice-tone/hooks/test/voice-tone-eval-once-per-session.bats` — 7 behavioural tests.
  - Full suite: 735/735 green.

  Backward-compatible for consumers: first-prompt output is byte-identical to the pre-change behaviour; only the second+ prompts see the terse reminder. Downstream tooling that parses the MANDATORY block text (none known) would still see the full text on the first prompt.

  Closes P095. Transitions the ticket from `.known-error.md` to `.verifying.md` per ADR-022.

## 0.6.0

### Minor Changes

- 6dd6a77: **Breaking change for external adopters**: remove the `docs/JOBS_TO_BE_DONE.md` runtime fallback. Canonical JTBD layout is now `docs/jtbd/` only (ADR-008 Option 3 chosen 2026-04-20 per P019).

  **Who is affected**: any project still using the legacy single-file `docs/JOBS_TO_BE_DONE.md` layout. The JTBD gate, agent, and CI validation no longer consult the legacy file.

  **Migration**: run `/wr-jtbd:update-guide` — it is the **sole** component in the suite permitted to read `docs/JOBS_TO_BE_DONE.md`, and only for one-shot migration into the `docs/jtbd/` directory layout. After migration, the legacy file can be deleted (git history is the archive).

  **Runtime changes**:

  - `@windyroad/jtbd` eval hook no longer injects the "docs/JOBS_TO_BE_DONE.md" enforcement variant; missing `docs/jtbd/` triggers an update-guide recommendation.
  - `@windyroad/jtbd` enforce hook no longer exempts the legacy file and no longer falls back to it. On projects without `docs/jtbd/`, the gate blocks with a `/wr-jtbd:update-guide` suggestion.
  - `@windyroad/jtbd` mark-reviewed hook no longer stores a hash against the legacy file; it exits early when `docs/jtbd/` is absent.
  - `@windyroad/jtbd` agent description and lookup logic now reference only `docs/jtbd/`.
  - `@windyroad/architect` enforce hook no longer exempts `docs/JOBS_TO_BE_DONE.md` as a peer-plugin policy artefact (it is no longer a recognised governance artefact).
  - `@windyroad/architect` detect hook's "does not apply to" list no longer mentions `docs/JOBS_TO_BE_DONE.md`.

  **Documentation changes**:

  - ADR-008 amended: Option 3 "Directory-only, no fallback" added as the chosen option; Option 1 retained with dated rejection (2026-04-19) so the rationale chain is readable.
  - ADR-005 line 138 rephrased to reflect the single canonical path.
  - ADR-007 supersession note extended to call out the artefact-name change (format, not just structure).
  - `wr-jtbd:update-guide` SKILL.md documents the migration carve-out explicitly.
  - This repository's own `docs/JOBS_TO_BE_DONE.md` stub is deleted (it was a 5-line redirect with no unique content).
  - Bats tests in `jtbd-eval`, `jtbd-enforce-scope`, `jtbd-mark-reviewed`, and `architect-enforce-scope` inverted to assert the legacy-file path is not consulted.

## 0.5.2

### Patch Changes

- 6e7c2e4: Strengthen the `wr-jtbd:agent` output contract to forbid bare verdicts without remediation guidance (closes P037). The agent now treats the inline response as the primary authoritative channel and the `/tmp/jtbd-verdict` file as a subordinate internal signal. Every response must begin with a structured `JTBD Review: PASS | ISSUES FOUND | JOB UPDATE NEEDED | PERSONA UPDATE NEEDED` line and, on non-PASS verdicts, include file + line + issue + affected job + suggested fix. "FAIL" alone or a bare file list is now explicitly forbidden. Includes a 7-test doc-lint bats regression file.

## 0.5.1

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.5.0

### Minor Changes

- b7d6739: Add on-demand assessment skills (P020)

  New user-invocable skills per ADR-015:

  - `wr-risk-scorer:assess-release` — pipeline risk score on demand; pre-satisfies the commit gate
  - `wr-risk-scorer:assess-wip` — WIP risk nudge for the current uncommitted diff
  - `wr-architect:review-design` — on-demand ADR compliance review
  - `wr-jtbd:review-jobs` — on-demand persona/job alignment check

  All four skills are discoverable via `/` autocomplete and delegate to existing
  governance subagents. No hook gate changes; bypass marker is still written by
  the PostToolUse hook after the pipeline subagent runs.

## 0.4.0

### Minor Changes

- fe1b903: Gate markers now persist across prompts (ADR-009). Removed Stop-hook reset scripts from all 5 review plugins. Marker lifecycle is now governed entirely by TTL (30 min default, configurable via `*_TTL` env vars) + drift detection of policy files. Resolves P001 — reviews no longer need to re-run on every prompt. Note: this is a behaviour change; users who relied on fresh-review-every-prompt should set a shorter TTL.

## 0.3.1

### Patch Changes

- ec16630: Add project-root check to all enforce hooks (P004). Absolute file paths outside the current project (e.g., ~/.claude/channels/discord/access.json) are no longer gated — gates now only fire on files within the project root.

## 0.3.0

### Minor Changes

- 2b39c9e: Migrate JTBD plugin to docs/jtbd/ directory structure with per-persona directories and individual job files (ADR-008). Backward compatible with docs/JOBS_TO_BE_DONE.md.

## 0.2.1

### Patch Changes

- e6a916a: Fix chicken-and-egg bug where JTBD enforce hook blocked creation of docs/JOBS_TO_BE_DONE.md itself (P002)

## 0.2.0

### Minor Changes

- 93527a5: Broaden JTBD enforcement to all project files, not just web UI files. JTBD is a product-level concern that applies to any project type.

## 0.1.3

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
