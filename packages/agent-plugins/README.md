# @windyroad/agent-plugins

**One-command installer for all Windy Road Agent Plugins.** Install exactly the guardrails your project needs — architecture, risk, TDD, ITIL, retrospectives, and more — in a single `npx` call, instead of wiring each plugin up by hand.

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
