# Problem 249: No process for issue reporters to check for responses — symmetric gap to inbound discovery

**Status**: Verifying
**Reported**: 2026-05-17
**Phase 1 fix landed**: 2026-05-18 — `/wr-itil:check-upstream-responses` skill ships us-as-upstream-reporter polling surface. Phase 2 (external-reporter-as-our-reporter) remains scheduled-future-surface per P179.
**Fix released**: 2026-05-18 (`@windyroad/itil@0.34.0`, source commit `49dd0ba`; consumed in version-packages commit `11caa25` 2026-05-17 23:41:35 UTC, merged via PR #144 / merge commit `5388ba3` 2026-05-18 09:46:05 AEST; current ships at 0.35.2)
**Priority**: 9 (Medium) — Impact: 3 (Moderate — symmetric gap leaves reporters without acknowledgement signal; degrades inbound-channel quality and the feedback loop completing ADR-062's "every submitted report receives a verdict" contract) × Likelihood: 3 (Possible — fires whenever we report upstream via `/wr-itil:report-upstream` AND whenever an external reporter files via our intake)
**Effort**: M (Phase 1 landed; Phase 2 estimated S — composes with existing `.github/ISSUE_TEMPLATE/problem-report.yml` intake surface)
**WSJF**: 9/2 = **4.5** (raw Priority/Effort retained per README display convention; Known Error → Verifying on release per ADR-022 P143 fold-fix amendment; Phase 1 ships in 0.34.0; awaiting in-loop verification window — 5 AFK iterations across ≥2 sessions per § Verification (post-release); Phase 2 remains Open as scheduled-future-surface per P179)

## Description

You've made changes to the itil plugin to check for issues that have been reported by users (inbound discovery / assessment pipeline — P079 / ADR-062 / `/wr-itil:report-upstream`), but there is an issue now that those that report issues don't have any regular process for checking for responses.

The symmetric gap: we built the half where WE (the maintainer) detect inbound issues filed against our projects. But the reporter side — the persona that filed the issue — has no regular process for checking whether their report has been acknowledged, triaged, transitioned, or resolved.

**Two interpretations of "reporter", both valid**:

1. **Internal reporter (us reporting upstream)**: when we use `/wr-itil:report-upstream` to file an issue against an upstream repository (e.g. anthropics/claude-code, or a downstream plugin user's project), we have no regular process to check whether the upstream maintainer has responded, triaged, or closed our report. We file and forget; responses sit in GitHub unread until we manually visit the issue. Sibling to P080 (bidirectional update — the other direction: we should push status back to upstream-reported tickets we've ingested).

2. **External reporter (plugin user reporting to us)**: when a plugin user files an issue against our repo via `.github/ISSUE_TEMPLATE/problem-report.yml`, they have no regular process to check whether we (the maintainer) have triaged, ingested via `/wr-itil:report-upstream`'s inbound counterpart, or transitioned the ticket. They get GitHub's default notification once, then nothing structured.

Both interpretations are gaps. Both deserve the same shape of fix: a regular "check for responses to issues I reported" surface. The shape differs per persona:
- For us: a `/wr-itil:check-upstream-responses` skill (or hook on session start) that polls the GitHub issues we've filed and surfaces new responses.
- For external reporters: better triage feedback (e.g. ack comments per inbound report — P229 captures the bureaucratic-ack-comments anti-pattern; that's the inverse axis of THIS ticket).

## Symptoms

(deferred to investigation)

Initial signal: P229 (inbound discovery ack comments are bureaucratic, not verdict-shaped, JTBD-301 violation) is the inverse of this ticket. P229 says our ack-back to external reporters is the wrong shape. This ticket says THE WHOLE FEEDBACK LOOP from our side back to the reporter (us-as-reporter checking upstream; external-reporter checking us) doesn't exist as a structured surface.

## Workaround

Currently manual: visit the GitHub issue URL directly to see if there's a response. No batched view, no notification surface, no `/wr-itil:`-prefixed slash command.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — initial: every reporter persona (us-as-upstream-reporter; plugin-user-as-our-reporter; external-repo-reporter per P072).
- **Frequency**: per-report cycle — every report has the gap; gap fires whenever the reporter wonders "did anything happen?".
- **Severity**: (deferred to investigation) — initial: moderate. The feedback-loop gap erodes the trust that the inbound discovery half builds. Asymmetric surfaces (we observe inbound; reporters can't observe outbound) feel half-done.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems (2026-05-17 re-rated to 9/2 = 4.5)
- [x] Investigate root cause — ADR-062 designed the inbound discovery surface but did NOT specify the outbound symmetric counterpart. Framing was "inbound is the gap; outbound is the existing user-driven manual polling". The asymmetry is the gap: ADR-062's inbound assessment pipeline auto-polls + classifies + acknowledges, but the outbound axis was left as "user remembers to check the upstream issue URL".
- [x] Decide scope — split per P016 multi-concern: Phase 1 = us-as-upstream-reporter (interpretation 1, simpler bounded scope: we know which upstream URLs to poll via existing `## Reported Upstream` back-link mechanism). Phase 2 = external-reporter-as-our-reporter (interpretation 2, deferred to separate iter).
- [x] Design the check-for-responses surface — Phase 1 ships as standalone skill `/wr-itil:check-upstream-responses` per architect verdict 2026-05-18 (skill > hook > sub-skill of `review-problems` — discrete intent per ADR-010 skill-granularity rule).
- [x] Create reproduction test — `packages/itil/scripts/test/check-upstream-responses.bats` (13 behavioural tests; all green). Mocks `gh` via `--gh-bin` flag for testability.
- [ ] (Phase 2, scheduled) Design external-reporter-as-our-reporter surface — composes with `.github/ISSUE_TEMPLATE/problem-report.yml` intake; structured feedback channel for plugin users.
- [ ] (Phase 2, scheduled) Cross-reference P229 (bureaucratic ack comments) — that ticket covers the SHAPE of inbound acks; Phase 2 covers the EXISTENCE of outbound feedback-from-our-side.
- [ ] (Phase 2, scheduled) Cross-reference P072 (no persona model for external repo reporter) — Phase 2 may need the external-reporter persona JTBD to land first.
- [ ] Cross-reference P080 (bidirectional update) — Phase 1 composes with P080's inverse axis (P080 pushes local status BACK to upstream; this Phase 1 pulls upstream state DOWN to local). Together they form the bidirectional outbound feedback loop.

## Dependencies

- **Blocks**: completing the upstream-reporting feedback loop (the inbound half is shipped; the outbound check-for-responses half is missing)
- **Blocked by**: potentially P072 (external-reporter persona) if interpretation 2 is in scope; potentially P080 (bidirectional update) if the surfaces compose
- **Composes with**: P079 (inbound assessment pipeline parent), P080 (bidirectional update), P229 (ack-comment shape), P072 (external-reporter persona), ADR-062 (inbound discovery)

## Fix Released

Shipped 2026-05-18 in `@windyroad/itil@0.34.0`:

- Source commit: `49dd0ba` "feat(itil): P249 Phase 1 — /wr-itil:check-upstream-responses skill ships outbound symmetric counterpart to ADR-062 inbound discovery" (2026-05-18)
- README skill-inventory follow-up: `e4e100b` "docs(itil): README skill-inventory row for /wr-itil:check-upstream-responses (P249 Phase 1 follow-up)"
- Changeset removed: `.changeset/itil-p249-phase-1-check-upstream-responses.md` (per ADR-022 P143 fold-fix — changeset removal IS the canonical fix-shipped signal)
- Version-packages commit: `11caa25` (2026-05-17 23:41:35 UTC) — `0.33.0` → `0.34.0`
- Merge PR: #144, merge commit `5388ba3` (2026-05-18 09:46:05 AEST)
- Current cache: `@windyroad/itil@0.35.2` — 3 subsequent release cycles (0.35.0 / 0.35.1 / 0.35.2) with zero regression on the `/wr-itil:check-upstream-responses` skill surface; skill SKILL.md present in cache at both 0.34.0 and 0.35.2

**Phase 1 scope (shipped)**: `/wr-itil:check-upstream-responses` skill ships us-as-upstream-reporter polling surface — script `packages/itil/scripts/check-upstream-responses.sh` + bin shim `wr-itil-check-upstream-responses` + `packages/itil/skills/check-upstream-responses/SKILL.md` + 13 behavioural bats tests (mocks `gh` via `--gh-bin` flag for testability). ADR-014 commit-message-convention table amended (new row for the `## Reported Upstream` back-link audit-log entry). ADR-024 Confirmation amended (back-link section URL field now load-bearing for two skills — `/wr-itil:report-upstream` writes it; `/wr-itil:check-upstream-responses` reads it). ADR-062 `## Related` amended (forward-pointer to P249 Phase 1 sibling — completes the symmetric inbound/outbound feedback loop at the assessment-pipeline level).

**Phase 2 scope (deferred — this ticket NOT the SFS for Phase 2)**: external-reporter-as-our-reporter surface (composes with `.github/ISSUE_TEMPLATE/problem-report.yml` intake; structured feedback channel for plugin users) remains Open as a separate concern per P179 deferred-with-scheduled-future-surface pattern. The K → V transition is gated on Phase 1 alone because Phase 1 is a self-contained shipped slice with its own user-facing surface (`/wr-itil:check-upstream-responses`); Phase 2 is a distinct user surface (intake-template structured feedback) that does NOT compose with Phase 1's polling shape — they're orthogonal halves of the symmetric gap per the ticket's own scope-split decision (Phase 1 = us-as-upstream-reporter; Phase 2 = external-reporter-as-our-reporter). Same scope-bounding shape exercised in P246 / P247 / P250 K → V transitions this session (release-vehicle citation, Phase 2 deferral via P179, single-commit grain per ADR-014, README Verification Queue insert per P186 evidence-cell shape).

**Sibling-class linkage**: Fourth K → V transition this session (after P250 iter-1, P246 iter-2, P247 iter-3) — distinct surface (skill-ship vs SKILL.md contract amendment) but identical transition shape. The K → V fold-fix shape (release-vehicle citation, Phase deferral via P179 SFS, single-commit grain per ADR-014, README Verification Queue insert per P186 evidence-cell shape) is now exercised across four distinct surfaces this session, demonstrating the pattern's portability across skill-creation (P249), SKILL.md contract amendment (P247), Step 6.5 mechanic refinement (P246), and clause-removal (P250).

Verification window remains in-flight per § Verification (post-release) — 5 AFK iterations across ≥2 sessions of low-risk iters. Recovery path: `/wr-itil:transition-problem 249 known-error` after reverting commit `49dd0ba`.

## Change Log

- **2026-05-17**: Captured via /wr-itil:capture-problem. Initial WSJF placeholder.
- **2026-05-17**: Re-rated to Priority 9 / Effort M / WSJF 4.5 via /wr-itil:review-problems.
- **2026-05-18**: Phase 1 implementation landed. Skill `/wr-itil:check-upstream-responses` + script `packages/itil/scripts/check-upstream-responses.sh` + bin shim `wr-itil-check-upstream-responses` + 13 behavioural bats tests. ADR-014 commit-message-convention table amended (new row for `chore(problems): check upstream responses ...`). ADR-024 Confirmation amended (back-link section URL field now load-bearing for two skills). ADR-062 `## Related` amended (forward-pointer to P249 Phase 1 sibling). Status: Open → Known Error (Phase 1 fix released; Phase 2 remains Open as scheduled-future-surface per P179 deferred-with-scheduled-future-surface pattern).
- **2026-05-18** (session 7 iter 4): Known Error → Verifying via `/wr-itil:work-problems` AFK loop. Fold-fix per ADR-022 P143 amendment — changeset `itil-p249-phase-1-check-upstream-responses.md` removed in version-packages commit `11caa25` (2026-05-17 23:41:35 UTC, shipped `@windyroad/itil@0.34.0`), merged via PR #144 / merge commit `5388ba3` (2026-05-18 09:46:05 AEST); current cache `@windyroad/itil@0.35.2` spans 3 subsequent release cycles (0.35.0 / 0.35.1 / 0.35.2) with zero regression on the `/wr-itil:check-upstream-responses` skill surface; cache verification confirms SKILL.md present in both 0.34.0 and 0.35.2. Architect + JTBD pre-edit reviews PASS — no new ADR required (ADR-022 P143 fold-fix + ADR-014 single-commit grain + ADR-031 per-state subdir + P186 evidence-first cell shape + ADR-024 back-link audit-log amendment + ADR-062 outbound symmetric counterpart amendment all honoured; docs/problems/ edits are gate-excluded per system-reminder READ tolerance). README Known Error Rankings row removed; Verification Queue row inserted at 2026-05-18 same-day-ID-ASC position (after P247, before P250); evidence cell carries P186-conformant default. Recovery path: `/wr-itil:transition-problem 249 known-error` after reverting commit `49dd0ba`.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P079** — no inbound sync of upstream-reported problems (parent: the inbound half this ticket is the missing outbound counterpart of)
- **P080** — no bidirectional update of upstream-reported problems (the inverse axis: we push status back to upstream-reported tickets we've ingested; together with this ticket, both directions of feedback loop are captured)
- **P229** — inbound discovery ack comments are bureaucratic, not verdict-shaped (JTBD-301 violation; covers the SHAPE of acks where this ticket covers the EXISTENCE of checks)
- **P072** — no persona models external repo reporter (if interpretation 2 in scope, the persona JTBD may need to land first)
- **P129** — P079 inbound assessment pipeline lacks version-aware classification (sibling assessment-pipeline improvement)
- **P196** — agent reports RFC document completion as fix-shipped (related: reporting semantics asymmetry)
- **ADR-062** — inbound upstream-report discovery assessment pipeline (parent ADR for the inbound half; this ticket may motivate an amendment to cover the outbound symmetric surface)
- `/wr-itil:report-upstream` SKILL.md — the report-filing surface; the natural place to chain or sibling the check-for-responses surface
- `.github/ISSUE_TEMPLATE/problem-report.yml` — the plugin-user-side inbound surface; interpretation 2 fix may compose here
