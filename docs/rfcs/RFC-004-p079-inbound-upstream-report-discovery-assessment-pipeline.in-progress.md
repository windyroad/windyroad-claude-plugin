---
status: in-progress
rfc-id: p079-inbound-upstream-report-discovery-assessment-pipeline
reported: 2026-05-15
decision-makers: [Tom Howard]
problems: [P079]
adrs: [ADR-062, ADR-015]
jtbd: [JTBD-001, JTBD-005, JTBD-006, JTBD-101, JTBD-201, JTBD-202, JTBD-301]
---

# RFC-004: P079 inbound upstream-report discovery + assessment pipeline (ADR-062 implementation rollout)

**Status**: in-progress
**Reported**: 2026-05-15
**Problems**: P079
**ADRs**: ADR-062, ADR-015
**JTBD**: JTBD-001, JTBD-005, JTBD-006, JTBD-101, JTBD-201, JTBD-202, JTBD-301

## Summary

Ships the inbound discovery + assessment pipeline framework that closes P079's invisible-inbound-report gap. Peer of ADR-024's outbound contract. Decomposed across seven slices (A-G per P079's 2026-05-14 RCA extensions); Slices A and D landed under commit `ca4f6e4` as the foundational architecture scaffold. This RFC captures the remaining execution and the integration seam for P129's version-aware classifier carve-out.

## Driving problem trace

**P079** (`docs/problems/open/079-no-inbound-sync-of-upstream-reported-problems.md`) — plugin-user files a structured `problem-report.yml` issue on `windyroad/agent-plugins`; report sits in `gh issue list` until the maintainer remembers to look; `/wr-itil:manage-problem review` and `/wr-itil:work-problems` are local-only and never surface it. Breaks the end-to-end promise of P055 (intake templates) + ADR-024 (outbound contract) + ADR-036 (downstream scaffold) + JTBD-301 (plugin-user persona's "Report a Problem Without Pre-Classifying It"). User direction (2026-04-21 + 2026-04-26 interactive AskUserQuestion resolution) extended the close-the-loop work into a multi-step assessment pipeline (JTBD alignment + dual-axis risk + branches to {auto-acknowledge with local ticket | pushback comment | policy-violation close with verdict comment}, all external comms riding P064 + P038 gates per ADR-028 amended). ADR-062 pins all design decisions; this RFC carries execution.

## Scope

**In scope (this RFC):**

- Implementation of ADR-062's Decision Outcome across seven slices (A-G per P079's 2026-05-14 RCA extensions). Slices A + D landed in commit `ca4f6e4` as the foundational scaffold; B/C/E/F/G outstanding.
- Channel config + cache JSON schemas at `docs/problems/.upstream-channels.json` + `docs/problems/.upstream-cache.json` (Slice A — shipped).
- `/wr-itil:review-problems` Step 8.5 inbound-discovery sub-step + six-step assessment pipeline (Slice C).
- Sibling subagent `wr-risk-scorer:inbound-report` (NOT extension of `:external-comms`) + on-demand skill `/wr-risk-scorer:assess-inbound-report` (Slice B).
- `RISK-POLICY.md` `## Inbound Report Risk Classes` amendment enumerating Request-risk + Fix-risk classes (Slice B).
- ADR-015 Scope table extension with the `wr-risk-scorer:inbound-report` row (Slice B).
- Audit-log file `docs/audits/inbound-discovery-log.md` with the documented append shape (Slice D — shipped; ADR-062 § Confirmation criterion 4 audit-log-shape extension lands here).
- Bats coverage per ADR-037 + P081 — behavioural (synthetic-channel fixture; six pipeline outcomes route correctly; cache contract + TTL; subagent prompt contract; README render contract; anti-`AskUserQuestion` assertion on the pipeline path to protect the P132 mechanical-stage carve-out) (Slice E).
- `--force-upstream-recheck` flag wiring + TTL-expiry auto-recheck (Slice F).
- `## Inbound Upstream Reports` section renderer in `docs/problems/README.md` Step 9e (Slice G).
- Integration seam for P129 at pipeline Step 1 (the version-aware classifier carve-out plugs in here when it lands; this RFC reserves the seam, does not implement the classifier).

**Out of scope (deferred to separate tickets / RFCs):**

- **P129** — version-aware classification (pipeline Step 1 implementation); separate carve-out ticket.
- **P128** — outbound Versions schema; already shipped per ADR-033 amendment 2026-05-03.
- **P123** — blocked-user-list enforcement; separate ticket per ADR-046's enforcement extension. This RFC's clear-malicious branch writes to the audit-log only until P123 lands.
- **P080** — bidirectional outbound-lifecycle update; outbound-direction sibling.
- Auto-resolution detection (P079 sub-concern 7); carve-out candidate; deferred.
- Duplicate-detection-bot comment classification (P079 sub-concern 5); carve-out candidate; deferred.
- Time-pressure deadline tracking (P079 sub-concern 6); carve-out candidate; deferred.

## Tasks

Ordered A → D → B → C → E → F → G per P079's "lightest first, gives a working scaffold, then enriches" rationale. Each unshipped slice is one ADR-014-grain commit candidate.

- [x] **Slice A** — channel-config + cache JSON schema files committed; `/wr-itil:review-problems` SKILL.md Step 8.5 contract documentation (shipped commit `ca4f6e4`).
- [x] **Slice D** — audit-log file scaffold at `docs/audits/inbound-discovery-log.md` with documented append shape; ADR-062 § Confirmation criterion 4 audit-log-shape extension (shipped commit `ca4f6e4`).
- [x] **Slice B** — `wr-risk-scorer:inbound-report` subagent (`packages/risk-scorer/agents/inbound-report.md`) + `/wr-risk-scorer:assess-inbound-report` on-demand skill (`packages/risk-scorer/skills/assess-inbound-report/SKILL.md`); `RISK-POLICY.md` `## Inbound Report Risk Classes` amendment (Request-risk + Fix-risk classes); ADR-015 Scope table row + Confirmation checkbox + Related entry (shipped `<this commit>`). Bats coverage deferred to Slice E per RFC scope.
- [x] **Slice C** — `/wr-itil:review-problems` Step 4.5 implementation (ADR-062 § Step 8.5; numbering reconciled per the SKILL.md naming-reconciliation note): `gh issue list` / `gh api discussions` / `gh api security-advisories` polling, cache write, P070 semantic-comparator matched-local-ticket cross-reference comment, six-step pipeline orchestration (version-aware-classification stub-seam / JTBD-alignment classifier / dual-axis risk classifier / above-threshold-pushback / clear-malicious-close-with-verdict / safe-and-valid-local-ticket-create), per-branch gate-denial sub-branch handling, audit-log append, fail-soft GH API handling, AFK-loop silent path. `--force-upstream-recheck` parsed as Slice C string-match stub (SLICE-C-FLAG-STUB marker; Slice F replaces with parsed-flag variable). Shipped `<this commit>`.
- [ ] **Slice E** — bats coverage per ADR-037 + P081 (behavioural). Synthetic-channel fixture exercising each of the six pipeline outcomes; cache TTL contract; `--force-upstream-recheck` flag contract; subagent prompt contract (`INBOUND_REPORT_VERDICT` + `INBOUND_REPORT_KEY`); README `## Inbound Upstream Reports` renderer contract; **anti-`AskUserQuestion` assertion** on the pipeline path (load-bearing test protecting JTBD-001 + JTBD-006 against inverse-P078 drift per P132 mechanical-stage carve-out).
- [ ] **Slice F** — `--force-upstream-recheck` flag wiring on `/wr-itil:review-problems` invocation + TTL-expiry auto-recheck branch (when cache age > `ttl_seconds`, force recheck without flag).
- [ ] **Slice G** — `## Inbound Upstream Reports` section renderer in `docs/problems/README.md` Step 9e: `{ #issue, title, author, date, classification, matched-local-ticket? }` columns.

## Commits

Maintained automatically by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12 (lands in Slice 3 task B5.T9; until then, this list is hand-curated).

- `ca4f6e4` — Slice A + D scaffold per ADR-062 (channel-config + cache JSON schemas + audit-log file)
- `0e41f87` — ADR-062 + P079 RCA extensions — inbound discovery + assessment pipeline (peer of ADR-024)
- `f41925f` — capture RFC-004 (skeleton at proposed)
- `63b3feb` — accepted transition (populate Scope + Tasks + Related)
- `f635470` — Slice B + accepted → in-progress transition (inbound-report subagent + assess-inbound-report skill + RISK-POLICY `## Inbound Report Risk Classes` + ADR-015 Scope row)
- `<this commit>` — Slice C (review-problems Step 4.5 orchestration: channel poll + cache + P070 cross-reference + six-step pipeline + audit-log + fail-soft)

## Related

- **P079** — driving problem ticket. `docs/problems/open/079-no-inbound-sync-of-upstream-reported-problems.md`.
- **ADR-062** — Inbound upstream-report discovery + assessment pipeline (peer of ADR-024). Pins all design decisions this RFC carries.
- **ADR-024** — outbound problem-reporting contract; explicit peer of ADR-062 + this RFC.
- **ADR-028** — external-comms gate; pushback / acknowledgement / verdict comments ride P064 + P038 evaluator halves.
- **ADR-029** — Diagnose before implement; classifier follows hypothesis/evidence/structured-verdict shape.
- **ADR-031** — problem-ticket directory layout; cache + channel-config files live under `docs/problems/`.
- **ADR-036** — downstream scaffolding; downstream adopters inherit no inbound-discovery obligation (JTBD-101 non-obligation).
- **ADR-037** — bats doc-lint; behavioural coverage required per Slice E.
- **ADR-044** — decision-delegation contract; mechanical-stage carve-out is the category-4 framework-resolution boundary.
- **ADR-046** — blocked-reporters persistence; clear-malicious branch writes to audit-log (P123 enforcement extension follow-up).
- **ADR-060** — Problem-RFC-Story framework; this RFC is a canonical I1-satisfying instance.
- **ADR-014** — single-commit governance grain; each unshipped slice = one ADR-014-grain commit.
- **ADR-015** — agent scope table; Slice B amended with the `wr-risk-scorer:inbound-report` row + `/wr-risk-scorer:assess-inbound-report` skill row.
- **ADR-022** — lifecycle suffix conventions; RFC lifecycle mirrors.
- **P129** — version-aware classifier carve-out; integration seam at pipeline Step 1.
- **P128** — outbound Versions schema; consumed by P129's classifier (already shipped).
- **P123** — blocked-user list mechanism; composes with policy-violation-close branch.
- **P070** — semantic-comparator infrastructure; reused for matched-local-ticket detection at the cache layer.
- **P080** — bidirectional outbound-lifecycle update; outbound-direction sibling.
- **P132** + inverse-P078 — mechanical-stage carve-out; load-bearing for Slice E's anti-`AskUserQuestion` behavioural test.
- **JTBD-301** (plugin-user — Report a Problem Without Pre-Classifying It) — driving persona; verdict-on-close requirement is non-negotiable.
- **JTBD-001** (solo-developer — Enforce Governance Without Slowing Down) — mechanical-stage carve-out preserves "without slowing down".
- **JTBD-005** (solo-developer — Invoke Governance Assessments On Demand) — `/wr-risk-scorer:assess-inbound-report` is the pre-flight surface added in Slice B (added to RFC-004 frontmatter 2026-05-15 after JTBD review surfaced the under-trace).
- **JTBD-006** (solo-developer — Progress the Backlog While I'm Away) — AFK orchestrator throughput protected by branch-deterministic pipeline.
- **JTBD-101** (plugin-developer — Extend the Suite with New Plugins) — downstream-adopter non-obligation prevents ceremony-tax accumulation.
- **JTBD-201** (tech-lead — Restore Service Fast with an Audit Trail) — audit-log surface satisfies replay-ability.
- **JTBD-202** (tech-lead — Run Pre-Flight Governance Checks Before Release or Handover) — `--force-upstream-recheck` flag is the pre-flight on-demand surface.
