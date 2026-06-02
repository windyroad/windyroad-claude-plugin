# Problem 062: `manage-problem` does not refresh `docs/problems/README.md` on single-ticket transitions; fast-path cache goes stale silently

**Status**: Closed — verified in AFK-iter-7 session 2026-04-21 (README refreshed atomically on 4 transitions: iter 1 P084 .open→.verifying; iter 5 P086; iter 6 P067; iter 7 P076)
**Reported**: 2026-04-20
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S — edit `packages/itil/skills/manage-problem/SKILL.md` Step 7 / Step 11 to include a README.md refresh in the transition commit
**WSJF**: 4.0 — (4 × 1.0) / 1

## Description

`packages/itil/skills/manage-problem/SKILL.md` Step 9 (the `review` operation) has a cache-refresh step 9e that writes `docs/problems/README.md` with the ranked dev-work table + verification queue + parked section. Step 9's fast-path (the hit case) skips 9a–9e entirely when the README.md cache is fresh, delivering immediate operation with no rescan.

The gap: Step 7 status transitions (`Open → Known Error`, `Known Error → Verification Pending`, `Verification Pending → Closed`) do **not** refresh README.md. Step 11's commit convention covers the transition commit but does not include README.md in the stage list. Consequence: a transition that happens outside a `review` operation leaves README.md stale, and the next session's fast-path check correctly detects staleness and runs a full review (safe, but slow) — OR worse, if the same session later runs a `work` operation, the already-stale README is consumed as the ranking source.

Observed 2026-04-20 AFK iter 5: P059 transitioned Open → Verification Pending. The transition commit staged the ticket rename + `## Fix Released` content + skill source + ADR amendment + bats test, but NOT `docs/problems/README.md`. README.md still reflects the pre-P059 state. The next `work` invocation's fast-path will trigger a full rescan because the freshness check correctly detects README.md as older than the transition commit.

This is self-healing but wasteful. A single-line refresh in Step 7 / Step 11 keeps README.md current across all operations.

## Symptoms

- `docs/problems/README.md` lags the actual `.open.md` / `.known-error.md` / `.verifying.md` / `.parked.md` / `.closed.md` inventory by the count of ticket transitions since the last `review` operation.
- Fast-path cache check fires "stale" on any subsequent invocation, forcing a full rescan.
- Human readers browsing README.md see outdated WSJF rankings.
- The Verification Queue section may miss newly-transitioned `.verifying.md` entries (this session's P058, P059 are both transitions in a session where README.md was never re-written).

## Workaround

After every transition, manually run `/wr-itil:manage-problem review` to refresh README.md. The fast-path cache's freshness check will trigger the rescan automatically, but the explicit invocation is a forcing function if the user wants README.md current sooner.

## Impact Assessment

- **Who is affected**: anyone browsing `docs/problems/README.md` between sessions. AFK orchestrators that do multiple transitions in one session but only one `review` are the primary source.
- **Frequency**: every `manage-problem` session that performs ≥ 1 transition without running `review` at the end. Very common in AFK loops (1 review at start + many transitions + no refresh).
- **Severity**: Minor — README.md staleness is self-detecting via the freshness check, and the fast-path correctly falls back to a full rescan. No data loss, no silent corruption.
- **Analytics**: 2026-04-20 AFK iter 5 is one observed instance. The broader pattern is that most AFK iterations transition tickets but don't refresh README.md — this will be the common case going forward.

## Root Cause Analysis

### Structural

Step 7's transition blocks describe the `git mv` + Edit + `git add` sequence for renaming tickets. Step 11 describes the commit convention. Neither mentions `docs/problems/README.md`.

Step 9e writes README.md, but 9e only fires on the `review` code path. The `work` code path fires Step 9 which may take the fast-path (no 9e) or the slow-path (full rescan with 9e). The `known-error` / `transition` code paths skip Step 9 entirely.

### Fix strategy

Two shapes:

**(a) Cheap incremental refresh**: when Step 7 stages a transition, also regenerate README.md in-place and add it to the same commit. The regeneration uses the same logic as Step 9e but scoped to the already-in-memory set of problem files. Adds one paragraph to Step 7 and one bullet to Step 11's stage list.

**(b) Explicit `review` invocation after transitions**: amend Step 11 to close each transition commit with a trailing `review` run that fires 9e. Heavier; doubles the commit count if interpreted literally, or requires squashing.

Prefer (a). It keeps README.md current with zero extra commits. The cost is one more file write per transition commit, which is already within the transition's tracked-file set.

### Affected files

- `packages/itil/skills/manage-problem/SKILL.md` — Step 7 (transition sequence) and Step 11 (commit convention) amendments.
- Optional: `packages/itil/skills/manage-problem/test/manage-problem-readme-refresh-on-transition.bats` — doc-lint assertion that Step 7 / Step 11 reference the README.md refresh.

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20 AFK iter 5; P059 transition commit did not include README.md. Git log confirms: `git show --stat` on the transition commit does not list `docs/problems/README.md`.
- [ ] Decide between shapes (a) and (b). Lean (a) per above.
- [ ] Apply the Step 7 + Step 11 amendment.
- [ ] Optional: bats doc-lint regression.

## Fix Released

Shipped 2026-04-20 (AFK iter 6 iter 4, commit pending). `manage-problem` SKILL.md now refreshes `docs/problems/README.md` on every Step 7 status transition and stages it in the same commit (shape (a) — cheap incremental refresh, per the ticket).

- `packages/itil/skills/manage-problem/SKILL.md` Step 7 gains a new "README.md refresh on every transition (P062)" subsection (after the Verification Pending → Closed block, before Step 8). The block describes the mechanism (regenerate in-place reflecting new filename set + Status; `git add` alongside the ticket rename; update the Last reviewed line), covers all four transition scopes (Open → KE, KE → VP, VP → Closed, Parked), explicitly covers folded-fix commits (where the `.verifying.md` transition rides with a `fix(<scope>): ...` commit), and explains the fast-path interaction (cache stays fresh by construction).
- `packages/itil/skills/manage-problem/SKILL.md` Step 11 commit convention now requires `docs/problems/README.md` in the stage list for every Step 7 transition, including folded-fix commits.
- `packages/itil/skills/manage-problem/test/manage-problem-readme-refresh-on-transition.bats` — NEW. 9 structural doc-lint assertions (Permitted Exception per ADR-005) covering refresh block presence, all four transition scopes, folded-fix coverage, "render not re-rank" wording, same-commit staging, Step 11 requirement, Step 11-to-Step-7 cross-reference, fast-path interaction, and Last reviewed line update.

The refresh is a render (uses existing WSJF values trusted from ticket files), not a re-rank (no full re-scoring pass — that remains Step 9's job). This distinguishes the on-transition refresh from the `review` operation's full rescan.

Architect review PASSED (no new ADR needed; aligns with ADR-014 commit ordering and ADR-022 Verification Queue; strengthens ADR-022 Confirmation by keeping the README in sync between reviews). JTBD review PASSED (primary: JTBD-201 audit trail; secondary: JTBD-202, JTBD-001).

Awaiting user verification: next `manage-problem` status transition (outside a `review` invocation) should include `docs/problems/README.md` in the transition commit's stage list, with the refreshed file reflecting the new ticket state. The subsequent session's fast-path freshness check should report "fresh" (no stale-cache rescan) on the next `work` invocation.

## Related

- **ADR-022** — introduced the `.verifying.md` lifecycle; the Verification Queue section in README.md depends on transitions being reflected.
- **ADR-014** — governance skills commit their own work; this ticket extends ADR-014's "commit ordering" to include README.md in transition commits.
- **P031** (closed 2026-04-19) — stale cache detection using git history. The freshness check Step 9 describes is the existing infra; this ticket closes the "never goes stale" complement.
- **P047** (Verification Pending) — WSJF effort bucket re-rate at lifecycle transitions. Sibling concern: P062 is about README.md inventory, P047 is about WSJF score freshness. Both contribute to README.md accuracy; they are independently fixable.
