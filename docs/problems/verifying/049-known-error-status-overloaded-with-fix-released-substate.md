# Problem 049: Known Error status is overloaded — "fix released, awaiting verification" deserves its own explicit status

**Status**: Verification Pending
**Reported**: 2026-04-19
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: M (re-rated L for the full scope including migration; see iter 5 plan)
**WSJF**: 0 (excluded from dev-work ranking — per ADR-022)

## Fix Released

Shipped 2026-04-19 (AFK iter 5, this commit) — the SKILL.md documentation contract half of ADR-022. Migration of existing `.known-error.md` files follows in a separate commit per ADR-022 Scope.

- **`packages/itil/skills/manage-problem/SKILL.md`**:
  - Lifecycle table gains a `Verification Pending | .verifying.md | Fix released, awaiting user verification (ADR-022)` row between Known Error and Parked.
  - WSJF multiplier table gains `Verification Pending | 0 (excluded)` and `Parked | 0 (excluded)` rows with rationale (user-side work should not mix into dev-work ranking).
  - Closing-problems section rewritten: fix-release transition is Known Error → Verification Pending (`git mv` to `.verifying.md` + Status field update + `## Fix Released` section, all one commit per ADR-014). Closed is the user-confirmed Verification Pending → Closed transition.
  - Step 7 adds explicit "Known Error → Verification Pending" and "Verification Pending → Closed" transition blocks with git mv commands.
  - Step 9b explicitly skips `.verifying.md` and `.parked.md` files in WSJF loop.
  - Step 9c presents a dedicated "Verification Queue" section (ranked by release age, oldest first) parallel to the main dev-work ranking.
  - Step 9d targets `docs/problems/*.verifying.md` via glob; closure transitions `git mv` from `.verifying.md` to `.closed.md`.
  - Step 9e README template gains a "Verification Queue" section alongside WSJF Rankings, Parked.
  - Commit-convention list documents the Verification Pending transition.
- **`packages/itil/skills/work-problems/SKILL.md`**:
  - Step 1 backlog scan excludes `.verifying.md` (per ADR-022).
  - Step 4 classifier row "Known Error with `## Fix Released` → Skip" replaced with "`.verifying.md` → Skip" (suffix-based, no file-body scan).
- **`packages/itil/skills/manage-incident/SKILL.md`**:
  - Step 9 linked-problem close gating accepts `.verifying.md` alongside `.known-error.md` and `.closed.md` (ADR-022: Verification Pending is strictly stronger than Known Error for the Restored → Closed handoff because the fix has actually shipped).
- **`docs/problems/README.md`**:
  - Former "Known Errors (Fix Released — pending verification)" shadow table replaced with a "Verification Queue" section citing ADR-022.

Tests — `packages/itil/skills/manage-problem/test/manage-problem-verification-pending.bats` (new, 11 assertions, RED→GREEN this iteration):

- ADR-022 exists; three SKILL.md files exist (preconditions).
- Lifecycle table carries Verification Pending + `.verifying.md`.
- WSJF multiplier table documents the exclusion.
- Known Error → Verification Pending transition documented.
- Review step 9 targets `.verifying.md` via glob.
- Review step 9 has a Verification Queue section.
- SKILL.md cites ADR-022.
- work-problems and manage-incident reference `.verifying.md`.
- README.md template has a Verification Queue section.

Full project test surface: 264 tests, 0 failures (was 253/0; +11 from this iteration).

**What's deferred** (separate follow-up commit in this session, per ADR-022 Scope): migration of the 16 existing `.known-error.md` files that carry `## Fix Released` sections → `.verifying.md`. Each rename preserves git history via rename detection. Status field flipped from "Known Error" to "Verification Pending" in each. That commit will also update `docs/problems/README.md`'s Verification Queue table to cite the file glob rather than the hand-maintained list.

Architecture + JTBD reviews: both PASS. ADR-022 fully pre-approves this scope (architect advisory). No new ADR needed. ADR-022 itself stays `.proposed.md` until end-to-end validation over the next few session cycles (architect recommendation). ADR-005 Permitted Exception covers the structural bats tests. JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201 all aligned.

Awaiting user verification: next `manage-problem review` invocation should present a dedicated Verification Queue section; any fix that lands should transition the ticket from `.known-error.md` to `.verifying.md`; `manage-incident` close should accept `.verifying.md` linked-problem states.

## Description

The current problem lifecycle treats "Known Error" as a single status covering two distinct sub-states:

1. **Root cause confirmed, fix NOT yet implemented.** Work is required on the dev side to implement, test, and release the fix.
2. **Fix released, awaiting user verification.** Work is required on the user side to observe the fix in production and explicitly confirm it.

The skill signals the second sub-state by appending a `## Fix Released` section inside the `.known-error.md` file. The status field and filename suffix do not change. This forces every tool, orchestrator, and reader (human or agent) to open each file's body to figure out which sub-state it is in.

Empirical evidence (2026-04-19 snapshot of this repo): **16 of 16** `.known-error.md` files in `docs/problems/` have a `## Fix Released` section. In practice the "Known Error = confirmed-but-not-fixed" sub-state is effectively never the resting state — tickets pass through it quickly and then linger indefinitely in the "fix released, awaiting verification" sub-state. The overload is not theoretical; it is universal in this project's backlog today.

Consequences:

- `docs/problems/README.md` ranking table shows `Status: Known Error` for both sub-states, so WSJF output doesn't distinguish "work on this next" from "user: please verify".
- `manage-problem review` step 9d has to open every `.known-error.md` file to check for a Fix Released section before it can prompt the user.
- AFK orchestrators (`work-problems`) that try to skip Fix Released tickets via the classifier table (`Known Error with ## Fix Released | Skip`) must also open each file, which defeats the point of the README fast-path.
- Related ticket P048 (detection of verification candidates) inherits this overload — its fix surface is complicated by having to re-derive the sub-state that could have been a first-class field.
- Ranking WSJF for a ticket with `## Fix Released` is ambiguous: its effort is already spent (dev-side), its remaining work is user-side verification, but the WSJF formula still scores it as a "Known Error × effort" item — distorting the backlog prioritisation.

Proposed: introduce a new **explicit status** between Known Error and Closed to capture the "fix released, awaiting verification" sub-state, with its own file suffix and its own ranking semantics.

## Symptoms

- Readers (humans and agents) cannot tell from the README ranking table which Known Error tickets are truly awaiting dev work vs awaiting user verification.
- `grep -L "^## Fix Released" docs/problems/*.known-error.md` returned zero files on 2026-04-19 — the "root cause confirmed, not yet fixed" sub-state is empirically vacant; all Known Error tickets in practice mean "Fix Released".
- Step 9d and the `work-problems` classifier table both have to scan file bodies to distinguish sub-states.
- WSJF scoring for Fix-Released-and-waiting items mis-weights backlog priority — their remaining work is user-side verification, not dev effort, so including them at a high Known Error multiplier (×2.0) inflates the top of the ranking and pushes real-dev-work items down.
- The `## Known Errors (Fix Released — pending verification)` separate table in `docs/problems/README.md` is a workaround for the overload — an implicit "shadow status" maintained by hand.

## Workaround

- The skill appends a `## Fix Released` section to the body of each Known Error file when the fix lands.
- The README has a separate `## Known Errors (Fix Released — pending verification)` table maintained by hand.
- Readers mentally apply the rule: "if the file body contains `## Fix Released`, treat it as Verification Pending". The rule is not encoded in the status or filename.

None of these are systemic. Every consumer of the problem data (skill code, README renderers, orchestrators, the human) repeats the same file-body check independently.

## Impact Assessment

- **Who is affected**: solo-developer persona (JTBD-001, JTBD-006) — ranking output ambiguity; plugin-developer persona (JTBD-101) — anyone building tooling against `docs/problems/` has to encode the file-body-scan rule to distinguish sub-states, and any drift between tools creates inconsistent reports.
- **Frequency**: every read of the problem backlog (review, work selection, README render). With 16 Known Error files today, essentially every interaction with the backlog hits the overload.
- **Severity**: Minor — no functional breakage. The cost is cognitive, structural, and prioritisation-accuracy; not operational.
- **Analytics**: 2026-04-19 snapshot — 16/16 `.known-error.md` files contain `## Fix Released`. Zero Known Error tickets were in the "awaiting-implementation" sub-state today.

## Root Cause Analysis

### Structural: one status, two meanings

`packages/itil/skills/manage-problem/SKILL.md` defines the lifecycle table as:

| Status | File suffix | Meaning |
|--------|-----------|---------|
| Open | `.open.md` | Reported, under investigation |
| Known Error | `.known-error.md` | Root cause confirmed, fix path clear |
| Parked | `.parked.md` | Blocked on upstream or suspended |
| Closed | `.closed.md` | Fix verified in production |

The step-by-step closure workflow is "when the fix is released, add a `## Fix Released` section but keep as `.known-error.md`". That sentence is the entire disambiguation mechanism — it lives in prose inside the SKILL.md documentation, not in the data model.

### Structural: the WSJF model has no distinct multiplier for awaiting-verification

`manage-problem` WSJF uses two status multipliers: Open (1.0) and Known Error (2.0). A ticket whose remaining work is user-side verification should arguably have a different multiplier (user-facing action queue ≠ dev-facing work queue). Today both sub-states of Known Error share ×2.0, so the ranking doesn't reflect where the work lives.

### Candidate fixes

1. **Introduce a new status "Verification Pending"** (or similarly-named) with file suffix `.verifying.md` (or `.fix-released.md` / `.pending-verification.md`). The transition is automatic when a fix is released: the skill renames the file from `.known-error.md` → `.verifying.md` and writes the `## Fix Released` section. The README and all tools can distinguish sub-states by glob alone. Addresses the core overload.
2. **Adjust the WSJF status multiplier** for the new status. Options: 0.0 (exclude from dev-work ranking, list in a separate "awaiting verification" queue), 0.5 (count but down-weight since the work isn't dev effort), or keep at 2.0 if the multiplier is intended to capture "how close to Closed" rather than "how much dev work remains".
3. **Parked-style exclusion**: treat `.verifying.md` files like `.parked.md` — exclude from the main WSJF ranking, list in a dedicated section of `docs/problems/README.md`. Keeps the dev-work ranking clean.
4. **Migrate existing files**: rename all 16 existing `.known-error.md` files that carry a `## Fix Released` section to the new suffix, in a single batch commit. Zero net information change — just making the data model match the structural state.
5. **Update downstream readers**: `work-problems` classifier table, `manage-problem review` step 9c/9d, README template, any bats tests that grep for specific suffixes. Small, mechanical set of edits.

Candidates 1 + 3 + 4 + 5 form a minimum viable fix. Candidate 2 is a standalone decision that pairs naturally with 1.

### Interaction with related tickets

- **P048** (manage-problem does not surface Fix Released tickets as verification candidates) — P049 simplifies P048's fix surface substantially. Instead of "grep each file body for Fix Released and then filter", the detection layer becomes "glob `*.verifying.md` and sort". Both tickets should land together or P049 first; P048's heuristics (exercise evidence, age, likely-verified flag) still apply on top of the cleaner status.
- **P047** (WSJF effort buckets coarse and not re-rated) — sibling "skill's static model doesn't track reality" ticket. P049 is the same theme at the status-dimension level: the data model is coarser than the actual lifecycle.
- **P030** (closed) — fixed the verification prompt content. P049 fixes the discovery surface P030's prompt fires from.

### Naming decision (2026-04-19, user)

**Resolved**: status name = `Verification Pending`; file suffix = `.verifying.md`.

Rationale captured during the AFK loop wrap-up: clear intent, concise suffix, round-trips cleanly through `ls`. The ADR that lands with the fix should cite this decision rather than re-open the naming discussion.

Rejected options (for posterity):
- "Fix Released" (.fix-released.md) — matches current informal phrase but risks confusion with the body-section marker.
- "Awaiting Verification" (.awaiting-verification.md) — longer suffix without clear win over `.verifying.md`.
- "Staged for Closure" — too indirect about what's pending.

### Investigation Tasks

- [ ] Architect review: this change touches the problem-file data model — a core contract between `manage-problem`, `manage-incident`, `work-problems`, and any downstream renderer. Expect a new ADR to capture the status addition and migration plan. Likely path: `docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md`.
- [ ] Decide the status name and file suffix in the ADR.
- [ ] Decide WSJF status-multiplier semantics for the new status (candidate 2 above).
- [ ] Enumerate every SKILL.md / README / bats reference to `.known-error.md` or "Known Error" status that needs updating. Non-exhaustive list: `packages/itil/skills/manage-problem/SKILL.md` (lifecycle table, steps 7, 9b step 10 auto-transition, 9c, 9d, closing workflow), `packages/itil/skills/work-problems/SKILL.md` (classifier table, step 3 tie-break), `packages/itil/skills/manage-incident/SKILL.md` (linked-problem gating), `docs/problems/README.md` template + existing "Known Errors (Fix Released)" table.
- [ ] Draft migration script: `git mv` each `.known-error.md` with `## Fix Released` to the new suffix, preserving git history via rename detection. Verify on a branch first.
- [ ] Update bats tests to reference the new suffix where applicable; add new tests asserting the lifecycle-table and the WSJF multiplier for the new status.
- [ ] Coordinate with P048: after P049 ships, P048's fix can drop the file-body scan and use the suffix-based detection. Update P048's fix strategy accordingly.
- [ ] Consider whether `manage-incident` gains an analogous sub-state. Incidents have Investigating / Mitigating / Restored / Closed (ADR-011). "Restored" arguably has the same user-verification lag as Known Error here — but incident closure rules already force a linked-problem status check, which sidesteps the issue. Document the deliberate non-parallel.

## Related

- `packages/itil/skills/manage-problem/SKILL.md` — primary fix target (lifecycle table, transition rules, WSJF, step 9d).
- `packages/itil/skills/work-problems/SKILL.md` — classifier table "Known Error with `## Fix Released` | Skip" becomes a glob instead.
- `packages/itil/skills/manage-incident/SKILL.md` — linked-problem gating rule (step 9) references `.known-error.md` suffix; needs updating.
- `docs/problems/README.md` — ranking table + "Known Errors (Fix Released — pending verification)" shadow table; both simplify under the new status.
- P048: `docs/problems/048-manage-problem-does-not-detect-verification-candidates.open.md` — complementary; P049 simplifies P048's implementation surface.
- P047: `docs/problems/047-wsjf-effort-bucket-accuracy-gaps.open.md` — sibling theme (skill's static model doesn't track reality).
- P030: `docs/problems/030-manage-problem-verification-prompts-lack-fix-summary.closed.md` — predecessor; fixed the verification prompt content, not the discovery surface.
- ADR-011: `docs/decisions/011-manage-incident-skill.proposed.md` — incident lifecycle precedent; informs the non-parallel decision.
- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — governance commit rules apply to the migration commits and ADR authoring.
- Anticipated: `docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md` — the ADR that would land with the fix.
