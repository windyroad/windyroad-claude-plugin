---
status: proposed
job-id: compose-guardrails
persona: developer
date-created: 2026-04-14
human-oversight: confirmed
oversight-date: 2026-05-31
---

# JTBD-003: Compose Only the Guardrails I Need

## Job Statement

When I only need architecture and TDD enforcement, I want to install just those two plugins, so my session isn't cluttered with hooks that don't apply to my project.

## Desired Outcomes

- Each plugin is independently installable via `npx @windyroad/<name>`
- Installing a subset does not degrade the experience for installed plugins
- The meta-installer supports selective install via `--plugin` flag
- **(Amended in P087 Phase 3)** I can see at glance which surfaces in a plugin are stable enough to depend on without invoking measurement scripts — the maturity band rendered into each plugin's README (per ADR-063 §Phase 3b) tells me whether to compose `manage-problem` (heavily exercised) or `mitigate-incident` (newly shipped) without having to read transcripts, run measurement scripts, or eyeball commit history. Drivers: ADR-053 (taxonomy), ADR-063 (presentation), P087 (parent ticket).

## Persona Constraints

- May install only 2-3 plugins relevant to their project

## Current Solutions

Install everything and ignore irrelevant hooks, or don't install at all
