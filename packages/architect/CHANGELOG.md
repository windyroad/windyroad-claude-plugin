# @windyroad/architect

## 0.7.1

### Patch Changes

- da1a3fe: P132 Phase 2a-iii-B: `/wr-architect:create-adr` Step 2 retrofitted as the 4th adopter of the shared derive-first dispatch helper. Canonical helper relocated from `packages/itil/lib/derive-first-dispatch.sh` to `packages/shared/derive-first-dispatch.sh` per ADR-017 (architect verdict: cross-package source would have violated the self-contained-published-package property). Synced per-package copies at `packages/itil/lib/` and `packages/architect/lib/`; new `scripts/sync-derive-first-dispatch.sh` (with `--check` mode) + `npm run check:derive-first-dispatch` + CI step + drift-detection bats. create-adr SKILL.md Step 2 rewritten from single AskUserQuestion-everything to 12-field derive-first dispatch table: silent-framework cat-4 on Title (kebab from prose), status=proposed, date=today, reassessment-date=today+3mo, Context-and-Problem-Statement (verbatim from `$ARGUMENTS`), consulted/informed defaults; cat-1 direction-setting retained on Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, decision-makers (architect verdict: no silent `git config user.name` derive — multi-party-decision mis-attribution risk). 13 new ADR-044-contract bats for create-adr; 7 new drift bats for sync; 2 new 4-surface assertions in derive-first-dispatch.bats. P132 transitions Known Error → Verification Pending per ADR-022 fold-fix. Phase 2b detection hook remains DEFERRED. Full suite green.

## 0.7.0

### Minor Changes

- b60f576: P170 Phase 2 Slice 2.5 — hook exemption globs for the governance-managed story-map + story surfaces (ADR-060 § Phase 2 amendment 2026-05-12 lines 481-496). Adds path-based exemptions for `docs/story-maps/**/*.html` and `docs/stories/**/*.md` across four PreToolUse enforce-edit hooks:

  - `packages/architect/hooks/architect-enforce-edit.sh` — case-statement exemption alongside existing `docs/problems/` and `docs/jtbd/` entries
  - `packages/jtbd/hooks/jtbd-enforce-edit.sh` — same case-statement exemption pattern
  - `packages/style-guide/hooks/style-guide-enforce-edit.sh` — exemption short-circuit BEFORE the `*.css|*.html|*.jsx|...` opt-in extension check
  - `packages/voice-tone/hooks/voice-tone-enforce-edit.sh` — exemption short-circuit BEFORE the `*.html|*.jsx|...` opt-in extension check; closes the empirical block documented at P170 line 297 (STORY-MAP-001 bootstrap rejected on first HTML write)

  `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh` left untouched — it gates only `RISK-POLICY.md` and never fires on story-maps/stories paths, so no exemption is needed (the ADR's "5 hooks" framing is structurally inaccurate at this surface; documented in commit body).

  Behavioural bats coverage (per ADR-052) across all four hooks: 6 new test cases each in architect-enforce-scope + jtbd-enforce-scope (extending existing files); new style-guide-enforce-scope.bats (5 cases) + new voice-tone-enforce-scope.bats (6 cases). 159 total tests across the four affected plugins' hook suites pass with zero regressions.

  Unblocks Phase 2 Slices 3-6 (story-map skills) and Slice 14 (STORY-MAP-001 bootstrap migration) per architect finding 1 on the P170 Phase 2 Slice 3 design review 2026-05-12 — these slices were blocked because their behavioural bats fixtures must perform HTML writes that the unmodified hooks rejected outright. Takes effect for adopters (including this repo) after the next marketplace release cycle + `/install-updates` + session restart.

## 0.6.2

### Patch Changes

- d3468c4: P164 — apply `10#` base-10 prefix to next-ID formula across 6 ticket-creator skills to prevent latent octal-eval failure at the `099 → 100` ID transition

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

## 0.6.1

### Patch Changes

- 670929a: P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T1: dual-pattern hook glob widening for `docs/problems/` migration

  `packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` gain a sibling exemption pattern (`docs/problems/*/*.md` + `*/docs/problems/*/*.md`) alongside the existing flat-layout pattern (`docs/problems/*.md` + `*/docs/problems/*.md`). The dual-pattern shape is forward-compatible: the new pattern matches zero files today (the per-state subdirs do not exist yet); the existing pattern continues to exempt the current flat-layout ticket files.

  **Why this is the first sub-task of RFC-002**:

  ADR-031 § Hook exemption glob contract notes that the flat-layout pattern matches zero files post-migration (shell `*` does not cross `/`), so any subsequent commit that migrates ticket files would immediately trigger architect+jtbd edit-gate denials on its own transition bookkeeping (`git mv` + Edit + re-stage on a ticket file). ADR-031 originally required hook update + migration in ONE big landing commit to bridge this gap.

  ADR-014 single-purpose grain dominates that single-shot framing. T1 lands the dual-pattern as a separate ADR-014-grain commit BEFORE the migration; T6 (post-migration cleanup) drops the flat-layout half once T5's bulk migration verifies. The dual-pattern window spans T1 → T6 and bounds the transient layout-coexistence exposure flagged in JTBD-001 amendment-drift (per ADR-060 Reassessment criterion).

  **No current behaviour changes**:

  - Flat-layout ticket-edits continue to skip the architect+jtbd gate (existing pattern matches).
  - Per-state subdir ticket-edits (none today) would also skip the architect+jtbd gate (new pattern would match if such files existed).
  - All other file paths continue to enter the gate as before.

  **ADR-014 single-purpose grain check**: the commit changes one logical thing — the exemption-glob shape on the two enforce-edit hooks — across two package boundaries that share the same exemption contract. Per ADR-014 § "single-purpose" guidance, "one logical change across multiple files" satisfies the grain when the files share the contract being changed.

  **JTBD impact**:

  - **JTBD-001** (governance without slowing down) — neutral now; enables the directory-skimmability win when T5 ships.
  - **JTBD-101** (atomic-fix-adopter friction guard) — neutral; no new gate, no new prompt; dual-pattern preserves existing adopter behaviour.
  - **JTBD-006** (AFK orchestrator) — neutral; the hooks remain idempotent.
  - **JTBD-201** (tech-lead audit trail) — neutral now; enables the directory-as-audit-trail win when T5 ships.
  - **JTBD-301** (plugin-user no-pre-classification) — untouched.

  **Held-changeset window scope**:

  This entry lands under the ADR-060 § Confirmation criterion 6 atomicity contract — held alongside the Slice 4 entries (`wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md` + `wr-itil-p170-slice-4-b7-capture-problem-type-prompt.md`) and the Slice 2-3 entries (`wr-itil-p170-rfc-framework-phase-1.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md`). The full chain graduates atomically per architect finding 12 once RFC-001 reaches `closed` post-Slice-5 forward-dogfood (which RFC-002 itself drives to closure).

  **Out of scope (deferred to subsequent T-tasks)**:

  - T2: dual-tolerant SKILL.md glob updates across `manage-problem`, `work-problems`, `manage-incident`, `report-upstream`, `run-retro` (plus forward audit on `capture-rfc` + `manage-rfc` per architect advisory 2026-05-07).
  - T3: bats fixture audit + dual-tolerant assertions.
  - T4: `docs/problems/README.md` generation logic dual-tolerant.
  - T5: bulk migration commit (rename + ADR-031 proposed→accepted + ADR-022 / ADR-016 / ADR-024 amendments).
  - T6: drop dual-pattern compatibility post-verification.
  - T7-T11: Slice B adopter auto-migration (shared routine, manage-problem + work-problems integration, bats, ADR-014 commit-gate marker).

  Refs: RFC-002

## 0.6.0

### Minor Changes

- d28bd51: P156: ship `/wr-architect:capture-adr` skill — lightweight aside-invocation surface for ADR capture during foreground work

  Closes the heavyweight-only-capture-path gap on the architect plugin namespace (parent P014 ADR-032 child, sibling to P155's `/wr-itil:capture-problem`). The current ADR-creation surface is `/wr-architect:create-adr`, a ~10-15 turn ceremony designed for canonical new-ADR creation that walks Considered Options ≥2 (with pros/cons), Decision Drivers, full Consequences (Good/Neutral/Bad), Confirmation criteria, Pros/Cons of Options, Reassessment Criteria, plus a Step 5 confirm-with-user AskUserQuestion review pass. This is wrong for the **aside-invocation** use case where a foreground work session generates a decision worth recording but the agent / user can't afford the full ceremony.

  Three repeating patterns surfaced the friction:

  - **Mid-AFK-iter design decisions** — agent or user lands on a design choice during a foreground iter (e.g. iter 17 P137 Option C namespace-prefix; iter 19 ADR-056 Phase 2a back-channel write contract). The ~10-15 turn ceremony breaks iter cadence; decisions get buried inline in commit bodies or RCA sections.
  - **Architect-review verdict capture** — a `wr-architect:agent` review yields a substantive PASS-WITH-NOTES / ISSUES-FOUND verdict whose rationale deserves an ADR-shaped record. Today the verdict + rationale lands in commit messages and rots; future readers grep history but lose the structured trace.
  - **User-driven design conversations** — user resolves options (a)/(b)/(c) during conversational work; the settlement currently lives in a problem-ticket RCA section instead of a discoverable ADR.

  `/wr-architect:capture-adr` is the source-side fix.

  Adds:

  - `packages/architect/skills/capture-adr/SKILL.md` (~190 lines, ADR-038 progressive-disclosure budget). Steps 1-6: parse Title + 1-line Context + 1-line Decision from `$ARGUMENTS` (graceful-degradation on partial payload, halt-with-stderr-directive on empty); P056-safe `git ls-tree --name-only` next-ID formula reused from `create-adr` Step 3 (local_max + origin_max + 1); skeleton-fill MADR template with status `proposed`, full minimum frontmatter (sentinel `decision-makers: [unspecified — fill at canonical review]`, default `reassessment-date` 3 months from today), numbered-options placeholder `1. Option A (chosen) — <one-line>` + `2. (deferred — see /wr-architect:create-adr canonical review)` to preserve MADR ≥2-options surface for any doc-lint, deferred-flagged Decision Drivers / Consequences (Good/Neutral/Bad) / Confirmation / Pros-Cons / Reassessment Criteria; single Write; single commit `docs(decisions): capture ADR-<NNN> <title>` per ADR-014; trailing pointer to `/wr-architect:create-adr` for canonical expansion.
  - `packages/architect/skills/capture-adr/REFERENCE.md` — rationale (capture vs create trade-off; skeleton-MADR validity at status `proposed`; numbered-options placeholder rationale; frontmatter sentinel values vs truly minimal), edge cases (empty `$ARGUMENTS` halt, partial-payload graceful-degradation, title slug collision, ID collision with origin via P056-safe `--name-only`, captured-ADR-never-expanded path, architect-review-verdict capture pattern, cross-namespace consistency with capture-problem), composition with create-adr (auto-detect-and-expand path is follow-up scope) + wr-architect:agent (deferred-canonical-expansion contract; review fires at canonical expansion not at skeleton time) + capture-problem (compose for problem+decision capture in ~6-8 turns) + work-problems iter subprocesses (foreground-lightweight is AFK-compatible).
  - `packages/architect/skills/capture-adr/test/capture-adr.bats` — 12 behavioural tests per ADR-052: existence/wiring (SKILL.md + REFERENCE.md present, frontmatter declares `wr-architect:capture-adr`), next-ID formula (P056-safe mixed-suffix glob / empty-dir first-ADR / origin-collision-guard prefers origin_max when origin > local), skeleton-fill MADR shape (status proposed / decision-makers sentinel / Title at H1 / Context survives verbatim / Decision survives verbatim / deferred-flag literal pointer string / numbered-options placeholder), default reassessment-date 3 months from today, allowed-tools surface (no AskUserQuestion / Bash present / Write present), deferred-canonical-expansion contract presence; 12/12 green.

  Amends:

  - `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` — appends "Foreground-lightweight-capture variant — capture-adr (P156 amendment, 2026-05-03)" section after the P155 amendment block. Names the new variant under the foreground-synchronous taxonomy distinguishing **full-intake** (`/wr-architect:create-adr`, ~10-15 turns) from **lightweight-capture** sub-variants (~3-4 turns) on the architect plugin namespace, symmetric with the ITIL plugin precedent. Documents the deferred-canonical-expansion contract (no inline architect-agent review handoff; review fires at canonical expansion). Pins variant-selection precedence (foreground-lightweight is LEAD post-P156; background-capture remains deferred sibling slot per P088). Files auto-detect-and-expand path as follow-up scope under P014.

  Architectural design (zero AskUserQuestion branches per ADR-044 framework-mediated mechanical-stage carve-out):

  | Decision                                                                           | Resolution                                                                                                                                                                            |
  | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | Considered Options ≥2                                                              | Mechanical skeleton placeholder (`1. Option A (chosen)` + `2. (deferred — see /wr-architect:create-adr canonical review)`); MADR enforcement deferred to canonical-acceptance review. |
  | Decision Drivers / Consequences / Confirmation / Pros-Cons / Reassessment-criteria | Framework-policy deferred flag (literal pointer string `(deferred to /wr-architect:create-adr canonical review)`).                                                                    |
  | Reassessment-date                                                                  | Framework-policy default 3 months from today (matches create-adr Step 4).                                                                                                             |
  | decision-makers / consulted / informed                                             | Framework-policy sentinel `[unspecified — fill at canonical review]`.                                                                                                                 |
  | Multi-decision split                                                               | Out of scope; route to `/wr-architect:create-adr` Step 2b.                                                                                                                            |
  | Empty `$ARGUMENTS`                                                                 | Halt-with-stderr-directive (AFK-safe).                                                                                                                                                |

  Deferred-canonical-expansion contract:

  - capture-adr does **not** invoke the `wr-architect:agent` review inline (the create-adr Step 5 confirm-with-user AskUserQuestion pass is intentionally omitted).
  - Architect review fires when canonical expansion runs (`/wr-architect:create-adr <NNN>` or direct architect-agent delegation).
  - The architect-agent reviewing a `.proposed.md` skeleton sees `status: proposed` + deferred-flag literals and treats it as a not-yet-accepted ADR; reviews focus on whether the captured Decision conflicts with existing accepted ADRs.
  - Trailing pointer in Step 6 is the user-visible signal that canonical expansion is needed.

  Composes with:

  - ADR-032 (governance skill invocation patterns) — this skill is the foreground-lightweight-capture variant amendment 2026-05-03 for capture-adr.
  - ADR-038 (progressive disclosure) — SKILL.md + REFERENCE.md split shape.
  - ADR-044 (decision-delegation contract) — framework-mediated mechanical-stage carve-outs justify zero-AskUserQuestion design.
  - ADR-049 (bin/ on PATH) — capture-adr is self-contained (no shim needed; same as create-adr).
  - ADR-052 (behavioural-tests-default) — bats fixtures exercise primitives, not SKILL.md prose.
  - P155 (sibling capture-problem) — same shape, symmetric on the ITIL namespace; capture-on-correction OFFER pattern (P078) gains an `/wr-architect:capture-adr` companion.

  P157 (pending-questions-surface hook) remains Open under the same parent P014; ships in a subsequent iter.

## 0.5.2

### Patch Changes

- 1fe2cad: Gate markers now survive long-running Agent and Bash subprocesses (P111).

  A new PostToolUse hook (`*-slide-marker.sh`) fires on Agent and Bash tool
  completion in the parent session. If the parent already holds a valid gate
  marker, the hook touches it — sliding the TTL window forward — so the wall-
  clock time spent inside an Agent-tool subagent or a `claude -p` iteration
  subprocess no longer counts against the parent's TTL.

  The slide is bounded:

  - The hook only TOUCHES an existing marker. It NEVER creates one — creation
    still requires a real gate review with verdict parsing in
    `*-mark-reviewed.sh`.
  - The hook skips the touch when `tool_response.is_error` is true. A failed
    subprocess does not extend the parent's trust window.
  - For risk-scorer, only the score files (`commit`, `push`, `release`) are
    slid. The `*-born` markers are deliberately invariant under sliding so
    the 2×TTL hard-cap from P090 still bounds total marker life.

  This replaces the symptom-treatment of P107 (TTL bumped 1800s → 3600s) with
  the architectural fix per ADR-009's new "Subprocess-boundary refresh"
  subsection. Adopters who configured a non-default `ARCHITECT_TTL` /
  `REVIEW_TTL` / `RISK_TTL` envvar do not need to change anything.

## 0.5.1

### Patch Changes

- 5d367e9: P100 slice 1 — `architect-enforce-edit.sh` + `architect-detect.sh` extended to exempt `docs/briefing/*` from the architect edit gate, alongside the existing `docs/BRIEFING.md` exemption. Adopter projects that adopt the `docs/briefing/` tree layout (split-per-topic briefing introduced in P100 slice 1) no longer trip architect review on every retrospective append. Scope bats test added to assert the SCOPE prose advertisement.

## 0.5.0

### Minor Changes

- db104da: P095 — UserPromptSubmit hooks across all five windyroad plugins now emit the full MANDATORY instruction block only on the first prompt of a session; subsequent prompts emit a ≤150-byte terse reminder. Reclaims ~120KB / ~30k tokens per 30-turn session in a 3-active-hook project (~80% of the prior per-prompt hook preamble). Detection and enforcement semantics are unchanged — the `PreToolUse` edit gate remains the enforcement surface; only the reminder prose is gated.

  **New:**

  - Canonical helper `packages/shared/hooks/lib/session-marker.sh` with `has_announced` + `mark_announced` functions (empty-SESSION_ID fallback: no-op, never crashes).
  - Five per-plugin byte-identical copies at `packages/<plugin>/hooks/lib/session-marker.sh` for `architect`, `jtbd`, `tdd`, `style-guide`, `voice-tone`. Distributed via `scripts/sync-session-marker.sh` with `--check` mode + `npm run check:session-marker` + CI step per ADR-017 / ADR-028.
  - ADR-038 "Progressive disclosure + once-per-session budget for UserPromptSubmit governance prose" codifies the pattern, the marker-path convention (`/tmp/${SYSTEM}-announced-${SESSION_ID}`), the ≤150-byte per-prompt budget, the four-element terse-reminder shape (MANDATORY signal word + gate name + trigger artifact + delegation affordance), and the `tdd-inject.sh` dynamic-state carve-out.

  **Changed:**

  - `packages/architect/hooks/architect-detect.sh` — gates the full MANDATORY ARCHITECTURE CHECK block behind `has_announced "architect" "$SESSION_ID"`; subsequent prompts emit `MANDATORY architecture gate active (docs/decisions/ present). Delegate to wr-architect:agent before editing project files.` Absent-`docs/decisions/` branch unchanged.
  - `packages/jtbd/hooks/jtbd-eval.sh` — same pattern for the JTBD CHECK; terse reminder cites `docs/jtbd/ present` and `wr-jtbd:agent`. Absent-`docs/jtbd/README.md` branch unchanged.
  - `packages/tdd/hooks/tdd-inject.sh` — special case per ADR-038 carve-out: static prose (STATE RULES table, WORKFLOW, IMPORTANT) is gated; dynamic TDD state (IDLE/RED/GREEN/BLOCKED) and tracked test files list emit every prompt. No-test-script fallback branch unchanged.
  - `packages/style-guide/hooks/style-guide-eval.sh` — same pattern; terse reminder cites `docs/STYLE-GUIDE.md present` and `wr-style-guide:agent`.
  - `packages/voice-tone/hooks/voice-tone-eval.sh` — same pattern; terse reminder cites `docs/VOICE-AND-TONE.md present` and `wr-voice-tone:agent`.

  **Tests (bats):**

  - `packages/shared/test/session-marker.bats` — 9 unit tests for the helper.
  - `packages/shared/test/sync-session-marker.bats` — 6 drift-check tests.
  - `packages/architect/hooks/test/architect-detect-once-per-session.bats` — 8 behavioural tests.
  - `packages/jtbd/hooks/test/jtbd-eval-once-per-session.bats` — 8 behavioural tests.
  - `packages/tdd/hooks/test/tdd-inject-once-per-session.bats` — 8 behavioural tests, including the dynamic-state carve-out assertion.
  - `packages/style-guide/hooks/test/style-guide-eval-once-per-session.bats` — 7 behavioural tests.
  - `packages/voice-tone/hooks/test/voice-tone-eval-once-per-session.bats` — 7 behavioural tests.
  - Full suite: 735/735 green.

  Backward-compatible for consumers: first-prompt output is byte-identical to the pre-change behaviour; only the second+ prompts see the terse reminder. Downstream tooling that parses the MANDATORY block text (none known) would still see the full text on the first prompt.

  Closes P095. Transitions the ticket from `.known-error.md` to `.verifying.md` per ADR-022.

## 0.4.1

### Patch Changes

- 6dd6a77: **Breaking change for external adopters**: remove the `docs/JOBS_TO_BE_DONE.md` runtime fallback. Canonical JTBD layout is now `docs/jtbd/` only (ADR-008 Option 3 chosen 2026-04-20 per P019).

  **Who is affected**: any project still using the legacy single-file `docs/JOBS_TO_BE_DONE.md` layout. The JTBD gate, agent, and CI validation no longer consult the legacy file.

  **Migration**: run `/wr-jtbd:update-guide` — it is the **sole** component in the suite permitted to read `docs/JOBS_TO_BE_DONE.md`, and only for one-shot migration into the `docs/jtbd/` directory layout. After migration, the legacy file can be deleted (git history is the archive).

  **Runtime changes**:

  - `@windyroad/jtbd` eval hook no longer injects the "docs/JOBS_TO_BE_DONE.md" enforcement variant; missing `docs/jtbd/` triggers an update-guide recommendation.
  - `@windyroad/jtbd` enforce hook no longer exempts the legacy file and no longer falls back to it. On projects without `docs/jtbd/`, the gate blocks with a `/wr-jtbd:update-guide` suggestion.
  - `@windyroad/jtbd` mark-reviewed hook no longer stores a hash against the legacy file; it exits early when `docs/jtbd/` is absent.
  - `@windyroad/jtbd` agent description and lookup logic now reference only `docs/jtbd/`.
  - `@windyroad/architect` enforce hook no longer exempts `docs/JOBS_TO_BE_DONE.md` as a peer-plugin policy artefact (it is no longer a recognised governance artefact).
  - `@windyroad/architect` detect hook's "does not apply to" list no longer mentions `docs/JOBS_TO_BE_DONE.md`.

  **Documentation changes**:

  - ADR-008 amended: Option 3 "Directory-only, no fallback" added as the chosen option; Option 1 retained with dated rejection (2026-04-19) so the rationale chain is readable.
  - ADR-005 line 138 rephrased to reflect the single canonical path.
  - ADR-007 supersession note extended to call out the artefact-name change (format, not just structure).
  - `wr-jtbd:update-guide` SKILL.md documents the migration carve-out explicitly.
  - This repository's own `docs/JOBS_TO_BE_DONE.md` stub is deleted (it was a 5-line redirect with no unique content).
  - Bats tests in `jtbd-eval`, `jtbd-enforce-scope`, `jtbd-mark-reviewed`, and `architect-enforce-scope` inverted to assert the legacy-file path is not consulted.

- f9bfa56: Fix the next-ID origin-max lookup in `manage-problem` Step 3 and `create-adr` Step 3 (P056). The prior bash pipeline ran `git ls-tree origin/main <path>/ | grep -oE '[0-9]{3}'` — default `git ls-tree` output includes the 40-char blob SHA, whose hex run can contain three consecutive decimal digits that the regex falsely matches (observed `origin_max=997` on 2026-04-20 opening P055). The fix adds `--name-only` to drop mode/type/SHA columns and pipes through `sed` to strip the path prefix, so the anchored `grep -oE '^[0-9]+'` only picks up real filename IDs. ADR-019's next-ID invariant and P043's collision guard both presume this pipeline is sound; this change restores the invariant. Two new bats doc-lint tests (8 assertions) guard the contract.
- 3bf2074: Document the `git mv` + Edit + `git add` staging-ordering trap (P057) in `manage-problem` Step 7 and `create-adr` Step 6. `git mv` alone stages only the rename — subsequent `Edit`-tool modifications must be re-staged explicitly (`git add <new>`) before commit. Without the re-stage, transition commits capture the rename but drop the `Status:` / `## Fix Released` content edits, which then leak into an unrelated later commit and corrupt the audit trail (observed 2026-04-19 in P054's `.verifying.md` transition).

  Changes:

  - `manage-problem` Step 7: new warning block applying to all three transition arrows (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed), plus an explicit `git add <new>` line in each code block.
  - `manage-problem` Step 11: commit convention now recommends `git add -u` as a safety-net for tracked modifications.
  - `create-adr` Step 6: supersession rename now instructs authors to `git add` the file again after the frontmatter + "Superseded by" edits.
  - Two new bats doc-lint tests guard the contract in both SKILL.md files.

## 0.4.0

### Minor Changes

- b2f1646: Add runtime-path performance review to `wr-architect:agent` per ADR-023 (closes P046). When a proposed change touches HTTP cache directives, rate limits, throttles, response size, or per-request handler behaviour, the architect now MUST report a per-request cost delta (concrete units: ms, bytes), a request-frequency estimate (with cited source — ADR, JTBD, telemetry, or explicit "worst-case assumption"), their product as aggregate load delta, and a verdict against any in-scope `performance-budget-*` ADR. Qualitative phrases like "load is negligible" or "microseconds only" are now forbidden without concrete numeric backing. Includes a 9-test bats regression file enforcing the prompt wording. Rationale: the same architect agent reviews many downstream projects; a systemic blind spot for per-request cost trade-offs (addressr 2026-04-18 incident) affects every consumer.

## 0.3.2

### Patch Changes

- 359ec7c: ticket-creators: next-ID collision guard against origin (P043)

  Adds the next-ID collision guard from ADR-019 confirmation criterion 2 to
  both ticket-creator skills:

  - `manage-problem` step 3 (Assign the next ID): now computes max of
    local-max and `git ls-tree origin/<base>` max, then increments. Catches
    collisions between local work and parallel sessions before the ticket
    file is written.
  - `create-adr` step 3 (Determine sequence number): same mechanism applied
    to `docs/decisions/`.

  Both skills cite ADR-019 and log renumber decisions in the user-facing
  report. Sibling fix to P040 (work-problems Step 0 preflight, shipped in
  @windyroad/itil@0.4.2): preflight catches divergence at loop start; this
  ticket catches collisions at ticket-creation time as a defence in depth.

  Adds bats tests (3 assertions per skill) verifying ADR-019 references and
  the collision-guard pattern.

  Closes P043 pending user verification.

## 0.3.1

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.3.0

### Minor Changes

- b7d6739: Add on-demand assessment skills (P020)

  New user-invocable skills per ADR-015:

  - `wr-risk-scorer:assess-release` — pipeline risk score on demand; pre-satisfies the commit gate
  - `wr-risk-scorer:assess-wip` — WIP risk nudge for the current uncommitted diff
  - `wr-architect:review-design` — on-demand ADR compliance review
  - `wr-jtbd:review-jobs` — on-demand persona/job alignment check

  All four skills are discoverable via `/` autocomplete and delegate to existing
  governance subagents. No hook gate changes; bypass marker is still written by
  the PostToolUse hook after the pipeline subagent runs.

## 0.2.0

### Minor Changes

- fe1b903: Gate markers now persist across prompts (ADR-009). Removed Stop-hook reset scripts from all 5 review plugins. Marker lifecycle is now governed entirely by TTL (30 min default, configurable via `*_TTL` env vars) + drift detection of policy files. Resolves P001 — reviews no longer need to re-run on every prompt. Note: this is a behaviour change; users who relied on fresh-review-every-prompt should set a shorter TTL.

## 0.1.5

### Patch Changes

- ec16630: Add project-root check to all enforce hooks (P004). Absolute file paths outside the current project (e.g., ~/.claude/channels/discord/access.json) are no longer gated — gates now only fire on files within the project root.

## 0.1.4

### Patch Changes

- dbb2e79: Exempt peer-plugin policy files from architect gate (P009): docs/JOBS_TO_BE_DONE.md, docs/PRODUCT_DISCOVERY.md, docs/jtbd/, docs/VOICE-AND-TONE.md, docs/STYLE-GUIDE.md. Each plugin governs its own policy files — the architect should not re-gate them.

## 0.1.3

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
