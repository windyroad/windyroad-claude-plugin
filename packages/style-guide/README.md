# @windyroad/style-guide

**Style guide enforcement for Claude Code.** Reviews CSS and UI component changes against your design system before they're applied. *Maturity: Experimental (suite-bootstrap window; 100 invocations / 30d).*

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

AI agents generate CSS that works but doesn't match your design system. They pick arbitrary colours, invent spacing values, and ignore your component patterns. This plugin catches that.

The style-guide plugin:

1. **Detects** when an edit touches CSS, style tokens, or visual styling
2. **Blocks** the edit until the style-guide agent has reviewed it
3. **Reviews** the proposed changes against your `docs/STYLE-GUIDE.md`
4. **Reports** violations with suggested fixes

## Install

```bash
npx @windyroad/style-guide
```

Restart Claude Code after installing.

## Usage

The plugin works automatically. On first use in a project without a style guide, it blocks edits and directs you to create one:

```
/wr-style-guide:update-guide
```

This examines your existing CSS, components, and design patterns, then asks about your style preferences to generate a `docs/STYLE-GUIDE.md`.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `style-guide-eval.sh` | Every prompt | Evaluates whether the task involves visual styling |
| `style-guide-enforce-edit.sh` | Edit or Write | Blocks edits until the style-guide agent has reviewed |
| `style-guide-mark-reviewed.sh` | Agent completes | Marks the review as done (TTL: 3600s) |

## Agent

The `wr-style-guide:agent` reads your `docs/STYLE-GUIDE.md` and reviews proposed changes against your documented design system.

## Updating and Uninstalling

```bash
npx @windyroad/style-guide --update
npx @windyroad/style-guide --uninstall
```

## Licence

[MIT](../../LICENSE)
