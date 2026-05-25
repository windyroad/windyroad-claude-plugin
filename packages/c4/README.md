# @windyroad/c4

**C4 architecture diagram generation and validation for Claude Code.** Generates C4 model diagrams from your source code and checks whether they're up to date. *Maturity: Experimental.*

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

## Updating and Uninstalling

```bash
npx @windyroad/c4 --update
npx @windyroad/c4 --uninstall
```

## Licence

[MIT](../../LICENSE)
