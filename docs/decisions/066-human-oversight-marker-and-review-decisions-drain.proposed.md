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

# ADR-066: Human-oversight marker + `/wr-architect:review-decisions` drain for recorded decisions

## Context and Problem Statement

This repo holds 54 `proposed` ADRs; **none** carry any record that a human reviewed and confirmed the decision. Many were recorded autocratically — the architect proposed an option, the main agent wrote it, and the auto-made pick stood. P283's root concern: *"some of the automatically decided decisions are poor, so we're going to lift them up and make them human decisions."*

ADR-064 (P283 prong 1) closed the **new-decision leak** — `create-adr` now asks + confirms via `AskUserQuestion` at recording time. But two gaps remain:

1. **The existing set was never human-confirmed.** 54 proposed ADRs sit unreviewed with no way to tell which a human actually picked.
2. **`status:` does not imply human oversight.** An ADR can be `accepted` (production-validated) yet never human-*oversighted* (auto-decided, then shipped). ADR-046 is the proof case: it transitioned `proposed`→`accepted` on a production landing, and its human confirmation was recorded in prose, not in any frontmatter field. "Accepted yet never human-oversighted" is a real, currently-unrepresentable state.

Adopter projects that use the architect plugin have the same problem. The mechanism must therefore be **reusable** and **token-cheap** — surfacing the unconfirmed set must not cost a per-ADR LLM call.

## Decision Drivers

- **Token-cheapness** — steady-state cost of "what needs oversight?" must be ≈ one grep, no body reads, no per-ADR LLM call. Once drained, ongoing cost ≈ zero.
- **Orthogonality to `status:`** — oversight is a second axis; an ADR's production-validation state says nothing about whether a human picked the option.
- **Born-confirmed going forward** — decisions recorded through the post-ADR-064 `create-adr` flow are written confirmed automatically, so the unconfirmed set only ever shrinks.
- **Persistence / never-re-ask** — once a human confirms a decision, that fact is durable and never re-surfaced.
- **Adopter reusability** — ship as a reusable architect-plugin primitive, not a one-off repo script.

## Considered Options

The user pinned most of the design (see Decision Outcome). The one genuinely-open sub-decision was the **marker field shape**, deferred by P283 to "the asking flow" and surfaced via `AskUserQuestion` per ADR-064:

- **Option 1 — flat scalars `human-oversight: confirmed` + `oversight-date: YYYY-MM-DD`.** Grep-cheapest: detection matches a single literal line. Cannot be confused with `status:` or with gate-review markers. An `oversight-by:` scalar can be added later without migration if per-confirm accountability proves load-bearing (anti-BUFD per ADR-044).
- **Option 2 — nested map `oversight: {confirmed-by, date}`.** Captures *who* confirmed (parallels ADR-046's `author` field), but a nested YAML map is harder to match with a flat frontmatter grep, raising the token-cheap-detection bar the user pinned.
- **Option 3 — `reviewed-by: [<name>]` + `reviewed-date:`.** MADR-adjacent naming, but "reviewed" collides semantically with the architect *gate* review (the `/tmp/architect-reviewed-${SESSION_ID}` markers per ADR-009) — naming ambiguity against an existing concept.

## Decision Outcome

Chosen: **Option 1 (flat scalars)** — confirmed by the user via `AskUserQuestion` 2026-05-25, on the token-cheap-grep and orthogonal-axis drivers.

1. **Frontmatter marker.** `human-oversight: confirmed` + `oversight-date: YYYY-MM-DD`, orthogonal to `status:`. Write-once-permanent (see Reassessment for the re-open carve-out).
2. **Detection.** A `$PATH`-resolved shim `wr-architect-detect-unoversighted` (ADR-049 naming grammar) dispatching `packages/architect/scripts/detect-unoversighted.sh`, which greps `docs/decisions/` ADR frontmatter for absence of `human-oversight: confirmed`. No body reads, no per-ADR LLM call. Emits a count + the list of unconfirmed ADR paths.
3. **Session-start nudge.** A new architect-plugin `SessionStart` hook (matcher `startup`, modelled on `itil-pending-questions-surface.sh`; silent-on-no-content) emitting `N decision(s) lack human oversight — run /wr-architect:review-decisions`. **The hook self-suppresses inside AFK subprocesses** via an env-var guard (`WR_SUPPRESS_OVERSIGHT_NUDGE=1`, set by AFK orchestrators before each `claude -p` spawn — the same discipline `itil-pending-questions-surface.sh` applies with `WR_SUPPRESS_PENDING_QUESTIONS`) so the interactive batch-confirm prompt never fires into an absent-user iteration (JTBD-006 friction guard).
4. **Drain skill.** A new `/wr-architect:review-decisions` skill drains the unconfirmed set in **topic-clustered batches, load-bearing ADRs first**, via `AskUserQuestion` (confirm / amend / reject per ADR). On confirm it writes the marker + today's date; never re-asks (the marker persists).
5. **Born-confirmed.** `create-adr` (post-ADR-064) writes `human-oversight: confirmed` + the confirm date when the user confirms at Step 5. Any ADR recorded through that flow is born oversighted.
6. **Confirmation gate.** A `capture-adr` `.proposed.md` skeleton MUST NOT transition to `accepted` without a `create-adr` / `AskUserQuestion` confirm pass — closing the "auto-decided skeleton stands as a decision" gap.
7. **Dogfood.** ADR-066 itself is recorded through the asking flow and born `human-oversight: confirmed` (the architect PASSed; the user confirmed the marker shape via `AskUserQuestion`).

> **Amendment 2026-05-27 (ADR-074) — marker ≠ implementation licence.** The "born-`proposed`, drain later" model governs the *recording/existence* of a decision and the *marker* alone. It is **NOT** a licence to build dependent work (other ADRs, RFC slices, invariants, code) on the decision's **substance** before that substance is human-confirmed. P315's root cause was exactly this conflation — "don't born-confirm the marker" was misread as "OK to implement before confirmation," and dependent work (ADR-060 I13 + the RFC-005 retrofit) was built on ADR-072/073 before the drain rejected them. The drain catching an unconfirmed decision is the backlog safety net; it is not the intended first point of substance-confirmation for a decision being actively built upon. See ADR-074 (confirm-substance-before-build) for the build-upon enforcement contract.

> **Amendment 2026-05-30 (P316) — `rejected-pending-supersede` is a third oversight value.** The marker vocabulary gains a third value on the same `human-oversight:` axis: `rejected-pending-supersede`. When the user explicitly rejects an ADR at the drain AND a problem ticket tracks the supersede rework, the drain skill writes `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>` into the ADR's frontmatter. The detector (`detect-unoversighted.sh`) and the build-upon predicate (`is-decision-unconfirmed.sh`) treat the marker+ticket pair as ratified-equivalent — the rejected ADR drops out of the unoversighted set and the [Unratified Dependency] flag stops firing on it. The pair must be present for the exclusion to apply: a `rejected-pending-supersede` marker without a `supersede-ticket: P<NNN>` scalar is malformed and still surfaces (defensive — preserves the JTBD-201/202 audit-trail guard so un-tracked rejections don't silently rot). Closes P316 (drain re-surfaced ADR-034/047/055/063 every drain after the 2026-05-26 rejection sweep — backfilled at this amendment). The same value+ticket pair is the canonical schema for the JTBD sibling under ADR-068 (mirrored in `packages/jtbd/scripts/detect-unoversighted.sh` + `packages/jtbd/scripts/is-job-or-persona-unconfirmed.sh`). **Supersede-lands transition:** when the supersede ADR eventually lands and the original transitions to `*.superseded.md`, the existing superseded-name skip takes over; the `human-oversight: rejected-pending-supersede` + `supersede-ticket:` lines become historical residue (no active clearance required). The same applies to the JTBD half (`.superseded.md` rename takes over). This amendment is itself the Reassessment-driven additive-scalar mechanism the original Decision Outcome anticipated ("revisit Option 2 / add an `oversight-by:` scalar in an amend cycle — no migration of existing entries required").

### Precedent citations (per architect review)

- **ADR-009** is cited for the **never-re-ask principle only**. This marker does **NOT** inherit ADR-009's TTL / drift-hash / subprocess-slide lifecycle — those govern *ephemeral* `/tmp` gate markers and are the opposite of what is wanted here. The oversight marker is durable, git-tracked, and write-once-permanent.
- **ADR-046** (blocked-reporters persistence) is the closer mechanism precedent — durable git-tracked frontmatter persistence — and the proof case for status-vs-oversight orthogonality.
- **ADR-064** (Needs-Direction verdict; main agent owns `AskUserQuestion`) is the parent: this ADR extends its confirm-every-ADR gate to the existing set + a machine-detectable marker.
- **ADR-040** (session-start briefing surface) is the precedent for the `SessionStart`-`startup` nudge-hook shape.
- **ADR-049** (`bin/` on `$PATH`) is the shim naming + packaging precedent.

## Consequences

**Good:**
- The "needs oversight" set is computable for ≈ one grep; the answer is always current.
- Human oversight becomes a first-class, auditable, git-tracked fact (serves JTBD-201 / JTBD-202 audit-trail outcomes).
- The new-decision leak is closed (born-confirmed), so the unconfirmed set monotonically shrinks to zero and ongoing cost → zero.
- Reusable by adopters out of the box (JTBD-101).

**Bad / costs:**
- One more frontmatter field on every ADR (two lines).
- The existing 54 proposed ADRs must be drained — a multi-day interactive sweep (P283 prong-2 task 2; explicitly run as focused sittings, not one blocking pass).
- A new `SessionStart` hook event is added to the architect plugin (none existed); it must carry the AFK self-suppress guard from day one to avoid re-injecting friction into AFK iterations.

## Reassessment Criteria

- If adopters report the flat scalar under-captures accountability (need to record *who* confirmed and *who* later disagreed), revisit Option 2 / add an `oversight-by:` scalar in an amend cycle — no migration of existing entries required.
- The marker is write-once-permanent **except** when an ADR is materially amended after confirmation: a supersede/amend that changes the Decision Outcome SHOULD clear `human-oversight` so the amended decision is re-confirmed (the never-re-ask principle covers an *unchanged* decision, not a rewritten one). The drain skill and `create-adr` amend path own this carve-out.
- Reassess at 2026-08-25 (or earlier if the drain surfaces a class of ADR the batch-confirm UX handles poorly).

## Confirmation

This decision is confirmed when:

1. `wr-architect-detect-unoversighted` resolves on `$PATH` and emits the correct count + path list of ADRs lacking `human-oversight: confirmed` (behavioural bats over a fixture tree).
2. The `SessionStart` nudge emits the count line in an interactive session and is silent (a) when the unconfirmed count is zero and (b) when `WR_SUPPRESS_OVERSIGHT_NUDGE=1` (AFK guard) — behavioural bats.
3. `/wr-architect:review-decisions` writes `human-oversight: confirmed` + `oversight-date` on a confirmed ADR and leaves an amended/rejected ADR's marker absent — behavioural bats.
4. `create-adr` Step 5 writes the marker on confirm (born-confirmed) — assertion against the create-adr SKILL contract.
5. **Dogfood self-check:** ADR-066 carries `human-oversight: confirmed` in its own frontmatter (it does — recorded through the asking flow).

## Related

- **P283** (`docs/problems/known-error/283-...md`) — driving ticket; Fix Strategy item 7 is this mechanism. Prong-2 task 2 ("drain this repo's unconfirmed set") consumes it.
- **ADR-064** — parent (Needs-Direction verdict / confirm-every-ADR gate).
- **ADR-009**, **ADR-046**, **ADR-040**, **ADR-049** — cited precedents (see Decision Outcome).
- **ADR-013**, **ADR-044** — structured user interaction + decision-delegation taxonomy parents.
- `packages/architect/skills/create-adr/SKILL.md` — born-confirmed write site (Step 5).
- `packages/itil/hooks/itil-pending-questions-surface.sh` — AFK self-suppress precedent for the nudge hook.
