---
status: "proposed"
date: 2026-04-10
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-07-10
---

# Project-Scoped Plugin Install by Default

## Context and Problem Statement

The installer (`npx @windyroad/agent-plugins`) uses `claude plugin install` which defaults to `--scope user`. This means plugins are installed globally — their hooks fire in every Claude Code session across all projects.

During development, buggy hooks (e.g., the risk-scorer grep pattern issue) fired globally and broke active projects. The user had to disable plugins to continue working on other repos. User-scope install creates a blast radius problem: a bug in one plugin affects every project.

## Decision Drivers

- **Safety**: Buggy hooks should not break unrelated projects
- **Least surprise**: Users expect plugins installed for one project to not interfere with others
- **Multi-project workflow**: Developers typically work on multiple repos; plugins appropriate for one may not be appropriate for all
- **Install overhead**: Project-scoped install means reinstalling per project, but this is a single `npx` command

## Considered Options

### Option 1: Default to `--scope project`

The installer passes `--scope project` to `claude plugin install`. Plugins only affect the project where they're installed. Users who want global install can pass `--scope user`.

### Option 2: Keep User Scope with Documentation Warning

Keep the default but document the risk of global hooks in the README and help text.

### Option 3: Prompt the User to Choose Scope

The installer asks the user which scope they want during install.

## Decision Outcome

**Chosen option: Option 1 — Default to `--scope project`**

Project scope provides isolation by default. The installer already has a `--scope` flag escape hatch for users who explicitly want global install.

## Consequences

### Good

- Buggy hooks can't break other projects
- Users can install different plugin versions per project
- Safer for experimentation and development

### Neutral

- Users must run the installer in each project where they want plugins
- Existing user-scoped installs are unaffected (they remain until explicitly uninstalled)

### Bad

- Users who genuinely want plugins everywhere must pass `--scope user` or install in each project

## Confirmation

- The `installPlugin` function always passes `--scope project` unless the caller explicitly overrides
- Help text documents the `--scope user` escape hatch
- `claude plugin list` shows project-scoped entries after install

## Pros and Cons of the Options

### Option 1: Default to `--scope project`

- Good: Isolation — buggy hooks can't break other projects
- Good: Matches user expectation of "install here, use here"
- Bad: Must reinstall per project

### Option 2: Keep User Scope with Warning

- Good: Install once, use everywhere
- Bad: Bugs affect all projects — the exact problem that motivated this decision
- Bad: Documentation warnings are easily missed

### Option 3: Prompt the User

- Good: User makes an informed choice
- Bad: Breaks non-interactive install (`npx @windyroad/agent-plugins` should just work)
- Bad: Adds friction to the install experience

## Reassessment Criteria

- **Plugin stability matures**: Once all hooks are well-tested and stable, reconsider whether user scope should be the default again.
- **Claude Code adds plugin sandboxing**: If Claude Code adds per-project plugin isolation at the platform level, this decision becomes moot.
- **Claude Code changes scope semantics**: If scope behavior changes in future versions, reassess accordingly.
