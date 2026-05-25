# Problem 289: Broaden + rename the `solo-developer` persona → `developer`

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — the persona's jobs are correct and serve real need; the defect is that they are filed under a too-narrow persona name, degrading the taxonomy's clarity and mis-signalling that the jobs are solo-only; no functional breakage) × Likelihood: 3 (Possible — every JTBD alignment review and every `persona:`-keyed reference reads the name)
**Effort**: L — 275 occurrences across 164 files (134 docs + 28 packages + scripts + root README); needs a migration-strategy decision (rename live-only vs all-historical) before execution
**WSJF**: 6/4 = **1.5** (Open multiplier 1.0)
**Type**: technical

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

- [ ] **Migration-strategy decision** (the load-bearing open question): rename live references only (the `docs/jtbd/developer/` files + active skill/hook/agent references + root README) and leave historical mentions (closed problem tickets, dated retros, accepted-ADR bodies) as point-in-time-accurate `solo-developer`? OR rename ALL 275 occurrences for consistency? Historical-doc rewriting risks falsifying the record; live-only risks a confusing split. Likely: live-only + a note in ADR-008.
- [ ] Pick the final name: `developer` vs `software-developer` (the AskUserQuestion option said `developer`).
- [ ] Execute: `git mv docs/jtbd/solo-developer docs/jtbd/developer`; update the 8 jobs' `persona:` field + the persona.md `name:` + `description:`; refresh `docs/jtbd/README.md`; update live references per the migration-strategy decision.
- [ ] Verify the JTBD edit gate + any `persona:`-keyed logic still resolves (jtbd-eval.sh, review-jobs, the new confirm-jobs-and-personas detector — the detector is name-agnostic so it is unaffected).
- [ ] Re-confirm the renamed persona via `/wr-jtbd:confirm-jobs-and-personas` → write `human-oversight: confirmed`.
- [ ] Possibly record an ADR amendment if ADR-008 (JTBD directory structure) names the persona set.

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
