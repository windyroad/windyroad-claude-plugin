# Changesets Holding Area

> **Blessed by ADR-042** (2026-04-23). This is the authoritative mechanism for the `move-to-holding` remediation class under ADR-042's open vocabulary. See `docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md` Rules 2 + 7.

Changesets that are authored against landed commits but are **not yet ready to ship** because they belong to a multi-slice fix whose other slices have not yet landed, OR that have been auto-moved here by the orchestrator under ADR-042 Rule 2 to bring release risk within appetite. Holding them here (outside `.changeset/`) keeps the intent intact without breaking the `changesets/action@v1` Release workflow, which does not tolerate subdirectories under `.changeset/` (`ENOENT` on `.changeset/pending/changes.md` observed 2026-04-22 — the original relocation target).

## When to hold a changeset

A changeset is a candidate for holding in either of two cases:

1. **Multi-slice WIP (user-authored)**: a `minor`/`major` bump that migrates file layout or introduces behaviour whose paired consumer-side hook lives in a slice still pending architect decisions — the P104 "painted into a corner" hazard.
2. **Auto-apply under ADR-042 (orchestrator-authored)**: residual push/release risk is above appetite (≥ 5/25) and the scorer suggests `move-to-holding` as a remediation. The orchestrator decides, performs the move, re-scores, and proceeds per ADR-042 Rule 2.

## Process

1. Author the changeset against the slice's commits normally in `.changeset/`.
2. When the slice-1-without-slice-N hazard is recognised (user path) OR the orchestrator's auto-apply fires (ADR-042 path), `git mv .changeset/<name>.md docs/changesets-holding/<name>.md`.
3. Reference the holding state:
   - User path: in the parent ticket's `## Fix Strategy` or `## Design Update` section so the reinstate trigger is captured.
   - Auto-apply path: the orchestrator's iteration/skill report logs the move per ADR-042 Rule 6, and this README's "Currently held" section is appended with the parent ticket reference.
4. When the blocking slices land (user path) or the user manually decides to reinstate (auto-apply path), `git mv docs/changesets-holding/<name>.md .changeset/<name>.md` and push. The next Release workflow run picks it up. Move the entry from "Currently held" to "Recently reinstated" in this README with the reinstate date + reason.

## Currently held

- `wr-itil-p170-rfc-framework-phase-1.md` — `@windyroad/itil` **minor**. Held 2026-05-05 (Case 1 multi-slice WIP), moved here from `.changeset/` immediately after the Phase 1 framework commit `12725a3` per ADR-060 § Phase 1 item 11 + architect finding 12 atomicity. Parent ticket: P170 (`.open.md`); driving ADR: ADR-060 (`accepted`). Intent: Phase 1 of the Problem-RFC-Story framework ships under a held window per ADR-042 / P162 graduation criteria. RFC framework correctness requires forward-dogfood evidence (architect finding 14: a NEW RFC captured before its first commit and run to closure) before adopter release; representability is demonstrated separately by RFC-001 retro on P168 (Slice 4 of `docs/plans/170-rfc-framework-story-map.md`). Same shape-precedent as the P085 + P064 + P159 + P168 holds above (load-bearing-from-the-start surfaces deferring release for in-repo dogfood evidence). The entire RFC-001 commit chain graduates atomically per ADR-060 finding 12 — ADR-042 auto-apply paused until RFC-001 reaches `closed`. Reinstate trigger: forward-dogfood RFC (Slice 5) runs to closure AND held-window graduation criteria evaluated per P162 counterfactual risk assessment OR user signals comfort with framework dogfood evidence (Phase 1 Confirmation criteria 1-9) — whichever arrives first.
- `wr-itil-p170-rfc-framework-phase-1-slice-3.md` — `@windyroad/itil` **minor**. Held 2026-05-05 (sibling to `wr-itil-p170-rfc-framework-phase-1.md`), moved here from `.changeset/` immediately after Slice 3 first-half commit `4c909c8` (reconcile-rfcs.sh + wr-itil-reconcile-rfcs bin shim + 18-case behavioural bats). Same parent ticket P170 + driving ADR-060; same atomicity contract — both changesets graduate as part of the single RFC-001 commit chain per ADR-060 finding 12. Sibling-changeset shape preserves per-slice audit-trail granularity within the same held-window window. Reinstate trigger: identical to the parent Phase 1 hold above (graduates with the chain).
- `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md` — `@windyroad/itil` **minor**. Held 2026-05-06 (sibling to `wr-itil-p170-rfc-framework-phase-1.md` and `wr-itil-p170-rfc-framework-phase-1-slice-3.md`), moved here from `.changeset/` immediately after Slice 3 second-half commits `44ae0dc` (B5.T8 — skill-side primary surface for the auto-maintained `## RFCs` reverse-trace section + reconcile-rfcs reverse-trace pass) + `c6ce9cf` (B5.T9 — `Refs: RFC-<NNN>` commit-message trailer advisory hook). Closes ADR-060 Phase 1 item 10 + item 12 + Confirmation criterion 3. Same parent ticket P170 + driving ADR-060; same atomicity contract — all three sibling changesets graduate as part of the single RFC-001 commit chain per ADR-060 finding 12. Reinstate trigger: identical to the parent Phase 1 hold above (graduates with the chain).

## Recently reinstated

- `p100-retrospective-briefing-migration.md` — `@windyroad/retrospective` **minor**. Held during P100 slice 1 pending slice 2. Reinstated 2026-04-22 when slice 2 (SessionStart hook + ADR-040 + stub retirement) landed; scope body expanded to cover slice 1 + slice 2 combined.
- `wr-itil-p085-assistant-output-gate.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold, never part of P170 atomic-graduation cohort; user-comfort signal after 12-day dogfood window with no observed false-positive incidents).
- `wr-risk-scorer-p064-external-comms-gate.md` — `@windyroad/risk-scorer` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold; user-comfort signal after 10-day dogfood window — gate behaviour observed clean across `/wr-risk-scorer:assess-external-comms` invocations + changeset author surface).
- `wr-retrospective-p159-readme-jtbd-currency-hook.md` — `@windyroad/retrospective` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold; user-comfort signal after 2-day dogfood window — load-bearing-from-the-start commit-hook fired clean across all session commits including this iteration's RFC framework slice work).

## Related

- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — authoritative basis. Rule 7 blesses this convention; Rule 2 + Rule 2a define the open vocabulary under which the orchestrator decides to apply `move-to-holding`; Rule 6 mandates the README audit append.
- **P103** (closed by ADR-042) — behavioural driver: orchestrator escalated resolved release decisions instead of auto-applying.
- **P104** (closed by ADR-042) — structural driver: partial-progress painted the release queue into a corner.
- **ADR-018** (Inter-iteration release cadence for AFK loops) — at-or-below-appetite drain. Above-appetite governed by ADR-042.
- **ADR-020** (Governance auto-release for non-AFK flows) — symmetric non-AFK rule. Above-appetite governed by ADR-042.
- **JTBD-006 (Progress the Backlog While I'm Away)** — the persona-job this pattern serves.
- **JTBD-101 (Extend the Suite with New Plugins)** — the plugin-developer pattern: preserve changeset intent across multi-slice work without breaking changesets-CLI semantics.
