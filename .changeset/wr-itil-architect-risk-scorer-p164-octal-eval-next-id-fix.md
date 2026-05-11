---
"@windyroad/itil": patch
"@windyroad/architect": patch
"@windyroad/risk-scorer": patch
---

P164 — apply `10#` base-10 prefix to next-ID formula across 6 ticket-creator skills to prevent latent octal-eval failure at the `099 → 100` ID transition

**Bug shape**: The next-ID formula `next=$(printf '%03d' $(( $(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))` in 6 ticket-creator SKILL.md files passes its zero-padded ID string through bash's `$(( ... ))` arithmetic context. Bash treats leading-zero numbers as octal; `099` is invalid octal (digit ≥ 8) and bash emits `bash: 099: value too great for base (error token is "099")`, exiting non-zero before the skill writes its marker, before opening the file. The user sees a cryptic bash error.

**Trigger**: latent until any ticket-creator surface's `local_max` returns `099`. Fires once per surface per project lifetime (the 099 → 100 transition). Has not yet fired in this repo because problem-ticket IDs already crossed 099 before this formula's shape solidified, but any new ticket-creator surface (or any adopter project today) hits the bug as soon as their backlog reaches 099 entries.

**Fix**: standard `10#` base-10 prefix on the inner `$(echo ... | sort -n | tail -1)` expansion. Applied uniformly across all 6 affected SKILL.md (scope expanded from the originally-named 4 to 6 after grep verification per the ticket's Investigation Task):

- `packages/itil/skills/manage-problem/SKILL.md` Step 3
- `packages/itil/skills/capture-problem/SKILL.md` Step 2
- `packages/itil/skills/capture-rfc/SKILL.md` Step 2
- `packages/architect/skills/create-adr/SKILL.md` Step 3
- `packages/architect/skills/capture-adr/SKILL.md` Step 2
- `packages/risk-scorer/skills/create-risk/SKILL.md`

**Regression coverage**:

- `packages/architect/skills/capture-adr/test/capture-adr.bats` test 6 — synthetic `098-foo.proposed.md` + `099-bar.proposed.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
- `packages/itil/skills/capture-problem/test/capture-problem.bats` test 21 — synthetic `098-foo.open.md` + `099-bar.open.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
- Existing 26 bats updated in-place with `10#` prefix; full 28-test contract bats green.
- Manual sanity check confirms unfixed formula fires the documented octal error and fixed formula returns `100`.

**Why three packages in one changeset**: ADR-014 single-purpose grain — one logical change (the octal-eval defect) across three package boundaries that share the next-ID formula shape. Per ADR-014 "one logical change across multiple files / packages" guidance, the grain holds. The bats fixtures and SKILL.md edits are byte-symmetric across packages by design.

**Shared helper deferred**: the ticket's optional Investigation Task to extract a shared `lib/next-id.sh` is deferred. DRY benefit is small (~6 byte-identical formulas) versus the regression risk of introducing sourcing-order coupling across 6 currently-independent skills. Re-evaluate if a 7th ticket-creator surface lands.

**ADR alignment**:

- ADR-014 (one ticket = one commit) — holds; one logical change.
- ADR-019 (orchestrator preflight) — unaffected; preflight is about origin fetch, not ID computation.
- ADR-031 (per-state subdir layout) — unaffected; formula input glob unchanged.
- ADR-044 (decision-delegation contract) — aligned; one viable shape (`10#` is the standard bash idiom); scope-expansion from 4 → 6 is empirical evidence-driven (grep verified), exactly the framework-mediated mechanical action ADR-044 endorses.
- ADR-052 (behavioural tests default) — aligned; new regression tests assert formula output not SKILL.md prose.
- ADR-055 (namespace-prefixed IDs) — unaffected; no shipped-artefact IDs touched.

**JTBD alignment**:

- JTBD-301 (Report a Problem Without Pre-Classifying It) — primary; a cryptic `bash: 099: value too great for base` failure at ID rollover would break the "under 2 minutes or the report will be abandoned" constraint.
- JTBD-001 (Enforce Governance Without Slowing Down) — composes; ticket-creator skills are the substrate that lets solo-developers and tech-leads create ADRs, problems, RFCs, and risks automatically.
- JTBD-201 (Restore Service Fast with an Audit Trail) — composes; reliable next-ID computation is load-bearing for the audit trail.

Refs: P164
