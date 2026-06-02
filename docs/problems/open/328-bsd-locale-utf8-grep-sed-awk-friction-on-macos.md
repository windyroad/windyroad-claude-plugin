# Problem 328: BSD `grep` / `sed` / `awk` on macOS silently fail or error on UTF-8 without `LC_ALL=en_US.UTF-8`

**Status**: Open
**Reported**: 2026-05-30
**Priority**: 8 (Medium) — Impact: 2 (Minor — dev tooling friction on contributor environments; published packages unaffected) × Likelihood: 4 (Likely — every macOS contributor without `LC_ALL=en_US.UTF-8` export hits at least one of the grep/sed/awk failure modes; observed multiple times in single session)
**Origin**: internal
**Effort**: M (multiple call-sites across packages/* scripts need locale-export wrappers or a shared helper source)
**WSJF**: 4.0 (re-rated 2026-05-31; was placeholder I=3×L=1; honest grounding raises to S8/L4/Effort-M)

## Description

BSD `grep` / `sed` / `awk` on macOS silently fail (or emit `multibyte conversion failure` / `illegal byte sequence`) when processing UTF-8 multi-byte characters (em-dash `—`, smart quotes, en-dash) without `LC_ALL=en_US.UTF-8` set.

Observed multiple times during the 2026-05-30 ADR-076 / ADR-077 session:

- `grep -cE '^### ADR-' docs/decisions/README.md` returned 0 against a file that clearly had H3 ADR entries (em-dash separator) — silent wrong result.
- `awk '/^### ADR-/'` errored with `awk: towc: multibyte conversion failure on: '… sub-agent delegation precedent...'` — noisy failure.
- `sed -n '/^### /p'` errored with `sed: RE error: illegal byte sequence` while reading the generated compendium — noisy failure.

Each instance produced wrong results silently or noisy errors, requiring an `export LC_ALL=en_US.UTF-8` retry to recover.

Recurrence rate this session: 3+ distinct incidents in roughly one hour of work on the ADR-077 compendium generator + verification scripts. The codebase's prose is pervasively em-dash / smart-quote rich (ADRs, problem-ticket bodies, briefing entries, SKILL.md files), so any script that `grep` / `sed` / `awk`s those surfaces is exposed.

**Fix-strategy candidates:**

1. **Wrapper shims under `packages/shared/bin/`** that always set `LC_ALL` before exec-ing `grep` / `sed` / `awk`. Scripts that touch UTF-8 content invoke the shim instead of the raw command.
2. **Audit `packages/*/scripts/`** and prepend `export LC_ALL=en_US.UTF-8` to every script that calls `grep` / `sed` / `awk` on prose content (most of them — the codebase is em-dash rich).
3. **CI lint** that greps scripts for `grep|sed|awk` invocations without a preceding `LC_ALL` set and warns. Cheapest to ship; catches future regressions without changing existing scripts immediately.

Codification shape: shell-or-Node script (the wrapper helper or the lint), plus possibly a CI step (the lint). Routing target: `/wr-architect:create-adr` if a project-wide locale policy is warranted, otherwise a focused script + bats fixture.

Internal observation during the run-retro Step 2b pipeline-instability scan; no external reporter.

## Symptoms

- `grep -cE '<pattern with multi-byte chars somewhere in input>' <file>` returns `0` (silent wrong-result) when the input contains em-dashes / smart quotes / other multi-byte UTF-8 — recovery: `export LC_ALL=en_US.UTF-8` and retry.
- `awk '<pattern>' <file>` emits `awk: towc: multibyte conversion failure on: '<truncated context with multi-byte char>'` and aborts.
- `sed -n '<pattern>' <file>` emits `sed: RE error: illegal byte sequence` and aborts.
- All three recover identically with `export LC_ALL=en_US.UTF-8`; the failure mode is locale-class, not tool-class.

## Workaround

Set `export LC_ALL=en_US.UTF-8` at the top of any script that grep / sed / awks UTF-8 content, OR set it inline before each invocation. Per-session: run `export LC_ALL=en_US.UTF-8` once.

## Impact Assessment

- **Who is affected**: every developer running scripts on macOS BSD utilities (default macOS shell environment, `/bin/sh` and `/bin/bash`). Linux users on GNU coreutils are unaffected (GNU `grep` / `sed` / `awk` handle UTF-8 by default).
- **Frequency**: every script invocation that reads prose containing multi-byte chars without `LC_ALL` set.
- **Severity**: Medium — silent wrong-results (the grep-returning-0 case) are the most dangerous because they don't surface as errors; agents working from those wrong results burn turns chasing nonexistent bugs.
- **Analytics**: (deferred — would benefit from a quick audit of `packages/*/scripts/*.sh` to count exposure surface)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit `packages/*/scripts/*.sh` for `grep|sed|awk` invocations on prose paths; count exposure surface
- [ ] Choose fix strategy: wrapper shims, in-script LC_ALL, or CI lint (or combination)
- [ ] Implement chosen strategy + bats fixture using known-failing UTF-8 input

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P133 (zsh word-split P133 — sibling shell-portability class; both fire silently on macOS defaults and require explicit workarounds)

## Fix Strategy

**Kind**: create
**Shape**: shell-or-Node script (with a CI step)

**Suggested approach** — implement the CI lint first (cheapest, catches future regressions without rewriting existing scripts):

1. Add `packages/shared/scripts/lint-locale-aware-bash.sh` that walks `packages/*/scripts/*.sh` + `scripts/*.sh` and reports any file that calls `grep` / `sed` / `awk` (matching word boundaries; skipping `git grep`) without a preceding `export LC_ALL=`. Exit 1 on findings; 0 on clean. Advisory in CI initially per ADR-040 declarative-first; promote to load-bearing once the existing scripts are migrated.
2. Audit + migrate the existing high-traffic scripts (the architect compendium generator just shipped this session is one — it's already declarative-LC_ALL-safe via the call sites that set LC_ALL inline).
3. Optional Phase 2: ship `packages/shared/bin/wr-grep` / `wr-sed` / `wr-awk` wrapper shims that always `LC_ALL=en_US.UTF-8`. Adopt across the codebase once the lint enforces.

Triggers / Evidence: 3+ distinct incidents in the 2026-05-30 ADR-077 session (one hour of work on the compendium generator + verification scripts); silent wrong-results in `grep -c '^### ADR-' compendium`; noisy errors in `awk` / `sed` on em-dash-rich content.

## Related

- **P133** — sibling shell-portability class: zsh word-split silently iterates once where bash splits properly. Both classes fire silently on macOS defaults and require explicit workarounds.
- **P320** — sibling zsh quirk: `status` is a read-only zsh var, breaks bash idioms that assign to `status`. Same class — macOS default shell + macOS default utilities have non-obvious differences from Linux that catch agents.
- **ADR-076** — meta: the session that captured P327 (inbound-reported compendium token-burn problem) also captured this UTF-8 friction observation via run-retro Step 2b — the retro's pipeline-instability scan working as designed.

(captured via /wr-itil:capture-problem; expand at next investigation)
