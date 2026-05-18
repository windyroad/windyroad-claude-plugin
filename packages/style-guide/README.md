# @windyroad/style-guide

**Style guide enforcement for Claude Code.** Reviews CSS and UI component changes against your design system before they're applied. *Maturity: Experimental.*

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

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — style-guide review fires automatically on every CSS or component edit; the project's own design system is the policy source.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — style-guide alignment is reviewable on demand before a release or client handover.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/style-guide --update
npx @windyroad/style-guide --uninstall
```

## Licence

[MIT](../../LICENSE)
