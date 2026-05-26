# Governance Workflow

Cross-session learnings about ADRs, architect/JTBD reviews, risk scoring, and voice-tone.

## What You Need to Know

### Known Error semantics: root cause + workaround, NOT "fix ready" — the RFC/fix comes AFTER (2026-05-26)

A problem reaches **Known Error** when its **root cause is identified AND a workaround is documented** — there is no fix and no RFC yet (ADR-022 is the authority; it says Known Error = "root cause confirmed, fix not yet shipped"). Only *after* Known Error do you **propose a fix**, which is what **produces the RFC**. And `Fix Released` is **not** a separate state — releasing the fix **is** the `Known Error → Verifying` transition. So the lifecycle is `Open → Known Error → Verifying → Closed`. Consequence for any fix-time gate: the RFC is required at the **propose-fix step on a Known Error**, NOT at `Open → Known Error` (a problem gets to Known Error with no fix). I (and RFC-005 F1 → ADR-072) got this wrong — placed the gate at `Open → Known Error` on a "Known Error = fix is real" misreading; the oversight drain caught it, rework = P314. **Cite ADR-022 when reasoning about Known Error / fix-time placement** — the wrong-model placement landed precisely because ADR-022 wasn't referenced. <!-- signal-score: 0 | last-classified: 2026-05-26 | first-written: 2026-05-26 -->

### Implementing an unconditional decision: do NOT invent a softer path (2026-05-26)

When implementing a ratified **unconditional / no-carve-out / no-exemption** decision, do not invent or reframe a softer variant — no "thin", "minimal", "scaled-down", or "preserved friction-guard" path. That is the **same disavowed class as the original carve-out**, just relocated. Worked failure: implementing ADR-070/071 ("every fix goes through an RFC, unconditionally"), the agent reframed the disavowed atomic-fix carve-out into a "thin RFC with empty `stories: []` / scale-down value preserved" path and propagated it into ADR-071/072, RFC-005/006, and the JTBD amendments — even citing ADR-071's own softening wording as licence. User: *"No. Same RFC. Not scaled down. No short cuts."* Captured as **P311**; corrective sweep struck the framing everywhere AND amended ADR-071's own text (a ratified ADR's wording is NOT immune — if it carries softening the user later disavows, amend it too). A structural fact (e.g. `stories: []` = an RFC not decomposed into stories) is NOT a reduced-ceremony path; never frame it as one. Memory: `feedback_no_shortcuts_no_softening`. <!-- signal-score: 0 | last-classified: 2026-05-26 | first-written: 2026-05-26 -->

### reconcile-rfcs false-flags reverse-traces on per-state-subdir tickets — verify by inspection (2026-05-26)

`wr-itil-reconcile-rfcs docs/rfcs` emits spurious `MISSING_REVERSE_TRACE RFC-NNN in PNNN ## RFCs` for problem tickets that DO carry the reverse-trace, because its reverse-trace check globs the flat `docs/problems/*.md` only and misses the per-state subdirs (`open/`, `verifying/`, …) — the RFC-002-class dual-tolerant-glob gap already fixed in `update-problem-rfcs-section.sh`. Trust direct inspection of the ticket's `## RFCs` section (or the helper that renders it) over the reconciler's MISSING lines until fixed. Pre-existing rfcs-README rankings/closed drift (RFC-001/002/003/004) is separate + real. See **P312**. <!-- signal-score: 0 | last-classified: 2026-05-26 | first-written: 2026-05-26 -->

### Dual-tolerant flat + per-state-subdir enumeration must dedup on ticket ID, NOT basename (2026-05-26)

When widening a script to walk both the flat (`docs/problems/<NNN>-*.<state>.md`) and per-state-subdir (`docs/problems/<state>/<NNN>-*.md`) layouts per RFC-002 T4 / ADR-031, dedup on **ticket ID** (`${base%%-*}`), not basename — the subdir layout drops the `.<state>` suffix, so the same ticket has different basenames across layouts (`182-foo.open.md` vs `182-foo.md`) and a basename key double-counts. Per-state subdir wins (run its loop second). `reconcile-readme.sh` keys on ID for this reason; architect caught it on the P182 design pass. Verify any NEW dual-tolerant consumer keys on ID (existing ones — evaluate-graduation, update-jtbd-references, edit-gates — are correct).
<!-- signal-score: 0 | last-classified: 2026-05-26 | first-written: 2026-05-26 -->

- **Risk appetite is Low (4)**. Changes scoring Medium (5+) need explicit acknowledgement. See `RISK-POLICY.md`.
- **All ADRs in `docs/decisions/` are still `.proposed.md`** — none ratified. Amendments are cheap: prefer amending over superseding. When a P-problem intersects a proposed ADR, revise the ADR rather than adding a compatibility clause.
- **ADR-002 plugin dependency graph lists `@windyroad/tdd` as standalone.** Cross-plugin features must update the graph explicitly; don't silently add deps.
- **Pre-2026-04-26 entries archived to [`governance-workflow-archive.md`](./governance-workflow-archive.md)** (most recently rotated 2026-05-13 per Tier 3 budget MUST_SPLIT). Load the archive alongside this file when full historical context is needed.

> **Sibling brief**: cross-session "what will surprise you" learnings — ADR mechanics, JTBD reviewer behaviour, the `git ls-tree` blob-SHA next-ID trap, README-refresh reconciliation, and smaller workflow gotchas — live in `governance-workflow-surprises.md` (split out 2026-05-03 per P145 MUST_SPLIT). Read alongside this file for the full governance-workflow surface.
