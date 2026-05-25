---
status: "proposed"
date: 2026-04-16
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-10-16
---

# Add `manage-incident` Skill to `wr-itil` Plugin

## Context and Problem Statement

The `wr-itil` plugin currently ships a single skill, `manage-problem`, which drives a root-cause-oriented ITIL problem management workflow. There is no peer skill for **incident management** — the "production is broken right now" workflow whose primary goal is restoring service, not finding the root cause.

In practice, incidents and problems are distinct:

- An **incident** is a time-bound event: service is degraded, stakeholders are watching, and the priority is restoration. Root cause can wait.
- A **problem** is a persistent underlying cause that may manifest as one or more incidents. Its lifecycle is driven by investigation, known-error documentation, and WSJF-ranked remediation.

Without a dedicated skill, incidents are handled ad-hoc in chat. Hypotheses are acted on without cited evidence. Root causes are lost or conflated with the incident record. Post-incident reviews are written from memory. ADR-010 renamed the plugin from `wr-problem` to `wr-itil` precisely to carve room for peer ITIL skills; `manage-incident` is the first skill exercising that room.

Driven by JTBD-201 (Restore Service Fast with an Audit Trail) under the tech-lead persona.

## Decision Drivers

- **Evidence-first incident response**: hypotheses must cite evidence (logs, repro, diff, metric) before any mitigation is attempted. Reversible mitigations preferred over forward fixes.
- **Restoration-first priority**: during an incident, root-cause work is deferred; the skill must not slow restoration with investigation ceremony.
- **Clean handoff to problem management**: once service is restored, the incident must create or update a problem record so the underlying cause is tracked — without manual re-typing.
- **Audit trail**: timeline, observations, mitigations, and verification signals must be captured as a first-class artefact.
- **ADR-010 naming pattern**: `/wr-itil:<verb>-<object>` → `manage-incident`.
- **Solo-developer constraint**: the workflow must stay lightweight for low-severity incidents — no mandatory ceremony that discourages small-team use.
- **ADR-005 / P011 testing discipline**: behavioural tests must be functional, not source-grep.

## Considered Options

### Lifecycle separation

**Option A: Separate incident lifecycle and namespace (`I###` in `docs/incidents/`)** — chosen

**Option B: Extend `manage-problem` with incident states**

**Option C: Single unified ticket namespace (`T###` in `docs/tickets/`)**

#### Pros and Cons

| Option | Pros | Cons |
|--------|------|------|
| A (separate) | Mirrors ITIL model; prioritisation models (severity vs WSJF) stay clean; each lifecycle is tight and purpose-built; easy to cross-link many incidents to one problem | Two numbering schemes to maintain; users must learn both |
| B (extend problem) | Single skill, single file shape | Conflates restoration-first and root-cause-first priorities; WSJF makes no sense for live incidents; problem file becomes noisy with incident timelines |
| C (unified tickets) | One namespace, one skill | Same conflation as B plus loses the ITIL framing the plugin was renamed for (ADR-010) |

### Numbering scheme

**Option A: `I###` prefix in `docs/incidents/`** — chosen

**Option B: `INC-###` prefix**

**Option C: Year-prefixed (`2026-I-###`)**

**Option D: Shared namespace with problems**

#### Pros and Cons

| Option | Pros | Cons |
|--------|------|------|
| A (`I###`) | Matches `P###` house style; short, greppable, sorts naturally | Namespace collision requires vigilance if another domain adopts `I` |
| B (`INC-###`) | Disambiguates from `P`; matches some ITIL tools | Inconsistent with existing `P###` pattern |
| C (year-prefixed) | Groups by year | Long filenames; breaks when an incident spans year boundary |
| D (shared) | Single namespace | Loses lifecycle separation from Option A above |

### Evidence-first methodology

**Option A: SKILL.md enforces a required structured template (`## Observations`, `## Hypotheses` with evidence citation, `## Mitigation attempts`)** — chosen

**Option B: Encourage evidence-first in prose, no structural requirement**

**Option C: Separate "evidence log" file per incident**

#### Pros and Cons

| Option | Pros | Cons |
|--------|------|------|
| A (required template) | Auditable, enforceable, catches "jumping to conclusions" at the template level | Slightly heavier — though quality checks can waive sections for low-severity incidents |
| B (prose) | Maximum flexibility | No enforcement; skill becomes documentation, not workflow |
| C (separate file) | Rich evidence capture | Two-file workflow is brittle; incidents are short-lived and the second file gets lost |

### Cross-skill handoff (incident → problem)

**Option A: Direct `Skill`-tool call from `manage-incident` to `manage-problem`** — chosen

**Option B: Shared library extracted into `packages/itil/lib/` used by both skills**

**Option C: User-driven manual handoff (skill outputs instructions, user invokes problem skill themselves)**

**Option D: File-marker handoff (incident writes a marker file, problem skill picks it up)**

#### Pros and Cons

| Option | Pros | Cons |
|--------|------|------|
| A (Skill-tool call) | Direct, auditable in the session transcript, reuses existing dedupe flow in `manage-problem`, no new abstraction | Establishes a new inter-skill coupling — must be documented (this ADR) |
| B (shared library) | Reuses core logic without coupling skills | Premature abstraction before a second consumer exists; adds install-time complexity |
| C (manual handoff) | Zero coupling | User friction exactly where the user is most exhausted — at end of incident |
| D (file-marker) | Loose coupling | Async semantics are wrong for an interactive incident session; adds state-machine complexity |

### Prioritisation

**Option A: Severity only for incidents; WSJF stays on problems** — chosen

**Option B: WSJF for both**

#### Pros and Cons

| Option | Pros | Cons |
|--------|------|------|
| A (severity only) | Matches reality — live incidents are time-bound, not backlog-ranked. Users rank active incidents by severity, not by ROI | None significant |
| B (WSJF both) | Pattern consistency | WSJF divisor (effort) is meaningless during a live incident; restoration time is the only relevant clock |

## Decision Outcome

**Chosen options:**

1. Separate incident lifecycle with `I###` numbering in `docs/incidents/`.
2. Lifecycle: `investigating → mitigating → restored → closed`, mirroring `manage-problem`'s file-suffix pattern.
3. Required evidence-first template in SKILL.md.
4. Direct `Skill`-tool call from `manage-incident` to `manage-problem` on restoration.
5. Severity only for incidents; WSJF remains a problem-only concept.

Together these encode the "cool-headed, evidence-first, restore-then-learn" workflow the plugin needs while keeping the existing `manage-problem` skill untouched.

The cross-skill invocation pattern (decision 4) is the first-of-its-kind for this plugin suite and establishes a reusable pattern for future skills (e.g. `manage-change`, a continual-improvement skill).

## Scope

### In scope

- New file `packages/itil/skills/manage-incident/SKILL.md` implementing the workflow.
- New folder `docs/incidents/` (created on first incident declaration).
- BATS functional tests for the skill — **Option A-lite scope**: execute the bash fragments embedded in `SKILL.md` (ID assignment, file path conventions, directory creation) and assert on the mocked `Skill`-tool invocation contract between `manage-incident` and `manage-problem`. Tests live at `packages/itil/skills/manage-incident/test/*.bats`, consistent with ADR-005's `hooks/test/` convention applied to the skill directory. Broader skill-testing scope (structural SKILL.md validation, full workflow simulation, shared-lib extraction) is deferred to P012 and not included here.
- ADR-002 inventory update at lines 95–98 to list `manage-incident/SKILL.md` alongside `manage-problem/SKILL.md` (same pattern ADR-010 established on line 86).
- Tech-lead `persona.md` one-line update to include incident management.
- JTBD-201 added under tech-lead persona (see separate file).
- `packages/itil/README.md` documents the new skill and its relationship to `manage-problem`.
- Root `README.md` and `CHANGELOG.md` updates where they enumerate ITIL skills.
- Minor version bump on `@windyroad/itil`.

### Out of scope

- `manage-change` skill, continual-improvement skill.
- Any modification to `manage-problem`'s internal logic. The handoff uses the skill's existing public command surface (create/update with a description) plus its existing dedupe flow.
- Migrating historical incident records from ad-hoc locations.
- Install-time behaviour: no new hook, no new bin, no plugin.json change. The skill is auto-discovered from `skills/`.

## Consequences

### Good

- Incidents get a disciplined, evidence-first workflow without inheriting problem-management ceremony inappropriate for live events.
- The handoff from incident to problem is automatic and typed (via `Skill` tool), so root causes are not lost at restoration time.
- The `Skill`-tool invocation pattern is now documented; future skills in the suite have a reusable precedent.
- ADR-010's expansion signal is validated — the first peer skill lands cleanly.

### Neutral

- Two numbering namespaces (`I###`, `P###`) coexist. Users must remember which is which, but the prefix removes ambiguity.
- The required evidence template adds structure during an already-stressful event. Acceptable trade-off — the template is the forcing function for cool-headedness.
- The cross-skill invocation pattern could also be adopted by other plugins (e.g. `wr-connect`, `wr-retrospective`) for their own handoffs — worth watching as a reusable pattern, but no separate ADR required until a second consumer emerges.

### Bad

- New inter-skill coupling: `manage-incident` depends on the surface of `manage-problem`. A future rename or breaking change to `manage-problem`'s command surface becomes a breaking change for `manage-incident` too. Mitigated by keeping both skills in the same plugin (no cross-package dependency).
- First-of-its-kind cross-skill invocation — the BATS test suite must mock `manage-problem` rigorously to catch contract drift without running the real skill.

## Confirmation

- [ ] `docs/decisions/011-manage-incident-skill.proposed.md` created with all MADR 4.0 sections present.
- [ ] `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` created; tech-lead `persona.md` and JTBD `README.md` updated.
- [ ] `packages/itil/skills/manage-incident/SKILL.md` created. The SKILL.md documents that it invokes `wr-itil:manage-problem` via the `Skill` tool on restoration transition.
- [ ] `packages/itil/skills/manage-incident/test/*.bats` exists and is **functional** per ADR-005/P011 — assertions execute the skill's embedded bash fragments and assert on output/exit, not `grep` on source. One assertion specifically exercises the `Skill`-tool invocation contract between `manage-incident` and `manage-problem` (mocked target) so contract drift is test-visible.
- [ ] ADR-002 inventory (lines 95–98) lists the new skill.
- [ ] `packages/itil/README.md`, root `README.md`, and `CHANGELOG.md` enumerate the new skill.
- [ ] `@windyroad/itil` version bumped (minor).
- [ ] `grep -rn "manage-incident\|docs/incidents" packages/itil docs` returns only intentional references.
- [ ] Existing `manage-problem` BATS tests continue to pass (regression check).
- [ ] JTBD-201 promoted to `accepted` before (or together with) ADR-011 promotion, to avoid an accepted decision citing a proposed job.

## Reassessment Criteria

Reassess by 2026-10-16 (6 months). Triggers for earlier review:

- **Cross-reference confusion**: if `I###` ↔ `P###` links cause measurable user confusion or data-integrity issues within 6 months, consider a unified namespace.
- **No incidents declared**: if the skill sees zero real-world incident declarations within 6 months, it may be over-engineered; reassess whether a lighter-weight checklist or a retrospective-style post-facto record would serve better.
- **Cross-skill coupling pain**: if changes to `manage-problem` repeatedly break `manage-incident`, reassess whether the handoff should move to a shared library (Option B above) or a decoupled mechanism.
- **Second cross-skill invocation appears** in another plugin — consider whether a shared pattern document or cross-plugin ADR is warranted.

## Related

- JTBD-201 (`docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md`) — the job this ADR delivers.
- ADR-010 (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md`) — carved the room this skill occupies; established the `/wr-itil:<verb>-<object>` naming pattern.
- ADR-002 (`docs/decisions/002-monorepo-per-plugin-packages.proposed.md`) — package inventory is updated in this change.
- ADR-008 (`docs/decisions/008-jtbd-directory-structure.proposed.md`) — JTBD-201 numbering (tech-lead persona = 200–299).
- ADR-005 (`docs/decisions/005-plugin-testing-strategy.proposed.md`, as updated for P011) — functional-test requirement that the BATS tests must meet.
- `packages/itil/skills/manage-problem/SKILL.md` — structural template for the new skill and the handoff target.
- P012 (`docs/problems/012-skill-testing-harness.open.md`) — parked/deferred problem covering the broader skill-testing framework scope (structural SKILL.md validation, shared-lib extraction, location convention formalisation). ADR-011's narrower Option A-lite test scope is a deliberate holding pattern until P012 is resolved.
