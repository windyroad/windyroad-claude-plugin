# `/wr-architect:capture-adr` Reference

This file hosts the rationale, edge cases, contract trade-offs, and ADR cross-references for the `/wr-architect:capture-adr` skill. SKILL.md is the runtime contract (~190 lines, on-topic per ADR-038 progressive disclosure); this REFERENCE.md is the on-demand expansion for maintainers and curious users.

## Why a separate skill?

The `/wr-architect:create-adr` flow is ~10-15 turns of agent work for a full new-ADR intake: Step 1 discovery, Step 2 AskUserQuestion gathering (Title + Options ≥2 + Pros/Cons + Decision-makers + Consequences), Step 2b decision-boundary AskUserQuestion, Step 3 next-ID, Step 4 file write with full frontmatter + body, Step 5 confirm-with-user AskUserQuestion review pass, optional Step 6 supersession handling.

That cost is correct for the canonical new-ADR path — the user wants to walk the flow, see the option-comparison prompts, and codify the full MADR shape immediately.

It is wrong for the **aside-invocation** use case. P156 surfaced three repeating patterns where the heavyweight cost is load-bearing friction:

1. **Mid-AFK-iter design decisions**: agent or user lands on a design choice during a foreground iter (e.g. iter 17 P137 Option C namespace-prefix; iter 19 ADR-056 Phase 2a back-channel write contract). The 10-15 turn ceremony breaks iter cadence — decisions get buried inline in commit bodies or RCA sections.
2. **Architect-review verdict capture**: a `wr-architect:agent` review yields a substantive verdict (PASS-WITH-NOTES / ISSUES-FOUND) whose rationale deserves an ADR-shaped record. Today the verdict + rationale lands in commit messages and rots — future readers grep history but lose the structured trace.
3. **User-driven design conversations**: user resolves options (a)/(b)/(c) during conversational work; the settlement currently lives in a problem-ticket RCA section instead of a discoverable ADR.

`/wr-architect:capture-adr` is the source-side fix: a lightweight skill with a deferred-placeholder pattern that captures the decision in ~3-4 turns and routes the deferred canonical expansion through `/wr-architect:create-adr` at a time of the user's choosing.

## Contract trade-offs

### Skeleton-MADR validity at status `proposed`

Architect Q1 verdict (P156 review): the architect-agent's review prompt tolerates skeleton ADRs at `status: proposed`. It checks "does the proposed change conflict with the decision's outcome?" not "does every section have prose?" The deferred-flag pattern is the load-bearing signal that downstream tooling and any future canonical-expansion auto-detect path keys off (mirrors capture-problem's `(deferred — re-rate at next /wr-itil:review-problems)` literal).

Status `proposed` (not `accepted`) is the right cover for skeleton state. The architect-agent enforces the MADR ≥2-options requirement at **acceptance review**, not at `proposed.md` skeleton time. Each deferred section carries the literal pointer string `(deferred to /wr-architect:create-adr canonical review)` so canonical-expansion tooling can detect and expand mechanically.

### Considered Options skeleton — `1. Option A (chosen)` + `2. (deferred — see ...)`

Architect Q2 verdict: write a literal numbered placeholder so the file parses cleanly under any doc-lint asserting ≥2 numbered options. The placeholder pattern:

```markdown
1. **Option A (chosen)** — <one-line summary>
2. (deferred — see /wr-architect:create-adr canonical review)
```

Avoids tripping future structural lint while preserving the lightweight-capture promise (no AskUserQuestion gathering of alternatives at capture time).

### Frontmatter sentinel values vs. truly minimal

Architect Q5 verdict: full minimum frontmatter with sentinel values is friendlier than absent fields:

```yaml
---
status: "proposed"
date: <YYYY-MM-DD>
decision-makers: [unspecified — fill at canonical review]
consulted: []
informed: []
reassessment-date: <YYYY-MM-DD + 3 months>
---
```

The architect-agent flags missing required frontmatter fields; sentinel-with-flag carries the deferral signal explicitly, which is more discoverable than absence at canonical-expansion time.

`reassessment-date` defaults to 3 months from today (matches `create-adr` Step 4) — the criteria themselves remain deferred-flagged in body.

### Deferred-canonical-expansion contract

Capture-adr skips the architect-agent review handoff that `/wr-architect:create-adr` Step 5 (confirm-with-user) implicitly performs. The trade-off:

| Surface | Inline canonical (create-adr) | Deferred canonical (capture-adr) |
|---------|-------------------------------|----------------------------------|
| Architect-agent review at write-time | Yes (Step 5 confirm pass) | No (deferred to canonical expansion) |
| Capture-time turn cost | ~10-15 turns | ~3-4 turns |
| MADR conformance at write-time | Full | Skeleton (status: proposed covers) |
| Audit trail (commit) | One commit covers full ADR | One commit covers skeleton |
| Acceptance window | Same session | Bounded by next canonical-expansion invocation |

The deferred contract is acceptable because:

1. **Status `proposed` is the explicit covering signal** that the ADR is not accepted yet. The architect-agent reviews `.proposed.md` files and can flag deferred-skeleton state for expansion before any downstream consumer treats it as accepted.
2. **The trailing pointer in Step 6 is the user-visible signal** that canonical expansion is needed. The user has explicit instructions for how to reconcile.
3. **Auto-detect-and-expand is a follow-up** (Q3 verdict — out of scope for P156). When `/wr-architect:create-adr` is later invoked on a captured `<NNN>`, it can detect the existing skeleton and expand the deferred sections rather than writing a new ADR. P156 does not ship this auto-detect path; the manual workflow is `/wr-architect:create-adr` invoked with the captured ID + body context.

### No AskUserQuestion at all

Architect Q4 + JTBD review confirmed: capture-adr is a **mechanical-stage skill** per ADR-044's framework-resolution boundary. Every potentially-interactive decision is framework-mediated:

- **Considered Options**: skeleton placeholder; defer ≥2-options requirement to canonical review.
- **Decision Drivers / Consequences / Confirmation**: framework-policy deferred flag; canonical review fills.
- **Reassessment date**: framework-policy default 3 months from today.
- **Decision-makers / consulted / informed**: framework-policy sentinel `[unspecified — fill at canonical review]`.
- **Multi-decision split**: out of scope. The user invoking capture-adr with a multi-decision payload gets one ADR with the full payload; they re-route to `/wr-architect:create-adr` for the structured Step 2b decision-boundary split.

This mirrors the mechanical-stage carve-out pattern documented in CLAUDE.md (P132 / inverse-P078 trap): when a SKILL contract names a stage as mechanical, do not ask. Per-action consent gates re-ask decisions the user already made and silently undo the load-bearing UX investment.

## Edge cases

### Empty `$ARGUMENTS`

Halt-with-stderr-directive. capture-adr requires Title + 1-line Context + 1-line Decision; without payload there is nothing to capture. The directive points the user to `/wr-architect:create-adr`, which has Step 2 AskUserQuestion gathering for full intake.

AFK orchestrators MUST NOT invoke capture-adr with empty arguments — caller-side contract. The Rule 6 audit makes this explicit so AFK-iter writers don't accidentally introduce a halt mid-loop.

### Partial `$ARGUMENTS` (Title only / Title + Decision)

If only Title is supplied, write the skeleton with deferred placeholders in Context + Decision Outcome. If Title + Decision (no Context), defer Context only. The deferred-flag literal pointer string preserves the canonical-expansion signal.

This is a graceful-degradation case — real captures carry Title + Context + Decision — but the partial-payload path prevents a halt when only some context is available.

### Title slug collision

If two captures land on the same kebab-slug (different IDs but identical title fragments), the file paths differ by ID prefix so no collision occurs at the filesystem layer. The next-ID formula guarantees ID uniqueness against local + origin.

### ID collision with origin

The next-ID formula uses `git ls-tree origin/main` to read the remote-tracking ref without requiring a fetch. If a parallel session minted the same ID for a different decision and pushed it before this session captures, the local read sees the higher origin ID and increments past it.

If the local session has not fetched recently and origin has captures the local doesn't see, the formula may still collide. The renumber audit log line in Step 6 captures the resolution. P040 incident applies.

`--name-only` is required (P056): without it, default `git ls-tree` output carries the 40-char blob SHA which can contain three-digit runs that the digit-extraction regex false-matches. Same fix as create-adr Step 3 / manage-problem Step 3.

### Captured ADR never expanded

If the user captures and never invokes canonical expansion, the `.proposed.md` skeleton remains with deferred-flagged sections. Acceptable failure mode: the architect-agent flags `.proposed.md` files during compliance review and surfaces stale skeletons for expansion. The skeleton is more useful than no record at all (P156 line 19 driver: "decisions not captured drift; future iters reinvent the same design space").

### Architect-review verdict capture

Use case: a `wr-architect:agent` review yields PASS-WITH-NOTES with substantive rationale. Pattern:

1. User invokes capture-adr with `$ARGUMENTS = "Title from review topic\nContext: review of <change>\nDecision: <one-line verdict + rationale>"`.
2. Skeleton lands at `docs/decisions/<NNN>-<kebab-title>.proposed.md` with status `proposed`.
3. Trailing pointer reminds user to canonical-expand.
4. Canonical expansion via `/wr-architect:create-adr <NNN>` fleshes out Considered Options (the alternatives the architect weighed) + Consequences + Confirmation + Reassessment.

This pattern preserves architect-review verdicts as first-class ADR-shaped records instead of letting them rot in commit-message bodies.

### Cross-namespace consistency with capture-problem

The `capture-` verb is consistent across `/wr-itil:capture-problem` and `/wr-architect:capture-adr`. Same dispatch shape (~3-4 turns), same deferred-placeholder pattern, same single-commit-per-capture grain, same trailing-pointer signal. Users learn one mental model that spans both. ADR-032 amendment names this symmetry.

## Composition with the rest of the suite

### `/wr-architect:create-adr`

Heavyweight intake counterpart. The two skills share the `docs/decisions/*.proposed.md` directory and the next-ID formula. Cross-skill ordering: capture-adr writes a skeleton at `<NNN>`; later `/wr-architect:create-adr <NNN>` (or direct Edit) expands the deferred sections in place. The auto-detect-and-expand path (where `/wr-architect:create-adr` mechanically detects a captured skeleton at the requested ID and expands rather than writes) is a follow-up ticket (architect Q3 verdict — out of scope for P156).

### `wr-architect:agent`

The review surface that processes ADR review delegations. capture-adr does not invoke the architect-agent inline; the deferred-canonical-expansion contract routes review through `/wr-architect:create-adr`'s Step 5 confirm pass. The architect-agent reviewing a `.proposed.md` skeleton sees `status: proposed` + deferred-flag literals and treats it as a not-yet-accepted ADR; reviews focus on whether the captured Decision conflicts with existing accepted ADRs.

### `/wr-itil:manage-problem` / `/wr-itil:capture-problem`

Compose with capture-adr when an iter surfaces both a problem AND a related decision. The user fires `/wr-itil:capture-problem <observation>` + `/wr-architect:capture-adr <decision>` in sequence (~6-8 turns total) instead of ~20-30 turns through the heavyweight pair.

### `/wr-itil:work-problems` (AFK orchestrator)

Iter subprocesses can invoke capture-adr to capture mid-iter design decisions without breaking iter cadence. The AFK carve-out in ADR-032 (line 85) excludes the **background-capture** variant from AFK contexts; the **foreground-lightweight-capture** variant introduced by P156 is fine inside iter subprocesses because it has no `Agent(run_in_background: true)` invocation — it is a normal foreground-synchronous skill that happens to do less work than create-adr.

### `/wr-architect:capture-adr` callers

The intended invocation surface is `/wr-architect:capture-adr <Title>\n<Context>\n<Decision>`. The payload must be non-empty; the skill does not branch on payload shape beyond the partial-payload graceful-degradation path documented under Edge cases.

## Related ADRs

- **ADR-009** — gate-marker-lifecycle (capture-adr does not write `/tmp` markers; ADR-009 referenced for pattern lineage only).
- **ADR-013** — structured user interaction (Rule 6 fail-safe; capture-adr has no AskUserQuestion branches so Rule 6 is trivially satisfied).
- **ADR-014** — governance skills commit their own work (capture-adr owns its commit).
- **ADR-019** — AFK orchestrator preflight (next-ID formula uses origin-tracking ref per ADR-019 confirmation criterion 2).
- **ADR-032** — governance skill invocation patterns (this skill's parent ADR; foreground-lightweight-capture variant amendment 2026-05-03 for capture-adr).
- **ADR-038** — progressive disclosure (SKILL.md + REFERENCE.md split shape).
- **ADR-044** — decision-delegation contract (framework-mediated mechanical-stage carve-outs).
- **ADR-049** — bin/ on PATH (capture-adr is self-contained; no new shim required, same as create-adr).
- **ADR-052** — behavioural-tests-default for skill testing (capture-adr's bats fixtures exercise primitives, not SKILL.md prose).
- **ADR-056** (`docs/decisions/056-...md` if present) — example of an inline-shipped substantive ADR that capture-adr could have skeleton-captured first.

## Related problems

- **P014** — parent / master tracker (ADR-032 children).
- **P088** — settled the user-direction-scoped decision: capture-problem + capture-adr are shippable; capture-retro is deferred.
- **P155** — sibling capture-problem skill (just shipped 2026-05-03).
- **P156** — driver ticket.
- **P157** — sibling pending-questions-surface hook.
- **P056** — ticket-creator next-ID lookup blob-SHA false-match (capture-adr's next-ID formula uses the `--name-only` fix).
- **P040** — origin-collision incident referenced in Edge cases.
