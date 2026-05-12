# Style Guide

## Purpose

This project is a plugin-development monorepo. Style guidance applies primarily to:

- Story-map HTML (`docs/story-maps/**/*.html`) — minimal embedded `<style>` per ADR-060 § Phase 2 encoding amendment 2026-05-12.
- Any CSS / JSX / TSX / Vue / Svelte / ejs / hbs surfaces shipped by plugins (currently none — the repo publishes governance plugins, not UI plugins).

## Story-map HTML style rules

Per ADR-060 § Phase 2 encoding amendment 2026-05-12 lines 392-435:

### Layout
- Backbone × ribs × slices uses CSS Grid via embedded `<style>` block in `<head>`. Layout-only rules (no semantic styling).
- Grid sizing via `--<custom-property>` variables permitted inline on layout-container elements (e.g. `style="--cols: 4"` on `.backbone`).

### Prohibited
- **Inline `style=""` on data-bearing elements**: `<a class="slice">` carrying `data-story-id` MUST NOT carry inline `style=""`. Rationale: keeps `grep`-as-lint deterministic; data-attribute extraction never matches a styling string.
- **Inline `style=""` on `<h2 class="rib-header">` carrying `data-rib`**: same rationale.
- **External stylesheets** (`<link rel="stylesheet">`): story maps are self-contained artefacts; the embedded `<style>` block in `<head>` is the only permitted styling source.

### Permitted
- Embedded `<style>` block in `<head>` with layout-only class-keyed rules.
- `--<custom-property>` variables inline on layout containers (e.g. `--cols`, `--rows`, `--gap`).
- HTML5 semantic elements: `<section>`, `<header>`, `<h1>` / `<h2>`, `<a>`, `<div>` (only as a layout container).

### Class names (story-map vocabulary)
- `.backbone` — top-level grid container; one per map.
- `.rib` — horizontal lane of related slices; many per map.
- `.rib-header` — heading row for a rib; one per rib.
- `.slice` — single story reference (carries `data-story-id`); many per rib.

### Data attributes (machine-readable trace)
- `data-story-id="STORY-NNN"` — on `<a>` slice element.
- `data-rfc="RFC-NNN"` — optional; ties the slice to a parent RFC.
- `data-jtbd="JTBD-NNN"` — optional; ties to a persona-job.
- `data-status="<draft|accepted|in-progress|done|archived>"` — story's lifecycle state at map-render time.

## Naming

- **Filenames**: kebab-case. `STORY-MAP-001-rfc-framework-phase-1-bootstrap.html` not `storyMap001RfcFramework.html`.
- **CSS class names**: kebab-case. `.rib-header` not `.ribHeader` or `.rib_header`.
- **Custom properties**: kebab-case prefixed with `--`. `--cols` not `--Cols` or `--c`.

## Colours

Story maps are intentionally style-minimal; colour is OPTIONAL. If used:

- High contrast against white background (WCAG AA minimum 4.5:1 for text).
- Conventional status indicators: `draft = gray`, `accepted = blue`, `in-progress = yellow`, `done = green`, `archived = light gray`.
- No background colours on data-bearing `<a class="slice">` elements (keep them visually neutral; status conveyed via border / outline if at all).

## Typography

- Use the browser default font stack via `font-family: system-ui, sans-serif;` in the embedded style block.
- Slice card text: ≤ 80 characters; truncate longer titles with CSS `text-overflow: ellipsis` if needed.
- Heading sizes: H1 for map title; H2 for rib headers; no H3+ inside slices (slices are leaves).

## Scope

This guide applies to:
- HTML under `docs/story-maps/**/*.html`
- CSS files (none currently in the repo)
- JSX / TSX / Vue / Svelte component style blocks (none currently)
- ejs / hbs templates with embedded styling (none currently)

It does NOT apply to:
- Markdown documentation (no styling; render-target-dependent).
- Plugin SKILL.md prose (covered by `docs/VOICE-AND-TONE.md`).
- Test fixtures or temp HTML (out of scope; not adopter-facing).

## Related

- **ADR-060 amendment 2026-05-12** — HTML encoding for story-maps + prohibition on inline style on data-bearing elements.
- **`docs/VOICE-AND-TONE.md`** — sibling policy for prose content.
- **`docs/story-maps/README.md`** — story-map directory scaffold + per-state subdir convention.
- **JTBD-302** — Trust That the README Describes the Plugin I Just Installed; style guidance supports that trust by keeping HTML simple, semantic, and grep-able.
