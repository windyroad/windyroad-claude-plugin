---
"@windyroad/itil": minor
---

RFC-004 Slice C: review-problems Step 4.5 inbound-discovery + assessment-pipeline

Implements `/wr-itil:review-problems` Step 4.5 (ADR-062 § Step 8.5 / Decision
Outcome) per RFC-004 Slice C. Wires the runtime orchestration that activates
the channel-config + cache + audit-log scaffold (Slice A + D, shipped
`ca4f6e4`) and consumes the `wr-risk-scorer:inbound-report` subagent
(Slice B, shipped `f635470`).

The step polls three GitHub channels (`github-issues` / `github-discussions` /
`github-security-advisories`), matches fresh reports against local tickets via
P070's semantic-comparator, and routes unmatched reports through the
six-step assessment pipeline:

1. Version-aware classification (P129 carve-out — stub seam; skipped until P129
   lands).
2. JTBD-alignment classifier (`wr-jtbd:agent`): three outcomes —
   aligned-with-existing-JTBD / aligned-with-new-JTBD-for-existing-persona /
   not-aligned.
3. Dual-axis risk classifier (`wr-risk-scorer:inbound-report` from Slice B):
   four outcomes — safe-low-fix-risk / safe-high-fix-risk /
   above-threshold-risk / clear-malicious-request.
4. Above-threshold-pushback branch: gated `gh issue comment` declining the
   report (external-comms gate per ADR-028 amended).
5. Clear-malicious branch: brief gated verdict comment BEFORE close (JTBD-301
   acknowledgement contract — silent close forbidden). Append handle to
   `docs/audits/inbound-discovery-log.md` for P123 block-list future
   consumption.
6. Safe-and-valid branch: invoke `/wr-itil:capture-problem --no-prompt
   <body-verbatim>` (default `type=technical`; maintainer re-classifies at
   next interactive review-problems re-rate) + gated acknowledgement
   `gh issue comment` carrying the new local-ticket reference.

JTBD-301 acknowledgement contract honored on the matched-local-ticket path
too: P070 semantic-comparator hit posts a gated cross-reference comment naming
the local ticket (silent-skip would break "every report receives a verdict").

Mechanical-stage carve-out (P132 / ADR-044 category 4 silent framework
action): branch decisions resolve from JTBD-alignment + dual-axis-risk
verdicts; Step 4.5 does NOT use `AskUserQuestion` at the branch decision.
AFK orchestrator (`/wr-itil:work-problems` Step 6.5) calls into Step 4.5
silently; user-attention surfaces only at existing external-comms gates
(known interrupt class per ADR-028).

Fail-soft contract: any error in Step 4.5 emits advisory and continues to
Step 5 README rewrite. Per-branch gate-denial sub-branches preserve the
report for the next pass when an external-comms gate denies a verdict /
acknowledgement / pushback comment (silent-skip would break JTBD-301).

`--force-upstream-recheck` parsed as a Slice C minimal string-match stub
(marked `SLICE-C-FLAG-STUB` in the SKILL.md prose); Slice F replaces with
proper argument parsing + TTL-expiry auto-recheck branch.

Bats coverage deferred to Slice E per RFC scope (synthetic-channel fixture
exercising each of the six pipeline outcomes + anti-`AskUserQuestion`
assertion protecting the P132 mechanical-stage carve-out).

The SKILL.md naming-reconciliation note at the top of Step 4.5 preserves the
"Step 8.5" and "Step 9e" substring anchors verbatim so ADR-062 § Confirmation
criterion 1 remains string-anchorable without mid-stream ADR amendment.

Architect PASS (5 inline-prose hardenings folded in). JTBD PASS (no gaps).
External-comms substantive PASS (no Confidential Information class matched —
project-internal artefact IDs only); gate-key bypass per P166 (agents lack
Bash for shasum). Pipeline PROCEED.
