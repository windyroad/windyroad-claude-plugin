# @windyroad/retrospective

**Session retrospectives for Claude Code.** Captures learnings at the end of each session and creates problem tickets for failures and friction. *Maturity: Experimental.*

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

Every coding session produces learnings -- things that went well, things that broke, things that were harder than expected. Without a retrospective, those learnings evaporate.

The retrospective plugin:

- **Reminds** you to run a retro when a session ends
- **Updates** `docs/BRIEFING.md` with session learnings so future sessions start with context
- **Creates problem tickets** (via [`@windyroad/itil`](../itil/)) for failures and friction encountered during the session

## Install

```bash
npx @windyroad/retrospective
```

Restart Claude Code after installing.

> **Requires:** [`@windyroad/itil`](../itil/) and [`@windyroad/risk-scorer`](../risk-scorer/). The installer warns if they're missing.

## Usage

**Run a session retrospective:**

```
/wr-retrospective:run-retro
```

This walks through the session's work, identifies what went well and what didn't, updates `docs/BRIEFING.md`, and creates problem tickets for any failures. The retro also runs every shipped advisory script (briefing budgets, ask-hygiene, README JTBD currency per ADR-051, SKILL.md runtime budgets per ADR-054) so doc-content drift surfaces in the retro summary alongside session-level reflections.

**Analyse session context usage:**

```
/wr-retrospective:analyze-context
```

Deep on-demand context-usage analyser per ADR-043. Generates per-source attribution, per-plugin decomposition, and suggested trim actions. Complements the cheap-layer measurement that `run-retro` always emits.

The plugin also triggers a reminder via a `Stop` hook when a session ends naturally.

## Skills

| Skill | Purpose | Maturity |
| ------- | --------- | --- |
| `/wr-retrospective:run-retro` | Run a session retrospective; emits the briefing update, advisory detector outputs, and the Pipeline Instability section per Step 2b | Alpha |
| `/wr-retrospective:analyze-context` | Deep on-demand context-usage analyser per ADR-043; produces per-turn attribution and trim suggestions | Experimental |

## Advisory scripts

Each script ships as a `bin/`-resolvable shim per ADR-049. They emit signal-as-data on stdout and exit 0 always (advisory per ADR-013 Rule 6). `run-retro` invokes them as part of Step 2b / Step 3 and surfaces their findings in the retro summary; they can also be invoked manually before a release or audit.

| Shim | Purpose |
|------|---------|
| `wr-retrospective-check-readme-jtbd-currency` | ADR-051 Phase 1 detector — surfaces drift between plugin READMEs and the JTBD jobs they cite |
| `wr-retrospective-check-skill-md-budgets` | ADR-054 detector — flags SKILL.md files over the WARN / MUST_SPLIT byte budget |
| `wr-retrospective-check-internal-id-leaks` | ADR-055 detector — flags internal IDs leaking into published artefacts |
| `wr-retrospective-list-plugin-attribution` | Per-plugin context attribution support for `analyze-context` |
| `wr-retrospective-measure-context-budget` | Cheap-layer context-budget measurement support for `run-retro` Step 2c |

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `bin/check-deps.sh` | Session start | Verifies that `wr-itil` and `wr-risk-scorer` are installed |
| `session-start-briefing.sh` | Session start | Surfaces the latest `docs/BRIEFING.md` and any pending retrospective items so the new session begins with prior-session context (per [ADR-040](../../docs/decisions/040-session-start-briefing-surface.proposed.md)) |
| `retrospective-reminder.sh` | Session end | Reminds you to run a retrospective |

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-006 Progress the Backlog While I'm Away](../../docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md)** — every AFK iteration runs a retrospective before exiting so per-iter friction is captured as problem tickets and surfaced on return; learnings flow back into `docs/BRIEFING.md` so the next session starts with context.
- **[JTBD-002 Ship AI-Assisted Code with Confidence](../../docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md)** — release-readiness signals (pipeline-instability scan, ask-hygiene check, doc-currency advisory) accumulate at retro time so unresolved friction is visible before the next release.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/retrospective --update
npx @windyroad/retrospective --uninstall
```

## Licence

[MIT](../../LICENSE)
