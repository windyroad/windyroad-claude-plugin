# Problem 173: BYPASS_*_GATE env vars do not propagate from Bash subshell to PreToolUse hook context

**Status**: Known Error
**Reported**: 2026-05-06
**Priority**: 6 (Medium) — Impact: 2 (Minor — gate-bypass friction blocks the maintainer's in-session commits, forcing external-terminal workarounds; dev-tooling, not published-distribution) x Likelihood: 3 (Possible — documented recurring across sessions per the cross-session briefing)
**Effort**: M
**WSJF**: 6.0 — (6 × 2.0) / 2 (Known Error multiplier 2.0) — auto-transitioned Open → Known Error 2026-05-26 (confirmed root cause + documented workaround); Likelihood un-deferred from placeholder 1 → 3
**Type**: technical

## Description

`BYPASS_*_GATE` env vars (e.g. `BYPASS_CHANGESET_GATE`, `BYPASS_JTBD_CURRENCY`, `BYPASS_RISK_GATE`) do not propagate from a Bash subshell to PreToolUse hook context. The hook reads env at hook-process invocation time (Claude Code's process env), not the bash subshell's env that an inline `BYPASS_FOO=1 git commit` or `export BYPASS_FOO=1; git commit` would set.

**Symptom (2026-05-06 P170 Slice 2)**: trying to bypass `itil-changeset-discipline.sh` (P141) on a held-window opening commit by `BYPASS_CHANGESET_GATE=1 git commit -m '...'` was rejected with the same gate deny message; `export BYPASS_CHANGESET_GATE=1; git commit` (separate statements within the same Bash call) was also rejected. The bypass instruction in the deny-message reads `Bypass: BYPASS_CHANGESET_GATE=1` but the path-to-set is non-obvious — the env must be set in Claude Code's parent shell BEFORE invoking the agent (typically restart-required for an in-flight session).

**Workaround discovered**: the documented two-commit hold-window dance (`.changeset/<name>.md` then `git mv` to `docs/changesets-holding/`) preserves all gates (P141 satisfied because the changeset is staged; P064 still requires precomputed sha256 marker; risk-scorer state-drift between scoring and commit re-fires correctly).

**Cost**: one wasted turn + 4-line Bash retry + finding the `docs/changesets-holding/README.md` documented Process Step 2 pattern.

**Class of friction**: hook-bypass UX gap. The deny-message instruction is technically correct but operationally misleading because the env-set requires lifecycle-level action the user is not in a state to take mid-session. Affects all hook gates that read env at hook-process time (`itil-changeset-discipline.sh`, `retrospective-readme-jtbd-currency.sh`, `external-comms-gate.sh`, others).

**Suggested fix shape**: each gate's deny-message clarifies that the env bypass must be set in Claude Code's process env BEFORE the session began, AND names the gate's in-flight escape-hatch:

- `itil-changeset-discipline.sh` (P141) — held-area dance: author in `.changeset/`, commit, then `git mv` to `docs/changesets-holding/` per the held-area README "Process" Step 2.
- `retrospective-readme-jtbd-currency.sh` (P159) — recovery via JTBD-NNN reference addition + skill-inventory row updates in the affected `packages/<pkg>/README.md`.
- `external-comms-gate.sh` (P064) — recovery via delegating to `wr-risk-scorer:external-comms` agent with the precomputed sha256 of the draft body.

**Cite trigger**: 2026-05-06 P170 Slice 2 framework commit attempt; recovery via held-window dance commit `12725a3` + move commit `8572aa6`.

**SID-mismatch sub-finding — NOT a separate P173 concern; tracked by P142/P260 (2026-05-26 triage)**: the original capture noted that `get_current_session_id` (`packages/itil/hooks/lib/session-id.sh`) returned a stale SID during P173/P174 capture (2026-05-06, plugin cache `wr-itil/0.25.0`). The manage-problem Step 2 duplicate-check identifies this as the same root cause already tracked by **P142** (`get_current_session_id` helper system-priority bug — subprocess SIDs win mtime selection over orchestrator SID; fix shipped via ADR-050 runtime-SID instrumentation, released 2026-05-03, **status Verifying**) and the related **P260** (P119 create-gate marker race between concurrent sessions via the shared runtime-SID file, Known Error). The 2026-05-06 observations are therefore verification evidence for P142 — either a regression of the ADR-050 fix OR pre-fix behaviour on an un-refreshed `0.25.0` cache (the fix requires republish + reinstall per P142's Verification section). Determining regression-vs-stale-cache is P142's verification work, not a P173 root cause. NOT split into a new ticket (would duplicate P142). Cross-referenced under `## Dependencies` / `## Related`.

## Symptoms

- A maintainer who hits one of the affected gates mid-session reads the deny's `Bypass: BYPASS_*_GATE=1` line, tries it as an inline (`BYPASS_FOO=1 git commit`) or `export`-then-commit in a single Bash call, and is rejected with the *same* deny — because Claude Code reads hook env from its parent process at hook-invocation time, not from the agent's Bash subshell. One wasted turn + retry before the maintainer finds the real in-flight recovery.
- The deny message's bypass instruction is technically correct (the env var works) but operationally misleading: setting it requires a session restart (lifecycle-level action the maintainer is not in a state to take mid-session).
- Affects every gate whose deny advertised an env bypass as if it were in-flight: `itil-changeset-discipline.sh` (P141), `retrospective-readme-jtbd-currency.sh` (P294), `external-comms-gate.sh` (P064).

For the SID-mismatch observation that was previously documented in this section, see the cross-reference in `## Description` → tracked by P142 (Verifying) + P260 (Known Error), not a P173 concern.

## Workaround

- **In-flight, per gate** (no session restart needed): changeset gate → `bun run changeset` (staging any changeset satisfies it; `git mv` to `docs/changesets-holding/` afterward defers release); README-currency gate → name the skill in the affected `packages/<pkg>/README.md`; external-comms gate → delegate to the evaluator subagent (or `/wr-risk-scorer:assess-external-comms` / `/wr-voice-tone:assess-external-comms`).
- **Env bypass** (`BYPASS_*_GATE=1`): must be exported in Claude Code's process env BEFORE the session starts (restart-required); cannot be set from a mid-session Bash subshell.
- **Commit that must remove/narrow a load-bearing currency hook** (the gate blocks its own removal and the bypass can't reach it): commit from an external terminal — write the message to `.git/<name>.txt` (session `/tmp` is sandboxed). See briefing `hooks-and-gates.md`.

## Impact Assessment

- **Who is affected**: the plugin-developer / maintainer working in the monorepo (JTBD-001 — enforce governance without slowing down).
- **Frequency**: Possible (3) — recurs whenever a maintainer hits one of the three gates mid-session and reaches for the advertised env bypass. Documented across multiple sessions in the cross-session briefing.
- **Severity**: Minor (Impact 2) — gate-bypass friction costs in-session turns; dev-tooling, not published-distribution behaviour. No data loss, no outage.
- **Analytics**: N/A (dev-tooling friction; no telemetry surface).

## Root Cause Analysis

**Two layers — one upstream/by-design (not locally fixable), one local UX (fixed):**

1. **Core mechanism (upstream / by-design — NOT locally fixable):** Claude Code invokes PreToolUse hooks as separate processes whose environment is inherited from Claude Code's *parent* process at session start, NOT from the agent's Bash subshell. An inline `BYPASS_FOO=1 git commit` or `export BYPASS_FOO=1; git commit` inside a single Bash tool call sets the var only in that transient subshell, which the hook process never sees. This is a Claude Code runtime characteristic; the plugin cannot change how the host passes env to hooks. Per manage-problem external-root-cause detection, recorded as upstream/by-design (see `## Related` upstream-report-pending marker; not auto-reported per AFK policy / ADR-024).

2. **Local UX defect (FIXED 2026-05-26):** each affected gate's deny-message advertised the env bypass (`Bypass: BYPASS_*_GATE=1`) as though it were an in-flight escape, when it only takes effect pre-session. The misleading instruction caused maintainers to waste a turn trying it mid-session before discovering the real in-flight recovery. **Fix:** the three deny messages now lead with the accurate in-flight recovery and state `Env bypass is pre-session only.` (external-comms: `Override only ... (pre-session env): BYPASS_RISK_GATE=1.`). Within the ADR-045 ≤300-byte deny-band for the two budget-constrained gates (287 bytes worst-case slug).

### Fix Strategy

Deny-message accuracy correction across the three gate hooks. Architect-approved 2026-05-26 (within deny-message contract, no new ADR; ADR-013 Rule 1 / ADR-045 / ADR-052 compliant). Behavioural bats assert the deny carries `pre-session` (ADR-052). external-comms-gate edited at the ADR-017 canonical (`packages/shared/hooks/`) and synced to risk-scorer + voice-tone. **Note:** the ADR-045 budget could not also fit an explicit `docs/changesets-holding/` held-area pointer in the changeset deny; that defer-release dance is documented in `docs/changesets-holding/README.md` + briefing `hooks-and-gates.md`, and the gate-pass recovery (`bun run changeset`) is named.

### Investigation Tasks

- [x] Investigate root cause — two layers identified (upstream env-propagation + local deny-message UX)
- [x] Create reproduction test — behavioural bats assert `pre-session` in each gate's deny (RED→GREEN 2026-05-26)
- [x] Implement local fix — three deny messages corrected; canonical synced; all affected bats GREEN
- [x] SID-mismatch sub-finding triaged — duplicate of P142 (Verifying) + P260 (Known Error); not split (see Description)
- [ ] Release fix (`@windyroad/itil`, `@windyroad/retrospective`, `@windyroad/risk-scorer`, `@windyroad/voice-tone` republish) → then transition Known Error → Verifying per ADR-022

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P141 (changeset-discipline gate), P294 (README-inventory currency gate — supersedes the P159/ADR-051 JTBD-ID rule), P064 (external-comms gate), P166 (precomputed-sha256 helper for external-comms — same UX-gap class, different mechanism), P142 (`get_current_session_id` helper bug — the SID-mismatch sub-finding's actual root cause, Verifying), P260 (P119 create-gate marker race via shared runtime-SID file, Known Error)

## Related

- Fix commit: deny-message accuracy correction across `packages/itil/hooks/itil-changeset-discipline.sh`, `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`, `packages/shared/hooks/external-comms-gate.sh` (+ synced risk-scorer/voice-tone copies) + behavioural bats (2026-05-26).
- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready. (Core env-propagation mechanism is a Claude Code runtime characteristic / by-design; the local deny-message fix mitigates the friction. AFK fallback per ADR-013 Rule 6 — not auto-reported.)
- SID-mismatch sub-finding → tracked by P142 + P260 (see `## Description`).
- Briefing: `docs/briefing/hooks-and-gates.md` (P173 entry — external-terminal recovery for hook-blocked commits).
