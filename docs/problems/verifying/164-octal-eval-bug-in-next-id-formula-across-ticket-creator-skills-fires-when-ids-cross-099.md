# Problem 164: Latent octal-eval bug in next-ID formula across all 4 ticket-creator skills — `$(( $local_max + 1 ))` fails with "value too great for base" when local_max reaches 099

**Status**: Verifying
**Reported**: 2026-05-04
**Fix Released**: 2026-05-11 (committed; awaiting next plugin release for field verification)
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Almost certain (4)
**Effort**: S — one-line fix per skill across 6 skills (scope expanded from 4 to 6 after grep verification per Investigation Task; ≈ 6 SKILL.md edits + 2 bats fixture updates + 2 new regression tests)

**WSJF**: (16 × 1.0) / 1 = **16.0**
**Type**: technical

> Captured 2026-05-04 by `/wr-itil:work-problems` AFK loop iter 7 surfacing pass per user direction "capture all four now". Sibling finding from iter 3 P156 commit. **Latent — currently masked because ADR-NNN and P-NNN counts are below 099. Will fire when first ticket-creator skill's local_max reaches 099 and the bash arithmetic interpreter parses `099` as octal.**

## Description

The next-ID formula used by all four ticket-creator skills (`/wr-itil:manage-problem` Step 3, `/wr-architect:create-adr` Step 3, `/wr-itil:capture-problem` Step 2, `/wr-architect:capture-adr` Step 2) computes:

```bash
next=$(printf '%03d' $(( $(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

When `local_max` (or `origin_max`) reaches `099`, the bash arithmetic context `$(( ... ))` parses the leading-zero number as octal. `099` is invalid in octal (digits ≥ 8); bash emits:

```
bash: 099: value too great for base (error token is "099")
```

The skill exits non-zero before writing the marker, before opening the file. The user sees a cryptic bash error.

This is a **latent** bug — the trigger (local_max == 099) hasn't fired yet because:
- Problem tickets are at P166 today, but the formula compares the max (well past 099 already? No — the formula reads filename prefix not zero-padded), so the bash arithmetic on `162` etc. is fine because `162` doesn't match octal-leading-zero.

Actually re-reading: `local_max` is extracted via `grep -oE '^[0-9]+' | sort -n | tail -1`. For P162, this returns `162` not `0162`. `$(( 162 + 1 ))` is fine (no leading zero, no octal interpretation).

**The bug fires only when local_max returns `099`** — which would happen briefly between P099 and P100 creation. **Already passed** for problem tickets (P099 → P100 transition happened earlier this loop's history). Will fire next when a NEW ticket-creator surface starts a fresh sequence and the first 99 entries happen to be created (e.g. a new ADR series, a new risk register R series, a future ticket-creator pattern).

The risk surfaces specifically when:
1. `local_max == "099"` (extracted from `099-something.open.md` or similar)
2. The bash `$(( ... ))` operator parses it as octal
3. The first arithmetic operation hits the invalid-octal-digit fail

Standard fix: prefix with `10#` to force base-10:

```bash
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

Or unset the leading zero pre-arithmetic via `${var#0}` parameter expansion — slightly less robust because it misses `099` (only strips one zero).

## Symptoms

- Next-ID computation fails when local_max reaches `099`. Cryptic `bash: 099: value too great for base` error.
- Currently silent / latent across the 4 ticket-creator skills.

## Workaround

When the bug fires: manually pass `local_max=99` (one fewer) via env-var, or compute next-ID manually, or run the skill from inside Python/Node where decimal-leading-zero is unambiguous.

## Impact Assessment

- **Who is affected**: Every project using `/wr-itil:manage-problem`, `/wr-architect:create-adr`, `/wr-itil:capture-problem`, or `/wr-architect:capture-adr` whose ticket count crosses 099 in the relevant filename glob.
- **Frequency**: Bug fires once per ticket-creator surface per project lifetime (the `099 → 100` transition). After that it's silent again.
- **Severity**: Significant — cryptic bash error halts ticket creation; user has to debug.
- **Likelihood**: Almost certain — every project will eventually cross 099. This repo already crossed it for problems but the historical commits don't indicate the bug fired (might have used the marginal-error-recovery path: existing ticket counter started higher, or the bug DID fire silently and was retried).

## Root Cause Analysis

Bash's `$(( ... ))` arithmetic interpreter applies number-base conventions: leading `0` means octal, leading `0x` means hex, otherwise decimal. The skills' formulas treat the zero-padded ID string (e.g. `099`) as a decimal number but bash treats it as octal-with-invalid-digit.

The fix is the standard `10#` base-10 prefix that all robust shell-arithmetic-on-string-numbers code uses.

### Investigation Tasks

- [x] Confirm the ticket-creator skills affected — grep for `\$\(\(\s*\$\(echo` shape verified **6 affected SKILL.md** (scope expanded from the originally-named 4): `manage-problem`, `capture-problem`, `capture-rfc`, `create-adr`, `capture-adr`, `create-risk`.
- [x] Apply the `10#` fix consistently across all six skills.
- [x] Add regression bats fixture: synthetic `099-foo.open.md` + assert next-ID computation returns `100` cleanly without bash error. Added to `capture-adr.bats` (test 6) and `capture-problem.bats` (test 21); both pass.
- [ ] Optionally: shared helper `lib/next-id.sh` with the canonical formula, sourced by all six skills. **Deferred** — DRY benefit is small versus the risk of introducing a sourcing-order regression across the 6 currently-independent skills. Re-evaluate if a 7th ticket-creator surface is added.

## Fix Strategy

Phase 1 (completed 2026-05-11): applied the `10#` prefix across all 6 SKILL.md (verified by re-grep showing zero `\$\(\(\s*\$\(echo` matches without `10#`). Bats regression fixtures added to `packages/itil/skills/capture-problem/test/capture-problem.bats` and `packages/architect/skills/capture-adr/test/capture-adr.bats`. Single commit per ADR-014 covers all 6 fixes + regression tests.

Sanity check confirming the unfixed formula fires the documented error:
```
$ bash -c 'local_max=099; $(( $(echo -e "${local_max}\n0" | sort -n | tail -1) + 1 ))'
bash: line 1: 099: value too great for base (error token is "099")
$ bash -c 'local_max=099; echo $(( 10#$(echo -e "${local_max}\n0" | sort -n | tail -1) + 1 ))'
100
```

## Dependencies

- **Blocks**: (none — latent bug; nothing blocked today)
- **Blocked by**: (none)
- **Composes with**: P056 (next-ID formula `--name-only` correctness — this is the same formula's adjacent failure mode), ADR-019 (orchestrator preflight that fetches origin/<base> for the formula's input)

## Related

- P056 (`docs/problems/056-...closed.md`) — sibling on the same formula (`--name-only` for ls-tree).
- ADR-019 (`docs/decisions/019-afk-orchestrator-preflight.proposed.md`) — preflight contract that ensures origin_max is current.
- iter 3 P156 retro — `docs/retros/2026-05-03-p156-iter.md`.

## Change Log

- **2026-05-04** — Opened by orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 per user direction "capture all four now". Sibling finding from iter 3 P156 commit. Skeleton ticket; one-line fix scope plus bats fixture.
- **2026-05-11** — Fix applied by `/wr-itil:work-problems` AFK iter. Scope expanded from 4 → 6 SKILL.md after grep verification (added `capture-rfc` and `create-risk` to the originally-named 4). All 6 SKILL.md formulas now use `10#` base-10 prefix. Two regression bats tests added (`capture-adr` + `capture-problem`, exercising the `099 → 100` boundary). All 28 bats tests pass. Manual sanity check confirms unfixed formula fires `bash: 099: value too great for base` and fixed formula returns `100`. Architect + JTBD reviews PASS. Status: Open → Verifying (awaiting field verification on next plugin release per ADR-014).
