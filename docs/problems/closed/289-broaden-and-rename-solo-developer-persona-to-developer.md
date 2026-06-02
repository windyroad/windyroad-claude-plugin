# Problem 289: Broaden + rename the `solo-developer` persona → `developer`

**Status**: Closed
**Reported**: 2026-05-25
**Closed**: 2026-05-31
**Priority**: 6 (Medium) — Impact: 2 (Minor — the persona's jobs are correct and serve real need; the defect is that they are filed under a too-narrow persona name, degrading the taxonomy's clarity and mis-signalling that the jobs are solo-only; no functional breakage) × Likelihood: 3 (Possible — every JTBD alignment review and every `persona:`-keyed reference reads the name)
**Effort**: L — 275 occurrences across 164 files (134 docs + 28 packages + scripts + root README); needs a migration-strategy decision (rename live-only vs all-historical) before execution
**WSJF**: 6/4 = **1.5** (Open multiplier 1.0)

## Closed as no longer relevant

**Closure date**: 2026-05-31 (foreground relevance-scan batch 3, user-confirmed)
**Closure reason**: implementation-shipped (ticket body's own "Close to Verifying" marker honoured) — live-only migration strategy executed; the persona rename + JTBD relocation + active-reference scrub are done; the lifecycle transition is the lag this close resolves.
**Evidence (per ADR-026 grounding + ADR-079 evidence-based relevance-close pass)**:
- `docs/jtbd/developer/` directory exists with 8 JTBDs (verified `ls`): JTBD-001 through JTBD-008 + persona.md
- `docs/jtbd/solo-developer/` directory is gone (verified `ls` — "No such file or directory")
- Ticket body literally says: *"DONE 2026-05-27 — Migration-strategy decision: live-only (user-confirmed via AskUserQuestion). Renamed the docs/jtbd/developer/ files + active skill/hook/agent references + root README + the JTBD-anchored stories/story-maps README persona headings; left historical mentions (CHANGELOGs, dated retros, closed/open problem-ticket narrative, accepted-ADR + RFC bodies, README-history, .bats fixtures) as point-in-time-accurate solo-developer."*
- Ticket body literally says: *"persona's relevance was broadened from 'personal or small-team' to 'solo, small-team, or larger team' — the distinguishing axis is now explicitly role (the developer who does the work) vs tech-lead (governance), not team size."*
- Ticket body literally says: *"Close to Verifying."*
- 178 remaining `solo-developer` string occurrences are intentional historical references per the live-only migration strategy explicitly chosen by the user

**Relevance evidence shape**: implementation-shipped (the fix shipped 2026-05-27; the ticket body itself marks "Close to Verifying" — close-on-evidence per ADR-044, same shape as P334/P336 today)
**Authorising decision**: P346 user direction 2026-05-31; user confirmed P289 in foreground relevance-scan batch 3. Sibling-class observation: this is also an instance of P345 (fix-titled commits do not transition the ticket lifecycle) — the work shipped but the lifecycle stayed Open until the relevance-close pass surfaced it.

## Description

Surfaced during the P288 / ADR-068 JTBD-oversight drain (`/wr-jtbd:confirm-jobs-and-personas`, 2026-05-25). When the `solo-developer` persona was presented for human-oversight confirmation, the user declined to confirm it as-named:

> User direction 2026-05-25 (drain): *"I don't know why this is just a solo-developer and not software development teams in general."* → chose **"Broaden + rename to 'developer'"** via AskUserQuestion.

The `solo-developer` persona's jobs (JTBD-001 enforce-governance, 002 ship-with-confidence, 003 compose-guardrails, 004 connect-agents, 005 assess-on-demand, 006 work-backlog-afk, 007 keep-plugins-current, 008 decompose-fix) are **developer-role jobs that apply to a developer on any size team**, not just solo/small-team developers. The name conflates *working alone* with *the developer role*. The original "solo/small-team, no dedicated QA" framing was the distinction from `tech-lead` (the governance role) — but the right axis is **role** (developer who does the work vs lead who enforces governance), not **team size**.

**Decision (user, 2026-05-25)**: rename `solo-developer` → `developer` (or `software-developer`), with a description like *"Developer using AI coding agents — solo, small-team, or within a larger software development team."* `tech-lead` stays the distinct governance role. `solo-developer` is **left unoversighted** (P288/ADR-068 marker withheld) until this rename lands and the renamed persona is re-confirmed — mirroring how P287 holds ADR-060's oversight.

## Symptoms

(deferred to investigation)

- 275 occurrences of `solo-developer` across 164 files: `docs/` (134 — ADRs, problems, retros, `docs/jtbd/solo-developer/`), `packages/` (28 — skills, agents, hooks referencing the persona), `scripts/` (1), root `README.md` (1).
- The directory `docs/jtbd/solo-developer/` + 8 JTBD files carry `persona: solo-developer` frontmatter.
- The `@jtbd JTBD-006` etc. annotations reference jobs by ID (stable across rename), but prose references to the persona NAME are widespread.

## Workaround

None needed — the persona functions correctly; the name is the issue.

## Root Cause Analysis

### Investigation Tasks

- [x] **DONE 2026-05-27 — Migration-strategy decision**: **live-only** (user-confirmed via AskUserQuestion). Renamed the `docs/jtbd/developer/` files + active skill/hook/agent references + root README + the JTBD-anchored stories/story-maps README persona headings; left historical mentions (CHANGELOGs, dated retros, closed/open problem-ticket narrative, accepted-ADR + RFC bodies, README-history, .bats fixtures) as point-in-time-accurate `solo-developer`.
- [x] **DONE — final name**: `developer` (user-confirmed via AskUserQuestion 2026-05-27).
- [x] **DONE — execute**: `git mv docs/jtbd/solo-developer docs/jtbd/developer`; updated the 8 jobs' `persona:` field + the persona.md `name:` / `description:` / heading / broadened content; refreshed `docs/jtbd/README.md`; repointed the dead `docs/jtbd/solo-developer/...` doc-links in ~14 SKILL.md files; updated the capture-problem `--persona=` enum (`developer`); reworded the jtbd agent.md surface-3 first-fire example; updated root README persona table.
- [x] **DONE — verify**: `developer` persona resolves + is ratified (`wr-jtbd-is-job-or-persona-unconfirmed developer` → exit 1); the name-agnostic detector + new predicate unaffected; full jtbd suite (34) + capture-problem suite (57) GREEN; no `solo-developer` left in any LIVE surface.
- [x] **DONE — re-confirm**: wrote `human-oversight: confirmed` + `oversight-date: 2026-05-27` to `docs/jtbd/developer/persona.md` (born-confirmed — the user directly confirmed the rename + broadening substance via AskUserQuestion, so the marker is written per ADR-068 surface 1; no separate `/wr-jtbd:confirm-jobs-and-personas` pass needed). The persona's **jobs** JTBD-001..007 remain unratified (P288 drain scope, not P289).
- [x] **DONE — ADR check**: architect PASS — no ADR amendment required. ADR-008 defines the dir layout with `<persona-name>` as a variable (not an enumerated literal). ADR-060 P4.2 names the persona enum literal, but editing the capture-problem SKILL enum (`solo-developer`→`developer`) *preserves* P4.2 compliance (keeps the closed enum resolvable) rather than violating it — implementation surface, not a competing decision.

## Resolution (2026-05-27)

Renamed `solo-developer` → `developer` (live-only migration) and ratified the broadened persona. The persona's relevance was broadened from "personal or small-team" to "solo, small-team, or larger team" — the distinguishing axis is now explicitly **role** (the developer who does the work) vs `tech-lead` (governance), not team size. The new JTBD surface-3 build-upon guard (P323/RFC-011) now passes the ratified `developer` persona and continues to flag its still-unratified jobs (P288 drain). Shipped-file reference changes (capture-problem enum, agent.md example) ride with the next `@windyroad/itil` / `@windyroad/jtbd` release (the jtbd half rides with the held RFC-011 changeset). **Close to Verifying.**

## Dependencies

- **Blocks**: `solo-developer` (→ `developer`) persona human-oversight confirmation (held until this rename lands, per ADR-068).
- **Blocked by**: none — investigation can begin immediately.
- **Composes with**: P288 / ADR-068 (the drain that surfaced this), P287 (sibling — both are drain-surfaced material amendments to auto-made governance artifacts), ADR-008 (JTBD directory structure), the 8 `solo-developer` JTBD files.

## Related

(captured during the P288 / ADR-068 JTBD-oversight drain, 2026-05-25)

- **P288** / **ADR-068** — the oversight-drain mechanism that surfaced this.
- **P287** — sibling drain-surfaced material amendment (ADR-060 type-tag removal); same "drain found an auto-made artifact the user wants changed → capture rework, withhold marker" pattern.
- **ADR-008** (`docs/decisions/008-jtbd-directory-structure.proposed.md`) — defines the JTBD directory/persona layout; may name the persona set.
- `docs/jtbd/solo-developer/` — the directory + 8 JTBD files to rename.
