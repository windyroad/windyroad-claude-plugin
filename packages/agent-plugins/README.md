# @windyroad/agent-plugins

**One-command installer for all Windy Road Agent Plugins.** Installs the full governance suite into your Claude Code project with a single `npx` call.

Part of [Windy Road Agent Plugins](../../README.md).

## Install

**Install everything:**

```bash
npx @windyroad/agent-plugins
```

**Install specific plugins only:**

```bash
npx @windyroad/agent-plugins --plugin architect tdd risk-scorer
```

Restart Claude Code after installing. Type `/wr-` to see all available skills.

> Plugins install to your project by default (not globally). Pass `--scope user` to install globally.

## Available Plugins

| Plugin | What it does |
|--------|-------------|
| `architect` | Architecture decision enforcement |
| `risk-scorer` | Pipeline risk scoring, commit/push gates, secret leak detection |
| `tdd` | Red-Green-Refactor TDD cycle enforcement |
| `voice-tone` | Voice and tone review for user-facing copy |
| `style-guide` | Style guide review for CSS and UI components |
| `jtbd` | Jobs-to-be-done review for UI changes |
| `itil` | ITIL-aligned problem and incident management |
| `retrospective` | Session retrospectives |
| `connect` | Cross-repo agent collaboration via Discord (experimental) |
| `c4` | C4 architecture diagram generation |
| `wardley` | Wardley Map generation |

## Jobs to be Done

This meta-installer is the front door for the suite. It serves the [Jobs to be Done](../../docs/jtbd/) below; per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md) the JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-003 Compose Only the Guardrails I Need](../../docs/jtbd/solo-developer/JTBD-003-compose-guardrails.proposed.md)** — `--plugin <name> [<name> ...]` selects exactly the guardrails the project needs without forcing the whole suite.
- **[JTBD-007 Keep Plugins Current Across Projects](../../docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md)** — `--update` refreshes every installed `@windyroad/*` plugin in one command, addressing plugin-version drift across sibling projects (the persona's named pain point).

### Plugin developer

- **[JTBD-101 Extend the Suite with New Plugins](../../docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md)** — the meta-installer's package list is the canonical inventory contributors register a new plugin against.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating

```bash
npx @windyroad/agent-plugins --update
```

## Uninstalling

```bash
npx @windyroad/agent-plugins --uninstall
```

## Licence

[MIT](../../LICENSE)
