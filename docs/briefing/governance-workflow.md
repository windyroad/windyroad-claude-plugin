# Governance Workflow

Cross-session learnings about ADRs, architect and JTBD reviews, risk scoring, voice-tone, and the session-wide unifying patterns (progressive disclosure, canonical+sync, SKILL+REFERENCE).

## What You Need to Know

### The human-oversight drain is a high-yield systematic-review pattern (2026-05-25)

The ADR-066 + ADR-068 oversight mechanism (`human-oversight: confirmed` frontmatter marker + grep detector + session-start nudge + `/wr-architect:review-decisions` / `/wr-jtbd:confirm-jobs-and-personas` drains) is not just bookkeeping — running the drain **surfaces systematic decision drift**. The 2026-05-25 drain confirmed ~37 ADRs and surfaced **13 reworks (1-in-3 hit rate held all the way through)**: auto-made governance artifacts drift from intent, and confirming them one-by-one with the user is how you catch it. Worth running the drain systematically, not treating it as a formality. Two recurring drift themes the drain exposed, both now user-stated principles (see memory): (1) **automatic cadence over deferral/on-demand** — "if there's no automatic cadence / it's deferred, it doesn't happen" (drove P295/P296/P297); (2) **adopter-facing content must be self-contained** — no internal IDs or governance plumbing in published artifacts (drove P294/P298). The held ADRs awaiting rework stay unoversighted on purpose — don't write their marker until the rework lands and re-confirms.

### Slice-handoff stub markers preserve refactor seams across an RFC's lifecycle (2026-05-15)

When a slice ships a temporary stub that a later slice replaces, mark it inline with an HTML comment naming the stub + the slice that owns the replacement. Pattern observed RFC-004 Slice C → Slice F: `<!-- SLICE-C-FLAG-STUB: $ARGUMENTS string-match for --force-upstream-recheck is a Slice C minimal stub; Slice F (RFC-004) owns proper argument parsing + TTL-expiry auto-recheck. Remove this string-match when Slice F lands; replace with Slice F's parsed-flag variable. -->` The marker (a) makes the refactor seam discoverable in the source, (b) lets Slice E's bats assert the stub is present (Slice C) AND assert the stub is absent (Slice F replaced it), and (c) survives RFC document edits because it's in the runtime artefact, not the planning artefact. Architect-approved pattern (Slice C review 2026-05-15). Reusable across any multi-slice RFC with cross-slice handoffs.
<!-- signal-score: 2 | last-classified: 2026-05-15 | first-written: 2026-05-15 -->

### ADR-against-SKILL numbering reconciliation via substring anchors (2026-05-15)

When an ADR is authored against a stale view of a SKILL's step numbering (e.g. ADR-062 named "Step 8.5" / "Step 9e" but the current SKILL has only 7 steps), do NOT mid-stream-amend the ADR for naming pedantry (violates ADR-006 deliberation discipline). Instead: insert the new step at the current numbering's natural position (e.g. Step 4.5) AND preserve the ADR's substring anchors verbatim in the SKILL's prose via an HTML comment marker. Anchor preservation keeps ADR-XXX § Confirmation criterion N string-anchorable (greps for "Step 8.5" still hit) without rewriting either the ADR or the SKILL's numbering. Pattern shipped RFC-004 Slice C (2026-05-15). Architect issues 1+2 of the slice review name this contract.
<!-- signal-score: 2 | last-classified: 2026-05-15 | first-written: 2026-05-15 -->

### R009 SKILL-prose-class above-appetite is the standing catalog baseline, not a per-action regression (2026-05-15)

The pipeline scorer flags R009 (functional defects in shipped behaviour) at 8/25 Medium on every SKILL/agent-prose ship — above the 4/Low appetite. This is the **documented catalog baseline** per RISK-POLICY.md § Risk Catalog clause 3 ("standing class signal, not per-action defect"). Per-action specific controls (architect + JTBD + external-comms PASS + bats coverage on the test surface) are sufficient to proceed via acknowledged-residual + `BYPASS_RISK_GATE=1` with explicit rationale in the commit body citing clause 3. The R009 catalog floor stays Medium until P012 master harness lands behavioural synthetic-channel coverage. Observed RFC-004 Slices C/E/F/G ship cycle 2026-05-15 — every slice's pipeline scorer flagged 8/25 above-appetite for the same R009 baseline class; user-pinned direction "release and install" + the four per-action controls cited above resolved each acknowledged-residual proceed.
<!-- signal-score: 2 | last-classified: 2026-05-15 | first-written: 2026-05-15 -->


- **Risk appetite is Low (4)**. Changes scoring Medium (5+) need explicit acknowledgement. See `RISK-POLICY.md`.
- **All ADRs in `docs/decisions/` are still `.proposed.md`** — none ratified. Amendments are cheap: prefer amending over superseding. When a P-problem intersects a proposed ADR, revise the ADR rather than adding a compatibility clause.
- **ADR-002 plugin dependency graph lists `@windyroad/tdd` as standalone.** Cross-plugin features (e.g. P018 JTBD traceability, P017 shared concern-splitting helper) must update the graph explicitly; don't silently add deps.
- **Pre-2026-04-26 entries archived to [`governance-workflow-archive.md`](./governance-workflow-archive.md)** (most recently rotated 2026-05-13 per Tier 3 budget MUST_SPLIT, P145 ratio-exceeds-2x). Now covers six pre-2026-04-23 entries plus four 2026-04-23/24/25 entries on BUFD ranked-iteration rejection, gate-validates-change-not-hypothesis, auto-create-on-missing-doc pattern, and post-landing ADR cleanup. Load the archive alongside this file when full historical context is needed.

> **Sibling brief**: cross-session "what will surprise you" learnings — ADR mechanics, JTBD reviewer behaviour, the `git ls-tree` blob-SHA next-ID trap, README-refresh reconciliation, and smaller workflow gotchas — live in `governance-workflow-surprises.md` (split out 2026-05-03 per P145 MUST_SPLIT contract for Tier 3 budget compliance). Read alongside this file for the full governance-workflow surface.
