# Windy Road Agent Plugins

**Governance guardrails for AI coding agents.** Architecture reviews, risk scoring, TDD enforcement, and delivery quality gates that run automatically inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Built by [Windy Road Technology](https://windyroad.com.au).

## The Problem

AI coding agents are fast. Sometimes too fast. They skip architecture reviews, introduce risk without assessment, ignore your design system, and write implementation before tests. The same governance that keeps human teams shipping safely gets bypassed when an agent writes code.

These plugins bring that governance back -- automatically. They hook into Claude Code's plugin system and enforce your team's standards on every edit, commit, and push. No manual checks. No hoping the agent remembers.

## Quick Start

Install all plugins with one command:

```bash
npx @windyroad/agent-plugins
```

Restart Claude Code. That's it. The plugins activate automatically based on what they find in your project.

**Install only what you need:**

```bash
npx @windyroad/agent-plugins --plugin architect tdd risk-scorer
```

**Or install a single plugin directly:**

```bash
npx @windyroad/architect
```

> Plugins install to your project by default (not globally), so they won't affect your other projects. Pass `--scope user` to install globally.

After installing, type `/wr-` in Claude Code to see all available skills.

## How It Works

Each plugin uses Claude Code's hook system to intercept actions at the right moment:

1. **Detect** -- A `UserPromptSubmit` hook scans for relevant project files (e.g., `docs/decisions/` for architect, `RISK-POLICY.md` for risk-scorer)
2. **Gate** -- A `PreToolUse` hook blocks edits to relevant files until the review agent has been consulted
3. **Review** -- The agent reviews the proposed change against your project's policy documents
4. **Unlock** -- A `PostToolUse` hook marks the review as complete, allowing edits to proceed

Policy files are generated for you. When a plugin detects that its policy file is missing, it blocks edits and directs you to the setup skill (e.g., `/wr-voice-tone:update-guide`).

## Plugins

### Governance and Quality Gates

These plugins enforce review workflows. They block edits to relevant files until the appropriate review agent has been consulted.

| Package | What it enforces |
|---------|-----------------|
| [`@windyroad/architect`](packages/architect/) | Architecture decisions reviewed before code changes |
| [`@windyroad/risk-scorer`](packages/risk-scorer/) | Pipeline risk scoring, commit/push gates, secret leak detection |
| [`@windyroad/tdd`](packages/tdd/) | Red-Green-Refactor TDD cycle for implementation code |
| [`@windyroad/voice-tone`](packages/voice-tone/) | User-facing copy reviewed against voice and tone guide |
| [`@windyroad/style-guide`](packages/style-guide/) | CSS and UI components reviewed against style guide |
| [`@windyroad/jtbd`](packages/jtbd/) | UI changes reviewed against jobs-to-be-done document |

### Process Tools

| Package | What it does |
|---------|-------------|
| [`@windyroad/itil`](packages/itil/) | ITIL-aligned IT service management — problem management (WSJF-prioritised) and evidence-first incident management with automatic handoff |
| [`@windyroad/retrospective`](packages/retrospective/) | Session retrospectives that update briefings and create problem tickets |
| [`@windyroad/connect`](packages/connect/) | Cross-repo agent collaboration via Discord channels (experimental — see plugin README) |

### Diagram Generation

| Package | What it does |
|---------|-------------|
| [`@windyroad/c4`](packages/c4/) | C4 architecture diagram generation and validation |
| [`@windyroad/wardley`](packages/wardley/) | Wardley Map generation from source code analysis |

### Meta-Installer

| Package | What it does |
|---------|-------------|
| [`@windyroad/agent-plugins`](packages/agent-plugins/) | One-command installer for all plugins |

## Dependencies Between Plugins

Most plugins are standalone. Two have dependencies:

```
@windyroad/retrospective
  └── @windyroad/itil
        └── @windyroad/risk-scorer
```

The installer warns if dependencies are missing.

## Jobs to be Done

Each plugin's value framing is anchored to documented [Jobs to be Done](docs/jtbd/) — persona-grouped jobs that describe **what user pain the plugin removes**, not just **what features it ships**. Per [ADR-051](docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), every `@windyroad/*` plugin README cites at least one current JTBD job ID so the README is a navigable index into the JTBD research, not just a feature list.

| Persona | Primary jobs | Plugins serving this persona |
|---------|--------------|-----------------------------|
| **[Solo developer](docs/jtbd/solo-developer/persona.md)** — uses AI agents on personal or small-team projects | [JTBD-001 Enforce Governance Without Slowing Down](docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md), [JTBD-002 Ship with Confidence](docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md), [JTBD-003 Compose Only the Guardrails I Need](docs/jtbd/solo-developer/JTBD-003-compose-guardrails.proposed.md), [JTBD-006 Progress the Backlog While I'm Away](docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md), [JTBD-007 Keep Plugins Current Across Projects](docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md) | architect, risk-scorer, tdd, jtbd, voice-tone, style-guide, retrospective, agent-plugins |
| **[Tech lead / consultant](docs/jtbd/tech-lead/persona.md)** — accountable for code quality across teams or client engagements | [JTBD-201 Restore Service Fast with an Audit Trail](docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md), [JTBD-202 Pre-Flight Governance Checks Before Release](docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md) | itil, architect, risk-scorer, c4, wardley |
| **[Plugin developer](docs/jtbd/plugin-developer/persona.md)** — extends the suite with new plugins | [JTBD-101 Extend the Suite with New Plugins](docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) | architect, agent-plugins, c4, wardley |
| **[Plugin user](docs/jtbd/plugin-user/persona.md)** — installed a plugin and hit a problem; reporting is incidental to their primary work | [JTBD-301 Report a Problem Without Pre-Classifying It](docs/jtbd/plugin-user/JTBD-301-report-problem-without-pre-classifying.proposed.md), [JTBD-302 Trust That the README Describes the Plugin I Just Installed](docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md) | itil (intake surface), every plugin (README currency) |

See [`docs/jtbd/README.md`](docs/jtbd/README.md) for the full index.

## Risk Management

This suite follows ISO 31000 / ISO 27001 risk management practice. Risk criteria, impact and likelihood scales, appetite, and the matrix are defined in [`RISK-POLICY.md`](RISK-POLICY.md). Standing risks the suite tolerates and treats are tracked in the [risk register](docs/risks/README.md). Per-change pipeline risk is scored on every commit, push, and release by `@windyroad/risk-scorer` and snapshotted to `.risk-reports/` for audit purposes.

## Updating and Uninstalling

```bash
# Update everything
npx @windyroad/agent-plugins --update

# Update a single plugin
npx @windyroad/architect --update

# Remove everything
npx @windyroad/agent-plugins --uninstall

# Remove a single plugin
npx @windyroad/architect --uninstall
```

## Development

For plugin development, load directly from source with `--plugin-dir`:

```bash
claude --plugin-dir ~/Projects/windyroad-agent-plugins/packages/architect
```

Or load all plugins at once:

```bash
./claude-wr.sh
```

Changes take effect on session restart -- no install or update step needed.

### Running Tests

Hook tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System):

```bash
npm test
```

### Releasing

This monorepo uses [Changesets](https://github.com/changesets/changesets) for versioning:

```bash
npx changeset        # Create a changeset
npm run release      # Publish to npm
npm run push:watch   # Push and watch CI
```

## Monorepo Structure

```
packages/
  agent-plugins/    Meta-installer for all plugins
  architect/        Architecture decision enforcement
  risk-scorer/      Pipeline risk scoring and gates
  tdd/              TDD state machine enforcement
  voice-tone/       Voice and tone review
  style-guide/      Style guide review
  jtbd/             Jobs-to-be-done review
  itil/             ITIL problem and incident management
  retrospective/    Session retrospectives
  connect/          Cross-repo agent collaboration via Discord
  c4/               C4 diagram generation
  wardley/          Wardley Map generation
  shared/           Shared install utilities (internal)
```

## Licence

[MIT](LICENSE)
