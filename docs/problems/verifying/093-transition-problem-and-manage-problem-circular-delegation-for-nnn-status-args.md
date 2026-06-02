# Problem 093: `/wr-itil:transition-problem` ↔ `/wr-itil:manage-problem` circular delegation for `<NNN> <status>` args

**Status**: Verification Pending
**Reported**: 2026-04-22
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: S
**WSJF**: excluded from ranking (Verification Pending — ADR-022)

## Description

The P071 phase-4 split of `/wr-itil:manage-problem <NNN> <status>` into its own named skill (`/wr-itil:transition-problem`) has an unresolved circular delegation. Neither skill hosts the Step 7 execution code; each SKILL.md's contract points to the other:

- **`/wr-itil:transition-problem` Step 4** says: "Delegate the transition to `/wr-itil:manage-problem <NNN> <status>` via the Skill tool. The delegated skill runs its Step 7 transition block."
- **`/wr-itil:manage-problem` Step 1 forwarder** says: "When arguments start with a three-digit ticket ID followed by a status word (`known-error`, `verifying`, or `close`), delegate to `/wr-itil:transition-problem` via the Skill tool … The forwarder does NOT re-implement the Step 7 transition logic locally — it invokes the Skill tool with `wr-itil:transition-problem` and returns the new skill's output verbatim."

A contract-literal agent invoking `/wr-itil:transition-problem 029 close` would:

1. Run transition-problem Step 4 → invoke `/wr-itil:manage-problem 029 close`.
2. Run manage-problem Step 1 → detect `<NNN> <status>`, delegate to `/wr-itil:transition-problem 029 close`.
3. Run transition-problem Step 4 → invoke manage-problem again.
4. …infinite loop.

Observed 2026-04-22 this session: during a run-retro Step 4a close of P029 + P059, I invoked `/wr-itil:transition-problem 029 close ...` via the Skill tool. The SKILL.md loaded and I saw the delegation instruction. I recognised the cycle and broke it by executing Step 7 inline (git mv + Edit + README refresh + commit) rather than re-invoking manage-problem. A less-cautious agent (or one that trusts the SKILL.md literally) would have recursed.

## Symptoms

- Any path `/wr-itil:transition-problem <NNN> <status>` → manage-problem → transition-problem → … has no terminal state if both contracts are followed literally.
- The same loop is reachable from the deprecated form `/wr-itil:manage-problem 029 close` (P071 forwarder) → transition-problem → manage-problem → …
- The agent must break the cycle with judgement (execute Step 7 inline), which itself is a skill-contract deviation logged in the retro summary.

## Workaround

When invoking either skill for a transition, break the cycle by executing the Step 7 block inline after reading the SKILL.md body. Both SKILL.md files describe the Step 7 block in detail (pre-flight checks, P063 external-root-cause detection, file rename, Status edit, P057 re-stage, P062 README refresh, ADR-014 commit), so an inline execution respects the contract in spirit even if the "delegate" instruction is technically bypassed.

## Impact Assessment

- **Who is affected**: Any user or agent invoking `/wr-itil:transition-problem <NNN> <status>` OR the deprecated `/wr-itil:manage-problem <NNN> <status>` form.
- **Frequency**: Every transition path invocation.
- **Severity**: Significant for contract-literal execution; currently masked by agent judgement.
- **Analytics**: The P071 split is still relatively fresh; no production session has exercised this path in a way that would infinite-loop visibly (my session is the first to hit it explicitly, and I broke the cycle).

## Root Cause Analysis

### Root cause — confirmed

The P071 phase-4 split moved the Step 7 block from manage-problem into transition-problem conceptually, but neither SKILL.md was updated to actually HOST the Step 7 execution code. Both point at each other. The split was a data-parameter-handling refactor; the authoritative-block relocation was deferred.

Two candidate fix directions:

1. **Make `/wr-itil:transition-problem` the authoritative Step 7 executor.** Copy the Step 7 block from manage-problem into transition-problem SKILL.md. manage-problem's forwarder stays as a deprecation notice; transition-problem executes Step 7 inline without re-invoking manage-problem. This matches the P071 split's intent — one skill per distinct user intent.

2. **Make `/wr-itil:manage-problem` the authoritative Step 7 executor, but only for non-forwarded invocations.** Add a "not-from-transition-problem" guard to manage-problem's Step 1 forwarder. transition-problem delegates to manage-problem; manage-problem runs Step 7 directly when invoked from transition-problem. This preserves the existing "manage-problem owns execution" contract but requires a provenance signal that the Skill tool doesn't currently provide.

Direction (1) is cleaner — avoids a provenance channel and matches the P071 split semantics. Direction (2) preserves ownership continuity but needs a new inter-skill signalling primitive.

### Investigation tasks

- [x] Investigate root cause (confirmed — both SKILL.md files delegate without hosting Step 7 code).
- [x] Pick the fix direction (Direction 1 per the P071 split intent — transition-problem hosts Step 7 inline; "copy, not move" per architect guidance so manage-problem's in-skill callers retain their inline block).
- [x] Implement: copy the Step 7 block (pre-flight checks + P063 detection + P057 re-stage + P062 refresh + ADR-014 commit) into `/wr-itil:transition-problem` SKILL.md as inline Steps 4–9. Update manage-problem Step 1 forwarder to be one-way (no round-trip clause).
- [x] Add contract-assertion coverage: inverted existing `transition-problem-contract.bats` test in place (architect-approved over adding a parallel `-no-manage-problem-roundtrip.bats` fixture — the split-file pattern would duplicate setup and split the audit trail). New assertion: SKILL.md body does NOT contain a delegation-imperative route back to manage-problem; positive assertion added for inline Step 7 mechanics (git mv, git add, Fix Released, commit).
- [x] ADR-010 amendment added: "Split-skill execution ownership" sub-rule codifies "copy, not move" for future splits so the same trap does not recur.
- [ ] Verify the fix by invoking `/wr-itil:transition-problem NNN close` in a fresh session and confirming no Skill-tool re-entry. (Deferred to user verification post-release — this is the explicit user-side confirmation step that moves the ticket Verification Pending → Closed.)

## Fix Strategy

- **Kind**: improve
- **Shape**: skill
- **Target files**: `packages/itil/skills/transition-problem/SKILL.md` (primary — absorb Step 7 block) + `packages/itil/skills/manage-problem/SKILL.md` (secondary — fix Step 1 forwarder to not round-trip).
- **Observed flaw**: Circular delegation between the two SKILL.md files; neither hosts the Step 7 execution code; contract-literal execution infinite-loops.
- **Edit summary**: Move the Step 7 transition block from manage-problem into transition-problem as an inline execution step. Update manage-problem's Step 1 forwarder to delegate to transition-problem one-way (no return trip).
- **Evidence**:
  1. transition-problem SKILL.md Step 4: "Delegate the transition to `/wr-itil:manage-problem <NNN> <status>` via the Skill tool."
  2. manage-problem SKILL.md Step 1 forwarder: "delegate to `/wr-itil:transition-problem` via the Skill tool … does NOT re-implement the Step 7 transition logic locally."
  3. In-session observation 2026-04-22: I recognised the cycle and broke it by executing Step 7 inline during the P029 + P059 closure path; flagged the deviation in the retro summary.

Chosen per run-retro Step 4b Stage 2 Option 2 (`Skill — improvement stub`). The fix is a bounded edit to two existing SKILL.md files — no new concept, no new ADR required (though ADR-010 amended may want a one-line clarification on "split skills own their own execution" to prevent the same trap on future splits).

## Fix Released

Deployed in `@windyroad/itil` (session 2026-04-22, AFK iteration 2, commit pending). Awaiting user verification.

**Fix summary**: `/wr-itil:transition-problem` now hosts the Step 7 transition block inline (pre-flight checks by destination, P063 external-root-cause detection with AFK fallback, `git mv` + Status edit + P057 staging re-stage, `## Fix Released` section write for `verifying`, P062 README refresh, ADR-014 commit through the risk-scorer pipeline gate). The skill no longer re-invokes `/wr-itil:manage-problem` — the round-trip clause was stripped from manage-problem's Step 1 forwarder paragraph (lines ~203-211). The in-skill Step 7 block on manage-problem stays intact for in-skill callers (Step 9b auto-transition, the Parked path, Step 9d closure) per the architect-approved "copy, not move" shape.

**Exercise evidence this session**:
- `npx bats packages/itil/skills/transition-problem/test/transition-problem-contract.bats` — 15/15 green after inversion (test 7 now asserts no round-trip; new test 8 asserts inline Step 7 mechanics are documented).
- `npm test` — 736/736 green (full bats suite, including all manage-problem contract fixtures — the transition-forwarder, review-forwarder, work-forwarder, list-forwarder, and external-root-cause-detection fixtures all pass with the forwarder-paragraph rewrite).
- This very commit is written through the authoritative transition-problem Step 7 block (the fix dogfoods itself): Open → Verification Pending rename + Status edit + `## Fix Released` write + P062 README refresh + ADR-014 commit.

**ADR-010 amended**: "Split-skill execution ownership" sub-rule added to the Amendments section (2026-04-22). Codifies "copy, not move" for future clean-split skills so the P093 trap does not recur.

**Verification path**: invoke `/wr-itil:transition-problem 093 close` (or any other ticket ID) in a fresh session. Expected behaviour: the skill reads its own SKILL.md, runs pre-flight + rename + edit + re-stage + README refresh + commit gate + commit, and emits the outcome report — without re-invoking `/wr-itil:manage-problem` via the Skill tool. A fresh session trace showing no Skill-tool call to `wr-itil:manage-problem` during the transition path confirms the fix.

## Related

- **P071** (Argument-based skill subcommands are not discoverable in Claude Code autocomplete) — originating ticket for the split. This ticket is a post-split follow-up.
- **ADR-010 amended** (Skill Granularity section) — governing decision for the split. May benefit from a clarifying line about split skills hosting their own execution code.
- **ADR-022** — Verification Pending lifecycle; Known Error → Verification Pending and Verification Pending → Closed are the most-frequently-exercised transitions this bug affects.
- **P057** — staging-trap rule that any Step 7 execution must honour (applies regardless of which skill hosts the block).
- **P062** — README.md refresh on every transition; same rule applies (applies regardless of which skill hosts the block).
- **P094** — sibling ticket this session about README.md refresh on ticket *creation* (not covered by P062). Distinct failure mode.
