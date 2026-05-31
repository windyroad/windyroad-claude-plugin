---
"@windyroad/itil": minor
---

P346 Phase 3 — wire hang-off-check subagent into capture/manage Step 2

Companion to the prior Phase 3 changeset that shipped the subagent
itself. This entry covers wiring the subagent into its two calling
SKILL surfaces:

- `/wr-itil:capture-problem` Step 2 — split into 2a (existing
  title-only grep) + 2b (NEW mechanical pre-filter + hang-off-check
  dispatch on non-empty filtered set ≤5 candidates per ADR-032
  latency-bound + JTBD-001 60s flow budget).

- `/wr-itil:manage-problem` Step 2 — adds sub-step 2.8 with parallel
  shape. JTBD-301 firewall: dispatch is skipped when ingesting
  plugin-user-reported issues from `.github/ISSUE_TEMPLATE/problem-
  report.yml` (preserves the existing Step 1.5 firewall pattern —
  plugin-user descriptions do not carry maintainer-internal authorial
  intent).

Both sites: verdict-acts deterministically. `HANG_OFF: P<NNN>` halts
the new-ticket creation and emits a structured directive for the
orchestrator to amend the named parent (Investigation Tasks expansion
/ Phase N section). `PROCEED_NEW` continues and appends the
subagent's rationale + per-candidate explanation to the new ticket's
`## Related` section as the audit trail per ADR-026 grounding +
JTBD-201 audit-trail completeness.

AFK safe-default preserved: `--no-prompt` still dispatches the
subagent (the verdict is non-interactive by construction — no
`AskUserQuestion`); ambiguous-multi-parent collapses to `PROCEED_NEW`
per the subagent's Rule 6 contract. Satisfies JTBD-006's "decisions
normally requiring my input are resolved using safe defaults."

Closes the wrongly-captured-sibling failure mode at the SKILL surface
(prior changeset closed it at the subagent surface). The
P347-vs-P346 regression case from 2026-05-31 is the canonical
behavioural trace; bats coverage at
`packages/itil/agents/test/hang-off-check.bats` (32 structural
assertions per ADR-052 Surface 2) verifies the wired contract.
