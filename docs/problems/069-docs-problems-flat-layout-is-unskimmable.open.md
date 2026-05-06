# Problem 069: docs/problems/ flat layout is unskimmable — migrate to per-state subdirectories

**Status**: Open
**Reported**: 2026-04-20
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Certain (5)
**Effort**: XL (re-rated from L 2026-04-20 post-architect review on auto-migration addition) — bulk `git mv` of ~72 existing tickets (this repo) + update path references across 5+ SKILL.md files (manage-problem, work-problems, manage-incident, report-upstream, run-retro) and their ~30 bats tests + update README.md generation + draft ADR-031 (done — ADR-031 `proposed`) + in-place amendments to ADR-022, ADR-016, ADR-024, `packages/risk-scorer/agents/wip.md` + hook-exemption glob updates in architect-enforce-edit.sh + jtbd-enforce-edit.sh + **auto-migration logic shipped inside `manage-problem` AND `work-problems` for adopter repos** (per-project on first-run, ADR-017-style shared routine candidate, with ADR-027 Step 0 collision to resolve + ADR-014 commit-gate treatment to resolve + novel "plugin-driven repo migration" pattern question). Cross-plugin reach + multi-ADR amendment + novel distribution pattern = XL territory.
**WSJF**: 1.875 — (15 × 1.0) / 8 — re-rated from 3.75 at 2026-04-20 after scope expansion (auto-migration + architect-raised execution-time questions). High severity / ecosystem-wide navigation friction remains unchanged; the migration lift + architectural open questions justify the XL bucket.
**Type**: technical

## Priority pull-forward (2026-04-26 user direction — post-AFK-loop /wr-retrospective:run-retro AskUserQuestion)

**Override WSJF math: pull P069 forward to the next AFK loop's first iter.** WSJF 1.875 (XL after the auto-migrate-adopter-repos scope add) underrates the readability friction the user is hitting visibly across every retro / manage-problem / reconcile-readme caller (`docs/problems/README.md` at 30K tokens hits the Read tool's 25K-token budget per iter 6's pipeline-instability finding). Manual priority overrides the automated ranking.

**Architect re-rate effort + scope-split**: at the next AFK loop's iter-1, the architect should re-evaluate whether the scope is genuinely XL or whether it splits cleanly into:

- **Slice 1**: per-state subdirs in THIS repo only (`docs/problems/{open,known-error,verifying,closed,parked}/<NNN>-...md`). Bulk `git mv` + path-reference updates across SKILL.md files + bats tests + README.md generation logic. Effort L. Independently shippable.
- **Slice 2**: auto-migrate adopter repos (the lift that pushed effort to XL). Migration logic in the README-refresh block per the 2026-04-21 Direction decision below. Effort M-L. Ships AFTER slice 1 demonstrates the layout's value.

ADR-041 partial-progress pattern blesses the slice-1-without-slice-2 shipping path with a held changeset for slice 2 if needed. WSJF re-rate at the next `/wr-itil:review-problems` invocation should reflect the slice-split: slice 1 lands at WSJF 3.75 (L effort) which matches the 3.0 tier; slice 2 stays in XL territory until slice 1 lands.

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**Migration trigger**: **detect-and-migrate inside the problem README.md refresh step** (P062's Step 7 "README.md refresh on every transition" block in `manage-problem` SKILL.md). Every Step 7 transition already regenerates `docs/problems/README.md`; extend that block to also:

1. Detect flat-layout (any `docs/problems/*.<state>.md` files at the top level rather than inside per-state subdirs).
2. If detected: run the bulk `git mv` migration as part of the same Step 7 commit. Migration is a render-side concern, not a separate opt-in step.

**Why this shape beats the install-updates-based migration**:
- Migration fires naturally on first transition per adopter repo (no separate invocation to remember).
- Same-commit atomicity: README.md refresh + migration land together, no intermediate mixed-state commit.
- No dedicated migration skill needed; `/wr-itil:manage-problem` already owns the README refresh surface.
- Adopter repos that never transition tickets in the AFK loop wait until the next manual transition — acceptable because the flat layout is still functional, just unskimmable.

Supersedes the 2026-04-20 direction below (which proposed auto-migration inside manage-problem AND work-problems independently). This shape centralises the migration in the README-refresh block, eliminating the dual-location risk.

**User note**: *"when we are updating the problem README.md, can't we detect then and migrate if detected?"* — exact framing of the chosen direction.

## Direction decision (2026-04-20, user — AFK pre-flight via AskUserQuestion) — superseded by 2026-04-21 above

**Filename suffix**: **drop** the `.<state>.md` suffix. The directory path is the single source of truth for state. Filename is `<NNN>-<title>.md`. Every transition is a single `git mv` between directories — no suffix rename. The Status field in the ticket body frontmatter remains as a human-readable indicator, but machine-readable state comes from `$(basename $(dirname <path>))`.

**Defaults AFK can apply without further user input**:
- New ADR drafts as `docs/decisions/NNN-problem-ticket-directory-layout.proposed.md` (next free number; `/wr-architect:create-adr` handles allocation per ADR-019).
- Subdirectory names (kebab-case): `open`, `known-error`, `verifying`, `closed`, `parked`.
- Single-commit migration (bulk `git mv` + all SKILL.md updates + bats test updates + README.md generation update) so no intermediate state has mixed paths.
- `docs/problems/README.md` stays at the top level — it's the aggregation view.
- Update the `git ls-tree` pipeline in `manage-problem` / `create-adr` next-ID lookups to use `-r` (recursive) so subdirectory files are discovered.
- Ship ordering: land this **after** P062, P063, P066–P068 (SKILL.md edits these tickets require touch the same files); doing P069 last avoids a rebase storm.

## Description

`docs/problems/` is currently a **flat directory of 69 Markdown files** plus a `README.md`. The filename encodes state via a suffix (`.open.md`, `.known-error.md`, `.verifying.md`, `.parked.md`, `.closed.md`). For skimmability this works up to ~20 tickets; beyond that, visual scan of `ls docs/problems/` returns a wall of filenames intermixed by state, requiring the reader to parse suffixes on every line to find, for example, the active dev-work queue.

`ls docs/problems/` output at time of report (2026-04-20): 69 Markdown files, 3 parked, 3 verifying that are clear candidates to close, 10 open tickets (7 of which were opened in the last 24 hours). The mix makes it hard to answer "what's actively in flight" at a glance. README.md mitigates this via the WSJF Rankings / Verification Queue / Parked tables but the on-disk view (which the user sees during every `ls` or file-browse) stays unstructured.

The fix is mechanical: **one subdirectory per problem state**. File names drop the state suffix (the directory encodes it). The transition commands become "move the file between directories" instead of "rename with a new suffix".

## Symptoms

- `ls docs/problems/` returns 69+ files; open / known-error / verifying / closed / parked all interleaved by numeric ID, impossible to skim by state.
- File explorers (VSCode tree, Finder, Codeium sidebar) show the same flat mess.
- New contributors asking "what should I work on next?" have to either read `README.md` (good) or type the exact glob (`ls docs/problems/*.open.md`) — the latter is discoverable only to people who already know the suffix convention.
- Every new ticket compounds the problem; the flat layout cannot scale without hitting a wall.
- Path references in SKILL.md files and bats tests use literal `docs/problems/*.<state>.md` globs that are fragile to filename-suffix drift (e.g. P057 staging trap edge cases).
- The symbolic weight of "we are doing ITIL problem management" is undercut by a directory that looks like a dump of notes.

## Workaround

Readers lean on `docs/problems/README.md` for ranked tables and ignore the directory tree; contributors use exact globs (`ls docs/problems/*.open.md` etc.) when they remember the suffix. Neither is a fix — they route around the flat layout but don't make the directory navigable.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — every `ls docs/problems/` is an ambient friction moment. "Without slowing down" fails at the most basic navigation step.
  - **Plugin-developer persona (JTBD-101)** — adopters cloning the repo to learn the suite's conventions (P055 Part A templates, ADR structure, problem-ticket discipline) see an unstructured `docs/problems/` as anti-pattern. Reputation-relevant.
  - **Tech-lead persona (JTBD-201)** — audit trail browsing (what changed between these dates, what state was P048 in during 2026-04-15's incident) is harder than it needs to be.
  - **Future contributors** — onboarding cost grows linearly with ticket count.
- **Frequency**: Every browse of `docs/problems/`. Certain.
- **Severity**: High for navigation ergonomics; Medium for automation (the path references in SKILL.md and bats tests all need updating, which is the migration cost).
- **Analytics**: N/A; frictional cost is ambient and would require session-level time-on-task measurement to quantify.

## Root Cause Analysis

### Structural

The flat-layout-with-state-suffix convention was set early (P001–P010 era) when ticket count was small and the suffix-in-filename was the simplest way to record state machine-readably. ADR-022 (Verification Pending lifecycle) added a fifth suffix without revisiting whether the container shape still fits. 69 tickets later, the convention has hit its natural ceiling.

The fix is not to add more suffixes or a sixth state — it's to promote state from suffix-in-filename to directory-of-files.

### Candidate fix

**Option 1 (recommended): per-state subdirectories, drop the suffix.**

Layout:

```
docs/problems/
├── README.md                 # aggregation of WSJF / Verification Queue / Parked
├── open/
│   ├── 063-manage-problem-does-not-trigger-report-upstream-for-external-root-cause.md
│   ├── 064-no-risk-scoring-gate-on-external-comms.md
│   └── ...
├── known-error/
│   └── ...
├── verifying/
│   ├── 017-create-adr-should-split-multi-decision-records.md
│   ├── 020-on-demand-assessment-skills.md
│   └── ...
├── closed/
│   ├── 001-architect-gate-marker-consumed-too-quickly.md
│   ├── 002-jtbd-gate-blocks-own-policy-file-creation.md
│   └── ...
└── parked/
    ├── 005-connect-setup-skill-doesnt-match-discord-plugin.md
    └── ...
```

Filename drops the `.<state>.md` suffix — the directory path encodes state. Machine-readability is preserved: the state is `$(basename $(dirname <path>))` instead of `${filename#*.}`.

**Option 2: per-state subdirectories, keep the suffix.**

Layout: `docs/problems/open/063-...open.md`. Redundant but useful as a defence-in-depth against a ticket being in the wrong directory (double-check: does the suffix match the directory?). Lightly considered because it doubles the mutation surface on every transition (now must `git mv` the file AND rename the suffix), which is the opposite of simplification.

**Option 3: flat but hide .closed.md and .parked.md in `archive/`.**

Weaker — still unskimmable once open/verifying alone exceed ~30. Punts the problem rather than solving it.

**Recommendation**: Option 1. The directory IS the state; filename is `<NNN>-<title>.md` and nothing more.

### Migration mechanics

The tricky part is keeping everything machine-readable through the transition. Mitigations:

1. **Single commit for the whole migration** so no intermediate state has half-old, half-new paths. Migration script:
   ```bash
   for state in open known-error verifying parked closed; do
     mkdir -p docs/problems/$state
     for f in docs/problems/*.$state.md; do
       [ -e "$f" ] || continue
       new=$(basename "$f" .$state.md).md
       git mv "$f" docs/problems/$state/$new
     done
   done
   ```

2. **Update the four SKILL.md files that reference paths** in the same commit:
   - `packages/itil/skills/manage-problem/SKILL.md` — file-path globs in Steps 7, 8, 9, 10; transition commands; README-staleness check; next-ID lookup.
   - `packages/itil/skills/work-problems/SKILL.md` — ticket selection globs.
   - `packages/itil/skills/report-upstream/SKILL.md` — `ls docs/problems/<ID>-*.{open,known-error,verifying,closed}.md` lookup in Step 1.
   - `packages/retrospective/skills/run-retro/SKILL.md` — if P068 lands before this migration, the `.verifying.md` glob.

3. **Update bats tests** in `packages/itil/skills/*/test/*.bats` and `packages/retrospective/skills/*/test/*.bats` that assert literal paths.

4. **Update the Status-field in each ticket body** — currently frontmatter carries `**Status**: Open` etc. Stays as a cross-check; the filename no longer redundantly encodes state but the frontmatter still does. No migration edit needed on ticket bodies beyond what's required by the suffix-drop.

5. **Update `docs/problems/README.md` generation** — aggregation now walks subdirs instead of globbing by suffix.

6. **ADR** — draft `docs/decisions/NNN-problem-ticket-directory-layout.proposed.md` covering the convention change, migration, and a cross-reference to ADR-022 (lifecycle) + the suffix-drop rationale.

### Investigation Tasks

- [ ] Draft the ADR for the directory-layout change. Cite ADR-022 as the lifecycle authority being expressed in directory shape rather than filename suffix.
- [ ] Enumerate all path references that need updating. Grep for `docs/problems/` across packages + bats tests; also check if any installers or scripts reference paths.
- [ ] Write the migration script and test it in a scratch branch with a dry-run mode.
- [ ] Decide whether to keep the `.md` suffix on filenames (yes — markdown file) or adopt plain `<NNN>-<title>` (no — Markdown convention matters for GitHub rendering).
- [ ] Decide whether to rename subdirs from `known-error` to `known_error` (underscore) or leave kebab-case. Lean: kebab-case for consistency with the existing suffix pattern and general Unix-friendliness.
- [ ] Decide whether `docs/problems/README.md` stays at the top level or moves under `docs/problems/` with a thin re-export. Lean: stays where it is — it's the aggregation view.
- [ ] Confirm `git mv` preserves history across the moves (expected yes; verify with `git log --follow` on a sample ticket after migration).
- [ ] Update architecture-agent + JTBD-agent exemption rules if any reference `docs/problems/<NNN>-*.md` paths literally. The current hook exemption (`docs/problems/ (problem tickets)`) is directory-scoped so the exemption still holds — but the hook scripts themselves should be audited.
- [ ] Ensure that this ticket does not inadvertently ship alongside P048 / P049 / P068 changes that depend on the old paths; architect review sequences the work.

## Decision record

**ADR-031** (Problem-ticket directory layout — per-state subdirectories under `docs/problems/`) — drafted 2026-04-20 post-AFK interactive. Captures: per-state subdirectory layout (`open/`, `known-error/`, `verifying/`, `parked/`, `closed/`); filename `.state.md` suffix dropped (authoritative encoding moves to directory path, in-file `Status:` becomes fallback); hook exemption glob update to `docs/problems/*/*.md`; next-ID discovery contract moves to recursive `git ls-tree -r`; hard-cut migration in this monorepo; **auto-migration on first-run in adopter repos** (both `manage-problem` AND `work-problems` must detect flat layout and migrate before layout-dependent logic); ADR-022 + ADR-016 + ADR-024 + `packages/risk-scorer/agents/wip.md` amendments in the execution commit.

This ticket (P069) is the **execution tracker** for ADR-031. Before the migration ships, four execution-time questions (surfaced by architect review of the auto-migration scope) must be resolved:

1. **Step numbering under ADR-027** — auto-migration cannot sit AT Step 0 because ADR-027 already claims Step 0 in both SKILL.md files for subagent auto-delegation. Resolution options: (a) migration is the subagent's first substantive step inside the skill body; (b) pre-delegation PreToolUse hook that fires before ADR-027 handoff; (c) dedicated Bash PreToolUse hook in `.claude/settings.json`. Lean: (a). Needs architect sign-off.
2. **Shared migration routine distribution** — identical logic in both skills; candidate for ADR-017 shared-code-sync pattern (canonical source in `packages/shared/`, synced into each skill's `lib/`). Needs architect sign-off.
3. **Commit-gate treatment (ADR-014 interaction)** — migration commit is pure file-rename with zero semantic content. Options: (a) normal `work → score → commit` (overhead on every adopter first-run); (b) bypass via explicit marker (`RISK_BYPASS: adr-031-migration`); (c) pre-approve the commit category structurally in ADR-014. Lean: (b).
4. **"Published skill mutates adopter repo on first-run" — novel distribution pattern** — no precedent in the suite. Options: (a) one-off with a Reassessment Criterion for when to standardise; (b) companion ADR upfront that standardises "plugin-driven repo migrations". Lean: (a) YAGNI.

Also still in scope: the **false-zero defect in `work-problems`** on adopter repos — Step 1 (Scan the backlog) enumerates ticket files BEFORE any delegation to `manage-problem`. On a flat-layout adopter repo that glob returns zero matches, stop-condition #1 fires, and the orchestrator exits silently — never reaching manage-problem. This is why auto-migration MUST run in work-problems too, at its own Step 0 / pre-delegation point. Not a separate concern; just calling it out because "first-call-wins via manage-problem" was the naive (wrong) framing.

The migration itself lands in a follow-up commit that flips ADR-031 `proposed` → `accepted` and ships: ~72 ticket renames (this repo) + SKILL.md glob updates across 5 skills + hook-script updates (2 hooks) + bats fixture audit across ~30 tests + ADR-022 + ADR-016 + ADR-024 amendments + `packages/risk-scorer/agents/wip.md` update + the auto-migration logic itself (shared between `manage-problem` and `work-problems`).

Effort after scope expansion: **XL** (was L before the auto-migration addition; the distributed migration logic + ADR-017 sync setup + two fixture-based bats tests push effort past L). WSJF re-rates: `(15 × 1.0) / 8 = 1.875`, from 3.75 pre-expansion.

## Related

- **ADR-031** — decision record for this migration (new; drafted 2026-04-20).
- **ADR-022** (problem lifecycle Verification Pending) — the lifecycle authority whose shape this ticket promotes from filename suffix to directory.
- **P048** (manage-problem does not detect verification candidates) — path-reference overlap; cross-check during migration.
- **P049** (Known Error status overloaded with Fix Released substate, ADR-022) — same file-path surface.
- **P057** (git mv + Edit staging ordering trap) — the staging-ordering invariant survives: `git mv` to the new dir + Edit still needs re-stage.
- **P056** (next-ID `--name-only` fix) — the `git ls-tree` pipeline needs to walk subdirs after the migration (`git ls-tree --name-only -r origin/main docs/problems/`).
- **P062** (manage-problem README not refreshed on single-ticket iterations) — the README generation logic is rewritten by this migration anyway; fix can ride along.
- **P068** (run-retro does not close verifying tickets observed verified in-session) — the `.verifying.md` glob in run-retro's housekeeping step needs to change.
- `packages/itil/skills/manage-problem/SKILL.md` — the primary SKILL.md whose path references change.
- `packages/itil/skills/work-problems/SKILL.md`, `packages/itil/skills/report-upstream/SKILL.md`, `packages/retrospective/skills/run-retro/SKILL.md` — all carry path references.
- `packages/itil/skills/*/test/*.bats` and `packages/retrospective/skills/*/test/*.bats` — bats assertions.
- **JTBD-001** (Enforce Governance Without Slowing Down) — navigation ergonomics directly affect this.
- **JTBD-101** (Extend the Suite with Clear Patterns) — the "clear pattern" should include the shape of the directory.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — browsable audit trail.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-002 | in-progress | docs/problems/ flat layout migration — per-state subdirs + adopter auto-migration |
