# @windyroad/jtbd

**Jobs-to-be-done enforcement for Claude Code.** Reviews UI changes against your documented user jobs, personas, and desired outcomes before they ship.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

An AI agent building a feature doesn't know *why* the feature exists or *who* it's for. It builds what you describe, but can't validate whether the result actually serves the user's job-to-be-done.

The JTBD plugin:

1. **Detects** when an edit touches user-facing UI files
2. **Blocks** the edit until the JTBD agent has reviewed it
3. **Reviews** changes against your `docs/jtbd/` directory (per-persona job files)
4. **Reports** alignment gaps -- features that don't map to a documented job, or that conflict with persona constraints

## Install

```bash
npx @windyroad/jtbd
```

Restart Claude Code after installing.

## Usage

The plugin works automatically. On first use in a project without a JTBD directory, it blocks edits and directs you to create one:

```
/wr-jtbd:update-guide
```

This examines your existing features and asks about your user jobs, personas, and desired outcomes to generate `docs/jtbd/<persona>/persona.md` plus per-job files at `docs/jtbd/<persona>/JTBD-NNN-<title>.<status>.md`. If a legacy `docs/JOBS_TO_BE_DONE.md` exists, it is migrated into the directory structure on first run (per [ADR-008](../../docs/decisions/008-jtbd-directory-structure.proposed.md)).

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `jtbd-eval.sh` | Every prompt | Evaluates whether the task involves user-facing UI |
| `jtbd-enforce-edit.sh` | Edit or Write | Blocks edits until the JTBD agent has reviewed |
| `jtbd-mark-reviewed.sh` | Agent completes | Marks the review as done (TTL: 3600s) |
| `jtbd-slide-marker.sh` | Agent or Bash | Slides the review marker forward across non-edit operations so an active review session is not invalidated by intervening Bash or sub-agent calls |

## Agent

The `wr-jtbd:agent` reads your `docs/jtbd/` directory and reviews proposed UI changes against:

- Documented user jobs (per persona) and their success criteria
- Persona definitions and constraints
- Screen-to-job mappings

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — JTBD review fires automatically on every UI edit; manual review is replaced by an agent reading the persona files the project already maintains.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — `/wr-jtbd:review-jobs` produces an on-demand alignment report against documented jobs, attachable to a release note or handover doc.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/jtbd --update
npx @windyroad/jtbd --uninstall
```

## Licence

[MIT](../../LICENSE)
