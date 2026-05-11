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

- `wr-itil-p165-readme-refresh-discipline.md` — `@windyroad/itil` **patch** (P165). Held 2026-05-12 per ADR-042 Rule 2 auto-apply by `/wr-itil:work-problems` Step 6.5. Risk scorer R003 new-hook-landing modulator drove release-layer residual to 8/25 (Medium) above-appetite; held-changeset move drops the modulator from +1 to -1 after dogfood window. **Reinstate trigger**: ≥7 days in-repo dogfood with no false-positive deny observed in iter subprocess commits (review at next `/wr-itil:work-problems` Step 6.5 ≥ 2026-05-19), OR risk scorer downgrades release residual ≤ 4/25 on re-evaluation per ADR-061 dogfood-graduation symmetric balance.

## Recently reinstated

- `p100-retrospective-briefing-migration.md` — `@windyroad/retrospective` **minor**. Held during P100 slice 1 pending slice 2. Reinstated 2026-04-22 when slice 2 (SessionStart hook + ADR-040 + stub retirement) landed; scope body expanded to cover slice 1 + slice 2 combined.
- `wr-itil-p085-assistant-output-gate.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold, never part of P170 atomic-graduation cohort; user-comfort signal after 12-day dogfood window with no observed false-positive incidents).
- `wr-risk-scorer-p064-external-comms-gate.md` — `@windyroad/risk-scorer` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold; user-comfort signal after 10-day dogfood window — gate behaviour observed clean across `/wr-risk-scorer:assess-external-comms` invocations + changeset author surface).
- `wr-retrospective-p159-readme-jtbd-currency-hook.md` — `@windyroad/retrospective` **minor**. Reinstated 2026-05-06 per I001 Hypothesis 3 mitigation (orthogonal-gate hold; user-comfort signal after 2-day dogfood window — load-bearing-from-the-start commit-hook fired clean across all session commits including this iteration's RFC framework slice work).
- `wr-itil-p170-rfc-framework-phase-1.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (atomic-cohort graduation per ADR-060 finding 12; forward-dogfood Slice 5 closed; user-comfort signal via I002 declaration + "you are empowered" direction).
- `wr-itil-p170-rfc-framework-phase-1-slice-3.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (sibling of Phase 1 hold; same atomic-cohort).
- `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (sibling of Phase 1 hold; same atomic-cohort).
- `wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (sibling of Phase 1 hold; same atomic-cohort).
- `wr-itil-p170-slice-4-b7-capture-problem-type-prompt.md` — `@windyroad/itil` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (sibling of Phase 1 hold; same atomic-cohort).
- `wr-architect-jtbd-rfc-002-t1-glob-widening.md` — `@windyroad/architect` + `@windyroad/jtbd` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T1; part of RFC-001+RFC-002 atomic chain; Slice 5 closed).
- `wr-itil-retrospective-rfc-002-t2-dual-tolerant-skill-globs.md` — `@windyroad/itil` + `@windyroad/retrospective` **minor**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T2; same atomic-cohort).
- `wr-itil-rfc-002-t3-bats-dual-tolerant-coverage.md` — `@windyroad/itil` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T3; same atomic-cohort).
- `wr-itil-rfc-002-t4-reconcile-readme-dual-tolerant.md` — `@windyroad/itil` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T4; the dual-tolerant reconcile-readme fix that was blocking adopter cache freshness — now graduates).
- `wr-itil-rfc-002-t2-fixup-flag-order-for-structural-test.md` — `@windyroad/itil` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T2 fix-up; same atomic-cohort).
- `wr-risk-scorer-rfc-002-t5-bulk-migration.md` — `@windyroad/risk-scorer` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (RFC-002 T5a; same atomic-cohort).
- `wr-itil-p178-skip-state-machine-gates-capture.md` — `@windyroad/itil` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (P178 capture; same atomic-cohort per the originally-documented sibling shape).
- `wr-itil-p179-defer-discipline-capture.md` — `@windyroad/itil` **patch**. Reinstated 2026-05-10 per I002 mitigation H3 (P179 capture; same atomic-cohort per the originally-documented sibling shape).

## Related

- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — authoritative basis. Rule 7 blesses this convention; Rule 2 + Rule 2a define the open vocabulary under which the orchestrator decides to apply `move-to-holding`; Rule 6 mandates the README audit append.
- **P103** (closed by ADR-042) — behavioural driver: orchestrator escalated resolved release decisions instead of auto-applying.
- **P104** (closed by ADR-042) — structural driver: partial-progress painted the release queue into a corner.
- **ADR-018** (Inter-iteration release cadence for AFK loops) — at-or-below-appetite drain. Above-appetite governed by ADR-042.
- **ADR-020** (Governance auto-release for non-AFK flows) — symmetric non-AFK rule. Above-appetite governed by ADR-042.
- **JTBD-006 (Progress the Backlog While I'm Away)** — the persona-job this pattern serves.
- **JTBD-101 (Extend the Suite with New Plugins)** — the plugin-developer pattern: preserve changeset intent across multi-slice work without breaking changesets-CLI semantics.
