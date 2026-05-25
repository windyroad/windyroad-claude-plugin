# @windyroad/wardley

**Wardley Map generation for Claude Code.** Analyses your codebase and generates a value chain evolution map. *Maturity: Experimental.*

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

## Updating and Uninstalling

```bash
npx @windyroad/wardley --update
npx @windyroad/wardley --uninstall
```

## Licence

[MIT](../../LICENSE)
