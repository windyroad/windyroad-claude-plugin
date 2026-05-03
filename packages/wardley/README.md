# @windyroad/wardley

**Wardley Map generation for Claude Code.** Analyses your codebase and generates a value chain evolution map.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

A [Wardley Map](https://learnwardleymapping.com/) visualises your system's components along two axes: value chain (visibility to the user) and evolution (genesis to commodity). This plugin generates one from your source code.

It produces:

- **OWM source file** -- editable source in Online Wardley Maps format
- **SVG and PNG** -- rendered diagram images
- **Markdown analysis** -- written interpretation of the map's strategic implications

## Install

```bash
npx @windyroad/wardley
```

Restart Claude Code after installing.

## Usage

**Generate or update the Wardley Map:**

```
/wr-wardley:generate
```

Analyses your codebase to identify components, their relationships, and their evolutionary stage, then produces the map and analysis.

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — a fresh Wardley Map is a strategic-readiness signal attachable to a release note or handover doc; the analysis surfaces commodity-vs-genesis components and their evolutionary stage.

### Plugin developer

- **[JTBD-101 Extend the Suite with New Plugins](../../docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md)** — generated Wardley Maps give contributors a value-chain mental model of the suite without reverse-engineering from source.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/wardley --update
npx @windyroad/wardley --uninstall
```

## Licence

[MIT](../../LICENSE)
