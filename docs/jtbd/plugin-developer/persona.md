---
name: plugin-developer
description: Developer building new plugins or contributing to the suite
human-oversight: confirmed
oversight-date: 2026-05-25
---

# Plugin Developer / Contributor

## Who

Builds new plugins or contributes to the suite. Needs to understand conventions, test hooks, and release safely. May be Tom or a future contributor.

## Context Constraints

- Works in the monorepo with `--plugin-dir` for local testing
- Runs BATS tests, uses changesets for versioning
- Must not break existing plugins when adding new ones

## Pain Points

- Undocumented conventions requiring reverse-engineering
- Slow test-fix-release cycles (push, marketplace update, reinstall, restart)
- Unclear patterns for hook structure, gate logic, and skill format
