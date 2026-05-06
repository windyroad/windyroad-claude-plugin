# Problem 133: zsh-portability gap in shell-snippet examples across SKILL.md files — bash-style word-splitting + bash-builtin variable names fail silently or noisily on zsh

**Status**: Verification Pending
**Reported**: 2026-04-27
**Fix Released**: 2026-04-28 (P133 Phase 1 — install-updates SKILL.md L167 array form + reconcile-readme.sh defensive rename)
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M — likely combination of (a) audit of every SKILL.md and `scripts/*.sh` for bash-isms (unquoted variable iteration, `local status=`, `local declare`, `${array[@]}` zsh-array-vs-bash-array, `[[ ... ]]` extended-test in posix-sh contexts); (b) per-occurrence remediation (replace `for x in $VAR` with `for x in "${VAR[@]}"` or `for x in ${=VAR}` zsh-equivalent; rename `local status` to `local result`; etc.); (c) optional CI step or pre-commit hook lint that fails on bash-isms in shell snippets that should be portable.

**WSJF**: (9 × 1.0) / 2 = **4.5**
**Type**: technical

> Surfaced 2026-04-27 by direct user observation during `/install-updates` Step 7 execution after end-of-session restart. Two distinct zsh-vs-bash failures in the same wrapper script: (1) `local status=$(install_with_retry_rollback ...)` failed with `(eval):32: read-only variable: status` because zsh has `status` as a read-only built-in mapping to `$?`; (2) `for plugin in $PLUGINS_TO_UPDATE` (where `PLUGINS_TO_UPDATE="itil retrospective risk-scorer tdd"`) iterated **once** with the entire string as a single value, because zsh does NOT word-split unquoted variables by default (a deliberate zsh-vs-bash divergence). All 24 install operations marked `lost` until the wrapper was rewritten to use a proper bash array (`PLUGINS=(itil retrospective risk-scorer tdd)` with `for plugin in "${PLUGINS[@]}"`).

## Description

Shell snippets in SKILL.md files and `scripts/*.sh` are typically written in **bash idiom** — unquoted variable iteration, `local status=`, `${VAR[@]}` array expansion, `[[ ... ]]` extended-test brackets — but get **executed under zsh** when the user's interactive shell is zsh (the default on macOS). zsh-vs-bash divergence then causes silent failures (the bad case) or noisy failures (the recoverable case).

This session hit two distinct cases in `/install-updates` Step 7:

**Case 1 — `local status=...` (noisy)**:

```bash
install_with_retry_rollback() {
  local plugin="$1" target="$2" prior="${3:-unknown}"
  local key="wr-$plugin@windyroad"
  ...
  status=$(...)   # <-- zsh: (eval):32: read-only variable: status
}
```

In bash, `status` is a normal variable. In zsh, `$status` is a read-only built-in alias for `$?` (the most-recent exit code). Assigning to it errors. The error is loud (`read-only variable`) and the wrapper exits non-zero — so the failure surfaces immediately. Recoverable: rename `status` to `result` or any other identifier.

**Case 2 — `for plugin in $PLUGINS_TO_UPDATE` (silent)**:

```bash
PLUGINS_TO_UPDATE="itil retrospective risk-scorer tdd"
for plugin in $PLUGINS_TO_UPDATE; do   # <-- zsh: iterates ONCE with the full string as one value
  echo "$plugin"
done
```

In bash, unquoted variable expansion **word-splits** on `IFS` (default whitespace). The loop iterates 4 times. In zsh, unquoted expansion does NOT word-split by default — the loop iterates **once** with the full string (`"itil retrospective risk-scorer tdd"`) as the single value of `$plugin`.

The failure is **silent** in the sense that no syntax error fires — the loop runs, just with the wrong iteration count. In `/install-updates` Step 7, this caused every install attempt to use a bogus joined plugin name (`wr-itil retrospective risk-scorer tdd@windyroad`); each `claude plugin install` failed (key not found); status reported `lost` for all 24 operations — but the actual installed plugins were not removed because the matching uninstall also used the bogus key (no-op).

The `/install-updates` SKILL.md Step 7 example shape uses this bash-style iteration:

```bash
for plugin in $PLUGINS_TO_UPDATE; do
  PROJECT_STATUS["$plugin"]=$(install_with_retry_rollback "$plugin" "$TARGET_DIR" "${PRIOR_VERSION[$plugin]}")
done
```

A user copying or following this shape under zsh hits the silent failure.

## Symptoms

- Observed 2026-04-27 (post-restart `/install-updates` invocation):
  - First wrapper attempt: failed at line 32 with `(eval):32: read-only variable: status`. Wrapper exited non-zero. Recovered by renaming `status` → `result`.
  - Second wrapper attempt: ran without error but reported `lost` for all 24 install operations. Investigation revealed the inner loop ran once per project (6 iterations) instead of 24 times (6 projects × 4 plugins). Recovered by switching to `PLUGINS=(itil retrospective risk-scorer tdd)` array form.
  - Third wrapper attempt: 24/24 installed clean.
- Pattern likely affects:
  - Every SKILL.md that authored a shell snippet using `for x in $VAR` for word-splitting iteration
  - Every SKILL.md / script using `local status=` (or any other zsh-built-in name as a local variable)
  - `scripts/*.sh` files in this repo that don't have an explicit `#!/bin/bash` shebang (zsh users running `bash scripts/foo.sh` get bash, but running `./scripts/foo.sh` may pick up zsh if the shebang is missing or zsh-aware)
- The `/install-updates` SKILL.md example at Step 7 is the proximate failure point this session, but the class extends to every shell snippet in every SKILL across the project.

## Workaround

Per-snippet hand-fix when discovered. Pattern this session: rename `status` → `result`; replace `for x in $VAR` with `for x in "${VAR[@]}"` (array form) or `for x in ${=VAR}` (zsh-explicit word-splitting). The fix is mechanical once the symptom is recognised; the cost is the diagnostic cycle to recognise the symptom, plus the silent-failure cost of running through bogus iterations.

`SHELL=/bin/bash bash -c '...'` forces bash for an individual invocation; doesn't help for shell snippets pasted into the user's interactive zsh session.

## Impact Assessment

- **Who is affected**: every macOS user (zsh is default since Catalina); every user who has set zsh as their interactive shell on Linux. Solo-developer (JTBD-001) and plugin-developer (JTBD-101) personas — both interact with SKILL.md examples in their daily work.
- **Frequency**: every time a shell snippet using bash-isms gets executed under zsh. For `/install-updates` Step 7 specifically, every invocation hits the issue until the wrapper is rewritten.
- **Severity**: Moderate — the silent failure (Case 2) is more dangerous than the loud failure (Case 1) because the loud one is recoverable in seconds, while the silent one masquerades as a successful run that produces wrong output (24 "lost" plugins this session looked like a real catastrophe until investigation showed the actual plugins were intact).
- **Likelihood**: Likely — every macOS user copying a SKILL.md shell snippet into their interactive shell hits this. Cross-shell portability isn't tested by any existing CI.
- **Analytics**: 2026-04-27 session — `/install-updates` Step 7 wrapper hit both Case 1 and Case 2 in adjacent attempts. Total recovery cost: ~3 wrapper iterations, ~$0 cost (no subprocess), but the failed second attempt's "lost" status report would have looked like an actual P112-class plugin-install catastrophe to a user who didn't investigate.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit every SKILL.md file for bash-style shell snippets that fail on zsh. Concrete patterns to grep:
  - `for X in $Y;` (unquoted iteration) — Case 2 silent-fail shape
  - `local status=`, `local declare=`, `local typeset=`, `local exit=`, `local pipestatus=`, `local fignore=`, `local jobtexts=` — zsh built-in names that error on local-assignment
  - `[[ ... ]]` extended-test brackets — works on bash + zsh, but fails on dash/posix-sh; not strictly a zsh issue but a portability one
  - `${array[@]}` array expansion — works on bash; zsh has different array semantics (1-indexed by default; subscript syntax differs)
  - `read -p` (bash; zsh requires `read "?"` form)
- [ ] Inventory which SKILL.md examples are explicitly bash-only (have `bash` highlighted in the codeblock fence) vs intended-for-any-shell (no fence specifier or `sh` fence).
- [ ] Decide remediation strategy:
  - Option A: rewrite all snippets to be zsh-compatible (preferred for examples meant to be pasted into interactive shells)
  - Option B: explicitly mark bash-only snippets with `#!/bin/bash` shebangs and document the zsh-incompatibility in the SKILL.md prose
  - Option C: provide both bash and zsh examples for shell snippets the user is expected to paste interactively
- [ ] Optional: CI step or pre-commit lint that runs `shellcheck --shell=zsh` against shell snippets in SKILL.md files (extracted via fence-parser). Catches the class at author-time.
- [ ] Per-occurrence fix priority: `/install-updates` Step 7 first (the surface that broke this session); then audit other SKILL.md surfaces.

### Preliminary hypothesis

The bash-style shell snippet convention is **historical** — the project's authors are bash-fluent, the original `scripts/*.sh` files used bash-isms, and SKILL.md examples were copied from those scripts. zsh-incompatibility wasn't tested because no CI step exercises shell snippets, and the author's own interactive shell may have been bash.

The fix path is mechanical (per-snippet remediation) but cross-cutting (every SKILL with shell snippets). Phase 1 Option A (rewrite all to zsh-compatible) is the cleanest because it removes the trap entirely; Option B preserves bash idiom but adds documentation overhead the user must read.

## Fix Strategy

**Phase 1 — `/install-updates` Step 7 immediate fix**:

- Replace the SKILL.md Step 7 example with array-based iteration:

  ```bash
  PLUGINS=(itil retrospective risk-scorer tdd)
  for plugin in "${PLUGINS[@]}"; do
    ...
  done
  ```

- Rename `local status` → `local result` (or similar).
- Add a brief portability note in the SKILL.md prose: *"Shell snippets use array form for cross-shell portability; bash and zsh both word-split array expansions. Plain `for x in $VAR` is bash-only and silently iterates once on zsh."*

**Phase 2 — repository-wide audit + remediation**:

- Grep audit per Investigation Tasks above.
- Per-occurrence rewrite to zsh-compatible idiom.
- Update each SKILL.md prose where the snippet shape changes.

**Phase 3 — author-time enforcement (optional)**:

- New CI step extracts shell snippets from SKILL.md files and runs `shellcheck --shell=zsh` against them. Fails the build if any snippet would fail under zsh.
- Behavioural bats per ADR-005 + ADR-044 (once landed) — fixture: known-bad bash-only snippet in a fixture SKILL.md → assert CI step fails. Fixture: known-good portable snippet → assert CI step passes.

**Out of scope**: rewriting `scripts/*.sh` source files unless they're called from SKILL.md examples — internal scripts may stay bash-explicit if they have a `#!/bin/bash` shebang. Cross-shell test fixtures for posix-sh or dash compatibility — the dominant audience is zsh + bash on macOS/Linux; broader posix coverage is a separate ticket.

## Dependencies

- **Blocks**: (none — P133 is a portability gap; nothing strictly waits on it)
- **Blocked by**: (none — Phase 1 immediate fix can proceed standalone; Phase 2 audit is repository-wide and follows; Phase 3 CI lint is optional)
- **Composes with**: P124 (verifying — same class: `session-id.sh` helper used `shopt -s nullglob` which is bash-only, fails on zsh; same root pattern), P130 (orchestrator presence-aware dispatch — different concern but adjacent agent-discipline gap surfaced same session), P131 (`.claude/` user-space writes — same), P132 (inverse-P078 over-asks — same), P081 (structural-tests — once Phase 1 lands, dogfood-ready for the new zsh-aware bats fixtures), P127 (closed — GNU vs BSD `cp` divergence; same class of cross-substrate portability bug on a different surface).

## Related

- **P124** (`docs/problems/124-...known-error.md`) — `session-id.sh` `shopt-under-zsh` regression; same root pattern (bash-isms in helper script). P124 fix should compose with P133's Phase 2 audit.
- **P127** (`docs/problems/127-...verifying.md`) — GNU vs BSD `cp -R . dest` divergence on scaffold-intake fixture; cross-substrate portability bug on a different surface. Same family of "the snippet works in environment A, breaks silently in environment B".
- **P130** (`docs/problems/130-...open.md`) — orchestrator presence-aware dispatch; this-session capture.
- **P131** (`docs/problems/131-...open.md`) — `.claude/` user-space writes; this-session capture.
- **P132** (`docs/problems/132-...open.md`) — inverse-P078 over-asks; this-session capture.
- **P081** (`docs/problems/081-...open.md`) — structural-tests-are-wasteful; once Phase 1 lands, P133's Phase 3 bats fixtures can be behavioural-by-default per ADR-044.
- **`packages/itil/skills/install-updates/SKILL.md`** Step 7 — proximate failure point for the inner-loop word-split issue; first remediation target.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — silent shell-snippet failures are exactly the friction this JTBD targets.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-the-suite-with-new-plugins.proposed.md`) — downstream plugin authors copying SKILL.md examples inherit the trap.
- 2026-04-27 session evidence: `/install-updates` Step 7 wrapper hit both Case 1 (`local status=` zsh read-only) and Case 2 (`for plugin in $PLUGINS_TO_UPDATE` zsh-no-word-split) in adjacent attempts; recovered by switching to array form on the third attempt.
