# @windyroad/architect

**Architecture decision enforcement for Claude Code.** Ensures every code change is reviewed against your project's architecture decisions before it lands. *Maturity: Experimental (suite-bootstrap window; 811 invocations / 30d).*

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

**Review recorded decisions that lack human oversight:**

```
/wr-architect:review-decisions
```

The `review-decisions` skill drains the set of ADRs that were recorded without a human confirming the chosen option (per ADR-066). It surfaces each decision's chosen option and alternatives via AskUserQuestion so you confirm, amend, or reject the auto-made call, then writes a `human-oversight: confirmed` marker. Detection is a token-cheap grep over ADR frontmatter; a session-start nudge reports the unoversighted count. New ADRs created through `create-adr` are born oversighted, so the unconfirmed set only shrinks.

**Run an on-demand architecture compliance review:**

```
/wr-architect:review-design
```

The `review-design` skill checks staged changes and recent commits against the existing ADRs in `docs/decisions/` — a pre-flight you can run before editing architecture-bearing files or cutting a release, without waiting for the per-edit gate.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `architect-detect.sh` | Every prompt | Checks for `docs/decisions/` and injects the review instruction |
| `architect-enforce-edit.sh` | Edit or Write | Blocks the edit if the architect hasn't reviewed yet |
| `architect-plan-enforce.sh` | ExitPlanMode | Ensures plans are reviewed before execution |
| `architect-mark-reviewed.sh` | Agent completes | Marks the review as done (TTL: 3600s) |
| `architect-refresh-hash.sh` | After edit | Refreshes the content hash so the next edit triggers a fresh review |
| `architect-slide-marker.sh` | Agent or Bash | Slides the review marker forward across non-edit operations so an active review session is not invalidated by intervening Bash or sub-agent calls |
| `architect-oversight-nudge.sh` | Session start | Reports how many recorded decisions lack human oversight and points to `/wr-architect:review-decisions`; silent when none, and self-suppressed inside AFK iterations |

## Agent

The `wr-architect:agent` reviews proposed changes against existing decisions in `docs/decisions/` and reports:

- Whether changes comply with or violate existing decisions
- Whether a new ADR should be created
- Whether existing decisions are stale and need reassessment

## Updating and Uninstalling

```bash
npx @windyroad/architect --update
npx @windyroad/architect --uninstall
```

## Licence

[MIT](../../LICENSE)
