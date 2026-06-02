# Problem 117: No batch-transition surface for multiple problem tickets in a single run-retro / review cycle

**Status**: Verification Pending
**Reported**: 2026-04-24
**Priority**: 6 (Med) — Impact: Minor (2) x Likelihood: Likely (3)
**Effort**: M — confirmed shape per user direction 2026-04-26: **new skill `/wr-itil:transition-problems` (plural)** that accepts a list of `<NNN> <status>` pairs and reuses the singular `/wr-itil:transition-problem` per-ticket logic in a loop, producing a single shared commit (ADR-014 batch-commit semantics). Matches the singular/plural pattern P071 established (`work-problem` vs `work-problems`).
**WSJF**: (6 × 1.0) / 2 = **3.0**

## User direction (2026-04-26 interactive AskUserQuestion resolution)

The "architect decision pending on shape" called out in the README is now resolved: **new sibling skill `/wr-itil:transition-problems` (plural)**. Rationale: matches P071's singular/plural split-skill pattern (`work-problem` vs `work-problems`), preserves the singular skill's "one ticket per invocation" contract, and surfaces in autocomplete as a distinct command. Implementation reuses the singular skill's per-ticket logic in a loop — including pre-flight checks, P063 external-RCA detection, P057 staging-trap re-stage, P062 README refresh — and produces ONE shared commit covering all transitions per ADR-014 batch semantics.

Rejected alternatives (with reason):
- **Multi-arg on existing transition-problem**: blurs the singular's "one ticket per invocation" contract; conflicts with the singular/plural pattern other skills follow.
- **Hook on run-retro Step 4a**: couples run-retro and transition-problem; doesn't surface as a standalone command for ad-hoc batch transitions outside retro context.
- **Defer / won't-fix**: the SKILL.md reload cost is real and recurs every `run-retro` Step 4a session that closes multiple verifyings.

> Surfaced during this session's run-retro Step 4a. User explicitly requested the ticket after observing four verification-close transitions executed inline (not via `/wr-itil:transition-problem` delegation) because per-ticket Skill invocations would each re-load the transition-problem SKILL.md context, creating N× overhead on an inherently-batchable operation.

## Description

`/wr-itil:transition-problem` is the canonical executor for per-ticket lifecycle transitions (Open → Known Error → Verification Pending → Closed). Per ADR-010 amended "Split-skill execution ownership" and P093's resolution, the skill hosts the rename + Edit + P057 re-stage + P062 README refresh + ADR-014 commit inline.

The skill's argument shape is `<NNN> <status>` — one ticket per invocation. There is no batch surface. When N tickets need the same transition in one operation — as in `run-retro` Step 4a's verification-close housekeeping after a multi-ticket session, or `manage-problem review` Step 9d's closure prompts across the Verification Queue — the caller faces a choice:

1. **Delegate N separate times**, one `Skill` invocation per ticket. Each invocation re-loads the full `transition-problem` SKILL.md into context. For 4 tickets this is ~4× the SKILL.md footprint in context, duplicating the same procedural knowledge for each closure. Given SKILL.md runtime size concerns (P097), the amplification is material.
2. **Batch inline**, running the rename + Edit + README refresh + commit outside the transition-problem skill's ownership. Efficient but violates the ADR-014 / ADR-010-amended ownership boundary — run-retro is not supposed to commit its own work; transition-problem is. Inline batching makes run-retro (or whatever caller) effectively a shadow executor.
3. **Sequence `git mv` + `Edit` manually, then invoke transition-problem just for the commit**. Hybrid. Ambiguous ownership; the skill's pre-flight checks and P063 external-root-cause detection are bypassed on the inline edits. Unsafe.

None of the three is satisfying. The session that surfaced this hit (2026-04-24 run-retro): 4 verification-close candidates (P063, P067, P092, P094) all approved in one user AskUserQuestion batch; the assistant chose Option 2 inline for efficiency, noting the ownership-boundary drift.

## Symptoms

- Closing 4+ tickets in one run-retro invocation costs either 4× SKILL.md reloads (if delegated) OR an ownership-boundary violation (if inline).
- The `transition-problem` skill has no batch mode; no `--batch`, no comma-separated IDs.
- The `run-retro` skill contract explicitly requires delegation to `transition-problem` for closures, but provides no guidance on how to avoid the N× context cost.
- Same issue presents in `manage-problem review` Step 9d when multiple verifyings are old enough to be closure candidates.

## Workaround

Chosen 2026-04-24: batch inline (Option 2). Run `git mv` + `Edit` + README refresh for all N tickets, commit once with a batch commit message listing all closed tickets (`docs(problems): close P<A>, P<B>, P<C> — verified in-session via run-retro Step 4a`). Explicitly acknowledge the ownership-boundary drift in the run-retro summary. Not a sustainable long-term pattern.

## Impact Assessment

- **Who is affected**: every run-retro Step 4a invocation that finds ≥ 2 verification-close candidates from in-session evidence. Manage-problem review Step 9d with ≥ 2 stale verifyings. Any future batch-ticket-lifecycle workflow.
- **Frequency**: once per multi-ticket run-retro. Observed 2026-04-22 run-retros (P084/P036/P060/P054 batch-close, 4 tickets; P057/P095 batch-close, 2 tickets) and 2026-04-24 (this session, 4 tickets P063/P067/P092/P094). Pattern: every retro that follows a productive multi-ticket session trips this.
- **Severity**: Moderate. Not blocking — the workaround works. But it forces a choice between context bloat and ownership-boundary violation on every batch retro. Accumulates toward P097's SKILL.md-runtime-size pressure.
- **Analytics**: N/A — developer-experience observation.

## Root Cause Analysis

### Preliminary hypothesis (ADR decision needed)

Four candidate shapes for the fix, each with different contract surfaces:

1. **Extend `transition-problem` argument shape** to accept `<NNN>[,<NNN>...] <status>` (comma-separated IDs, single destination). One Skill invocation, single SKILL.md load, iterates over IDs internally. Clean. Respects the ownership boundary. Needs argument-parser update + bats assertions. Risk: all IDs must transition to the same destination; mixed transitions are separate invocations.
2. **New `/wr-itil:batch-transition` skill** with full batch semantics (mixed destinations allowed, e.g. `--close P063,P067 --verifying P076`). More flexible. Higher implementation cost. Proliferates skill surfaces (arguably counter to ADR-010's one-skill-per-intent rule — batching IS a distinct intent). Risk: duplication of transition-problem's internal logic.
3. **Run-retro embeds transition-problem as an inlined library**. Make the SKILL.md body of transition-problem smaller / more library-like so the "re-load on each invocation" cost is negligible. Generalisation of P097. Doesn't add batch surface but makes the N× delegation cheap. Risk: requires P097's resolution first.
4. **Accept the status quo, document the inline-batch pattern**. Inline batching becomes a blessed ownership exception when the caller is run-retro (or manage-problem review) batch-closing ≥ 2 tickets. Lowest implementation cost but explicit exception-to-ownership feels wrong. Risk: sets precedent that "when inconvenient, the ownership boundary is optional".

### Investigation Tasks

- [x] Architect Q1: which shape? — Resolved 2026-04-26 by user direction: NEW sibling skill `/wr-itil:transition-problems` (plural). Matches P071 singular/plural split precedent.
- [x] Architect Q2: argument shape — Resolved by 2026-04-26 architect verdict: space-separated `<NNN> <status>` pairs (no `P` prefix, no `=`/`:` separator, no CLI flags). Mixed destinations supported by construction (each pair carries its own destination).
- [x] Architect Q3: bats contract-assertion shape — Resolved by 2026-04-26 architect verdict: `transition-problems-contract.bats` per ADR-037 canonical naming. 20 assertions covering frontmatter shape, allowed-tools, citations, inline-mechanic positives, no-Skill-tool-delegation negative, single-commit-at-end positive + no-per-pair negative, single-README-refresh-at-end, partial-failure skip-and-surface, argument-shape positive + flag-style negative, no `deprecated-arguments` flag, and a CROSS-FILE drift-detection assertion that the staging-trap `git add docs/problems/` phrase appears in BOTH this skill's SKILL.md and the singular's SKILL.md (catches drift between inline copies per ADR-010 amended "copy, not move").
- [x] JTBD alignment: JTBD-001 primary (eliminates N×SKILL.md reload tax + ownership-boundary violation at batch closures); JTBD-006 composes (work-problems may delegate batch closures here during AFK orchestration); JTBD-101 (singular/plural split mirrors the established pattern).
- [x] Implementation: complete. New `packages/itil/skills/transition-problems/SKILL.md`, behavioural contract bats, changeset.

### Reproduction

Run `/wr-retrospective:run-retro` after a multi-ticket session where ≥ 2 verifyings are exercised in-session. Step 4a prompts the close candidates; approve all; observe the assistant chooses between N Skill-loads and inline-batch. Both paths work; neither is satisfying.

### Fix Strategy

Deferred pending architect decision on contract shape. Implementation effort is M regardless of shape: argument parser / new skill / inlining / doc edit all carry roughly the same implementation + test footprint.

## Fix Released

**Released**: 2026-04-26 (commit pending — `fix(itil): P117 batch-transition surface — new /wr-itil:transition-problems plural skill`)

**Summary**: New plural sibling skill `/wr-itil:transition-problems` accepts a space-separated list of `<NNN> <status>` pairs and runs each pair's per-ticket mechanic inline (pre-flight, P063 detection, `git mv` + Edit + P057 re-stage). Refreshes `docs/problems/README.md` ONCE at the end (P062 at batch grain) and commits ALL surviving transitions in ONE commit per ADR-014 batch-grain. Partial-failure semantics: skip-and-surface (failed pairs continue; succeeded pairs commit at end; zero successes means no commit). Inline per-ticket mechanic per ADR-010 amended "copy, not move"; drift between singular and plural detected by a contract-bats assertion that asserts the `git add docs/problems/` re-stage phrase appears in both SKILL.md files.

**Awaiting user verification**. Verification path: invoke `/wr-itil:transition-problems` with a multi-pair argument list (e.g. release-aged verifyings to close), confirm the single batch commit lands, README refreshes once, and per-pair outcomes are reported in the structured summary. Confirms when used in a real run-retro Step 4a / manage-problem review Step 9d batch closure where ≥ 2 verifyings are exercised — the original surface-context P117 names.

**Exercise evidence in this session**: contract bats fixture (20 assertions) green; SKILL.md citations cross-checked against singular + ADR-010 amended + ADR-014 + ADR-022 + ADR-013 Rule 6 + P057 + P062 + P063 + ADR-037; sibling skill bats (transition-problem-contract + work-problems) re-run green confirming no drift introduced.

## Dependencies

- **Blocks**: efficient multi-ticket lifecycle operations from run-retro + manage-problem review + future work-problems AFK release orchestration (when tracking N close-candidates post-drain).
- **Blocked by**: architect decision on shape (Q1-Q3 above).
- **Composes with**: P097 (SKILL.md runtime size — the N× reload cost is a direct symptom of P097's broader problem). If P097's progressive-disclosure solution sufficiently shrinks per-skill runtime footprint, shape 3 (inlined library) may be the cleanest answer; otherwise shape 1 (batch args) is likely the best cost/benefit tradeoff.

## Related

- **P093** (closed-ish) — transition-problem ↔ manage-problem circular delegation; resolved by giving transition-problem ownership of the per-ticket transition. P117 extends the question: batch ownership.
- **P097** (open) — SKILL.md runtime size cluster. P117 is a concrete cost case of P097's generalised concern.
- **P057** — `git mv` + Edit staging trap. Any batch-transition implementation must hold P057's contract per ticket.
- **P063** — external-root-cause detection in transition-problem Open → Known Error. Batch transitions at the Open → Known Error boundary must not silently skip P063.
- **ADR-010 amended** — Skill Granularity + Split-skill execution ownership. Any new batch surface needs this decision's amendment or cross-reference.
- **ADR-014** — governance skills commit their own work. Batch-transition is still one commit per batch (one transaction); ADR-014 does not need amending, but the skill body must state the batch-as-single-transaction invariant explicitly.
- **run-retro Step 4a** (`packages/retrospective/skills/run-retro/SKILL.md` — governance-workflow topic of briefing) — primary caller of the batch-close path.
- **manage-problem review Step 9d** — secondary caller.
