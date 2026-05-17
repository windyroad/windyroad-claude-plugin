---
"@windyroad/itil": minor
---

P249 Phase 1: ship `/wr-itil:check-upstream-responses` skill — the outbound symmetric counterpart to ADR-062's inbound discovery pipeline.

ADR-062's inbound discovery pipeline auto-polls upstream-filed reports against THIS repo and classifies them through JTBD-alignment + dual-axis risk. The symmetric outbound gap — polling responses to reports WE filed against upstream repos via `/wr-itil:report-upstream` — was left as manual "remember to check the upstream issue URL". P249 closes that gap.

New skill `/wr-itil:check-upstream-responses` scans local problem tickets for the `## Reported Upstream` back-link section (written by `/wr-itil:report-upstream` Step 7 per ADR-024), polls each upstream issue via `gh issue view` (read-only — does NOT trip the ADR-028 external-comms gate), diffs the response against `docs/problems/.outbound-responses-cache.json`, and surfaces five response classes:

- `NEW` — new comments since last check (with delta count)
- `STATE` — upstream state changed (OPEN → CLOSED, REOPENED, etc.)
- `LABEL` — labels added or removed
- `NONE` — no change since last check
- `FAIL` — gh poll error (surfaced per-ticket; pass continues for others)

Cache + audit-log mirror ADR-062's inbound shapes:

- Cache: `docs/problems/.outbound-responses-cache.json` (mirrors `.upstream-cache.json` per ADR-031)
- Audit-log: `docs/audits/outbound-responses-log.md` (mirrors `inbound-discovery-log.md` per CLAUDE.md P131)

AFK-safe by construction: no `AskUserQuestion` calls, no external-comms gate triggers, no auto-posting back to upstream issues. Partial-failure exit code (2) lets AFK orchestrators distinguish "some URLs unreachable" from "everything broke" without halting the loop. Future iter wires `/wr-itil:work-problems` Step 0c pre-flight invocation (sibling to Step 0b inbound staleness check per ADR-062 Confirmation #5); Phase 1 ships manual-invocation only.

Phase 2 (external-reporter-as-our-reporter — plugin users polling responses to reports they filed against THIS repo) remains scheduled-future-surface per P179 deferred-with-scheduled-future-surface pattern.

Components:

- `packages/itil/skills/check-upstream-responses/SKILL.md` — skill contract
- `packages/itil/scripts/check-upstream-responses.sh` — diagnose+act script body
- `packages/itil/bin/wr-itil-check-upstream-responses` — `$PATH`-resolved bin shim per ADR-049
- `packages/itil/scripts/test/check-upstream-responses.bats` — 13 behavioural tests covering: existence, discovery, skip-without-section, cache-match-to-NONE, new-comments-to-NEW with delta, state-change-to-STATE, cache write, audit-log append, --ticket filter, RFC-002 dual-tolerant subdir layout, partial-failure exit 2, --force-recheck

ADR amendments (within existing reassessment windows; no new ADRs):

- ADR-014 commit-message-convention table gains `chore(problems): check upstream responses — <N> polled, <M> new` row.
- ADR-024 Confirmation amended (back-link section URL field now load-bearing for two skills: `/wr-itil:report-upstream` writes it, `/wr-itil:check-upstream-responses` reads it).
- ADR-062 `## Related` amended with forward-pointer to P249 Phase 1 outbound-response-check sibling.

Architect verdict 2026-05-18: APPROVED with 4 amendments (cache filename disambiguation, audit-log-only output, ADR-014 row, ADR-024+ADR-062 cross-references) — all landed in this commit.

JTBD verdict 2026-05-18: PASS — JTBD-004 (Connect Agents Across Repos to Collaborate) primary anchor; JTBD-001 (governance without slowing down), JTBD-006 (AFK-safe), JTBD-201 (audit trail), JTBD-202 (pre-flight checks) secondary fits.

P249 transitions Open → Known Error at this commit (Phase 1 fix released; Phase 2 remains open as scheduled-future-surface).

Closes P249 Phase 1.
