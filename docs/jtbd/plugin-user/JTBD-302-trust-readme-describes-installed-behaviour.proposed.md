---
status: proposed
job-id: trust-readme-describes-installed-behaviour
persona: plugin-user
date-created: 2026-05-03
human-oversight: confirmed
oversight-date: 2026-05-25
---

# JTBD-302: Trust That the README Describes the Plugin I Just Installed

## Job Statement

When I install a `@windyroad/*` plugin and read its README to understand what it does, I want to be confident the prose describes the version I just installed (not a prior release), so I can invoke the right skills, configure the right hooks, and trust the documented contract without cross-checking against the source under `node_modules/`.

## Desired Outcomes

- README narrative is anchored to the JTBD jobs the plugin currently serves — not a legacy job framing the plugin grew past.
- Every shipped skill, agent, and hook listed in the plugin's `plugin.json` / `commands/*.md` / `hooks/*.json` has a corresponding README mention. Inventory drift is detectable, not silent.
- When a skill is renamed or split (e.g. `manage-problem list` → `list-problems` per P071), README invocation examples reflect the **current** names, not the deprecated ones.
- When an ADR is amended and a README cited it (e.g. ADR-013 amended by ADR-044), the README citation is refreshed before the next release ships, not left dangling for adopters to catch.
- A drift-detection signal exists at commit / release / retrospective time so adopters never receive a silently-stale README via `npm install`.
- **(Amended 2026-05-04 by P159)** The signal is **load-bearing at commit time** via the PreToolUse:Bash hook (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`); retro-time and release-time advisories ride as backup signals. Drift class detection is enforced at the closest surface to the failure mode (the commit itself), not gradualism-deferred. The original advisory-then-escalate phrasing was superseded by P159 after the user correction *"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"*. **(Amended 2026-05-25 by P294/ADR-069: the commit-hook is retained but narrowed to skill-inventory-drift — a shipped skill not named in the README; the JTBD-ID-citation rule it used to enforce is superseded.)**
- **(Amended 2026-05-25 by P294/ADR-069)** The README **markets the persona's problem in prose** — derived from the JTBD jobs the plugin serves — so the adopter understands **what problem the plugin solves for them** directly, without cross-referencing an internal JTBD ID. ADR-069 superseded the ID-citation mechanism: the printed `JTBD-NNN` was plumbing the persona (low context on repo internals) could not act on.
- **(Amended in P087 Phase 3)** I can see the maturity band (and, during the suite-bootstrap window, the compound evidence per ADR-053 §Bootstrapping clause Phase 3 rendering requirement) for every plugin and every per-skill surface from the README alone, without source archaeology under `node_modules/` and without invoking measurement scripts. Drivers: ADR-053 (maturity taxonomy), ADR-058 (measurement scripts), ADR-063 (presentation-layer contract), P087 (parent ticket).

## Persona Constraints

- **Low context on repo internals.** The adopter does not read the monorepo's ADRs, problem tickets, or source. The README is the primary contract surface — when it drifts, the contract is silently broken.
- **AI agent as primary interface.** Many adopters interact with installed plugins through Claude Code; an agent reading a stale README expands stale prose into context and acts on out-of-date instructions. Currency is more critical for AI-mediated readership than for human readers who can spot drift through experience.
- **No `node_modules/` archaeology expected.** The persona's defining constraint is **not** reading source; expecting them to verify README claims against installed source defeats the plugin distribution model.
- **Trust is asymmetric.** A correct README earns no special trust; one stale claim erodes trust in everything the README says.

## Current Solutions

- **Source side (until P152 fix lands)**: nothing. READMEs are hand-maintained; drift accumulates between releases; release-time is when adopters re-encounter the drift via `npm install`. The asymmetry is stark — code drift has architect, JTBD, risk-scorer, style-guide, voice-tone, TDD, and changeset-discipline gates; README content drift has zero gates.
- **Adopter side**: compare the plugin's README against `node_modules/@windyroad/<plugin>/SKILL.md` / `hooks.json` / agent definitions. Heavyweight, brittle, and exactly the context this persona is defined as lacking.
- **Adopter-side fallback**: rely on changelog narrative and ignore the README. Loses the README's intended audience-framing value.

## Related problem tickets

- **P152** — originating ticket. *"There is nothing that provide pressure or nudges for us keeping the documentation up to date... leverage the JTBD pages so we can help the reader understand the value through the jobs it helps them do"* — filled the persona gap that ADR-051's drift-detector mechanism addresses.
- **P137** — sibling on adopter-facing content quality (semantic correctness axis): plugin-published artefacts reference internal IDs that don't resolve in adopter contexts. Composes with this job (semantic correctness vs currency).
- **P151** — sibling on adopter-facing content quality (executable correctness axis): published skills reference repo-relative script paths that don't resolve in adopter contexts. Resolved 2026-05-02 via ADR-049 bin/-on-PATH. Composes with this job.
- **P087** — sibling on adopter-facing content quality (maturity-label axis): no battle-hardening signal for plugin features. Composes with this job (static maturity vs dynamic currency).

## Related decisions

- **ADR-051** — JTBD-anchored README structure (amended P159; **superseded 2026-05-25 by ADR-069**). Originated the load-bearing commit-hook + prose-weaving; ADR-069 carries prose-weaving + skill-inventory currency forward and drops the JTBD-ID-citation rule.
- **(Added 2026-05-25) ADR-069** — READMEs market the persona's problem derived from the JTBD, no ID citation; the commit-hook is narrowed to skill-inventory-drift. Current home of the structural rule that serves this job.
- **(Added 2026-05-04) P159** — Drift detector should be a load-bearing commit-hook with auto-fix, not a retro-time advisory. Drives the load-bearing-from-the-start direction for this job's primary enforcement surface.
- **(Added 2026-05-04) P158** — Sibling problem ticket; retro Step 2b wiring shipped under `df47ad1`. Retro wiring survives as a backup advisory after P159 migrates the primary surface to the commit-hook.
- **ADR-049** — Plugin-bundled scripts invoked from SKILL.md resolve via `bin/` on `$PATH`. Sibling adopter-context decision (executable correctness axis).
- **ADR-013** — Structured user interaction; Rule 6 advisory-then-escalate pattern that ADR-051 follows for the drift detector.
- **ADR-008** — JTBD directory structure. Establishes `docs/jtbd/<persona>/JTBD-NNN-<title>.<status>.md` as the canonical layout the README anchors against.
