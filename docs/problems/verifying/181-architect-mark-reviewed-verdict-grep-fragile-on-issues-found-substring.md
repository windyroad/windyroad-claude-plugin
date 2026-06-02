# Problem 181: PostToolUse `architect-mark-reviewed.sh` verdict-grep is fragile — `"ISSUES FOUND"` substring anywhere blocks marker even when proposed-change verdict is PASS

**Status**: Verification Pending
**Reported**: 2026-05-11
**Fix released**: 2026-06-01 — @windyroad/architect@0.13.0 (commit a1939e7)
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The PostToolUse hook `packages/wr-architect/<ver>/hooks/architect-mark-reviewed.sh` parses architect-agent verdict output by literal substring grep:

```bash
if echo "$AGENT_OUTPUT" | grep -q "Architecture Review: PASS"; then
  VERDICT="PASS"
elif echo "$AGENT_OUTPUT" | grep -q "ISSUES FOUND"; then
  VERDICT="FAIL"
fi
```

The PASS check runs first but is gated on the **exact heading shape** `Architecture Review: PASS`. The FAIL check on `"ISSUES FOUND"` matches the substring **anywhere in the response**, including:

- Headings that describe non-blocking follow-up findings (`**Architecture Review: ISSUES FOUND**` opening + body explicitly stating *"do not block the declaration"*).
- Architect prose discussing a NEW DECISION RECOMMENDED follow-up where the proposed change itself is in scope.
- Inline phrasings like *"the architect found no issues"* (literal substring "no issues" doesn't match "ISSUES FOUND" but variants like *"if you find issues found in this..."* would).

The hook can't disambiguate "issues in the proposed change" vs "issues in surrounding state but proposed change is fine". When the architect's substantive verdict is PASS-with-non-blocking-follow-ups, the marker fails to drop and the next Write is blocked — even though the architect explicitly approved the file write.

### Verbatim evidence (2026-05-10 I002 mitigation)

Architect's first response on I002 declaration review opened with heading `**Architecture Review: ISSUES FOUND**` describing the drain-condition empty-conjunct coupling across ADR-018 / ADR-020 / ADR-042 / ADR-060 (a structural defect in the surrounding ADR landscape, not in the proposed I002 declaration). The body concluded:

> "Verdict: PASS on the I002 file write itself. NEW DECISION RECOMMENDED as a follow-up: extend P162's Phase 1 ADR scope ... Surface the recommendation as an Outstanding Design Question on the I002 ticket — do not block the declaration on it."

The PostToolUse hook grepped `ISSUES FOUND` → VERDICT=FAIL → no marker → next Write blocked with `Cannot edit 'I002-...investigating.md' without architecture review`.

Recovery: re-emit asked architect (via SendMessage to existing `agentId`) for `Architecture Review: PASS` heading with NEW DECISION RECOMMENDED note beneath. Second response had clean PASS heading and the marker dropped on PostToolUse fire.

**Cost**: 1 extra round-trip per affected edit. Observed once this session; pattern likely recurs whenever architect surfaces non-blocking surrounding-state findings on a PASS-on-the-edit verdict.

### Architectural context

- ADR-009 (Edit-gate hook contract) defines the verdict-marker semantics. The hook's verdict-classification is the load-bearing contract.
- ADR-032 (Governance skill invocation patterns) — architect-agent invocation per Step-0 fits within ADR-032's foreground-mediated pattern.
- The literal-substring grep is fast and simple but can't carry semantic disambiguation. Either the agent's verdict format must be more rigid (e.g. parse a structured `VERDICT:` line) OR the grep must be anchored (e.g. require `^**Architecture Review: PASS**$` at column 0 of a known position).

## Symptoms

(deferred to investigation)

## Workaround

When the architect's substantive verdict is PASS-with-non-blocking-follow-ups but the response opens with `ISSUES FOUND` framing, re-invoke the architect (or `SendMessage` to the existing `agentId`) asking for `Architecture Review: PASS` heading with the follow-up notes underneath. The second response should clear the marker.

## Impact Assessment

- **Who is affected**: every adopter of `@windyroad/architect` running incident-management or substantial governance work where the architect raises non-blocking follow-up findings.
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — likely a verdict-parsing-precision gap. Two candidate fix shapes:
  1. **Anchored heading match**: change `grep -q "ISSUES FOUND"` to `grep -qE '^\*\*Architecture Review: ISSUES FOUND\*\*$'` and the PASS check to `grep -qE '^\*\*Architecture Review: PASS\*\*$'`. Forces the agent to use the heading-as-verdict shape.
  2. **Structured verdict line**: amend the architect agent prompt to emit a `VERDICT: PASS|FAIL` line at the end of the response; hook parses that line specifically. Decouples verdict signalling from prose-content phrasing.
- [ ] Survey other PostToolUse mark-reviewed hooks (`jtbd-mark-reviewed.sh`, `style-guide-mark-reviewed.sh`, `voice-tone-mark-reviewed.sh`) for the same fragility pattern.
- [ ] Create reproduction test — bats fixture exercising both heading shapes with body content containing the substring `ISSUES FOUND`; assert marker drops only on `Architecture Review: PASS` heading.

## Dependencies

- **Blocks**: (none direct)
- **Blocked by**: (none)
- **Composes with**: I002 (the incident where this pattern surfaced), P135 (ADR-044 framework-resolution boundary — architect verdict-grep is a framework primitive whose precision affects the mechanical-stage discipline), ADR-009 (Edit-gate hook contract).

## Related

- **I002** (`docs/incidents/I002-release-pressure-and-wip-limit-controls-not-firing.restored.md`) — where the pattern was observed; commit `670929a` carries the verdict re-emit cycle.
- **ADR-009** — Edit-gate hook contract defining the verdict-marker semantics.
- **ADR-032** — Governance skill invocation patterns (architect-agent invocation surface).
- **ADR-044** — Decision-Delegation Contract; architect verdict-grep precision affects framework-mediated boundary.
- `packages/wr-architect/<ver>/hooks/architect-mark-reviewed.sh` — the hook with the fragile grep.
- Sibling hooks for survey: `jtbd-mark-reviewed.sh`, `style-guide-mark-reviewed.sh`, `voice-tone-mark-reviewed.sh`.

## Fix Strategy

**Kind**: improve
**Shape**: hook
**Target file**: `packages/wr-architect/hooks/architect-mark-reviewed.sh` (and sibling mark-reviewed hooks for parity).
**Observed flaw**: literal-substring grep on `ISSUES FOUND` matches anywhere in agent output, including non-blocking follow-up narrative.
**Edit summary**: anchor the verdict-classification grep to the heading position OR introduce a structured `VERDICT:` line emitted by the agent and parsed exclusively by the hook. Path option 1 (anchored heading) is the more bounded edit; option 2 (structured verdict line) decouples but requires agent-prompt amendments.
**Evidence**: 2026-05-10 I002 mitigation declaration — single observation this session, pattern likely recurs.

## Fix Released

Fixed 2026-05-31 in session 9 AFK iter 5 (single commit, `@windyroad/architect` patch). Anchored verdict-classification grep in `packages/architect/hooks/architect-mark-reviewed.sh` to the canonical heading shape from `packages/architect/agents/agent.md` "How to Report": `^[[:space:]]*>?[[:space:]]*\*\*Architecture Review: (PASS|ISSUES FOUND)\*\*`, replacing literal substring matching. Optional `> ` blockquote prefix tolerated; PASS check still runs first so PASS-with-inline-issues-prose narrows to PASS. Path option 1 (anchored heading) chosen over option 2 (structured `VERDICT:` line) — bounded, no agent-prompt amendment required, sibling parity unaffected (jtbd/style-guide/voice-tone use a separate `/tmp/<name>-verdict` file mechanism, not grep-on-output — confirmed during pre-fix survey). New behavioural bats fixture `packages/architect/hooks/test/architect-mark-reviewed-verdict-grep.bats` (8 tests; 2 RED→GREEN cases reproduce the substring false-positive on inline body prose). NEEDS DIRECTION verdict handling (informational follow-up surfaced during architect pre-review) NOT widened into this scope — separate concern.

Released 2026-06-01 in **@windyroad/architect@0.13.0** (fix commit `a1939e7`, packaged via `1d1d6a8 chore: version packages`). Awaiting user verification that the next architect-agent invocation in a fresh session correctly drops the marker on a PASS verdict whose body references the `ISSUES FOUND` shape inline (the canonical P181 false-positive scenario).

## Related

- ADR-009 — Edit-gate hook contract; this fix is a parser-precision change within ADR-009's TTL+drift regime, not a contract change.
- ADR-074 — Substance-confirm-before-build: the ticket's recorded Fix Strategy (Path option 1, anchored heading) is the user-confirmed substance the fix implements.
