# Problem 225: Docs-only changes should not invoke risk scorer or trigger drift detection

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

> **safe-high-fix-risk flag** (per dual-axis-risk classifier): "skip the gate when path matches `*.md`" is a classic load-bearing-safety-check-bypass shape. An over-broad allowlist could let ADR-text changes (which materially affect framework behaviour) or hook-adjacent READMEs escape review. Maintainer must adjudicate the precise allowlist scope (which docs? including `docs/decisions/`?) before merge.

## Description

The risk-scorer hooks treat documentation-only changes (problem tickets, decision records, risk reports, markdown files in `docs/`) the same as code changes. This causes: (1) wasted scoring, (2) false drift detection on architect / jtbd / style-guide gates for routine docs writes.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] **Architect call (safe-high-fix-risk)**: define the docs-only allowlist precisely. `docs/decisions/` changes are NOT docs-only — they materially affect framework behaviour. Likely scope: `docs/problems/*.md`, `docs/retros/`, `docs/audits/`, `docs/briefing/`, ticket READMEs. Excludes: `docs/decisions/`, `docs/jtbd/`, `RISK-POLICY.md`, `STYLE-GUIDE.md`, `VOICE-AND-TONE.md`, hook-adjacent READMEs.
- [ ] Each gate hook adds the docs-only short-circuit at the top: `is_docs_only_change && exit 0`.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/58
- **Pipeline classification**: **safe-high-fix-risk** (cache_audit_note: high-fix-risk-flag); route=safe-and-valid + flag.
- **Affected plugin**: all gate plugins.
- **Evidence (2026-05-23, work-problems iter 1 / P073 close)**: `/wr-retrospective:run-retro`'s mechanical Step 2d ask-hygiene trail write under `docs/retros/` tripped BOTH the architect AND JTBD `PreToolUse` edit gates, forcing 2 subagent round-trips (architect agent `a50c2e466` PASS + jtbd agent `a0ded4a3` PASS) for a pure advisory artefact. `docs/retros/` is named in this ticket's proposed docs-only allowlist (task above) but is **absent from both the architect and JTBD gate exclusion lists** today, though 70+ identically-shaped sibling retro-trail files already exist. Concrete per-iter cost: 2 agent dispatches on every AFK retro-on-exit. Surfaced as a deviation-approval at work-problems loop end; user direction 2026-05-23: append the evidence here rather than open a distinct exclusion-list-gap ticket. Quantified witness for the `docs/retros/` row of the allowlist task.
- **Evidence (2026-05-25, run-retro Step 2d, LIVE RECURRENCE)**: writing the Step 2d ask-hygiene trail `docs/retros/2026-05-25-work-problems-release-149-fix-ask-hygiene.md` again tripped BOTH gates in the same retro (architect agent `ac53ce1e6` PASS, then jtbd agent `a84f29ba1` PASS — 2 dispatches for one advisory write). **Both agents independently confirmed the gap from source this time**: architect read `architect-enforce-edit.sh` (no `docs/retros/` in the exclusion `case`, lines 42-96) and jtbd read `jtbd-enforce-edit.sh` (excludes `docs/jtbd/`, `docs/problems/`, `docs/briefing/`, `docs/story-maps/`, `docs/stories/` at lines 56-104 — but NOT `docs/retros/`). Precedent for treating `docs/retros/` as a managed skill-owned surface already exists (`itil-fictional-defer-detect.sh` P234 + `check-tickets-deferred-cause.sh` both reference `docs/retros/`). **Fix shape (architect-confirmed, ADR-amendment-worthy)**: add `docs/retros/` to BOTH `architect-enforce-edit.sh` and `jtbd-enforce-edit.sh` exclusion lists (alongside the existing `docs/problems/` / `docs/briefing/` entries), synced per the copy-sync contract; route the gate-scope change through an amendment to the gate-scope ADR. Note the safe-high-fix-risk flag above still applies — the exclusion must be scoped to `docs/retros/` exactly (not a broad `docs/*` allowlist).
