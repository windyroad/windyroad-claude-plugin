# Problem 003: Plugin Installs Stack Instead of Replacing

**Status**: Closed (not a bug)
**Reported**: 2026-04-14
**Priority**: 6 (Medium) — Impact: Minor (2) x Likelihood: Almost Certain (5)

## Description

Running `claude plugin install wr-architect@windyroad --scope project` multiple times adds duplicate entries instead of replacing the existing installation. This results in 6x copies of each plugin in `claude plugin list`, and potentially 6x hook executions per event.

## Symptoms

- `claude plugin list` shows every windyroad plugin 6 times
- Hook overhead may be multiplied by the number of duplicate installations
- No error or warning when installing over an existing installation

## Workaround

Uninstall the plugin before reinstalling: `claude plugin uninstall <name>` then `claude plugin install <name>@windyroad --scope project`.

## Impact Assessment

- **Who is affected**: Anyone who reinstalls plugins (e.g., after marketplace updates)
- **Frequency**: Every reinstall cycle
- **Severity**: Medium — causes visual clutter and potential performance overhead
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed: Not a bug

Investigation (2026-04-15) found the 6 entries in `claude plugin list` correspond to **6 different projects**, each with its own `--scope project` install:

- `/Users/tomhoward/Projects/windyroad-claude-plugin`
- `/Users/tomhoward/Projects/windyroad`
- `/Users/tomhoward/Projects/addressr`
- `/Users/tomhoward/Projects/addressr-mcp`
- `/Users/tomhoward/Projects/addressr-react`
- `/Users/tomhoward/Projects/bbstats`

This is correct behaviour per ADR-004 (project-scoped plugin install). `claude plugin list` lists all installs across all projects, not just the current project — arguably a display UX issue, but not duplication and not a hook-overhead problem (only the current project's hooks fire).

### Investigation Tasks

- [x] Confirmed root cause — `installed_plugins.json` shows distinct `projectPath` per entry
- [x] Checked install flags — no `--update`/`--replace`, but none needed
- [x] Concluded: not a bug; ADR-004 working as intended

## Related

- `packages/shared/install-utils.mjs` — shared installer
- ADR-004 — project-scoped plugin install
