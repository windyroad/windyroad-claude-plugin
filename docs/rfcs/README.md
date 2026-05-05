# RFC Backlog

> Last reviewed: 2026-05-05 **scaffold landed** — `docs/rfcs/` directory + lifecycle index initialised per ADR-060 Phase 1 items 1 + 4 (P170 Slice 2 B5.T1 + B5.T2). No RFCs captured yet; first dogfood RFC (RFC-001 retro on P168) lands in Slice 4. Skill skeletons (`/wr-itil:capture-rfc` + `/wr-itil:manage-rfc`) are Slice 2 follow-up tasks B5.T3 + B5.T4; held-changeset window per ADR-042 / P162 opens with B5.T3 (this README is docs-only and does NOT open the held window).
> Run `/wr-itil:manage-rfc review` to refresh once the manage-rfc skill ships.

## Status

`docs/rfcs/` is the canonical home for **Request for Change (RFC)** artefacts per ADR-060 (Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology). RFCs are the *what we're shipping* layer of the four-tier governance hierarchy:

| Tier | Surface | Lifecycle | Captures |
|------|---------|-----------|----------|
| Problem | `docs/problems/` | `Open → Known Error → Verifying → Closed` (or `Parked`) | What hurts |
| ADR | `docs/decisions/` | `proposed → accepted → superseded` | How we decided to solve it |
| **RFC** | **`docs/rfcs/`** (this directory) | **`proposed → accepted → in-progress → verifying → closed`** | **What we're shipping to solve it** |
| Story | (Phase 2 — deferred) | INVEST + JTBD-anchored | Slices of an RFC |

This directory is **scaffold-only** until `/wr-itil:capture-rfc` and `/wr-itil:manage-rfc` ship in Slice 2 of P170's RFC framework story map (`docs/plans/170-rfc-framework-story-map.md`). RFCs land here once those skills exist; the first dogfood RFC (RFC-001 retro on P168 per ADR-060 Phase 1 item 9) is captured in Slice 4.

## Mandatory invariants (load-bearing per ADR-060)

- **I1 — Trace-to-problem**: every RFC MUST trace to ≥ 1 problem ticket. Orphan RFCs are prohibited. Hard-block at `/wr-itil:capture-rfc` (no `--problem` flag = capture refuses, no escape); bounded escape at `/wr-itil:manage-rfc` lifecycle transitions to irreversible states. See ADR-060 § Decision Outcome "I1 enforcement".
- **I2 — Uniform problem ontology**: technical and user-business problems use the same RFC decomposition path. Type-tag is a classification facet, never a workflow split. Behavioural test (per ADR-052) asserts no skill carries a branch keyed on `type` value.

## RFC filename grammar

`docs/rfcs/RFC-<NNN>-<kebab-case-title>.<status>.md`

- `<NNN>` — three-digit zero-padded ID (matches `ADR-<NNN>` form). Avoids collision with `R<NNN>` (risks register) and bare `<NNN>` (problem IDs).
- `<status>` — one of `proposed`, `accepted`, `in-progress`, `verifying`, `closed`. ADR-022-mirror lifecycle (file suffix carries the status; renames advance lifecycle per the staging-trap rule P057).

## RFC frontmatter shape

YAML frontmatter at the top of every RFC file. Required fields are non-optional; optional fields may be omitted in Phase 1 but become required in Phase 2+ where noted.

```yaml
---
status: proposed | accepted | in-progress | verifying | closed
rfc-id: <kebab-slug>             # matches the title slug in the filename
reported: YYYY-MM-DD             # date the RFC was captured
decision-makers: [<name>, ...]   # who can move the RFC through lifecycle states
problems: [P<NNN>, ...]          # REQUIRED (I1 invariant) — bare problem IDs the RFC traces to; ≥ 1
adrs: [ADR-<NNN>, ...]           # ADRs ride alongside RFCs as decisions made during execution; may be empty
jtbd: [JTBD-<NNN>, ...]          # Phase 1: optional. Phase 2+: REQUIRED when any traced problem is `type: user-business`. Bare JTBD IDs.
---
```

**Field semantics**:

| Field | Required | Notes |
|-------|----------|-------|
| `status` | yes | Must match the file's `.<status>.md` suffix (consistency check fires in `reconcile-rfcs.sh` per ADR-060 Phase 1 item 5). |
| `rfc-id` | yes | Kebab-slug derived from the RFC title; matches the filename's slug component. |
| `reported` | yes | ISO date. |
| `decision-makers` | yes | List of names. Solo-developer projects typically have one entry. |
| `problems` | yes (I1) | List of bare problem IDs (`[P168]`, `[P168, P169]`). At least one entry is required at capture-rfc time. The hard-block at I1 fires if this list is empty or absent. |
| `adrs` | no | List of bare ADR IDs the RFC references. RFC-internal decomposition decisions (story breakdown, phase ordering, task sequencing) do NOT spawn ADRs by default per ADR-060 § Decision Outcome — ADRs created during RFC execution capture decisions with scope outside the RFC's own boundary. |
| `jtbd` | conditional | Required Phase 2+ when any traced problem carries `type: user-business`. Optional in Phase 1. |

## RFC body structure

Sections appear top-to-bottom in this order. Sections marked **(required)** must be present at capture-rfc time; sections marked **(maintained)** are auto-refreshed by manage-rfc lifecycle transitions or by the commit-message trailer hook.

```markdown
# RFC-<NNN>: <Title>

**Status**: <status>
**Reported**: <YYYY-MM-DD>
**Problems**: <P<NNN> [, P<NNN>, ...]>
**ADRs**: <ADR-<NNN> [, ADR-<NNN>, ...]> | (none)
**JTBD**: <JTBD-<NNN> [, ...]> | (none) | (n/a — type: technical)

## Summary (required)

One-paragraph summary of what this RFC ships and why.

## Driving problem trace (required — I1 invariant)

Explicit prose linking each `problems:` entry to the symptom or RCA finding the RFC addresses. Multi-problem RFCs explain the coordination surface that justifies grouping the problems under one RFC.

## Scope

Bounded scope statement. What this RFC ships; explicit boundaries against neighbouring concerns.

## Tasks (Phase 1 placeholder; "story" reserved for Phase 2)

Ordered work-items. Each task is an ADR-014-grain commit candidate. Phase 1 uses **task** / **step** terminology; "story" is reserved for Phase 2's INVEST-shaped + JTBD-anchored shape (per ADR-060 § Decision Outcome amendment 13).

- [ ] Task 1 — <description>
- [ ] Task 2 — <description>
- ...

## Commits (maintained)

Ordered list of commit SHAs that advanced this RFC. Auto-maintained by the commit-message RFC trailer hook (per ADR-060 Phase 1 item 12 + Confirmation criterion 3): commits carrying a `Refs: RFC-<NNN>` trailer are appended here on push.

## Verification (required when Status reaches `verifying`)

What evidence demonstrates the RFC's intended outcome shipped. Mirrors `## Fix Released` on Verification Pending problem tickets (ADR-022) but at the RFC level: lists the release marker(s) for the commit chain, the user-side check the RFC awaits, and the trace-to-problem closure path.

## Closed scope (required when Status reaches `closed`)

Final scope statement: what shipped, what was deferred, what was dropped. Deferred work either lands in a follow-up RFC stub or is explicitly named in a driving problem ticket's continuing scope.

## Related

Links to ADRs, JTBDs, retro docs, and other RFCs this work composes with.
```

## Commit-grain composition (per ADR-060 architect finding 8 + ADR-014)

- **Mapping**: one RFC = N × ADR-014-grain commits, ordered. RFCs decompose into commits that ride the existing single-purpose grain.
- **One commit advances at most one RFC**. If a single commit attempts to advance two RFCs, the commit is mis-scoped; split. Coordination decisions across multiple RFCs go in a separate commit on a meta-RFC OR in an ADR if the scope is outside any single RFC.
- **Commit-message RFC trailer**: commits that advance an RFC carry a `Refs: RFC-<NNN>` trailer. The reverse-trace `## RFCs` section on driving problem tickets is auto-maintained off the trailer parsing (per ADR-060 Phase 1 item 12; hook lands in Slice 3 task B5.T9).

## RFC Rankings

(Empty — no RFCs captured yet. Once `/wr-itil:capture-rfc` ships in Slice 2 task B5.T3, this table populates with one row per RFC in `proposed` / `accepted` / `in-progress` status. RFC-level WSJF placement is Phase 1 default per ADR-060 § Decision Outcome — story-level WSJF is deferred to Phase 2. Rows sort by the same `(WSJF desc, ID asc)` tie-break ladder used for problem rankings, with RFC statuses extending the Status column. <!-- TIE-BREAK-LADDER-SOURCE: docs/problems/README.md WSJF Rankings + ADR-060 § Decision Outcome -->)

| WSJF | ID | Title | Severity | Status | Effort | Reported |
|------|-----|-------|----------|--------|--------|----------|

## Verification Queue

(Empty — no RFCs in `.verifying.md` status yet. Sorted by `Released date ASC` once populated, mirroring the canonical Verification Queue sort direction documented for `docs/problems/README.md` per P150. <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 -->)

| ID | Title | Released | Verification check |
|----|-------|----------|--------------------|

## Closed

(Empty — no closed RFCs yet. The first closed RFC will be RFC-001 (retro migration of P168) after Slice 4 closes per the P170 story map.)

| ID | Title | Closed | Driving problems |
|----|-------|--------|------------------|

## Held-changeset window

Phase 1 of the RFC framework rides a held-changeset window per ADR-042 / P162. **This README itself is docs-only and does NOT open the held-changeset window** — the window opens with Slice 2 task B5.T3 (first code-shipping task: `/wr-itil:capture-rfc` skeleton). Once open, the window graduates atomically per ADR-060 architect finding 12: the entire RFC-001 commit chain either ships or doesn't. ADR-042 auto-apply is paused until RFC-001 reaches `closed` status. Graduation criteria are evaluated via counterfactual risk assessment (delay-risk vs release-risk) per P162.

## Reconciliation

`docs/rfcs/README.md` is reconciled against on-disk RFC files by `wr-itil-reconcile-rfcs` (Slice 3 task B5.T6, `$PATH` shim per ADR-049 lands at B5.T7). The reconciliation contract mirrors `wr-itil-reconcile-readme docs/problems` per P118: diagnose-only mechanical drift detector that runs as a Step 0 preflight in `/wr-itil:manage-rfc` invocations.

## Related

- **ADR-060** — Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology. The decision that introduces this directory.
- **P170** — driver problem ticket capturing the strain pattern that motivated ADR-060.
- **`docs/plans/170-rfc-framework-story-map.md`** — Patton-style 6-slice decomposition of the RFC framework rollout. This scaffold is Slice 2 tasks B5.T1 + B5.T2.
- **JTBD-008** — Decompose a Fix Into Coordinated Changes. Persona-anchor for the capture-time decomposition surface this directory enables.
- **JTBD-001** (extended scope) — Enforce Governance Without Slowing Down. RFC framework extends JTBD-001's per-edit governance scope to multi-commit coordinated-change governance.
- **`docs/problems/README.md`** — sibling directory's lifecycle index. Same architectural pattern (WSJF Rankings + Verification Queue + reconciliation) applied at the RFC tier.
- **ADR-022** — problem lifecycle conventions. RFC lifecycle states (`proposed → accepted → in-progress → verifying → closed`) mirror problem lifecycle states for symmetry.
- **ADR-014** — governance skills commit their own work. Phase 1 RFC commits ride this grain.
- **ADR-032** — governance-skill aside-invocation pattern. `/wr-itil:capture-rfc` (lightweight aside) + `/wr-itil:manage-rfc` (heavyweight intake) follow this split.
- **ADR-038** — progressive disclosure. SKILL.md (runtime) + REFERENCE.md (deep context) split applies to capture-rfc + manage-rfc when they ship.
- **ADR-049** — plugin-bundled scripts via `bin/` on `$PATH`. `wr-itil-reconcile-rfcs` shim follows this naming grammar.
- **ADR-052** — behavioural-tests default. capture-rfc + manage-rfc + reconcile-rfcs ship with behavioural bats coverage (Slice 2 task B5.T5).
- **P118** — README reconciliation contract that this directory's reconciliation mirrors.
- **P162** — held-changeset graduation criteria. Phase 1 RFC framework rides this window.
