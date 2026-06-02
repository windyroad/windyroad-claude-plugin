# Problem 270: Agent waits for human to initiate upstream report instead of filing on detect — feedback delay class

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 8 (Medium) — Impact: 2 × Likelihood: 4
**Effort**: M (re-estimated 2026-05-18 — AFK orchestrator Step 4 fallback amendment + security/non-security classifier + bats fixture)

## Description

> I'm finding that nothing is proactivly reported upstream. The agent knows it needs to be reported, but waits for the human to initiate, which often doesn't happen because the human doesn't know. Also, it delays the feedback getting to the upsteam. When the agent detects that the issue is upstream, it should report it ASAP

The current P063 + ADR-024 contract instructs the agent to append a stable `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` marker to the ticket's `## Related` section when external root cause is detected. The marker preserves the audit trail across AFK iterations BUT does not file the report itself — the SKILL.md `/wr-itil:report-upstream` Step 6 security-path branch is interactive (per ADR-024 Consequences) so the AFK orchestrator never auto-invokes it. The defect captured here is that the human-initiate gate is asymmetric to the agent-detect signal: the agent has all the evidence it needs at detect-time (problem ticket body, upstream repo identified, P063 marker just appended), but the report waits for a human turn that often never comes because the human doesn't know there's a pending report queued.

Worked example evident in this session's BRIEFING.md carryover lines: "P010 + P007 composed upstream report against @windyroad/wr-risk-scorer (authorized — to be filed via /wr-itil:report-upstream when you're ready)" + "P011 upstream report against Claude Code (authorized — same)". Both have been authorized for an unspecified prior window; neither has been filed; the upstream maintainers have no visibility into the issues we've identified.

## Symptoms

(deferred to investigation)

Initial observations:
- BRIEFING.md "Carryover for next session" sections accumulate "authorized — to be filed when you're ready" lines across sessions without the corresponding `gh issue` filings landing.
- The `- **Upstream report pending** —` marker in ticket bodies is a static signal; nothing scans for it across the backlog to surface the unsent queue.
- The AFK orchestrator's Step 4 P063 fallback appends the marker but does NOT proactively invoke `/wr-itil:report-upstream` (per ADR-013 Rule 6 fail-safe — interactive security path).
- Upstream maintainers receive feedback at human-initiate latency (potentially weeks or never) instead of agent-detect latency (within the iter that surfaced the root cause).

## Workaround

User manually invokes `/wr-itil:report-upstream` for each pending ticket. Friction: the user has to know the pending queue exists, walk to each ticket, and run the skill — bypassed in practice because the queue is invisible.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — likely both maintainers (upstream feedback delay) and adopters (their problems are upstream-blocked but the upstream doesn't know to fix).
- **Frequency**: (deferred to investigation) — every external-root-cause detection in an AFK iteration produces an unsent report.
- **Severity**: (deferred to investigation) — initial: moderate. Compounds over time as the unsent queue grows.
- **Analytics**: (deferred to investigation) — count of `- **Upstream report pending** —` markers in docs/problems/ vs count of corresponding `gh issue` filings in `## Reported Upstream` sections.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — ADR-024 § Consequences "security-path branch is interactive" is the load-bearing constraint; can the non-security path (default external problem-report) be auto-invoked in AFK while preserving the security-path interactive carve-out?
- [ ] Audit current state: grep `docs/problems/` for the `- **Upstream report pending** —` marker; cross-reference against `## Reported Upstream` sections to compute the unsent queue depth.
- [ ] Consider sibling P249 (Phase 1 shipped `/wr-itil:check-upstream-responses` polling shape) — symmetric pattern; this ticket is the proactive-fire counterpart on the outbound side.
- [ ] Design candidate: AFK orchestrator Step 4 fallback amendment — after P063 marker append, classify the upstream report risk (security vs non-security); auto-invoke `/wr-itil:report-upstream` for non-security; preserve interactive carve-out for security per ADR-024 Consequences.
- [ ] Create reproduction test (bats fixture: ticket transitions Open → Known Error with external root cause; iter auto-files non-security report; security-classified report still defers to interactive).

## Dependencies

- **Blocks**: any timely upstream-feedback delivery — clamps the JTBD-006 audit-trail "every action taken during AFK mode should be traceable" outcome since the audit-trail tracks an INTENT-to-file, not the actual filing.
- **Blocked by**: (none observed yet — the ADR-024 security-path carve-out may need amendment but the non-security path is unblocked)
- **Composes with**:
  - P063 (closed) — manage-problem appends the `Upstream report pending` marker; this ticket asks the next class
  - P070 (verifying) — report-upstream does not check for existing upstream issues; sibling concern
  - P079 (open) — no inbound sync of upstream-reported problems; user explicitly cited this row
  - P080 (open) — no bidirectional update of upstream-reported problems; sibling
  - P220 (open) — manage-problem has no cadence for checking upstream-bound tickets
  - P249 (verifying) — `/wr-itil:check-upstream-responses` shipped the symmetric us-as-reporter polling shape; this ticket is the proactive-fire counterpart
  - P254 (open) — report-upstream automation blocks clamp agent feedback signal
  - ADR-024 — report-upstream contract; § Consequences security-path branch is interactive constraint
  - ADR-013 Rule 5 — policy-authorised silent proceed (non-security upstream reports are candidate Rule 5 fits)
  - ADR-013 Rule 6 — non-interactive fail-safe (current ADR-024 wording defaults to Rule 6 halt; this ticket asks Rule 5 over Rule 6 for non-security)
  - ADR-044 — framework-resolution boundary (the "should we file?" decision is framework-resolved once root cause is external + non-security)

## Related

(captured via /wr-itil:capture-problem mid-loop — orchestrator main turn while iter 2 P269 was running in background subprocess; user-initiated capture per CLAUDE.md MANDATORY capture-on-correction rule; description shape matches strong-signal direction-setting via user explicit instruction "When the agent detects that the issue is upstream, it should report it ASAP")

- P063 — closed; established `Upstream report pending` marker mechanism
- P070, P079, P080, P220, P249, P254 — sibling cluster on upstream report lifecycle
- ADR-024 — `/wr-itil:report-upstream` contract; Consequences clause names the security-path interactive carve-out
- `packages/itil/skills/work-problems/SKILL.md` Step 4 — current P063 fallback marker append (would gain a non-security auto-fire branch)
- `packages/itil/skills/manage-problem/SKILL.md` Step 6 — external-root-cause detection (would gain a non-security auto-fire branch)
- `packages/itil/skills/report-upstream/SKILL.md` Step 6 — security-path interactive branch (preserved verbatim under this ticket's fix shape)
