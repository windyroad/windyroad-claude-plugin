# Problem 029: Edit gate overhead disproportionate for governance documentation changes

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: S
**WSJF**: 18.0 — (9 × 2.0) / 1

## Description

The architect and JTBD pre-edit hooks fire on every project file edit, including documentation-only governance operations such as:
- Closing a problem (`git mv` + one-line status field update)
- Transitioning a problem to Known Error
- Updating investigation task checkboxes

These edits carry no architectural risk and no JTBD alignment risk — they are the output of governance skills doing their job, not code changes. Yet the hooks trigger mandatory agent delegations before each edit is allowed. The user rejected both gates during this session, treating them as unnecessary overhead.

When the user denies the architect or JTBD delegation, the edit is blocked and the governance skill stalls mid-operation. This forces either: (a) the user to approve the delegation despite considering it pointless, or (b) the session to be restructured around the blocked edit.

Observed this session: architect review rejected for P023 closure (one-line status change) and for P027 investigation start.

## Symptoms

- Architect + JTBD agents prompted before every problem file edit, including trivial status updates and `git mv` renames
- User rejecting agent delegations for documentation-only governance operations
- Governance skills stalling mid-operation when delegation is denied
- Friction observed: "this should have released by itself" — user expects governance ops to be low-friction end-to-end

## Workaround

Approve the architect and JTBD delegations even for trivial edits (they typically find no issues). Accept the overhead.

## Impact Assessment

- **Who is affected**: Solo-developer persona (JTBD-001, JTBD-005) — every governance session
- **Frequency**: Every problem file edit, every session
- **Severity**: Medium — interrupts flow, creates decision fatigue, contradicts "governance must be fast enough to not interrupt work" premise
- **Analytics**: Two rejected delegations observed this session

## Root Cause Analysis

### Confirmed Root Cause

The overhead comes from **two different hook layers** with mismatched scope:

**Layer 1 — `PreToolUse` edit gates (already fixed):**
Both `architect-enforce-edit.sh` (line 65-66) and `jtbd-enforce-edit.sh` (line 76-77) already exempt `docs/problems/*.md` via `exit 0`. Edits to problem files are NOT blocked at the tool-use level.

**Layer 2 — `UserPromptSubmit` prompt injection (the actual problem):**
Both `architect-detect.sh` and `jtbd-eval.sh` inject mandatory delegation instructions into EVERY user prompt. The scope exclusion text says:
- Architect: "Does NOT apply to: CSS/SCSS files, image assets, lockfiles, font files."
- JTBD: "Does NOT apply to: CSS, images, fonts, lockfiles, changesets, memory files, plan files."

Neither mentions `docs/problems/*.md`, `docs/BRIEFING.md`, `RISK-POLICY.md`, or other governance docs. So the LLM reads the injected instruction and dutifully delegates to architect + JTBD before every governance doc edit — even though the PreToolUse gate would allow the edit without delegation.

**The disconnect:** PreToolUse exempts governance docs; UserPromptSubmit does not. The LLM follows the broader UserPromptSubmit instruction, creating unnecessary agent calls that find no issues.

### Fix Strategy

Update the scope exclusion text in both `UserPromptSubmit` hooks to match the `PreToolUse` exemptions:

1. `packages/architect/hooks/architect-detect.sh` — add governance docs to the "Does NOT apply to" line
2. `packages/jtbd/hooks/jtbd-eval.sh` — add governance docs to the "Does NOT apply to" line

Files to match the PreToolUse exemptions: `docs/problems/*.md`, `docs/BRIEFING.md`, `RISK-POLICY.md`, `.risk-reports/`, `.changeset/*.md`, memory files, plan files.

Effort: **S** (two one-line text changes in shell scripts).

### Investigation Tasks

- [x] Audit which hook(s) fire on `docs/problems/` edits — both UserPromptSubmit hooks inject mandatory instructions; PreToolUse hooks already exempt
- [x] Check whether `docs/problems/*.md` actually needs architect or JTBD review — No, already exempted in PreToolUse gates
- [x] Update scope text in `architect-detect.sh` and `jtbd-eval.sh` to match PreToolUse exemptions
- [x] Check whether a governance-mode env var is needed — No, path-based scope text update is sufficient and consistent with existing PreToolUse pattern

## Fix Released

Deployed in commit `ac9d453` (2026-04-17):
- `packages/architect/hooks/architect-detect.sh` — UserPromptSubmit scope text updated to exclude governance docs (`docs/problems/*.md`, `docs/BRIEFING.md`, `RISK-POLICY.md`, `.risk-reports/`, `.changeset/*.md`, memory files, plan files)
- `packages/jtbd/hooks/jtbd-eval.sh` — same scope text update

Awaiting user verification that architect and JTBD hooks no longer fire for governance doc edits.

## Related

- P027: `docs/problems/027-manage-problem-work-flow-is-expensive.known-error.md` — sibling problem; both reduce governance overhead
- P028: `docs/problems/028-governance-skills-should-auto-release-and-install.open.md` — sibling problem; all three are aspects of "governance is too slow"
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md` — "under 60 seconds" outcome target
- ADR-007 / ADR-008: JTBD gate scope decisions — defines what the gate covers
