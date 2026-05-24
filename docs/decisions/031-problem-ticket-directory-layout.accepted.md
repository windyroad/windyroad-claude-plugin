---
status: "accepted"
date: 2026-04-20
human-oversight: confirmed
oversight-date: 2026-05-25
accepted-date: 2026-05-12
decision-makers: [Tom Howard]
consulted: [wr-architect:agent (initial 2026-04-20 + T5b accept-flip review 2026-05-12), wr-jtbd:agent (initial 2026-04-20 + T5b accept-flip review 2026-05-12)]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-20
---

# Problem-ticket directory layout — per-state subdirectories under `docs/problems/`

## Context and Problem Statement

`docs/problems/` holds every problem ticket in a single flat directory with state encoded as a filename suffix (`.open.md`, `.known-error.md`, `.verifying.md`, `.parked.md`, `.closed.md`). As of 2026-04-20 that directory contains ~72 files. Queue size is growing, and maintainers browsing the tree see every state interleaved — the Open queue is visually adjacent to the Closed archive. Grepping for "what's in flight right now" requires filename-suffix filtering (`docs/problems/*.open.md`).

Downstream consumers (manage-problem, work-problems, manage-incident, report-upstream, run-retro, wip governance-artefact detection, architect/jtbd edit-gate hook exemptions) all enumerate tickets via the same flat-glob contract. The contract is uniform but the resulting layout is unskimmable — P069 captures the friction.

Migrating to **per-state subdirectories** keeps the lifecycle semantics (states remain the same, transitions are still the authoritative state signal) while giving the directory tree an at-a-glance queue view: `docs/problems/open/` shows the dev-work queue, `docs/problems/verifying/` shows what's awaiting user verification, `docs/problems/closed/` archives the shipped history.

## Decision Drivers

- **Skimmability** — the tree should reflect the lifecycle structure it already has, not bury it behind filename suffixes.
- **No semantic change** — the five lifecycle states (Open, Known Error, Verification Pending, Parked, Closed) and their transition rules (per ADR-022) are unchanged. Only the encoding of "which state is this ticket in" moves from filename suffix to directory path.
- **Authoritative state signal** — one location for the state answer. Filename suffix AND subdirectory AND the "Status" field in the file body is three-way redundancy with drift risk. The subdirectory becomes authoritative; filename drops the suffix; the in-file Status field becomes a human-readable fallback.
- **Glob updates are mechanical** — every downstream consumer enumerates via glob. A global `docs/problems/*.<state>.md` → `docs/problems/<state>/*.md` swap is a mechanical migration.
- **Own every adopter** — no external consumers of this repo's `docs/problems/` layout exist today; migration can be a hard cut without a backward-compatibility window.

## Considered Options

1. **Per-state subdirectories (Recommended)** — `docs/problems/<state>/NNN-<slug>.md`. State encoded by directory; filename suffix dropped.
2. **Per-year subdirectories** — `docs/problems/2026/NNN-<slug>.<state>.md`. Chronological archive; easier long-term pruning; loses at-a-glance "what's queued right now".
3. **Flat layout with index files per state** — keep flat filenames; add `docs/problems/OPEN.md`, `VERIFYING.md` etc. indexes. Minimal migration; does not fix the directory-tree skimmability problem itself.
4. **Per-severity or per-plugin subdirectories** — groups tickets by owning package or by severity. Breaks cross-plugin tickets; state still needs a secondary encoding.

## Decision Outcome

**Chosen option: 1 — per-state subdirectories.**

User-pinned direction 2026-04-20 (interactive AskUserQuestion). Matches the existing filename-suffix discipline: the transition mechanics (ADR-022) already know how to move tickets between states; the migration extends that to move between directories rather than flip suffixes.

### Layout

```
docs/problems/
├── README.md              (canonical rendered index — WSJF queue, Verification Queue, Parked, Closed)
├── open/
│   └── NNN-<slug>.md
├── known-error/
│   └── NNN-<slug>.md
├── verifying/
│   └── NNN-<slug>.md
├── parked/
│   └── NNN-<slug>.md
└── closed/
    └── NNN-<slug>.md
```

Each ticket lives as `docs/problems/<state>/NNN-<slug>.md`. The `.state.md` filename suffix is **dropped** once the state is encoded by the directory — the previous three-way redundancy collapses to one authoritative source (directory path), one in-file fallback (`Status:` field in the body), and no redundant filename encoding.

### Transition mechanics

ADR-022's existing transition machinery is preserved; the only change is the `git mv` destination. The staging-trap rule (P057) applies unchanged:

```bash
# Example — Open → Known Error transition
git mv docs/problems/open/NNN-<slug>.md docs/problems/known-error/NNN-<slug>.md
# ... Edit tool updates the Status field + any other content ...
git add docs/problems/known-error/NNN-<slug>.md
```

Same for the other transitions (KE → Verifying, Verifying → Closed, any → Parked, Parked → any). The cross-directory `git mv` is still a pure rename from git's perspective.

### Hook exemption glob contract

`packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` both exempt problem-ticket edits from the architect / jtbd edit-gate via a shell glob on the `CLAUDE_FILE_PATH`. Under the current (flat) layout the exemption uses `docs/problems/*.md`. Shell `*` does NOT cross `/`, so under the new layout that pattern matches zero ticket files and every problem-ticket edit becomes gated — an unintended regression.

The exemption pattern MUST become `docs/problems/*/*.md` (and `*/docs/problems/*/*.md` for the path-prefix variant the hooks match against). This is explicitly in scope for the ADR-031 landing commit. The ADR should NOT land without this hook update because the subsequent commit that migrates the ticket files would immediately hit blocked-edit errors from its own transition bookkeeping.

### Next-ID discovery contract

The ID-allocation contract becomes recursive enumeration across subdirs. The current flat `ls docs/problems/*.md` pattern returns zero matches after the migration (ticket files live one level deeper). Every skill or script that allocates a new problem ID must use a recursive listing:

```bash
# Local next-ID lookup — recursive across subdirs
local_max=$(find docs/problems -mindepth 2 -maxdepth 2 -name '*.md' | sed 's|.*/||' | grep -oE '^[0-9]+' | sort -n | tail -1)

# Origin next-ID lookup — `git ls-tree -r` recurses (matches the --name-only P056 guard)
origin_max=$(git ls-tree --name-only -r origin/main docs/problems/ | sed 's|.*/||' | grep -oE '^[0-9]+' | sort -n | tail -1)
```

This contract change is called out explicitly rather than hidden inside the SKILL.md updates, because any new ID-allocating skill (e.g. `/wr-architect:create-adr` or future governance skills) must adopt the recursive pattern. P056 (ticket-creator next-ID blob-SHA false-match) shipped the `--name-only` guard; P069 adds the `-r` recursion requirement.

### Migration plan (implementation scope — tracked by P069 for execution)

This ADR is landed as the **decision record** in isolation; the migration itself (moving ~72 ticket files, amending ADR-022 / ADR-016 / ADR-024, updating SKILL.md globs and bats tests and hook scripts) is large enough to warrant its own dedicated commit. P069 is the driver ticket for that implementation work, and when it lands, ADR-031 transitions from `proposed` to `accepted` in the same commit.

1. Create the five subdirectories under `docs/problems/`.
2. `git mv` every existing ticket into the correct subdirectory, dropping the `.state.md` suffix from each filename (so `docs/problems/012-skill-testing-harness.open.md` becomes `docs/problems/open/012-skill-testing-harness.md`).
3. Update SKILL.md glob patterns across:
   - `packages/itil/skills/manage-problem/SKILL.md` (Step 7 transition globs, Step 9 fast-path stale check, Step 9d Verification Pending glob, Step 11 commit-message conventions — ~4 globs to update)
   - `packages/itil/skills/work-problems/SKILL.md` (classifier table matches on filename-suffix, upstream-blocked path glob, stop-condition globs)
   - `packages/itil/skills/manage-incident/SKILL.md` (incident-to-problem handoff glob)
   - `packages/itil/skills/report-upstream/SKILL.md` (local-ticket discovery glob)
   - `packages/retrospective/skills/run-retro/SKILL.md` (Step 4a Verification-close glob `docs/problems/*.verifying.md` → `docs/problems/verifying/*.md`)
4. Update hook exemption globs in:
   - `packages/architect/hooks/architect-enforce-edit.sh` — `docs/problems/*.md` → `docs/problems/*/*.md`.
   - `packages/jtbd/hooks/jtbd-enforce-edit.sh` — same update.
5. Update bats test fixtures and glob assertions across `packages/itil/skills/*/test/*.bats` and `packages/retrospective/skills/*/test/*.bats`. **Tests that assert a literal `docs/problems/*.open.md` path and find zero matches fail silently** (the glob returns nothing → assertions against empty-set become trivially true) — the migration audit must convert every such test to the new pattern and re-run the suite to confirm non-zero match counts where the intent is "this glob MUST match at least one file".
6. Update `docs/problems/README.md` rendering rules to read from the subdirectories rather than filename suffixes. Render targets are unchanged (WSJF queue, Verification Queue, Parked, Closed sections).
7. Amend ADR-022 (`docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md`) in the same commit to reflect the filename-suffix → directory-path shift. See "Updates to other ADRs" below.
8. Amend ADR-016 (`docs/decisions/016-wip-verdict-commit-for-completed-governance-work.proposed.md`) and `packages/risk-scorer/agents/wip.md` to use `docs/problems/**/*.md` (recursive glob) for governance-artefact detection.
9. Amend ADR-024 (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — reference path `docs/problems/<NNN>-<title>.<status>.md` updated to `docs/problems/<status>/<NNN>-<title>.md`.

### Backward compatibility — adopter repos auto-migrate on first-run

**Hard cut in this monorepo. Auto-migration in adopter repos.**

No external consumers of this repo's `docs/problems/` layout are known; Windy Road owns every downstream adopter (addressr, bbstats, any future) and can coordinate the migration end-to-end. The Windy Road monorepo itself migrates in one commit per the "Migration plan" above. **BUT** adopter repos that install `@windyroad/itil` do NOT get migrated by that commit — they still have their own `docs/problems/` in the flat-layout shape from the prior `@windyroad/itil` version. If the skills simply update their globs to `docs/problems/<state>/*.md`, adopter repos see empty enumerations on every subsequent invocation (silent "nothing to do"), which is a user-visible defect.

**Contract**: `manage-problem` AND `work-problems` MUST detect flat-layout presence on invocation and auto-migrate the adopter's `docs/problems/` before executing any layout-dependent logic. The migration is a pure `mkdir` + `git mv` + commit sequence; fully reversible via `git revert`; no external-comms, no secrets, no destructive overwrite. Auto-migration runs even in AFK / non-interactive mode per ADR-013 Rule 6, applying the ADR-019 precedent (pure-rename + pure-mkdir actions are policy-authorised).

**Detection**: any match of `compgen -G 'docs/problems/*.<state>.md'` (for state in open / known-error / verifying / parked / closed) indicates a non-migrated or partially-migrated adopter repo. The detector is partial-migration safe — it fires whenever any flat-layout file remains, regardless of whether other files are already in subdirs. Subsequent invocations after full migration find zero flat files and skip.

**Commit message**: `docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)`. Standalone commit (not folded into other work) so adopters can audit / revert in isolation.

**Why both skills (not just manage-problem)**: `work-problems` Step 1 (Scan the backlog) enumerates ticket files BEFORE delegating any iteration to `manage-problem`. On a flat-layout adopter repo, that Step 1 glob returns zero matches, stop-condition #1 fires, and the orchestrator exits with a false "nothing to do" signal — never reaching the `manage-problem` iteration that would have triggered migration. First-call-wins reasoning is incorrect here; both skills must run the migration.

**Open execution-time questions (P069 must resolve these before the migration ships)**:

1. **Step numbering under ADR-027** — ADR-027 already claims Step 0 in both SKILL.md files for subagent auto-delegation. Auto-migration cannot sit AT Step 0 as stated earlier. Options for the execution commit: (a) migration becomes the subagent's first substantive action (Step 1 of the subagent-executed body); (b) migration runs in a pre-delegation PreToolUse hook that fires before the ADR-027 subagent handoff; (c) dedicated migration hook on `.claude/settings.json` Bash PreToolUse matching any `manage-problem` or `work-problems` invocation. Lean: (a) — lowest surface area, simplest contract. Architect review required at execution time.

2. **Shared migration routine distribution** — the migration logic is identical in `manage-problem` and `work-problems`. ADR-017 (Shared code sync pattern) is the existing template for `lib/install-utils.mjs`-style duplication within this monorepo. The migration routine is a candidate for the same pattern, with a canonical source in `packages/shared/` synced into each skill's `lib/`. Architect review required at execution time.

3. **Commit-gate treatment (ADR-014 interaction)** — the migration commit is pure file-rename with zero semantic content. Options: (a) run the normal `work → score → commit` cycle (overhead on first-run in every adopter); (b) migration commits bypass the commit gate via an explicit marker (e.g. `RISK_BYPASS: adr-031-migration`); (c) pre-approve the commit category structurally in ADR-014. Lean: (b) — the bypass marker keeps the commit-gate's audit-trail while avoiding the full risk-score overhead.

4. **Novel distribution pattern** — "published skill mutates adopter repo on first-run" has no precedent in this suite. ADR-017 handles shared code inside the monorepo; marketplace ADRs handle skill distribution. The execution commit should either (a) treat this as a one-off with a Reassessment Criterion that captures when to standardise if a second such migration emerges, or (b) introduce a companion ADR that standardises "plugin-driven repo migrations" upfront. Lean: (a) — YAGNI until a second case emerges.

These open questions block the migration execution commit, not this ADR draft. ADR-031 records the decision and names the questions; P069 (execution ticket) — later subsumed by P170 Slice 5 + RFC-002 — drives them to resolution with architect + user input before the migration ships. See § Open Execution-time Questions resolution (2026-05-12) addendum below for outcomes.

### Open Execution-time Questions resolution (addendum 2026-05-12 — T5b accept-flip)

Resolutions for the four execution-time questions above, captured at the `proposed → accepted` status flip per architect re-review finding 1:

1. **Step numbering** — **MOOT under ADR-032.** ADR-027 (subagent auto-delegation Step 0) was superseded by ADR-032 (governance-skill-invocation-patterns) on 2026-04-21. ADR-032 makes `manage-problem` / `work-problems` foreground-synchronous; there is no Step 0 subagent handoff. Auto-migration lives as a Step 1 substantive action in the main-agent body of each skill (architect-original-lean (a) carried through into the ADR-032 foreground shape). Tracked under P170 Slice 5 T8 (`manage-problem`) and T9 (`work-problems`).
2. **Shared migration routine distribution** — **DEFERRED to P170 Slice 5 T7.** ADR-017 sync pattern (canonical source in `packages/shared/lib/`, mirrored into each skill's `lib/`) is the chosen template. Architect re-review at T7 execution time per ADR-017 shared-code-sync precedent.
3. **Commit-gate treatment (ADR-014 interaction)** — **DEFERRED to P170 Slice 5 T11.** Lean (b) confirmed: explicit `RISK_BYPASS: adr-031-migration` marker recognised by the commit-gate hook. T11 lands the marker recognition and amends ADR-014's commit-message-convention table to enumerate the bypass marker grammar.
4. **Novel distribution pattern (plugin-mutates-adopter-repo on first-run)** — **Reassessment-criterion-only, not a separate ADR.** Lean (a) carried: YAGNI until a second such migration emerges. The Reassessment Criteria section already captures "external consumers of `docs/problems/` appear that require flat layout"; an extension Reassessment Criterion is added under this addendum for "a second plugin-driven repo migration is contemplated — at that point, standardise the pattern in a companion ADR."

### Transitional dual-pattern window (T1-T6) — RFC-002 execution shape

This subsection captures the actual execution shape RFC-002 (P069 driver, P170 Slice 5 forward-dogfood) implemented for the in-repo migration. User direction 2026-05-10 endorsed a dual-pattern transitional window inside the monorepo so dependent skills + bats + hook surfaces could absorb both the pre-migration and post-migration shape during the multi-commit landing, narrowing the bootstrap-blocked-edit risk surface and avoiding a single mega-commit that would breach ADR-014 single-purpose grain.

**Phase shape:**

- **T1-T5 (dual-pattern tolerant)**: SKILL.md globs, bats fixture path-assertions, `reconcile-readme.sh`, hook exemption globs, and `manage-problem` / `work-problems` enumeration paths all accept BOTH `docs/problems/*.<state>.md` (flat) AND `docs/problems/<state>/*.md` (per-state). Forward-compatible; T5a (bulk migration commit `e31bd6a`) runs against this widened tolerance so no SKILL.md / bats / hook regression fires during the rename window.
- **T6 (single-pattern end-state)**: the flat-layout half of every dual-tolerant glob is dropped; surfaces tighten back to the prescribed `docs/problems/<state>/*.md` single shape. **T6 trigger gate**: T5a-stable-for-≥7-days OR explicit user-comfort signal. Until T6 lands, the in-repo state is `T5b-accepted-with-dual-pattern-tolerance-active`; this is the documented intermediate, not a regression.

**Why the carve-out lives in § Backward Compatibility, not § Decision Outcome**: the chosen option (per-state subdirectories) is unchanged. The carve-out describes the *transitional implementation reality* of how the migration unfolded across multiple commits — a backward-compatibility concern for the in-repo state during the window, not a re-decision of the chosen option.

**JTBD-006 protection during the window** (per jtbd-review non-blocking recommendation 2026-05-12): `work-problems` Step 1 (Scan the backlog) enumeration is dual-tolerant across T1-T5, so the AFK orchestrator continues to select tickets regardless of which side of the migration any given ticket lives on. At T6 collapse, the single-pattern enumeration matches every ticket because T5a has already moved them all. No AFK enumeration regression at any point in the window.

**Adopter-repo invariance**: the dual-pattern window is **internal-monorepo-only**. Adopter repos never see the intermediate — T7-T11 ship `mkdir` + `git mv` + standalone commit auto-migration that detects flat-layout and produces only the per-state end-state in one commit. JTBD-101 atomic-fix adopters and JTBD-101 multi-commit adopters both receive a single self-contained migration commit with `RISK_BYPASS: adr-031-migration` marker recognition (T11). Per jtbd-review finding 1 (PASS with note), no carve-out language is required at JTBD-101 surface; ADR-031 lines 114-127 already document the adopter contract.

External reporters use the `.github/ISSUE_TEMPLATE/problem-report.yml` intake (P066) — that path is unchanged.

### Updates to other ADRs (in-scope for the ADR-031 landing commit)

- **ADR-022** — amend in place (still `proposed`, no shipped code references depending on the filename-suffix encoding that don't also update under this ADR). Rationale: the Verification Pending *lifecycle* (the decision) is orthogonal to the suffix-vs-directory *encoding* (the implementation detail). The lifecycle survives unchanged; only the encoding moves. ADR-022's Decision Outcome paragraph, Confirmation items 2 and 3 (both cite `.verifying.md` globs), and the Consequences → Neutral bullet about `.parked.md` symmetry each need a one-line edit. Add a "See also ADR-031" cross-reference. No supersession marker.
- **ADR-016** (WIP verdict commit) — governance-artefact detection path list updates from `docs/problems/*.md` to `docs/problems/**/*.md`. Same update mirrored in `packages/risk-scorer/agents/wip.md`.
- **ADR-024** (cross-project problem-reporting contract) — reference path updates from `docs/problems/<NNN>-<title>.<status>.md` to `docs/problems/<status>/<NNN>-<title>.md`.
- **ADR-014** (governance skills commit their own work) — no change. Commit-message conventions unchanged; the rename in transition commits is now a cross-directory `git mv` instead of a same-directory one. Semantic content unchanged.

## Consequences

### Good

- `ls docs/problems/` shows the lifecycle states, not an alphabetical wall of ticket files.
- `ls docs/problems/open/` is the literal dev-work queue — queue depth is visible as directory size.
- `ls docs/problems/verifying/` is the Verification Queue — same for Parked and Closed.
- Glob patterns become shorter and more intuitive: `docs/problems/open/*.md` vs `docs/problems/*.open.md`.
- Filename suffix redundancy eliminated — one authoritative encoding (directory) plus one human-readable fallback (in-file `Status:` field).

### Bad

- One-shot migration touches ~72 ticket files + ~10 SKILL.md files + 2 hook scripts + ~30 bats fixtures. The landing commit is large.
- Silent test failure risk (bats glob asserting a pattern that no longer matches returns empty-set, which is truthy against most assertion shapes) — the migration must audit every test and re-run the suite with explicit "this pattern must match at least one file" assertions where applicable.
- Any offline work-in-progress ticket file a contributor has in their tree mid-migration gets rename-conflicted on rebase. Contributors need to rebase or re-create their ticket after the migration commit lands.

### Neutral

- `git log --follow` handles cross-directory renames cleanly; ticket history survives.
- The `git log`-based freshness check (manage-problem Step 9 fast-path, per P031) is path-agnostic and continues to work unchanged after the migration — it checks commit timestamps, not file paths.
- The P062 on-transition README refresh rule (manage-problem Step 7) is unchanged in semantics; the rename now spans directories but the README regeneration logic stays the same.

## Confirmation

### Confirmation (this repo, post-migration execution)

Per the Transitional dual-pattern window (T1-T6) carve-out above, Confirmation criteria fire in two distinct compliance phases:

**Phase A — T1-T5 dual-tolerant surfaces (post-T5a, pre-T6)**:

- All five state subdirectories (`open/`, `known-error/`, `verifying/`, `parked/`, `closed/`) exist as directories under `docs/problems/`.
- Every ticket file lives under one of those subdirectories with filename matching `^[0-9]{3}-[a-z0-9-]+\.md$` (no `.state.md` suffix).
- Every problem-ticket file's in-body `Status:` field matches its containing directory name (case-insensitive, `known-error` ↔ `Known Error`).
- SKILL.md globs in `manage-problem`, `work-problems`, `manage-incident`, `report-upstream`, `run-retro` accept BOTH `docs/problems/*.<state>.md` AND `docs/problems/<state>/*.md` (dual-tolerant enumeration during the window).
- Bats fixture path-assertions are dual-tolerant; assertions against "this glob MUST match at least one file" are explicit (no silent empty-set passes).
- `packages/itil/scripts/reconcile-readme.sh` enumerates both flat AND per-state shapes during the window.
- Hook exemption globs in `packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` cover BOTH `docs/problems/*.md` AND `docs/problems/*/*.md` (dual-pattern hook exemption).
- ADR-016 / ADR-022 / ADR-024 references match the new per-state paths.
- `packages/risk-scorer/agents/wip.md` governance-artefact path list uses the recursive `docs/problems/**/*.md` glob.

**Phase B — T6 single-pattern end-state (post-T6 collapse)**:

- All Phase A invariants hold.
- ADDITIONALLY: zero files at `docs/problems/*.open.md` / `*.known-error.md` / `*.verifying.md` / `*.parked.md` / `*.closed.md` (the old encoding is fully migrated).
- ADDITIONALLY: every SKILL.md that enumerates problem tickets uses the single per-state glob pattern; no bare `docs/problems/*.<state>.md` references remain in `packages/*/skills/*/SKILL.md`.
- ADDITIONALLY: bats fixtures + `reconcile-readme.sh` + hook exemption globs collapse to single-pattern (`docs/problems/*/*.md` shape) only.
- `npm test` green (current 428 + N new doc-lint assertions added by this ADR, the migration, and T6 single-pattern enforcement).

### Confirmation (downstream adopter repos, post-first-run)

After the first invocation of `manage-problem` OR `work-problems` in an adopter repo that previously carried the flat layout:

- Five state subdirectories exist under the adopter's `docs/problems/`.
- Zero files remain at `docs/problems/*.<state>.md`; every ticket lives at `docs/problems/<state>/NNN-<slug>.md`.
- The migration commit (message `docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)`) is the most recent addition to the adopter's git history at the point the skill was invoked.
- Subsequent skill invocations find no flat-layout files and skip migration silently.
- Partial-migration safe: if a prior run was interrupted, re-invocation completes the migration by moving only the still-flat files.

### Confirmation (bats fixtures)

- `packages/itil/skills/manage-problem/test/manage-problem-auto-migrate.bats` (new, at execution time) — fixture test simulating an adopter repo's flat `docs/problems/`; asserts first invocation migrates and subsequent invocations are no-ops. Same shape for `packages/itil/skills/work-problems/test/work-problems-auto-migrate.bats`.

## Reassessment Criteria

Revisit this decision if:

- Ticket count per subdir exceeds ~50 — a second-level grouping (year, plugin, severity) may become warranted.
- External consumers of `docs/problems/` appear that require the flat layout or the filename-suffix encoding (unlikely; ADR-024 is the main candidate, and its reference path moves with this ADR).
- The lifecycle gains a sixth state, in which case both the directory structure and the transition mechanics need the new state added.
- The migration proves lossier than expected — e.g. if `git log --follow` handling degrades under the rename volume, or if silent bats-glob failures slip through despite the Confirmation checks.
- **A second plugin-driven repo migration is contemplated** (per § Open Execution-time Questions resolution Q4) — at that point, standardise the "published skill mutates adopter repo on first-run" pattern in a companion ADR rather than leaving it as a one-off precedent in this ADR's § Backward Compatibility subsection.

## Related

- **P069** — the driver ticket. Direction pin 2026-04-20: migrate last (after smaller fixes), per-state subdirs.
- **P056** — ticket-creator next-ID `--name-only` fix. Paired with this ADR's `-r` recursion requirement.
- **P057** — `git mv + Edit + git add` staging trap. Applies unchanged to cross-directory renames.
- **P062** — on-transition README refresh rule. Applies unchanged; rename now spans directories.
- **ADR-022** — Verification Pending lifecycle. Amended in place by this ADR's landing commit.
- **ADR-016** — WIP verdict commit. Governance-artefact detection path list updated.
- **ADR-024** — cross-project problem-reporting contract. Reference path updated.
- **ADR-014** — governance skills commit their own work. No change.
- `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` — audit-trail outcome; the directory-tree layout makes the trail visible at a glance.
- `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md` — "without slowing down" is served by the clearer queue visibility.
- `docs/jtbd/plugin-user/JTBD-301-report-problem-without-pre-classifying.proposed.md` — the plugin-user persona doesn't directly consume `docs/problems/` (that's maintainer-facing), but the cleaner queue makes maintainer responses faster, improving JTBD-301's "predictable acknowledgement" outcome.
