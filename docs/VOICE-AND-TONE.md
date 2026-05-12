# Voice and Tone Guide

## Purpose

This project (`windyroad-claude-plugin`) is a plugin-development monorepo publishing `@windyroad/*` Claude Code plugins covering governance, risk management, ITIL, TDD, JTBD, retrospectives, and delivery quality.

The audience for HTML / copy-bearing content in this repo is **internal**: plugin maintainers, contributors, and adopters reading reference documentation. Story maps (`docs/story-maps/**/*.html`), README files, and CHANGELOG entries are the primary surfaces.

## Audience

- **Solo developers** building plugins, consuming the framework's primitives day-to-day.
- **Plugin developers / tech leads** extending the suite — atomic-fix-adopters and multi-commit-coordination-adopters.
- **Plugin users** reading shipped plugin READMEs and intake template prompts.

## Voice principles

1. **Precise over flowery** — engineering primitives have exact meanings; use the right word, not the prettier word. `RFC` is `RFC`, not `change proposal`.
2. **Active over passive** — `the skill writes the file` not `the file is written by the skill`. Names the actor; reveals responsibility.
3. **Specific over abstract** — cite ADR / problem / story IDs by number. `Per ADR-060 line 252` not `Per the architecture decision`.
4. **Plain over jargon-rich** — explain ITIL / Patton / WSJF terms when they first appear; assume the reader knows code but not the framework yet.
5. **Honest about deferral** — when work is partial or blocked, say so explicitly. `Slice 14 blocked on marketplace release` not `Slice 14 in progress`.

## Tone guidance

- **Conversational where appropriate** — SKILL.md prose addresses an LLM agent reading the contract; "you" / "the agent" / "the skill" forms are clear.
- **Authoritative for invariants** — `I7 hard-blocks at accepted` is a contract; the prose says so directly.
- **Neutral on choices** — when two paths exist (e.g. atomic-RFC fallback vs. story-decomposed), name both without preferring one; let the reader's context drive selection.

## Banned patterns

- **Marketing speak**: "powerful", "seamless", "robust", "industry-leading", "best-in-class" — meaningless for engineering primitives; remove.
- **Hedging without payoff**: "might", "could potentially", "may help" without naming the condition; replace with `When <condition>, <outcome>` or remove.
- **Apologetic prose**: "unfortunately", "sadly", "we regret" — neutral facts are better than apologies. The user prefers honest deferral over performative apology.
- **Implicit second-person commands without subject**: "Just run this" — name what `just` modifies, name the actor.

## Word list

| Prefer | Avoid |
|--------|-------|
| `problem` | `bug`, `issue`, `defect` (in framework contexts; reserve for specific surfaces) |
| `RFC` | `change proposal`, `change request` |
| `story` | `task`, `ticket`, `card` (in story-tier contexts; tasks are Phase 1 placeholder) |
| `traceable to` | `owned by`, `belongs to`, `under` |
| `hard-block` | `prevent`, `disallow`, `forbid` (when the invariant is gate-enforced) |
| `lightweight aside` / `heavyweight intake` | `simple skill` / `full skill` |
| `JTBD` (acronym) | `Job To Be Done` (acronym is universally understood in the framework) |
| `fail-open` / `fail-closed` | `permissive` / `strict` (when describing gate behaviour) |

## HTML content (story-maps)

Story maps in `docs/story-maps/**/*.html` use HTML5 + minimal embedded `<style>` per ADR-060 § Phase 2 encoding amendment 2026-05-12. Voice guidance:

- **Story titles** in `<a>` element text: short imperative or noun phrase; `Build capture-story skill` not `In which we build the capture-story skill`.
- **Backbone activity headings** in `<h2 data-rib>`: noun phrase naming the user-journey segment; `Capture` / `Validate` / `Decompose` / `Implement` / `Verify`.
- **No marketing speak** in `<title>` element or `<meta>` blocks; same banned patterns as Markdown surfaces.
- **Plain language** in any inline text describing the map's purpose; rely on data-attributes for machine-readable trace, prose for human readability.

## Scope

This guide applies to:
- HTML files under `docs/story-maps/**/*.html`
- JSX / TSX / Vue / Svelte components if any UI ships from this repo (currently none — plugin-development monorepo)
- ejs / hbs templates if any ship (currently none)

It does NOT apply to:
- Markdown documentation (covered by per-skill SKILL.md guidance + project CLAUDE.md)
- Changesets (`.changeset/*.md` covered by `wr-risk-scorer:external-comms` review gate per P073)
- Commit messages (covered by ADR-014 + ADR-018)

## Related

- **ADR-051** — JTBD-anchored README rule; voice guide composes with that.
- **ADR-060 amendment 2026-05-12** — HTML encoding for story-maps; this guide names voice rules for that surface.
- **CLAUDE.md** — project guidance; voice rules echo the MANDATORY rules there (e.g. "act on obvious, AskUserQuestion for ambiguous, NEVER prose-ask").
- **JTBD-302** — Trust That the README Describes the Plugin I Just Installed; voice rules support that trust by keeping prose honest about deferral and explicit about contracts.
- **JTBD-101** — Plugin developer extends the suite; voice rules favour the plain-language + plain-imperative shape that helps adopters extend confidently.
