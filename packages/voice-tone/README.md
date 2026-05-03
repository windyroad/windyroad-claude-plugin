# @windyroad/voice-tone

**Voice and tone enforcement for Claude Code.** Reviews user-facing copy against your brand's voice and tone guide before it ships.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

When an AI agent writes user-facing text -- button labels, error messages, onboarding copy, marketing pages -- it doesn't know your brand voice. This plugin teaches it.

The voice-tone plugin:

1. **Detects** when an edit touches user-facing copy
2. **Blocks** the edit until the voice-tone agent has reviewed it
3. **Reviews** the proposed copy against your `docs/VOICE-AND-TONE.md` guide
4. **Reports** violations with suggested fixes that match your brand's voice principles, banned patterns, and word list

## Install

```bash
npx @windyroad/voice-tone
```

Restart Claude Code after installing.

## Usage

The plugin works automatically. On first use in a project without a voice guide, it blocks edits and directs you to create one:

```
/wr-voice-tone:update-guide
```

This examines your existing content and asks about your brand voice, target audience, and tone preferences to generate a `docs/VOICE-AND-TONE.md` tailored to your project.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `voice-tone-eval.sh` | Every prompt | Evaluates whether the task involves user-facing copy |
| `voice-tone-enforce-edit.sh` | Edit or Write | Blocks edits until the voice-tone agent has reviewed |
| `voice-tone-mark-reviewed.sh` | Agent completes | Marks the review as done (TTL: 3600s) |

## Agent

The `wr-voice-tone:agent` reads your `docs/VOICE-AND-TONE.md` and reviews proposed copy changes against:

- Voice principles and personality traits
- Tone guidance for different contexts
- Banned words and patterns
- Preferred terminology

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — voice-and-tone review fires automatically on every user-facing copy edit; the project's own voice guide is the policy source rather than the agent's defaults.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — voice-and-tone alignment is reviewable on demand before a release or client handover.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/voice-tone --update
npx @windyroad/voice-tone --uninstall
```

## Licence

[MIT](../../LICENSE)
