# Governance Workflow

Cross-session learnings about ADRs, architect/JTBD reviews, risk scoring, and voice-tone.

## What You Need to Know

### Dual-tolerant flat + per-state-subdir enumeration must dedup on ticket ID, NOT basename (2026-05-26)

When widening a script to walk both the flat (`docs/problems/<NNN>-*.<state>.md`) and per-state-subdir (`docs/problems/<state>/<NNN>-*.md`) layouts per RFC-002 T4 / ADR-031, dedup on **ticket ID** (`${base%%-*}`), not basename — the subdir layout drops the `.<state>` suffix, so the same ticket has different basenames across layouts (`182-foo.open.md` vs `182-foo.md`) and a basename key double-counts. Per-state subdir wins (run its loop second). `reconcile-readme.sh` keys on ID for this reason; architect caught it on the P182 design pass. Verify any NEW dual-tolerant consumer keys on ID (existing ones — evaluate-graduation, update-jtbd-references, edit-gates — are correct).
<!-- signal-score: 0 | last-classified: 2026-05-26 | first-written: 2026-05-26 -->

### The human-oversight drain is a high-yield systematic-review pattern (2026-05-25)

The ADR-066 + ADR-068 oversight mechanism (`human-oversight: confirmed` marker + grep detector + session-start nudge + `/wr-architect:review-decisions` / `/wr-jtbd:confirm-jobs-and-personas` drains) surfaces systematic decision drift, not just bookkeeping. The 2026-05-25 drain confirmed ~37 ADRs and surfaced 13 reworks (1-in-3 hit rate) — auto-made governance artifacts drift from intent, and confirming them one-by-one is how you catch it. Two recurring drift themes, now user-stated principles: (1) automatic cadence over deferral/on-demand ("if there's no automatic cadence, it doesn't happen"); (2) adopter-facing content must be self-contained (no internal IDs / governance plumbing in published artifacts). Held ADRs awaiting rework stay unoversighted on purpose — don't write the marker until the rework lands and re-confirms.
<!-- signal-score: 2 | last-classified: 2026-05-25 | first-written: 2026-05-25 -->

### Slice-handoff stub markers preserve refactor seams across an RFC's lifecycle (2026-05-15)

When a slice ships a temporary stub a later slice replaces, mark it inline with an HTML comment naming the stub + the slice that owns the replacement (e.g. `<!-- SLICE-C-FLAG-STUB: ... Slice F owns proper parsing; remove when Slice F lands -->`). The marker makes the seam discoverable, lets the test surface assert stub-present (early slice) and stub-absent (later slice), and survives RFC-document edits because it lives in the runtime artefact. Architect-approved; reusable across any multi-slice RFC.
<!-- signal-score: 2 | last-classified: 2026-05-25 | first-written: 2026-05-15 -->

### ADR-against-SKILL numbering reconciliation via substring anchors (2026-05-15)

When an ADR is authored against a stale view of a SKILL's step numbering, do NOT mid-stream-amend the ADR for naming pedantry (violates ADR-006). Instead insert the new step at the current numbering's natural position AND preserve the ADR's substring anchors verbatim via an HTML comment marker, so `ADR-XXX § Confirmation criterion N` stays grep-anchorable without rewriting either document.
<!-- signal-score: 2 | last-classified: 2026-05-25 | first-written: 2026-05-15 -->

### R009 SKILL-prose-class above-appetite is the standing catalog baseline, not a per-action regression (2026-05-15)

The pipeline scorer flags R009 (functional defects in shipped behaviour) at 8/25 Medium on every SKILL/agent-prose ship — above the 4/Low appetite. This is the documented catalog baseline per RISK-POLICY.md § Risk Catalog clause 3. Per-action controls (architect + JTBD + external-comms PASS + bats coverage) suffice to proceed via acknowledged-residual + `BYPASS_RISK_GATE=1` citing clause 3. The R009 floor stays Medium until P012 master harness lands behavioural synthetic-channel coverage.
<!-- signal-score: 2 | last-classified: 2026-05-25 | first-written: 2026-05-15 -->

- **Risk appetite is Low (4)**. Changes scoring Medium (5+) need explicit acknowledgement. See `RISK-POLICY.md`.
- **All ADRs in `docs/decisions/` are still `.proposed.md`** — none ratified. Amendments are cheap: prefer amending over superseding. When a P-problem intersects a proposed ADR, revise the ADR rather than adding a compatibility clause.
- **ADR-002 plugin dependency graph lists `@windyroad/tdd` as standalone.** Cross-plugin features must update the graph explicitly; don't silently add deps.
- **Pre-2026-04-26 entries archived to [`governance-workflow-archive.md`](./governance-workflow-archive.md)** (most recently rotated 2026-05-13 per Tier 3 budget MUST_SPLIT). Load the archive alongside this file when full historical context is needed.

> **Sibling brief**: cross-session "what will surprise you" learnings — ADR mechanics, JTBD reviewer behaviour, the `git ls-tree` blob-SHA next-ID trap, README-refresh reconciliation, and smaller workflow gotchas — live in `governance-workflow-surprises.md` (split out 2026-05-03 per P145 MUST_SPLIT). Read alongside this file for the full governance-workflow surface.
