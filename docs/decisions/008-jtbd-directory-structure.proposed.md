---
status: "proposed"
date: 2026-04-20
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-07-14
supersedes: [007-jtbd-project-wide-enforcement]
---

# JTBD Directory Structure

## Context and Problem Statement

The JTBD plugin currently stores all jobs in a single `docs/JOBS_TO_BE_DONE.md` file. This was adequate for initial setup, but does not scale. The bbstats project already outgrew this format and migrated to a directory structure with individual files per persona and per job (bbstats commits `9a215dd` and `d961668`). That migration was done with local hook changes that are now lost since bbstats switched to the marketplace plugin.

The directory structure enables:
- Per-persona directories with dedicated persona definitions
- Individual job files with lifecycle status (`.proposed.md` -> `.validated.md`)
- Structured frontmatter (status, job-id, persona, screens, hateoas-actions)
- `@jtbd` code annotations linking source files to specific jobs
- Git history per job (not per document)

## Decision Drivers

- **Proven in production**: The bbstats project successfully uses this structure with 18 jobs across 3 personas
- **Per-job lifecycle**: Jobs move from proposed to validated independently — a single file can't track this
- **Traceability**: `@jtbd` annotations in source code link to specific job files, enabling the agent to review only relevant jobs for a given file change
- **Scalability**: 5 jobs fit in one file; 18+ jobs across 3 personas do not
- **Single canonical layout**: Every downstream consumer (eval/enforce/mark-reviewed hooks, agent, tests, CI, P018 quadruplet traceability) pays a dual-format tax when both layouts are supported. A single layout eliminates the tax.

## Considered Options

### Option 1: Directory Structure with Backward Compatibility (previously chosen 2026-04-14; now rejected)

Migrate to `docs/jtbd/` directory. Support both formats: if `docs/jtbd/README.md` exists, use the directory; if only `docs/JOBS_TO_BE_DONE.md` exists, use the single file. The update-guide skill offers migration.

**Rejected 2026-04-19** (per P019 direction decision): the backward-compat clause is a transition aid, not an active migration. bbstats (the reference implementation) has already migrated. The ongoing cost — dual-path logic in every hook, every test, every downstream consumer — outweighs the benefit of serving hypothetical projects that haven't yet run `update-guide`. Retained here so the rationale chain is preserved.

### Option 2: Keep Single File

Status quo. All jobs in `docs/JOBS_TO_BE_DONE.md`. No per-job lifecycle or code annotations. Rejected for the same reasons as before (no lifecycle, no traceability, no scalability).

### Option 3: Directory-only, no fallback (chosen 2026-04-20 per P019)

Canonical layout is `docs/jtbd/` with per-persona subfolders and per-job files. No runtime fallback to `docs/JOBS_TO_BE_DONE.md`. The `wr-jtbd:update-guide` skill is the **sole component** permitted to read `docs/JOBS_TO_BE_DONE.md`, and only for one-shot migration into the directory layout. Projects still on the legacy single-file layout must run `/wr-jtbd:update-guide` to migrate before upgrading to any post-deprecation plugin version.

## Decision Outcome

**Chosen option: Option 3 — Directory-only, no fallback**, because the backward-compat clause has finished its transitional purpose and the dual-format tax leaks into every downstream consumer (P018 quadruplet traceability, CI validation, plugin-developer guidance, agent file-resolution logic). Projects on the legacy layout have a migration path via `wr-jtbd:update-guide` — this preserves the one-shot migration while removing runtime dual-path logic everywhere else.

This decision supersedes ADR-007 (JTBD Project-Wide Enforcement). The project-wide enforcement scope from ADR-007 is preserved — the change is to the document structure, not the enforcement scope.

**Migration carve-out**: `packages/jtbd/skills/update-guide/SKILL.md` is the only component permitted to read `docs/JOBS_TO_BE_DONE.md`. Future cleanup passes must NOT strip this read path from the skill — it is the one-shot migration bridge.

## Directory Structure

```
docs/jtbd/
  README.md                              # Index — tables of personas and jobs by status
  <persona-name>/
    persona.md                           # Persona definition (who, constraints, pain points)
    JTBD-NNN-<kebab-title>.proposed.md   # Proposed job (not yet validated)
    JTBD-NNN-<kebab-title>.validated.md  # Validated job (confirmed with users)
```

### Persona File Format (`persona.md`)

```markdown
---
name: <persona-name>
description: <one-line description>
---

# <Persona Name>

## Who
<who this persona is>

## Context Constraints
<bullet list of constraints>

## Pain Points
<bullet list>
```

### Job File Format (`JTBD-NNN-<title>.<status>.md`)

```markdown
---
status: proposed | validated
job-id: <kebab-case-id>
persona: <persona-name>
date-created: YYYY-MM-DD
screens:
  - <route or screen path>
---

# JTBD-NNN: <Title>

## Job Statement
When [situation], I want to [motivation], so I can [expected outcome].

## Screen Mapping
- Primary screen: <route>
- Entry points: <routes>

## Desired Outcomes
<bullet list>

## Persona Constraints
<relevant constraints from persona>

## @jtbd Annotations
<list of source files with @jtbd annotations>
```

### ID Ranges

Each persona gets a range to avoid collisions:
- First persona: 001-099
- Second persona: 100-199
- Third persona: 200-299
- etc.

### README.md Index

The index groups jobs by persona and status (Validated, Proposed), with links to each file.

## Plugin Changes

### Eval Hook (`jtbd-eval.sh`)

Check for `docs/jtbd/README.md`. If it does not exist, suggest `/wr-jtbd:update-guide`. Do NOT consult `docs/JOBS_TO_BE_DONE.md` at runtime (migration carve-out only).

### Enforce Hook (`jtbd-enforce-edit.sh`)

- Hash `docs/jtbd` directory for drift detection
- Exempt `docs/jtbd/` files from the gate (replaces P002's `docs/JOBS_TO_BE_DONE.md` exemption)
- Do NOT fall back to `docs/JOBS_TO_BE_DONE.md` — the gate is inactive on projects that have not migrated

### Mark-Reviewed Hook (`jtbd-mark-reviewed.sh`)

- Store hash for `docs/jtbd` directory only
- No fallback to the single file

### Agent (`agents/agent.md`)

- Read `docs/jtbd/README.md` for the index
- Read relevant persona and job files matching the route being edited
- Do NOT fall back to `docs/JOBS_TO_BE_DONE.md`; the agent requires the directory layout

### Update-Guide Skill (`skills/update-guide/SKILL.md`)

- **Migration carve-out**: this skill is the ONLY component allowed to read `docs/JOBS_TO_BE_DONE.md`, and only for one-shot migration into `docs/jtbd/`.
- Generate the directory structure with persona directories and individual job files
- If `docs/JOBS_TO_BE_DONE.md` exists, offer to migrate its content to the directory structure
- After successful migration, recommend deleting the legacy single-file artefact (git history is the archive)
- Generate the README.md index

### Drift Detection

The `review-gate.sh` shared library already supports directory hashing. Changing the policy path from `"docs/JOBS_TO_BE_DONE.md"` to `"docs/jtbd"` uses the directory branch automatically. The `README.md` in `docs/jtbd/` should be included in the hash (it is the index and its structure matters).

## Consequences

### Good

- Per-job lifecycle (proposed -> validated) tracked in filenames
- Per-persona directories keep related jobs together
- Git history shows when each job was added/changed independently
- `@jtbd` annotations enable targeted review (only check jobs relevant to the file being changed)
- Single canonical layout — no dual-path logic in hooks, tests, or downstream consumers (P018 simplifies; CI validation simplifies)
- Plugin developers teach one pattern, not two

### Neutral

- More files to manage (mitigated by the update-guide skill generating the structure)
- Agent needs to read multiple files (mitigated by reading only relevant ones per review)

### Bad

- **Breaking change** for projects still on the single-file layout — requires running `/wr-jtbd:update-guide` to migrate before upgrading. This must be called out in the changelog.
- Migration effort for existing projects using `docs/JOBS_TO_BE_DONE.md` (one-shot via `update-guide`, then the legacy file can be deleted — git history is the archive)
- The enforce hook has no fallback: projects that have not migrated will not have a JTBD gate active. This is an acceptable trade because the alternative (running the gate against a single-file layout the rest of the plugin cannot read cleanly) is worse.

## Confirmation

- Eval hook detects `docs/jtbd/README.md` and suggests `update-guide` when missing
- Eval hook does NOT consult `docs/JOBS_TO_BE_DONE.md` at runtime
- Enforce hook hashes `docs/jtbd` directory for drift detection
- Enforce hook exempts `docs/jtbd/` files from the JTBD gate
- Enforce hook does NOT fall back to `docs/JOBS_TO_BE_DONE.md` — gate is inactive on projects that have not migrated
- Mark-reviewed hook stores hash for `docs/jtbd` directory and does NOT fall back to the single file
- Agent reads from `docs/jtbd/` only; absence is a "run update-guide" recommendation
- Update-guide skill generates the directory structure with personas and jobs AND is the sole component permitted to read `docs/JOBS_TO_BE_DONE.md` (for one-shot migration only)
- Architect plugin hooks (`architect-enforce-edit.sh`, `architect-detect.sh`) no longer carry `docs/JOBS_TO_BE_DONE.md` exemptions — the single-file path is not a recognised governance artefact
- BATS tests assert the single canonical path `docs/jtbd/`; legacy single-file paths are exercised ONLY in the update-guide skill's migration test fixtures
- A changelog entry calls out the breaking change for external adopters still on the single-file layout

## Reassessment Criteria

- **Code annotation tooling**: If Claude Code adds native support for linking code to documentation (beyond text comments), the `@jtbd` annotation pattern may need updating.
- **Job count exceeds 100 per persona**: Consider whether the flat file structure within persona directories needs sub-grouping.
- **Migration carve-out sunset**: When telemetry or the issue tracker shows no remaining legacy-layout projects in the wild (or a documented cutover date passes), retire the `docs/JOBS_TO_BE_DONE.md` reader from `packages/jtbd/skills/update-guide/SKILL.md`. Until then, the carve-out stays.
