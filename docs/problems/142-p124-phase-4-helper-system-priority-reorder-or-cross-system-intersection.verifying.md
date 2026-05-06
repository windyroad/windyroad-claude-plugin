# Problem 142: P124 Phase 4 — `get_current_session_id` helper system-priority bug; subprocess SIDs win mtime selection over orchestrator SID

**Status**: Verifying
**Reported**: 2026-04-29
**Fix Released**: 2026-05-03 (this commit; pending @windyroad/itil republish via push:watch + release:watch)
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3) — observed once in 2026-04-28 session BUT every long AFK loop with subprocesses creates the conditions for the bug to fire
**Effort**: M — Shipped via runtime-SID instrumentation hook (ADR-050) instead of the originally-listed options (a)/(b)/(c). Architect surfaced that pure-helper algorithms cannot disambiguate orchestrator-vs-subprocess context from filesystem state alone, so the fix shape is a new `PreToolUse:Bash|Write|Edit|Read` hook capturing the runtime stdin SID; helper reads it as authoritative. Single-commit fold-fix supersedes ADR-048's recovery prose.
**WSJF**: (9 × 1.0) / 2 = **4.5**
**Type**: technical

## Resolution (2026-05-03)

Shipped per **ADR-050** (`docs/decisions/050-runtime-sid-instrumentation-via-pretooluse.proposed.md`). New surfaces:

- `packages/itil/hooks/lib/runtime-sid.sh` — `runtime_sid_path()` shared between hook (writer) and helper (reader).
- `packages/itil/hooks/itil-runtime-sid-marker.sh` — new PreToolUse hook (matcher `Bash|Write|Edit|Read`); parses `session_id` from stdin JSON via python3 (jq fallback); writes via `printf '%s'`; ADR-045 Pattern 1 silent-on-pass; fail-open contracts on every error path.
- `packages/itil/hooks/lib/session-id.sh` — helper reads runtime marker FIRST; existing Phase 3 announce-marker priority preserved as cold-path fallback.
- `packages/itil/hooks/hooks.json` — registers new hook.
- `packages/itil/hooks/test/runtime-sid-marker.bats` — 7 new behavioural tests.
- `packages/itil/hooks/test/session-id.bats` — 4 new behavioural tests covering runtime-marker priority + cold-path fallback + env-var precedence.

**ADR-048 supersession** (same commit):

- `docs/decisions/048-...` renamed `.proposed.md` → `.superseded.md`; frontmatter `status` flipped + `superseded-by: 050-...` link added; top-of-doc supersession callout block added.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 — recovery sub-block removed (replaced with one "Phase 4 (P142 / ADR-050)" pointer paragraph).
- `packages/itil/hooks/manage-problem-enforce-create.sh` — conditional `RECOVERY_HINT` removed (deny stays terse and skill-pointing regardless of `/tmp/manage-problem-grep-*` state).
- `packages/itil/skills/manage-problem/test/manage-problem-p119-recovery-path.bats` — deleted (structural-grep on removed prose; behavioural coverage migrated to the two new bats files).
- `packages/itil/hooks/test/manage-problem-enforce-create.bats` — two `RECOVERY_HINT` tests reframed to pin the post-ADR-050 deny-message-invariance contract.

## Verification

After republish + reinstall in adopter projects:

1. Open a Claude Code session; confirm `/tmp/itil-runtime-sid-${USER}-*.current` is created on the first tool call and contains the runtime session UUID.
2. Run `/wr-itil:work-problems` for ≥3 iters where each creates a P-ticket via `/wr-itil:manage-problem`; confirm zero `BLOCKED` denials on legitimate first-creation paths in either orchestrator main turn or iter subprocess context.
3. Confirm `/tmp/itil-runtime-sid-${USER}-*.current` is OVERWRITTEN as the orchestrator's main-turn tool calls fire after each iter exit (`cat` the marker before and after to see the SID flip orchestrator → subprocess → orchestrator).
4. Confirm the conditional `Helper succeeded but SID mismatch detected — see manage-problem SKILL.md Step 2 substep 7.` recovery-hint text never appears in any deny message.

Close once verified across one full AFK orchestration session.

> Surfaced 2026-04-28 during interactive `/wr-itil:manage-problem` invocation in `/wr-itil:work-problems` orchestrator session. P124 Phase 3 helper picked iter 11 subprocess SID `3bb06924-8424-4114-b0fd-c097906cb4a1` (architect-announced marker mtime 21:29) over orchestrator SID `bbd89081-881a-4e1e-9518-9da5a7254c2f` (`itil-assistant-gate-announced` marker mtime 21:48). P119 manage-problem-enforce-create hook denied Write on stale-SID marker. Recovery: scrape `itil-assistant-gate-announced-*` directly to discover orchestrator SID.

## Description

P124 Phase 3 fixed the alphabetical-first stale-marker selection bug by introducing within-system mtime selection (`ls -t | head -1`). The helper iterates a fixed system priority list and picks the most-recent marker per system:

```
architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone
```

For each system, glob `/tmp/<system>-announced-*` and pick the most-recent mtime. First non-empty system wins.

**The Phase 3 bug**: `architect`, `jtbd`, and `tdd` UserPromptSubmit hooks fire for **both orchestrator main turns AND `claude -p` subprocesses**. When an AFK iter subprocess runs, its prompt-1 fires architect/jtbd/tdd announce hooks, creating markers with the subprocess's SID. These markers are MORE RECENT than the orchestrator's (which were set on the orchestrator's session-start, often hours earlier).

The `itil-assistant-gate-announced-*` marker, by contrast, is set by `packages/itil/hooks/itil-assistant-output-gate.sh` (P085) which scopes to **orchestrator main-turn ask discipline**. Subprocesses don't fire it. So `itil-assistant-gate-announced-<orchestrator-SID>` is the only marker that uniquely identifies the orchestrator SID.

The Phase 3 helper picks the WRONG SID because the system priority list puts subprocess-firing systems first.

## Symptoms

- 2026-04-28 session: P140 ticket creation in `/wr-itil:manage-problem` blocked by P119 hook because helper returned `3bb06924-...` (iter 11 subprocess SID) instead of `bbd89081-...` (orchestrator SID).
- Recovery required scraping `itil-assistant-gate-announced-*` directly, then `touch /tmp/manage-problem-grep-bbd89081-...`. Pattern is undocumented; agent had to discover the workaround under user pressure ("WTF? Why did you bypass instead of using the skill?").
- Pattern fires in EVERY long AFK loop session that uses subprocesses (most multi-iter sessions).
- The Phase 3 helper's stated guarantee — "returns the canonical session UUID" — fails silently in subprocess-rich sessions.

## Workaround

Scrape `itil-assistant-gate-announced-*` directly:

```bash
ls -t /tmp/itil-assistant-gate-announced-* | head -1 | sed 's|.*itil-assistant-gate-announced-||'
```

OR brute-force (less clean): touch markers for every architect-announced UUID. The brute-force pattern was attempted earlier in the session and user-rejected ("WTF? Why did you bypass instead of using the skill?"). Direct scrape is the prescribed workaround.

## Impact Assessment

- **Who is affected**: every `/wr-itil:manage-problem` invocation in an orchestrator session that has dispatched subprocesses. Solo-developer (JTBD-001), AFK orchestration (JTBD-006).
- **Frequency**: Every multi-iter AFK session. The 2026-04-28 session hit this once (during P140 capture); a session with more interactive ticket creation in the orchestrator main turn would hit it more.
- **Severity**: Moderate. Helper returns wrong SID → P119 hook denies → recovery required. Each occurrence costs ~3-5min + may surface the brute-force-vs-skill tension P119 / P135 capture.
- **Likelihood**: Likely. The 2026-04-28 session shipped 12 iters via subprocesses; the orchestrator's announce-marker mtime was older than every iter's by construction.
- **Analytics**: 2026-04-28 session — helper returned `3bb06924-...` (iter 11 SID) when orchestrator SID was `bbd89081-...`; manual recovery via `itil-assistant-gate-announced-*` lookup.

## Root Cause Analysis

### Investigation Tasks

- [ ] Confirm `itil-assistant-gate-announced-*` is unique to orchestrator main turn — verify by inspecting `packages/itil/hooks/itil-assistant-output-gate.sh` UserPromptSubmit binding and confirming subprocess sessions don't trigger it.
- [ ] Decide fix shape:
  - **(a) Re-order priority list**: put orchestrator-only systems first. New order: `itil-assistant-gate → itil-correction-detect → architect → jtbd → tdd → style-guide → voice-tone`. Architect-design call: which other systems are orchestrator-only?
  - **(b) Cross-system intersection**: find SID that ALL active systems agree on. Orchestrator SID would intersect across all 7 systems; subprocess SIDs would only appear in subprocess-firing systems. Slower (7 globs) but more robust.
  - **(c) Hybrid**: priority list with orchestrator-only systems first; fall back to cross-system intersection if priority systems return empty.
- [ ] Behavioural bats per ADR-037 + P081 covering: orchestrator session with subprocess-fresh markers (helper returns orchestrator SID); subprocess session (helper returns subprocess SID); empty markers (helper returns empty + non-zero); cross-system intersection edge cases.
- [ ] Update P124 ticket body with Phase 4 regression evidence + reference to this ticket.
- [ ] Compose-with consideration: P140 (Step 6.5 fix-and-continue) — Phase 4 fix is a pre-condition for P140's "fix-and-continue on `manage-problem` create-gate denial" path becoming reliable.

### Preliminary hypothesis

The system priority list in P124 Phase 3 was chosen for "most-likely-to-fire-on-prompt-1" without considering "fires-only-for-orchestrator". Re-ordering with orchestrator-only systems first should fix the bug deterministically. Cross-system intersection is more robust but slower.

## Fix Strategy

**Kind**: improve

**Shape**: skill (existing helper at `packages/itil/hooks/lib/session-id.sh`)

**Target file**: `packages/itil/hooks/lib/session-id.sh`

**Observed flaw**: helper's system priority list puts subprocess-firing systems (architect, jtbd, tdd) before orchestrator-only systems (itil-assistant-gate). Mtime-based selection within the priority list returns subprocess SID when orchestrator + subprocesses are both active.

**Edit summary**: re-order priority list to put orchestrator-only systems first: `itil-assistant-gate → itil-correction-detect → architect → jtbd → tdd → style-guide → voice-tone`. Add cross-system intersection as fallback when priority systems return empty (defensive depth).

**Evidence**: 2026-04-28 session — helper returned `3bb06924-...` (iter 11 subprocess SID, architect-announced mtime 21:29) when orchestrator SID was `bbd89081-...` (itil-assistant-gate-announced mtime 21:48). P119 hook denied Write; recovery via direct `itil-assistant-gate-announced-*` scrape.

## Dependencies

- **Blocks**: (none directly; closing this unblocks reliable P119 gate behaviour in multi-subprocess sessions)
- **Blocked by**: (none)
- **Composes with**: P124 (parent — Phase 4 is a follow-on phase to P124's Phase 1+2+3), P119 (manage-problem-enforce-create hook — Phase 4 fix prevents P119 false-deny), P140 (Step 6.5 fix-and-continue — Phase 4 fix improves the fix-and-continue surface)

## Related

- **P124** (`docs/problems/124-...verifying.md`) — parent ticket. Phase 4 is a follow-on regression fix.
- **P119** (`docs/problems/119-...verifying.md`) — manage-problem-enforce-create hook; P124 Phase 4 fix prevents false-deny on this gate.
- **P140** (`docs/problems/140-...verifying.md`) — Step 6.5 fix-and-continue; surfaced this regression during P140 capture.
- **ADR-038** — once-per-session announce marker pattern; defines the `<system>-announced-<SID>` shape this helper consumes.
- **ADR-009** — gate marker lifecycle.
- 2026-04-28 session evidence: helper-returned SID mismatch documented in P140 ticket body's Composes-with section (`P124 Phase 3 helper system-priority bug observed during P140 capture`).
