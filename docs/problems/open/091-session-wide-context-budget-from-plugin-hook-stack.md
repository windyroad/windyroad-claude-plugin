# Problem 091: Session-wide context budget — Claude Code consumes substantial context before and during every session across all contributor surfaces (meta)

**Status**: Open
**Reported**: 2026-04-22
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Effort**: XL (meta ticket — actionable work lives on P095/P096/P097/P098; this ticket owns framing, measurement, and the unifying ADR)
**WSJF**: (15 × 1.0) / 8 = **1.875**

> Meta ticket. Actionable work has been split into cluster children (see Related). Close this ticket only after every child closes or is Verification-Pending. Until then this ticket carries the shared framing, measurement plan, and ADR anchor for the unifying solution pattern (**progressive disclosure**).

## Description

Claude Code sessions in this workspace consume a large fraction of the 200K context window on *preamble* — content emitted by plugins, skills, memory, and global/project configuration — before and during real work. The user's observations 2026-04-22:

> we appear to be using up a lot of context just on start up
>
> and the problem is context usage in general, not just at startup
>
> and it's not just from plugins, it's from everything, including CLAUDE.md and local skills etc
>
> but you can fix THIS project itself if there is wasteful context usage

This is a meta ticket framing the full surface area and splitting action tickets by contributor cluster. Each cluster below names the child ticket that owns audit + remediation.

### Contributor map (measured 2026-04-22)

| # | Surface | Frequency | Size (this repo) | Windyroad-owned? | Child ticket |
|---|---------|-----------|------------------|------------------|--------------|
| 1 | Global `~/CLAUDE.md` | session start | 6163 B / ~1540 tok | user-owned | **P098** |
| 2 | Memory index (`MEMORY.md`) | session start | 1786 B / ~450 tok | user-owned | **P098** |
| 3 | Referenced memory files (ad-hoc) | mid-session | up to ~22KB / ~5500 tok | user-owned | **P098** |
| 4 | `UserPromptSubmit` hook injection × 5 plugins | every prompt | ~4.2–5.9KB / ~1050–1500 tok per turn | windyroad | **P095** (Known Error) |
| 5 | `PreToolUse` / `PostToolUse` hook injection × ~25 hooks | every qualifying tool call | unaudited | windyroad | **P096** |
| 6 | SKILL.md loaded per skill invocation | per skill call | up to 55KB / ~14k tok per skill (`manage-problem`); this-session total ~67KB / ~17k tok | windyroad | **P097** |
| 7 | Project-local `.claude/skills/install-updates/SKILL.md` | on invocation | 13524 B / ~3400 tok | project-owned | **P098** |
| 8 | MCP server instructions (e.g. `computer-use`) | session start | ~3KB+ per server | framework/user-configured | advisory — P091 notes only |
| 9 | Available-skills + subagent-types + deferred-tools listings | session start | ~35–50KB combined | framework-emitted | advisory — P091 notes only |

Estimated total per 30-turn session (rough):

- Startup one-off: ~35–55KB (items 1, 2, 8, 9) / ~9–14k tokens
- Per-prompt recurring: ~4.2KB × 30 = ~125KB (item 4) / ~30k tokens
- Per-tool-call recurring: unaudited but non-zero (item 5)
- Per-skill recurring: ~50KB over 3–5 invocations (item 6) / ~12k tokens
- Memory files (ad-hoc): ~5KB selectively (item 3)
- Project-local skill: ~3–14KB if invoked (item 7)

**Order-of-magnitude estimate: 30–40% of a 200K window is preamble in a typical AFK-orchestrator session.** Needs proper measurement via the harness below; numbers may move.

## Symptoms

- Cold-start `/clear` + single skill invocation consumes a meaningful fraction of the context window before the first assistant response.
- Every user turn's prefix carries identical MANDATORY hook blocks re-emitted (P095).
- Every skill invocation loads 10–55KB of SKILL.md (P097).
- Context-heavy sessions (AFK loops, long retros, batch problem work) compact materially earlier than expected.
- Self-referential observation: this very ticket was opened in a session that invoked `/wr-itil:work-problem` + `/wr-itil:manage-problem`, contributing ~17k tokens of SKILL.md load before the investigation began.

## Workaround

None for end-users. Mitigation lives on the child tickets.

## Impact Assessment

- **Who is affected**: Every user of any windyroad plugin set, plus anyone inheriting this workspace's `~/CLAUDE.md` / `.claude/` conventions.
- **Frequency**: Every session; cumulative across turns and tool calls.
- **Severity**: High cumulative. Early compaction costs both performance (slower turns from cache misses) and continuity (summarised history loses detail).
- **Analytics**: Measurement harness is a P091-owned deliverable that child tickets reuse.

## Root Cause Analysis

### Unifying design flaw

Every affected surface follows the same default: **emit all available context up-front, on every firing, with no affordance for the consumer to decide what to expand**. Concretely:

- Hooks emit full MANDATORY prose on every trigger (not once-per-session; not terse-on-success; not scope-aware).
- SKILL.md files inline policy + rationale + examples + deprecation notes that most invocations do not need (not split between runtime steps and reference material).
- `~/CLAUDE.md` carries project-type-specific policy globally (not gated by project type; not pointed-to from project-level config).
- Memory files implicitly load when read even if the index entry was already sufficient to decide relevance.

The default is **eager**, not **lazy**. The cost is paid on every firing regardless of whether the consumer (the assistant) needed the content this turn.

### Confirmed clusters

- **P095** (UserPromptSubmit, Known Error 2026-04-22): five hooks, no session gating, verbose prose. Fix: shared session-marker helper + once-per-session emission + terse reminder after first turn + ADR.
- **P097 magnitude** (SKILL.md size, hypothesised fix path): 55KB in `manage-problem`, 39KB in `work-problems`, 36KB in `run-retro` — directly measured.
- **P098 audit** (project/user-owned surfaces): `~/CLAUDE.md` 98 lines, `install-updates/SKILL.md` 13.5KB, memory files ~22KB total — directly measured.

### Hypothesised (needs child audit)

- **P096**: per-tool hook prose pattern — ~25 hooks, none yet measured for gate-pass vs gate-fail verbosity.

### Out of scope (advisory notes only)

- MCP preamble and Claude Code framework listings — not windyroad-owned and not project-editable. Noted in the table; user-level mitigations outside this ticket's scope.

## Solution pattern — progressive disclosure (per user direction 2026-04-22)

> *"please consider 'progressive disclosure' where less info is provided up front but it has affordances that allow the agent to get the extra info needed WHEN it needs to (just one part of a multi-part solution)"*

Progressive disclosure is the unifying design principle that child tickets adopt:

- **Less info upfront.** Default emission is lean — the minimum signal needed for the consumer to decide what to do next.
- **Affordances to get more.** The lean signal names explicitly *where* deeper context lives: a file path to Read, a subagent to delegate to, a command to run. The affordance is not implicit — it is a concrete next-step pointer.
- **Consumer-driven expansion.** The assistant decides when to read the full reference material, based on the situation at hand. The hook/skill/config is not the agent of disclosure — the consumer is.

Worked examples (one per cluster):

- **P095**: first-prompt emission is the full MANDATORY block (bootstrap). Subsequent prompts emit a terse `Governance gate active: wr-architect — delegate to wr-architect:agent for full scope and exclusions`. The **affordance** is the explicit agent pointer.
- **P096**: gate-pass emits nothing or `wip-risk gate passed`. Gate-fail emits the full error + fix suggestion. The **affordance** on gate-pass is implicit — "check the script if you need the scope rules"; on gate-fail, the full prose carries its own affordance.
- **P097**: lean `SKILL.md` carries runtime steps + explicit pointers like `See REFERENCE.md#staging-trap for the P057 staging-trap background.` The **affordance** is the path + anchor.
- **P098**: `~/CLAUDE.md` shrinks to a few lines naming project-level files to consult (`See project CLAUDE.md for project-type policy. See docs/decisions/ for ADRs`). The **affordance** is the project-level file path.

**Progressive disclosure is one part of a multi-part solution.** Companion axes (noted here for the ADR to enumerate):

- **Trimming** — drop content that is unused in any scenario (stale, duplicated, superseded).
- **Consolidation** — N verbose gate reminders become 1 terse aggregate reminder.
- **Gating** — once-per-session / once-per-file markers suppress redundant emission.
- **Scope-awareness** — hooks that know the current edit/tool call does not match their scope stay silent.

### Investigation tasks (P091 meta)

- [x] Enumerate the contributor surfaces (2026-04-22 audit)
- [x] Measure per-surface byte counts for this repo's current state (2026-04-22 audit)
- [x] Split action tickets by cluster (2026-04-22 — P095/P096/P097/P098 created)
- [ ] Build a measurement harness (`packages/shared/bin/measure-context-budget.sh` or equivalent) that counts hook output bytes per firing, totals a representative N-turn session's injections, and reports before/after deltas. Useful for every child.
- [ ] Draft ADR: "Progressive disclosure for governance tooling context" — enumerates the four axes (progressive disclosure, trimming, consolidation, gating, scope-awareness), the session-marker convention, the REFERENCE.md split convention, and the per-prompt / per-tool / per-skill token budget targets. Authored after P096 + P097 audits land so the budget numbers are informed.
- [ ] Close P091 only after every child ticket closes or sits Verification-Pending.

## Related

### Child tickets (split 2026-04-22)

- **P095 (UserPromptSubmit hook injection)** — Known Error. Effort L. WSJF 7.5. Shared session-marker helper + 5 hook edits + bats reproduction + ADR contribution.
- **P096 (PreToolUse/PostToolUse hook injection)** — Open. Effort L. WSJF 3.0. Audit + per-hook edits reusing the P095 helper.
- **P097 (SKILL.md runtime size)** — Open. Effort L. WSJF 3.0. Runtime-steps vs reference-material split; progressive disclosure pattern in SKILL.md bodies.
- **P098 (project/user-owned contributors)** — Open. Effort M. WSJF 6.0. Trim `~/CLAUDE.md` + `install-updates/SKILL.md` + MEMORY.md curation.

### Adjacent

- **P029 (Edit gate overhead disproportionate for governance documentation changes)** — agent-invocation volume on governance doc edits; scope-exclusion infrastructure is shared with P096.
- **P034 (Centralise risk reports for cross-project skill improvement)** — the measurement harness this meta ticket owns would benefit from centralised reporting.
- **P071 (Argument-based skill subcommands are not discoverable)** — the phased split already started trimming `manage-problem`; continues inside P097.
- **P087 (No maturity signal for plugin features)** — a hook-injection-budget dimension intersects with maturity signalling.

### ADR anchor

- **Proposed ADR**: "Progressive disclosure for governance tooling context" (renamed from earlier "Hook injection budget policy" framing). Single ADR covering the four axes and the conventions each cluster adopts. Authored against this meta ticket after children's audits inform the budget numbers.
