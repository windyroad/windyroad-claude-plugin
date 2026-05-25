---
name: wr-jtbd:update-guide
description: Create or update the project's docs/jtbd/ directory with per-persona directories and individual job files. Migrates from docs/JOBS_TO_BE_DONE.md if present.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Jobs To Be Done Document Generator

Create or update `docs/jtbd/` with per-persona directories and individual job files.
The wr-jtbd:agent reads these files to review changes against user jobs.

## Directory Structure

```
docs/jtbd/
  README.md                              # Index — tables of personas and jobs by status
  <persona-name>/
    persona.md                           # Persona definition
    JTBD-NNN-<kebab-title>.proposed.md   # Proposed job
    JTBD-NNN-<kebab-title>.validated.md  # Validated job
```

## Steps

### 1. Discover project context

Examine the project to understand what it does and who uses it.

**Find the product definition** by scanning for:
- README.md and documentation
- Landing page or marketing content
- Product discovery documents (PRODUCT_DISCOVERY.md, personas, user research)
- Route/page structure (reveals user workflows)
- Feature flags or configuration (reveals capabilities)

**Discover user workflows**:
- Map the main user-facing pages/screens and their purpose
- Identify the core user journey (what do users do from start to finish?)
- Look for onboarding flows, dashboards, settings, or admin areas
- Check for different user roles (admin, member, viewer, etc.)

### 2. Check for existing JTBD artefacts

Check in order of preference:

1. `docs/jtbd/README.md` — directory structure already exists. Read and update.
2. `docs/JOBS_TO_BE_DONE.md` — legacy single file. Offer to migrate to directory structure.
3. Neither — fresh creation.

If migrating from `docs/JOBS_TO_BE_DONE.md`, extract existing personas and jobs and
convert them into the directory structure. Ask the user before proceeding.

**Migration carve-out (ADR-008 Option 3 chosen 2026-04-20, P019)**: this skill is the
**sole component** in the plugin suite permitted to read `docs/JOBS_TO_BE_DONE.md`.
Every other component (eval hook, enforce hook, mark-reviewed hook, wr-jtbd:agent,
CI validation) reads only `docs/jtbd/`. Do NOT strip this read path from this skill
during future cleanup — it is the one-shot migration bridge for legacy projects. The
Reassessment Criteria in ADR-008 list the sunset trigger (no legacy-layout projects
remaining).

### 3. Draft personas

For each persona (2-4), create a file at `docs/jtbd/<persona-name>/persona.md`:

```markdown
---
name: <persona-name>
description: <one-line description>
---

# <Persona Display Name>

## Who
<who this persona is>

## Context Constraints
<bullet list of constraints relevant to using this product>

## Pain Points
<bullet list of frustrations this product addresses>
```

Use kebab-case for the directory name (e.g., `solo-developer`, `tech-lead`).

### 4. Confirm personas with the user

Use AskUserQuestion to present the drafted personas and ask:
- Are these the right personas?
- Any missing user segments?
- Any constraints or pain points to add?

**Born-confirmed write (ADR-068).** Once the user confirms a persona via this AskUserQuestion pass, write the human-oversight marker into that persona's frontmatter — insert after the `description:` line:

```yaml
human-oversight: confirmed
oversight-date: YYYY-MM-DD   # today
```

This is the born-confirmed gate: a persona authored through update-guide enters the world already human-oversighted (it does not appear in `/wr-jtbd:confirm-jobs-and-personas`' unoversighted set). Do NOT write the marker for a persona the user has not confirmed. The marker is orthogonal to status.

### 5. Draft jobs

For each job (3-8 per persona), create a file at
`docs/jtbd/<persona-name>/JTBD-NNN-<kebab-title>.proposed.md`:

```markdown
---
status: proposed
job-id: <kebab-case-id>
persona: <persona-name>
date-created: YYYY-MM-DD
screens:
  - <route or screen path, if applicable>
---

# JTBD-NNN: <Title>

## Job Statement
When [situation], I want to [motivation], so I can [expected outcome].

## Desired Outcomes
<bullet list of measurable outcomes>

## Persona Constraints
<relevant constraints from persona definition>

## Current Solutions
<how users currently accomplish this without the product>
```

**ID ranges** — assign non-overlapping ranges per persona:
- First persona: 001-099
- Second persona: 100-199
- Third persona: 200-299

**Status** — new jobs start as `proposed`. They become `validated` when confirmed
by user research or production use. To validate: rename the file from
`.proposed.md` to `.validated.md` and update the status field.

### 6. Confirm jobs with the user

Use AskUserQuestion to present the drafted jobs and ask:
- Do these jobs cover the core value proposition?
- Do the job statements ring true?
- Any missing jobs or user flows?

**Born-confirmed write (ADR-068).** Once the user confirms a job via this AskUserQuestion pass, write the human-oversight marker into that job's frontmatter — insert after the `date-created:` line:

```yaml
human-oversight: confirmed
oversight-date: YYYY-MM-DD   # today
```

A job authored through update-guide is born human-oversighted, so the `/wr-jtbd:confirm-jobs-and-personas` unoversighted set only ever shrinks. Do NOT write the marker for a job the user has not confirmed (drafted-but-unconfirmed jobs stay unmarked). The marker is orthogonal to `status:` — a `proposed` job can be `human-oversight: confirmed`.

### 7. Generate README.md index

Write `docs/jtbd/README.md` with tables grouping jobs by persona and status:

```markdown
# Jobs To Be Done (JTBD) Index

## <Persona Name>

<one-line description>

[Persona definition](<persona-name>/persona.md)

### Validated

| ID | Job | File |
|----|-----|------|
| JTBD-NNN | <title> | [JTBD-NNN-<title>.validated.md](<path>) |

### Proposed

| ID | Job | File |
|----|-----|------|
| JTBD-NNN | <title> | [JTBD-NNN-<title>.proposed.md](<path>) |
```

### 8. Handle legacy file

If `docs/JOBS_TO_BE_DONE.md` exists, after successfully migrating its content
into the directory layout, recommend deleting it (git history is the archive,
per ADR-008 Option 3 Consequences). If the user prefers to keep a stub for
external links, offer to replace its content with a pointer:

```markdown
# Jobs To Be Done

Job definitions have been migrated to individual files in `docs/jtbd/`.
Each persona has its own directory with a persona definition and individual
job files. See `docs/jtbd/README.md` for the full index.

This file is no longer consulted by the `@windyroad/jtbd` plugin at runtime
(ADR-008 Option 3). It is retained only for external links.
```

Default recommendation: delete the file once migration is confirmed. The
repository's own `docs/JOBS_TO_BE_DONE.md` stub was deleted in the same
commit that accepted ADR-008 Option 3 (P019).

### 9. Summary

Report what was created:
- Number of personas and their names
- Number of jobs and their IDs
- Files created/updated
- Whether migration from legacy file was performed

$ARGUMENTS
