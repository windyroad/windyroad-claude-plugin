# @windyroad/c4

**C4 architecture diagram generation and validation for Claude Code.** Generates C4 model diagrams from your source code and checks whether they're up to date.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

Architecture diagrams go stale. The C4 plugin keeps them current by generating C3 (component) and C4 (code) views directly from your source code. No manual diagram maintenance.

## Install

```bash
npx @windyroad/c4
```

Restart Claude Code after installing.

## Usage

**Generate or regenerate C4 diagrams:**

```
/wr-c4:generate
```

Analyses your source code and produces C3 component and C4 code-level architecture diagrams.

**Check whether diagrams are up to date:**

```
/wr-c4:check
```

Compares the current source code against existing diagrams and reports whether they need regeneration.

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — `/wr-c4:check` produces a release-readiness signal on whether architecture diagrams are still accurate; `/wr-c4:generate` regenerates them when they are not. Both are attachable to a release note or handover doc.

### Plugin developer

- **[JTBD-101 Extend the Suite with New Plugins](../../docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md)** — generated C3 component and C4 code-level views give contributors a structural mental model of the suite without reverse-engineering from source.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/c4 --update
npx @windyroad/c4 --uninstall
```

## Licence

[MIT](../../LICENSE)
