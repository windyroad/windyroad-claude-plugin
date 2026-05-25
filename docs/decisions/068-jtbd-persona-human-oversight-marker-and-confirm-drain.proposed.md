---
status: "proposed"
date: 2026-05-25
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-08-25
---

# ADR-068: JTBD + persona human-oversight marker + `/wr-jtbd:confirm-jobs-and-personas` drain (sibling of ADR-066)

## Context and Problem Statement

ADR-066 established that recorded **decisions** (ADRs) must carry human oversight — a `human-oversight: confirmed` + `oversight-date` frontmatter marker, a token-cheap grep detector, a session-start nudge, a `/wr-architect:review-decisions` drain, and born-confirmed recording via `create-adr`.

P288 (user direction 2026-05-25: *"new jobs to be done and new personas need human confirmation too"*) observes the same risk for the **other auto-derivable governance artifacts**: JTBDs (`docs/jtbd/<persona>/JTBD-NNN-*.md`) and personas (`docs/jtbd/<persona>/persona.md`). These can be agent-derived without a human confirming they reflect real user/business need — and the JTBD edit gate (`jtbd-enforce-edit.sh`) reviews *every* project edit against `docs/jtbd/`, so a drifted auto-made job/persona propagates wrong alignment verdicts suite-wide. As of this ADR, **17 jobs/personas** (4 personas + 13 JTBDs) carry no oversight marker.

## Decision Drivers

- Same drivers as ADR-066: token-cheap grep detection; orthogonal to `status:`; born-confirmed-going-forward; never-re-ask (ADR-009 principle); adopter portability (the mechanism ships in the plugin; each adopter drains its own `docs/jtbd/`).
- **Cross-surface consistency** — reuse the ADR-066 marker field verbatim so one detector grammar and one AFK guard cover both the ADR and the JTBD surfaces.

## Considered Options

- **Separate ADR-068 vs amend ADR-066.** Chosen: **separate**, citing ADR-066 as the precedent. The mechanisms are plugin-specific (`@windyroad/architect` vs `@windyroad/jtbd`, independently published per ADR-002); a shared hook/script would couple their release cycles. This mirrors how the two plugins already carry sibling — not shared — gate hooks (ADR-009 precedent).
- **Drain-skill name** (genuinely open — `/wr-jtbd:review-jobs` is already the read-only *alignment* reviewer, the analog of `/wr-architect:review-design`, not of `review-decisions`). Chosen: **`/wr-jtbd:confirm-jobs-and-personas`** (user, via `AskUserQuestion` 2026-05-25) — a distinct "confirm" verb that won't be confused with the alignment reviewer, naming both surfaces it drains. Rejected: a mode on `review-jobs` (conflates a read-only compliance review with a read-write oversight drain; the mode arg also fails the subcommand-discoverability rule).

## Decision Outcome

Chosen: **mirror ADR-066 as a wr-jtbd sibling**.

1. **Marker.** `human-oversight: confirmed` + `oversight-date: YYYY-MM-DD` on JTBD files AND persona files — the ADR-066 field verbatim, orthogonal to `status:`. **Additive to the ADR-008 JTBD-file frontmatter contract** (so a future ADR-008 reader does not flag it as undocumented). Write-once-permanent except on material amendment (see Reassessment).
2. **Detector.** `wr-jtbd-detect-unoversighted` (ADR-049 shim → `packages/jtbd/scripts/detect-unoversighted.sh`) greps `docs/jtbd/**/*.md` frontmatter for absence of `human-oversight: confirmed`; excludes `README.md`. **Token-cheap ceiling restated for the JTBD path: one grep, no body reads, no per-file LLM call** (a heavy detector would tax every session start).
3. **Session-start nudge.** A new wr-jtbd `SessionStart` hook (matcher `startup`; the jtbd plugin has no SessionStart event yet — this adds one, mirroring ADR-040 / ADR-066), emitting `N job(s)/persona(s) lack human oversight — run /wr-jtbd:confirm-jobs-and-personas`. **Self-suppresses on `WR_SUPPRESS_OVERSIGHT_NUDGE=1`.**
4. **Drain skill.** `/wr-jtbd:confirm-jobs-and-personas` drains the unoversighted set in batches via `AskUserQuestion` (confirm / amend / reject), writing the marker on confirm; never re-asks.
5. **Born-confirmed.** `packages/jtbd/skills/update-guide/SKILL.md` (the job/persona authoring surface — the JTBD equivalent of `create-adr`) writes the marker when the user confirms a new/edited job or persona.
6. **Confirm-gate.** A `proposed` job/persona is not treated as human-oversighted without a confirm pass.

### Shared cross-plugin contracts (named so they are not refactored away)

- **`WR_SUPPRESS_OVERSIGHT_NUDGE` is the suite-wide oversight-nudge AFK guard** — shared across ALL oversight-nudge hooks (architect today, jtbd here, any future surface). AFK orchestrators export it **once** (`work-problems` Step 5 already does); one var silences every oversight nudge with zero per-plugin orchestrator change. Do NOT split into per-plugin guard vars.
- **Marker field grammar is shared** (`human-oversight: confirmed` + `oversight-date`) — data-schema convergence, NOT code coupling. Each plugin's detector independently greps its own corpus.
- **Unoversighted ≠ unusable.** An unconfirmed job/persona remains fully readable and review-anchorable while it awaits confirmation — the marker records provenance, it does not quarantine the doc. The gate MUST NOT block reviews from reading unoversighted jobs (that would break the `wr-jtbd:agent` review flow itself).

## Consequences

**Good:** human oversight of the JTBD corpus becomes a first-class, grep-checkable, git-tracked fact (JTBD-202 / JTBD-201 auditability; JTBD-101 adopter reusability). The unconfirmed set only shrinks (born-confirmed via update-guide).

**Neutral:** two frontmatter lines on jobs/personas; reuses ADR-066's field + detector algorithm near-verbatim.

**Bad / costs:** the 17 existing unoversighted jobs/personas must be drained — a focused interactive sweep, not a blocking pass. Adds a `SessionStart` event to the jtbd plugin (none existed); it carries the AFK self-suppress guard **from day one**. Adds a `scripts/` dir to the jtbd plugin (none existed).

## Confirmation

Behavioural (per ADR-052), mirroring ADR-066's set:

1. `wr-jtbd-detect-unoversighted` resolves on `$PATH` and emits the correct count + path-list over a `docs/jtbd/` fixture tree (persona.md + JTBD-*.md; README excluded) — behavioural bats.
2. The SessionStart nudge emits the count line and is silent (a) on zero and (b) under `WR_SUPPRESS_OVERSIGHT_NUDGE=1` — behavioural bats.
3. `/wr-jtbd:confirm-jobs-and-personas` writes the marker on confirm and leaves it absent on amend/reject — behavioural bats.
4. `update-guide` writes the marker on the Step-N confirm (born-confirmed) — assertion against the update-guide contract.
5. **Dogfood self-check:** ADR-068 carries `human-oversight: confirmed` in its own frontmatter (it does — recorded through the asking flow, with the one open sub-decision resolved by `AskUserQuestion`).

## Reassessment Criteria

- Mirror ADR-066: the marker is write-once-permanent EXCEPT when a job's statement/outcomes (or a persona's definition) are materially rewritten — a material amend clears `human-oversight` so the changed artifact is re-confirmed.
- If a future surface needs per-confirm accountability, add an `oversight-by:` scalar without migration.
- Reassess at 2026-08-25.

## Related

- **P288** — driving ticket. **P283 / ADR-066** — the precedent mechanism this mirrors.
- **ADR-008** — JTBD directory structure; the marker is additive to its frontmatter contract.
- **ADR-049** — shim grammar. **ADR-040** — SessionStart nudge shape. **ADR-009** — never-re-ask principle (not its TTL lifecycle). **ADR-002** — per-plugin packaging (why sibling not shared). **ADR-013 / ADR-044** — structured user interaction + decision-delegation taxonomy.
- `packages/jtbd/skills/update-guide/SKILL.md` — born-confirmed write site. `packages/jtbd/skills/review-jobs/SKILL.md` — the read-only alignment reviewer (distinct from this drain).
- `packages/architect/scripts/detect-unoversighted.sh` + `architect-oversight-nudge.sh` + `skills/review-decisions/` — the templates mirrored here.
