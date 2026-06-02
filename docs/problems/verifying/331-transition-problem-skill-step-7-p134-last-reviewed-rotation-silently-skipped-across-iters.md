# Problem 331: transition-problem SKILL Step 7 P134 Last-reviewed rotation silently skipped across iters

**Status**: Verification Pending
**Reported**: 2026-05-30 (work-problems wrap retro — defers from iter 9 retro deferred-ticket observation per iter 10 retro carry-forward)
**Priority**: 6 (Medium) — Impact: 2 (Minor — line 3 staleness propagates across multiple iters; README-history.md misses entries; audit trail decoupled) × Likelihood: 3 (Likely — recurred 2 consecutive iters before iter-9 retro caught it)
**Effort**: S (SKILL.md prose amendment across 8 call sites + structural bats; mechanical edits, no new lib code)
**WSJF**: 6.0 (re-rated 2026-05-31; Effort S confirmed; was 3.0 placeholder)
**Origin**: internal

## Description

`/wr-itil:transition-problem` Step 7 (and the equivalent inline transition path in `/wr-itil:manage-problem`) prescribes the P134 truncation discipline: rotate line 3 of `docs/problems/README.md` ("Last reviewed" fragment) to `README-history.md` and replace with new fragment naming the transition. This contract was silently skipped in iter 7 + iter 8 of the 2026-05-30 work-problems AFK session; iter 9 retro caught the skip-class via post-fact comparison.

## Symptoms

- Iter 9 retro observed: `docs/problems/README.md` line 3 still carried iter-6 P282 fragment (3 iters old) despite iter 7 (P281 Open → KE) + iter 8 (P281 K→V) both modifying the WSJF Rankings + Verification Queue tables.
- `docs/problems/README-history.md` missing the iter-7 and iter-8 entries that should have been rotated.
- Iter 10 retro inherited the observation under `category: pipeline-instability-prior-iter` and deferred ticketing under `cause: skill_unavailable` (capture-* AFK carve-out per ADR-032).
- Concrete citation set in `docs/retros/2026-05-30-work-problems-iter9-p325.md` Pipeline Instability subsection.

## Workaround

Manual check after each transition + manual rotation if the line 3 hasn't been refreshed. Tedious; relies on operator memory.

## Impact Assessment

- **Who is affected**: every consumer of `docs/problems/README.md` line 3 (session-start surfaces; orchestrator preflight reads; ad-hoc audits).
- **Frequency**: 2 of 9 transition-bearing iters this session (~22%) — significant when transitions cluster.
- **Severity**: Minor — README line 3 is informational; downstream tooling reads tables, not line 3. Audit trail in `README-history.md` is the actual loss.
- **Analytics**: line 3 staleness propagation is silent until a retro catches it; can persist undetected across sessions.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — done 2026-05-31 (re-rated to 6.0 / S)
- [x] Reproduce: dispatch 2 consecutive iters that each call transition-problem with K→V; observe whether line 3 rotates on both — confirmed via the iter-7 + iter-8 evidence cited in 2026-05-30 retro
- [x] Audit transition-problem SKILL Step 7 + manage-problem inline Step 7 prose for P134 rotation step explicitness — done 2026-06-01; see Findings below
- [x] Cross-reference with reconcile-readme Step 5 P134 rotation (which fires correctly in this session) — what's structurally different? — done; see Findings below
- [x] Verify whether the silent-skip is per-skill-prose (Step 7 contract clarity) or per-execution (agent reading the contract but skipping the action) — per-skill-prose confirmed; see Findings below

### Findings (2026-06-01 audit during fix iter)

**Root cause confirmed: cross-document-reference contract pattern at 8 call sites.**

Each of the 8 surfaces that should rotate the line-3 fragment to `<index>-history.md` BEFORE rewriting it uses a one-liner prose reference of the form:

> "Update the 'Last reviewed' line per the **Last-reviewed line discipline (P134)** contract documented in `manage-problem` SKILL.md Step 5"

The mechanism (read line 3 → append-to-history-if-non-empty → replace line 3 → stage both) is NOT inlined at the execution site. Agents reading the SKILL in a single-pass execution context:

1. Don't cross-navigate to the manage-problem Step 5 § Last-reviewed line discipline subsection.
2. See the rotation as a subordinate sub-step after the obvious "regenerate README.md" + "git add README.md" steps.
3. Mistakenly believe the regeneration of README.md is sufficient (the new line 3 IS rewritten — but the PRIOR content is destroyed by the Edit tool's replace, with no archive step before it).

**Asymmetry confirmed**: `reconcile-readme` SKILL Step 5 (lines 106-118) inlines the same 3-step Mechanism as a standalone numbered list AT THE EXECUTION SITE. That surface fires correctly — visible evidence in `docs/problems/README-history.md` showing multiple 2026-05-31 rotations from the reconcile path.

**Surfaces affected** (8 total — broader than the ticket's original scope of 2):

| # | File | Line | Surface |
|---|------|------|---------|
| 1 | `packages/itil/skills/manage-problem/SKILL.md` | 548 | Step 5 — refresh on new ticket |
| 2 | `packages/itil/skills/manage-problem/SKILL.md` | 605 | Step 6 — refresh on conditional update |
| 3 | `packages/itil/skills/manage-problem/SKILL.md` | 720 | Step 7 — refresh on every transition |
| 4 | `packages/itil/skills/transition-problem/SKILL.md` | 209 | Step 7 sub-step 3 |
| 5 | `packages/itil/skills/transition-problems/SKILL.md` | 189 | Step 4a tail |
| 6 | `packages/itil/skills/review-problems/SKILL.md` | 374 | Step 5 refresh |
| 7 | `packages/itil/skills/manage-rfc/SKILL.md` | 134 | Step 4 README refresh (different target: docs/rfcs/) |
| 8 | `packages/itil/skills/manage-story/SKILL.md` | 127 | Step 4 README refresh (different target: docs/stories/; ALSO missing the README-history.md mention entirely) |

### Hypotheses (resolved)

1. **Step 7 contract clarity** — CONFIRMED as root cause. The rotation step is embedded in a single-sentence cross-document reference, not an enumerated mechanism. Agents skip it under execution-time cognitive load.
2. **Inline-vs-shim seam** — partially confirmed. The 5 manage-problem-family call sites all share the same one-liner shape; the manage-rfc + manage-story call sites mirror the same cross-document pattern against `docs/rfcs/README.md` + `docs/stories/README.md`.
3. **Cross-iter race** — NOT the root cause. The bug is per-iter execution, not cross-iter state. Each iter's Edit tool replace-line-3 destroys the existing line 3 because no prior archive step ran.

## Fix Strategy

**Kind**: improve
**Shape**: skill (SKILL.md prose amendment + structural bats)
**Target files** (8 SKILL.md surfaces — architect-approved scope expansion 2026-06-01):
1. `packages/itil/skills/manage-problem/SKILL.md` Steps 5, 6, 7
2. `packages/itil/skills/transition-problem/SKILL.md` Step 7
3. `packages/itil/skills/transition-problems/SKILL.md` Step 4a
4. `packages/itil/skills/review-problems/SKILL.md` Step 5
5. `packages/itil/skills/manage-rfc/SKILL.md` Step 4 (target docs/rfcs/)
6. `packages/itil/skills/manage-story/SKILL.md` Step 4 (target docs/stories/; plus fill missing README-history mention)

Plus structural bats lock-in at:
- `packages/itil/skills/transition-problem/test/transition-problem-contract.bats`
- `packages/itil/skills/transition-problems/test/transition-problems-contract.bats`

**Chosen option** (option a per ticket scope; architect APPROVED 2026-06-01):

Replace each one-liner cross-document reference with an inline 4-step **P134 rotation mechanism** numbered block:

1. **Read** line 3 of `<index>` (`awk 'NR==3' <index>` or equivalent).
2. **Append-if-non-empty** — if line 3 is non-empty AND not a same-session same-verb near-duplicate, append it verbatim to `<index>-history.md` under a `## YYYY-MM-DD` heading (creating the heading on first append for that date). **BEFORE step 3** — Edit-tool replacement of line 3 without this archive step destroys the displaced content, re-opening P331.
3. **Rewrite** line 3 with the new fragment of form `> Last reviewed: YYYY-MM-DD **<event>** — <one-line summary>` (≤ 1024 B soft / ≤ 5120 B hard per ADR-040 Tier 3 envelope).
4. **Stage both** — `git add <index> <index>-history.md` so the same single commit per ADR-014 captures both files.

The canonical rationale anchor stays at `manage-problem` SKILL.md Step 5 § Last-reviewed line discipline (P134) — the inlined mechanism block links back to it for the "why" but the "what" is self-contained at each execution site.

Structural bats assert: inlined `awk 'NR==3'` (or equivalent read pattern), `README-history.md` append marker, "BEFORE" / "before rewriting" ordering language, P134 citation. The bats lock the cross-skill copy pattern (transition-problem ↔ transition-problems carries the same inline block).

**Evidence**: 2026-05-30 iter-7 + iter-8 silent-skip cited verbatim in `docs/retros/2026-05-30-work-problems-iter9-p325.md`; iter-10 deferred-ticket carry-forward in `docs/retros/2026-05-30-work-problems-iter10-p302.md`. Reconcile-readme positive control (working surface) cited in `packages/itil/skills/reconcile-readme/SKILL.md` Step 5 lines 106-118.

**Release vehicle**: `.changeset/wr-itil-p331-inline-p134-rotation-mechanism.md` (deleted at version-packages commit ea68cba).

## Dependencies

- **Blocks**: clean cross-iter audit trail in `README-history.md`
- **Blocked by**: (none)
- **Composes with**: ADR-022 (Verifying lifecycle), ADR-031 (per-state subdir layout), `/wr-itil:reconcile-readme` (sibling skill with correct P134 behaviour — model for fix)

## Related

- `docs/retros/2026-05-30-work-problems-iter9-p325.md` — Pipeline Instability subsection (primary citation)
- `docs/retros/2026-05-30-work-problems-iter10-p302.md` — carry-forward observation
- 2026-05-30 work-problems wrap retro (this capture)
- P134 (truncation discipline — the contract being violated)
- `/wr-itil:reconcile-readme` Step 5 (correct P134 implementation — fix model)

## Fix Released

- **Release vehicle**: `@windyroad/itil@0.44.0` (npm: <https://www.npmjs.com/package/@windyroad/itil/v/0.44.0>)
- **Fix commit**: `156a85c` — `fix(itil): P331 — inline P134 rotation Mechanism at 8 SKILL.md call sites`
- **Release commit**: `71349f2` — `Merge pull request #193 from windyroad/changeset-release/main`
- **Changeset**: `.changeset/wr-itil-p331-inline-p134-rotation-mechanism.md` (deleted at version-packages commit `ea68cba`)
- **Release date**: 2026-06-01
- **Transition**: Known Error → Verification Pending per ADR-022. Completed inline from orchestrator main turn 2026-06-01 after iter 4 subprocess stuck-before-emit (P147 subclass: SIGTERM at 60min idle, 0-byte JSON; iter had staged ticket rename to verifying/ but never completed Status edit + ## Fix Released section + README refresh).
- **User verification path**: trigger any K→V transition via `/wr-itil:transition-problem` or `/wr-itil:transition-problems` and observe that `docs/problems/README.md` line 3 fragment is now rotated to `docs/problems/README-history.md` BEFORE being replaced (visible by `tail -1 docs/problems/README-history.md` matching the prior line 3 verbatim, and the new line 3 carrying the new transition's fragment).
