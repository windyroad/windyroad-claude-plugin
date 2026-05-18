# @windyroad/architect

**Architecture decision enforcement for Claude Code.** Ensures every code change is reviewed against your project's architecture decisions before it lands. *Maturity: Experimental.*

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

The architect plugin prevents architectural drift by gating edits behind an architecture review. When you have a `docs/decisions/` directory, the plugin:

1. **Detects** your architecture decisions on every prompt
2. **Blocks** edits to project files until the architect agent has reviewed the proposed changes
3. **Reviews** changes against your existing ADRs (Architecture Decision Records) and flags conflicts
4. **Flags** when a new decision should be documented

No decisions directory yet? The plugin stays silent until you create one.

## Install

```bash
npx @windyroad/architect
```

Restart Claude Code after installing.

## Usage

Once installed, the plugin works automatically. You don't need to invoke it -- it intercepts edits and runs the review before allowing changes through.

**Create a new Architecture Decision Record:**

```
/wr-architect:create-adr
```

This walks you through creating an ADR in [MADR 4.0](https://adr.github.io/madr/) format. It examines your existing decisions, asks about the problem and options, and writes a properly formatted record to `docs/decisions/`.

**Capture an architecture decision in the background while staying in the main turn:**

```
/wr-architect:capture-adr
```

The `capture-adr` skill is the foreground-lightweight aside-invocation variant of `create-adr` (per ADR-032 background-capture pattern). Use it when an architecture decision surfaces mid-conversation and you want the ADR scaffold drafted without losing the operational thread.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `architect-detect.sh` | Every prompt | Checks for `docs/decisions/` and injects the review instruction |
| `architect-enforce-edit.sh` | Edit or Write | Blocks the edit if the architect hasn't reviewed yet |
| `architect-plan-enforce.sh` | ExitPlanMode | Ensures plans are reviewed before execution |
| `architect-mark-reviewed.sh` | Agent completes | Marks the review as done (TTL: 3600s) |
| `architect-refresh-hash.sh` | After edit | Refreshes the content hash so the next edit triggers a fresh review |
| `architect-slide-marker.sh` | Agent or Bash | Slides the review marker forward across non-edit operations so an active review session is not invalidated by intervening Bash or sub-agent calls |

## Agent

The `wr-architect:agent` reviews proposed changes against existing decisions in `docs/decisions/` and reports:

- Whether changes comply with or violate existing decisions
- Whether a new ADR should be created
- Whether existing decisions are stale and need reassessment

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — architect review is available via `/wr-architect:review-design` for on-demand pre-flight, and via `wr-architect:agent` for automatic review on every edit.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — architecture decisions are reviewed automatically; the agent reads the project's existing ADRs without needing to be told what to look for.

### Plugin developer

- **[JTBD-101 Extend the Suite with New Plugins](../../docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md)** — `/wr-architect:create-adr` is the canonical surface for documenting structural decisions in MADR 4.0 format so contributors learn the "why" behind existing patterns.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/architect --update
npx @windyroad/architect --uninstall
```

## Licence

[MIT](../../LICENSE)
