# Problem 125: P057 staging-trap recurs despite documentation — hook-level enforcement candidate

**Status**: Verification Pending
**Reported**: 2026-04-26
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M — new `PreToolUse:Bash` hook in `packages/itil/hooks/` matching `git commit` invocations (architect verdict: deterministic per-invocation `git diff` cost is bounded; preferred over `PostToolUse:Bash + session marker` per P125 Investigation Tasks lean). Detects the trap-shape: a staged rename whose `<new>` path also appears as a working-tree modification. On detect, fail-loud with the P057 rule citation and the literal `git add <B>` recovery command. Composes with P119's create-gate hook pattern (PreToolUse:Write surface) — same `packages/itil/hooks/` directory and helper-pair shape (sibling `lib/staging-detect.sh`).
**WSJF**: (9 × 1.0) / 2 = **4.5** (excluded from dev-work ranking on transition to Verification Pending per ADR-022)

> Surfaced 2026-04-26 P122 retro session: the assistant fell into the P057 staging-trap during the design-question batch — `git mv docs/problems/115-*.open.md → 115-*.parked.md` followed by `Edit` to update Status and add the Parked section, then a batch commit that produced "1 file changed, 0 insertions(+), 0 deletions(-)" with only the rename captured. Recovery required `git commit --amend` after re-staging the missed content. P057 is `.closed.md` (the documentation-fix shipped 2026-04-22) but the rule itself is human-error-prone in long batch sequences. The Critical Points section of `docs/briefing/README.md` carries the rule; the briefing's `agent-interaction-patterns.md` line 8 carries the rule with explicit observation history. Despite all this, the trap recurred. Documentation alone is not preventing it.

## Description

The P057 staging-trap rule is well-known and well-documented:

- `docs/briefing/README.md` Critical Points line 6: *"`git mv` + `Edit` + `git add` requires re-stage after the Edit"*.
- `docs/briefing/agent-interaction-patterns.md` line 8: same rule with observation history.
- `packages/itil/skills/manage-problem/SKILL.md` Step 7 carries explicit `git add` callouts after every `git mv` block.

The rule is correct. The agent reads it. The agent acknowledges it in retros. And yet the trap recurs in long batch operations — when 5+ tickets are being staged and the agent's attention is on the batch composition rather than per-file staging integrity.

This is a **documentation-doesn't-prevent-recurrence** pattern. The fix is a hook that turns the trap-shape into a pre-commit denial with the recovery command inline, removing reliance on the agent's attention.

## Symptoms

- Long multi-file commit batches that include both `git mv`-renamed files AND post-rename Edits land with "X file changed" where X is less than the total file count, missing the Edit content on the renamed file(s).
- The trap is silent at commit time — no error, no warning. The next session sees the orphaned content as uncommitted modifications and may re-stage them as a follow-up commit (acceptable but split history) or include them in the next unrelated commit (audit-trail corruption — what P057 originally identified).
- Recovery via `git commit --amend` works when the trap is caught immediately; if the trap is missed and a subsequent commit lands, the orphaned content rides into the wrong commit.

## Workaround

After every `git mv <A> <B>` followed by any `Edit` to `<B>`, manually run `git add <B>` before the next commit. Or use `git add -u` as a catch-all after all edits (rebuilds the staging index from working-tree modifications). Both rely on agent attention — which is exactly what fails in batches.

## Impact Assessment

- **Who is affected**: every agent or human running multi-file batch commits that include rename-then-edit sequences. Empirically observed: across 4+ AFK iterations in this repo over the past month.
- **Frequency**: Likely — recurs in batch operations involving 3+ file changes with at least one rename. Less likely in single-file commits.
- **Severity**: Moderate — the trap can corrupt commit boundaries (P057's original concern: edits leaking into the next commit). Recovery is mechanical (`--amend` if caught immediately) but the failure is silent so it can go unnoticed.
- **Likelihood**: Likely — observed multiple times despite documentation. Documentation alone is not sufficient prevention.
- **Analytics**: 2026-04-26 session: trap fired during the P122 design-question batch (committed e7564ff with rename-only; amended to b8f3a01 after detection). Prior recurrences: each AFK iter retro since P057's original closure mentions the rule was exercised "without leak" — but this session shows leaks DO still happen in long batches.

## Root Cause Analysis

### Structural

`git mv` stages the rename atomically. The Edit tool modifies the file content but does NOT update the staging index — that's git's normal behaviour for Edit operations on already-staged files. The agent's mental model is "I edited the file, so the change is staged" but git's actual model is "the rename was staged; the post-rename content edit is a working-tree modification that needs separate staging".

P057 closed with documentation-only fixes. The documentation IS clear. The failure mode is not knowledge-gap; it's attention-gap during batch operations.

### Hook-shape candidate

A `PostToolUse:Bash` hook with the matcher `"Bash"` could:

1. Track `git mv <A> <B>` invocations within the session (e.g., write a session-scoped marker file `/tmp/wr-itil-pending-stage-<UUID>` listing files that were `git mv`-d).
2. Track subsequent `Edit` tool invocations on those files (tracked via PostToolUse:Edit fire) — clear the file from the pending list when re-staged via `git add <B>`.
3. On `git commit` invocation (PostToolUse:Bash matching commit), check the pending list. If non-empty, fail-loud with the rule + `git add` recovery command.

**Alternative hook-shape**: `PreToolUse:Bash` matching `git commit` that runs `git diff` on staged + working tree, detects rename-then-modify pattern (file appears in `git diff --staged` as renamed AND in `git diff` as modified), denies with the recovery command.

The PreToolUse variant is more deterministic (doesn't rely on session-state tracking) but more expensive (runs `git diff` on every commit). The PostToolUse-with-marker variant is cheaper but more fragile.

### Investigation Tasks

- [x] Confirm the hook surface — PreToolUse:Bash on commit (deterministic, expensive) vs PostToolUse:Bash + session marker (fragile, cheap). Lean: PreToolUse — the cost of one `git diff` per commit is bounded. **Resolved**: PreToolUse:Bash matching `git commit` substring; two `git diff` invocations per check, ~10-50ms on this repo's working tree.
- [x] Decide the deny-vs-warn behaviour. Lean: deny — the trap is silent enough that warnings get ignored. Deny forces explicit re-stage or `git add -u` before the commit lands. **Resolved**: deny with mechanical recovery (`git add <new>`) inline per ADR-013 Rule 1.
- [x] Compose with `wr-itil:hooks/lib/` shared-helper directory — likely a new `lib/staging-detect.sh` exporting `detect_p057_trap()` for reuse. **Resolved**: new `packages/itil/hooks/lib/staging-detect.sh` ships with this fix; mirrors `lib/create-gate.sh` precedent (P119) for the deny + helper-pair shape.
- [x] Add behavioural bats: trap detected (fail-loud), trap recovered via re-stage (allow), no rename in batch (allow), rename without subsequent edit (allow), rename with subsequent edit AND re-stage (allow). **Resolved**: 10 behavioural assertions in `packages/itil/hooks/test/p057-staging-trap-detect.bats` (5 trap/allow paths from the ticket spec + 5 supporting: non-Bash tool / non-commit Bash / empty JSON / deny-message contract / deny-message byte budget).
- [x] Update `docs/briefing/agent-interaction-patterns.md` line 8 to cite the new hook + name the recovery as "the hook fails the commit; run `git add <B>` and retry". **Resolved**: line 8 now cites `packages/itil/hooks/p057-staging-trap-detect.sh` as the enforcement layer with the `git diff --staged --name-status` + `git diff --name-only` detection logic and the `git add <new>` recovery shape.

### Fix Strategy

**Kind**: create

**Shape**: hook (new) + new shared helper

**Target files**:
- `packages/itil/hooks/p057-staging-trap-detect.sh` — NEW. PreToolUse:Bash hook matching `git commit` invocations.
- `packages/itil/hooks/lib/staging-detect.sh` — NEW shared helper. Function `detect_p057_trap()` returns 0 (no trap) / 1 (trap detected) and emits the recovery command on stderr when 1.
- `packages/itil/hooks/test/p057-staging-trap-detect.bats` — NEW. 5-7 behavioural assertions per ADR-037.
- `packages/itil/hooks/hooks.json` — register the new hook.
- `docs/briefing/agent-interaction-patterns.md` — update line 8 with hook citation.
- `.changeset/wr-itil-p125-*.md` — patch entry.

**Out of scope**: extending detection to non-git-mv staging traps (e.g. add+edit-without-add). Worktree-aware detection (P115 is parked; no need). Cross-language hooks (this is a Bash + git-only concern).

## Fix Released

`@windyroad/itil` patch via `.changeset/wr-itil-p125-staging-trap-hook.md`. AFK iter, single commit per ADR-014.

- New `packages/itil/hooks/p057-staging-trap-detect.sh` — `PreToolUse:Bash` hook matching `git commit` invocations.
- New `packages/itil/hooks/lib/staging-detect.sh::detect_p057_trap` — shared helper running `git diff --staged --name-status` + `git diff --name-only`; if any staged rename's `<new>` path also appears in the working-tree modification list, returns 1 (caller denies); otherwise 0 (allow). Fail-open on non-git working tree, parse error, or missing index — mirrors `lib/create-gate.sh` precedent (P119).
- New `packages/itil/hooks/test/p057-staging-trap-detect.bats` — 10 behavioural assertions per ADR-005 + P081 (5 trap/allow paths from the ticket spec; 5 supporting paths: non-Bash tool, non-commit Bash, empty JSON, deny-message contract, deny-message byte budget).
- `packages/itil/hooks/hooks.json` — registers the new hook under `PreToolUse` with `matcher: "Bash"`.
- `docs/briefing/agent-interaction-patterns.md` line 8 — cites the new hook as the enforcement layer with detection logic and recovery shape.

Architect APPROVED-WITH-AMENDMENTS verdict applied (3 amendments: ADR-005 cited in bats header instead of ADR-037 since hooks/test/ lives under ADR-005 / fail-open contract on parse-incomplete input mirrors create-gate.sh precedent / cost discoverability ~10-50ms documented in helper docstring per ADR-023). JTBD PASS — JTBD-001 (Enforce Governance Without Slowing Down) primary fit; JTBD-006 (Progress the Backlog While I'm Away) composes (AFK iter loops are the highest-frequency offenders per the ticket evidence). Voice-tone draft suggestion applied (~245-byte recovery message; observed 348 bytes including JSON envelope, well under the 400-byte ADR-038 progressive-disclosure cap).

Awaiting user verification: trigger the trap shape in any session (`git mv <A> <B>` followed by an `Edit` to `<B>` with no subsequent `git add <B>`, then `git commit`) and confirm the hook denies with the recovery line naming `<B>` and the literal `git add <B>` command. Recovery: run the surfaced `git add <B>` and retry the commit.

## Dependencies

- **Blocks**: (none directly — fix is bounded to commit-time enforcement)
- **Blocked by**: (none)
- **Composes with**: P057 (closed — documentation fix; this ticket adds the enforcement layer the documentation didn't enable). P119 (verifying — adjacent hook-enforcement pattern; same `packages/itil/hooks/` directory and helper shape).

## Related

- **P057** (`docs/problems/057-git-mv-edit-add-staging-ordering-trap-drops-content-edits.closed.md`) — original ticket; documentation fix landed 2026-04-22. This ticket adds the enforcement mechanism the documentation alone doesn't provide.
- **P119** (`docs/problems/119-agent-bypasses-manage-problem-step-2.verifying.md`) — adjacent hook-enforcement pattern. Same architectural shape (PreToolUse blocking deny with recovery instructions).
- `docs/briefing/agent-interaction-patterns.md` line 8 — current documentation of the rule; will gain a hook-citation pointer once this fix ships.
- `docs/briefing/README.md` Critical Points line 6 — same rule at the session-start surface.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. Documented rule + hook enforcement = governance enforced without depending on agent attention.
- **JTBD-006** (Progress the Backlog While I'm Away) — composes; AFK iter loops that batch multi-file commits are the highest-frequency offenders.
- 2026-04-26 session evidence: P122 design-question batch commit `e7564ff` shipped with only the P115 rename (1 file changed, 0 insertions, 0 deletions); recovery via `git commit --amend` produced `b8f3a01` (6 files changed, 178 insertions, 12 deletions). All 5 missing files (P079/P080/P115-content/P117/P123/README) had been Edited but not re-staged after the batch's various Write/Edit calls.
