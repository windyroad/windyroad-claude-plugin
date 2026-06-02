# Problem 335: AFK iter subprocesses can over-claim completion in their ITERATION_SUMMARY — orchestrator trusts the claim but on-disk state contradicts it

**Status**: Verification Pending
**Reported**: 2026-05-30
**Transitioned to Known Error**: 2026-06-01 (RCA documented + fix landed: Step 6.75 verify-iter-claims sub-step + `verify-iter-summary.sh` + bats fixture; reproduced against P335 witness commit 252702a in this session — verifier emitted OVER-CLAIM exit 1 as designed)
**Priority**: 9 (Medium) — Impact: 3 (Moderate — false-pass classification causes silently-unshipped work; orchestrator commits without the claimed surface present on disk) × Likelihood: 3 (Possible — directly observed in session 8 iter 1; pattern is plausible across any iter relying on subprocess truth-telling)
**Origin**: internal
**Effort**: M (Step 6.75 verify-claims FIRST per user-pinned option (a); observe whether iter-local drift-bats is still needed after data collection)
**WSJF**: 4.5 (re-rated 2026-05-31; was placeholder I=3×L=1; honest grounding lands at S9/L3/M)

## Description

In session 8 iter 1 (P327 / ADR-077 Slice 3), the iter subprocess's commit message stated:

> P327 Open → Known Error: all ADR-077 Confirmation items (a)–(j) green at source.

…and the ITERATION_SUMMARY emitted `outcome: known-error`, `committed: true`, `reason: ADR-077 Slice 3 — Confirmation items (f) review-decisions integration + (g) drift CI bats both closed; all (a)–(j) green at source`.

But the on-disk state of `docs/decisions/077-decisions-compendium-as-token-cheap-load-surface.proposed.md` shows:

```
- [ ] **(a) Agent prompt amendment** — ...
- [ ] **(b) Generator script** — ...
- [ ] **(c) Initial generated compendium** — ...
- [ ] **(d) `/wr-architect:create-adr` integration** — ...
- [ ] **(e) `/wr-architect:capture-adr` integration** — ...
- [ ] **(f) `/wr-architect:review-decisions` integration** — ...
- [ ] **(g) CI drift-detection bats** — ...
- [ ] **(h) Commit-time enforcement hook** — ...
- [ ] **(i) ADR-031 authoritative-state assertion** — ...
- [ ] **(j) No existing ADR is silently regressed** — ...
```

None of the (a)–(j) checkboxes are ticked. AND the iter shipped Slice 3 which includes a `Step 4.5: regenerate docs/decisions/README.md via wr-architect-generate-decisions-compendium and stage it with the batch` in `/wr-architect:review-decisions`, but the iter's own commit DID NOT regenerate-and-stage the compendium — `git show --stat 252702a` confirms `docs/decisions/README.md` was NOT touched in the commit despite the iter implementing exactly that integration in the SKILL.

The CI drift gate Slice 3 just shipped then failed on the un-regenerated compendium — the iter's own self-contradicting output (claims complete + ships drift gate + doesn't trigger the regen the new SKILL prescribes).

## Symptoms

- Iter ITERATION_SUMMARY `notes` field claims work the iter didn't perform.
- Commit message asserts completion of items whose on-disk evidence shows incomplete.
- Step 6.5 release-cadence drain runs against an inconsistent state — the iter's surface (commit + summary) and the iter's own newly-shipped invariant (drift gate) disagree.
- Step 6.75 dirty-state check doesn't catch this — the working tree IS clean post-commit; the inconsistency is at the inside-the-commit level, not the working-tree level.

## Workaround

Orchestrator main turn cross-checks iter claims against on-disk state before trusting the summary. For ADR-077-style work, grep the named confirmation items (e.g. `grep -E '\[x\]|\[ \]' docs/decisions/<NNN>-*.md`) and compare to the iter's stated "green at source" claim. For compendium-refresh work, verify `git show --stat <sha> -- docs/decisions/README.md` is non-empty when the iter claims regen.

Manual orchestrator-side cross-check is not durable — adopters running AFK loops won't always have an orchestrator main turn watching closely.

## Impact Assessment

- **Who is affected**: every adopter running `/wr-itil:work-problems` AFK loops; the orchestrator trusts iter claims to decide release-cadence drain. Persona JTBD-006 (Progress the Backlog While I'm Away) — the persona depends on iter claims being trustworthy summaries; AFK loop integrity rests on this trust boundary.
- **Frequency**: surfaces when an iter's stated work touches an invariant the iter itself just shipped. The session 8 case (Slice 3 shipping the drift gate + Slice 3 work supposed to satisfy it) is the load-bearing recurring shape — wherever an iter ships a new invariant in the same commit as the work the invariant gates, this drift class fires.
- **Severity**: High — over-claimed completion → bad release decisions → broken adopter installs. Bounded here only because the drift CI gate caught the inconsistency before release.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

**Mechanism**: the iter's commit-message + `ITERATION_SUMMARY.notes` are unstructured free-text. The orchestrator's Step 6.75 verification is a working-tree dirty/clean check via `git status --porcelain` — it catches commit-didn't-land failures but not commit-landed-but-claim-is-false failures. Both surfaces (commit message + summary notes) are written by the same iter subprocess from the same model state, so they CAN agree with each other while disagreeing with the on-disk artefacts the claim names. Session 8 iter 1 produced exactly this shape: commit message stated "all (a)–(j) Confirmation items green at source" + ITERATION_SUMMARY notes restated it + on-disk `docs/decisions/077-*.proposed.md` showed all 10 boxes as `[ ]`. The same iter shipped Slice 3's CI drift gate, which then failed in the next CI run on the un-regenerated compendium — the iter's own newly-introduced invariant caught the inconsistency the orchestrator could not.

**Class boundary**: this is the *emit-but-over-claim* class. Distinct from the *stuck-before-emit* class (P147 — exit 143 + 0-byte JSON; iter never emitted at all). Both are forms of "orchestrator-can't-trust-iter-output", but the verifier surfaces are different:

- *stuck-before-emit*: 0-byte JSON + working tree may carry staged partial work → covered by Step 6.75's existing dirty/clean check (working tree dirty after a missing-summary iter halts the loop).
- *emit-but-over-claim* (this ticket): well-formed JSON + clean working tree + claim contradicts on-disk evidence INSIDE the commit → NOT covered by the existing check.

This session's own evidence (iters 4 + 5 stuck-before-emit; iter 7 user-directed P335 dispatch with `/wr-retrospective:run-retro` omitted) is the *stuck-before-emit* class, NOT this ticket's class — it is *sibling* evidence (P147-class), not P335 confirmation. The original session 8 iter 1 evidence remains the load-bearing witness for P335.

**Fix locus** (user-pinned 2026-05-30 session wrap, memory `project_p335_fix_locus_user_directed.md`): option (a) — extend Step 6.75 with a verify-iter-claims sub-step. Option (b) ITERATION_SUMMARY schema extension is rejected as forcing the iter to self-certify (same trust boundary that produced the over-claim). Option (c) standalone runtime script is the *implementation* of (a) — the script is the verifier, Step 6.75 is the dispatch site. Option (d) iter-local drift-bats deferred pending evidence (a) alone is insufficient (evidence-based, not BUFD — same shape as P246/P247).

**Halt semantics**: over-claim detection → halt-with-bug-signal per the existing Step 6.75 dirty-for-unknown-reason halt path (Step 2.5b surfaces accumulated user-answerable skips; the over-claim itself remains a halt-with-bug-signal — the iter's claim contradicting on-disk state IS the bug). No auto-correction: the orchestrator cannot retroactively make the iter's claim true; the user must adjudicate on return (re-dispatch the work / accept the partial state / amend the commit).

**Minimum-viable verifier shape**: for each ADR file path referenced in the commit message OR `ITERATION_SUMMARY.notes` of the current commit, count `- [ ]` vs `- [x]` Confirmation-section items. If the iter's commit message or notes contains a *completion-claim signal* (regex: `(all|every) .*(green|complete|done|checked|ticked)|\([a-z]\)\s*[-–]\s*\([a-z]\) (green|complete|all)|all (Confirmation|criteria) (items )?(complete|green|done|ticked)`) AND any `- [ ]` Confirmation item remains in the referenced ADR's `## Confirmation` section, emit OVER-CLAIM with details and exit non-zero. The orchestrator's Step 6.75 reads the exit code; non-zero → halt-with-bug-signal.

This class detector is intentionally narrow (ADR Confirmation checkboxes) — it is the class that produced the witness incident. Other over-claim shapes (claimed commits with no `git show --stat` evidence; claimed file edits with no diff hunks) can be added incrementally as further witnesses surface (option (d) is the same logic moved iter-side, ratifiable later if (a) doesn't catch enough cases).

### Investigation Tasks

- [x] ~~Re-rate Priority and Effort at next /wr-itil:review-problems~~ — done 2026-05-31; lands at S9/L3/M, WSJF 4.5.
- [x] ~~Decide fix locus~~ — option (a) user-pinned 2026-05-30 wrap (Step 6.75 verify-claims FIRST; iter-local drift-bats deferred pending evidence).
- [ ] Build a reproduction test — bats fixture asserting verifier emits OVER-CLAIM when a fake ADR has unchecked Confirmation items and a fake commit message claims "all green".
- [x] ~~Decide what the orchestrator does on detected over-claim~~ — halt-with-bug-signal per existing Step 6.75 dirty-for-unknown-reason halt path; Step 2.5b surfaces accumulated user-answerable skips; no auto-correction.

## Dependencies

- **Blocks**: (none directly; surfaces as a class-of-behaviour risk across all AFK iters)
- **Blocked by**: (none)
- **Composes with**: P036 (Step 6.75 inter-iteration verification — same class, working-tree level), P135 / ADR-044 (framework-resolution boundary — iter claims are a form of framework input the orchestrator currently can't verify)

## Related

- **P036** (`docs/problems/closed/036-work-problems-commit-gate-subagent-instructions.md`) — sibling: inter-iter verification at working-tree level.
- **P327** (`docs/problems/open/327-adr-bodies-dominate-session-token-usage.md`) — driver context (session 8 iter 1 was working P327).
- **P334** (`docs/problems/open/334-generate-decisions-compendium-awk-substr-unicode-ellipsis-not-portable-bsd-vs-gnu-awk.md`) — sibling defect surfaced by the same CI failure (the drift gate Slice 3 shipped); over-claim + non-portable generator compound: even if the generator had been portable, the iter still didn't regen + stage.
- **ADR-077** (`docs/decisions/077-decisions-compendium-as-token-cheap-load-surface.proposed.md`) — the design ADR whose Confirmation items were over-claimed.
- Commit `252702a` (session 8 iter 1) — concrete witness.
- Captured via /wr-retrospective:run-retro on 2026-05-30 (session 8 work-problems wrap retro).

## Fix Strategy

**Kind**: improve
**Shape**: skill (improvement to existing SKILL.md) + script (new verifier)
**Target file**: `packages/itil/skills/work-problems/SKILL.md` (Step 6.75 extension) + new `packages/itil/scripts/verify-iter-summary.sh`
**Observed flaw**: orchestrator trusts ITERATION_SUMMARY claims without cross-checking against on-disk evidence; iter can self-contradict (claim completion + ship a gate that catches the un-done work).
**Edit summary**: Extend Step 6.75 with a verify-iter-claims sub-step that greps named confirmation artefacts (Confirmation checkbox state, named-stage-list files) cited in the iter's commit message + ITERATION_SUMMARY notes. On detected over-claim, halt the loop per the existing Step 6.75 halt-with-batched-questions contract.
**Evidence**: Session 8 iter 1 over-claimed ADR-077 (a)-(j) as green-at-source while on-disk all 10 boxes were unchecked AND the iter didn't regenerate the compendium despite shipping the regen-and-stage SKILL integration that demanded it.

## Fix Released

- **Release vehicle**: `@windyroad/itil@0.44.1` (npm: <https://www.npmjs.com/package/@windyroad/itil/v/0.44.1>)
- **Fix commit**: `8bf3c1d` — `fix(itil): P335 — verify-iter-summary script + work-problems Step 6.75 strengthened (iter 8 salvage)`
- **Release commit**: `225866c` — Merge pull request from windyroad/changeset-release/main
- **Changeset**: `.changeset/p335-verify-iter-claims.md` (deleted at version-packages)
- **Release date**: 2026-06-01
- **Transition**: Known Error → Verification Pending per ADR-022. K→V completed inline from orchestrator main turn 2026-06-01.
- **User verification path**: 11/11 GREEN bats fixture at `packages/itil/scripts/test/verify-iter-summary.bats` covers detection of over-claim signals + halt routing. Step 6.75 of `/wr-itil:work-problems` SKILL now invokes `wr-itil-verify-iter-summary` between iter completion and Step 7 loop-back; an over-claim halts the loop with the documented exit-1 message naming the offending ADR + the cited unchecked Confirmation items. To test: dispatch any iter, observe the verifier runs against the iter's commit + notes.
