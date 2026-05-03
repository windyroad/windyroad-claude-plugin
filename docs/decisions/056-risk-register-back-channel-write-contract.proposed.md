---
status: "proposed"
date: 2026-05-03
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, adopter maintainers (addressr, addressr-mcp, addressr-react, very-fetching, bbstats, windyroad)]
reassessment-date: 2026-08-03
---

# Risk Register Back-Channel Write Contract — agent emits, hook queues, calling skill drains

## Context and Problem Statement

ADR-047 (Phase 1, landed 2026-05-03 commit 9c45d8f) added `/install-updates` Step 6.5 that scaffolds `docs/risks/README.md` + `TEMPLATE.md` into adopter projects when `RISK-POLICY.md` exists. ADR-047 explicitly deferred Phase 2 — the **load-bearing** trigger that closes P033's 99% miss rate per the user's verbatim direction (2026-04-28): *"for each risk mentioned in the .risk-reports, there should be something in the risk register"*.

ADR-047 line 113 listed the deferred concerns: *"agent autonomy boundary, dedupe-by-risk-name, evidence-log appending, marker-driven backfill gating"*. Phase 2 architectural review (this iter, 2026-05-03) crystallised four sub-decisions plus one BLOCKING workspace-delta concern. ADR-056 captures the resolution.

**Why a sub-ADR rather than amending ADR-047**: ADR-047's reassessment criteria (lines 175-182) are scoped to scaffold-trigger evolution. The back-channel write contract is a separate concern — the agent autonomy boundary, dedupe semantics, queue-and-drain shape, ungrounded-scoring sentinel handling, and ADR-014 commit-grain interaction are independent reassessment surfaces. Sibling ADR with explicit cross-citation is the right shape.

## Decision Drivers

- **P033** — driver ticket (Phase 2 of multi-phase fix). Load-bearing per user direction.
- **P102 / P110** — sibling tickets in the back-channel triplet; consumers of this ADR's queue-and-drain output.
- **JTBD-001 (Enforce Governance Without Slowing Down)** — strong fit. Auto-population from existing pipeline runs IS the missing enforcement step. Today's 99% miss rate is a direct violation; Phase 2 closes it. JTBD review: PASS-WITH-CAVEATS.
- **JTBD-006 (Progress the Backlog While I'm Away)** — AFK transparency contract. Silent hook write is acceptable IFF the writes land in git diff (they do — register entries are `docs/risks/*.md`).
- **JTBD-201 (Restore Service Fast with an Audit Trail)** — register IS the audit-trail artefact for ISO 31000 / 27001. Auto-scaffolded entries marked `pending review` preserve provenance without falsifying scoring.
- **JTBD-202 (Pre-Flight Governance)** — register state at release matters. Pending-review entries surface as a finding, not a hard block (per JTBD review caveat 4).
- **ADR-005 / P011** (Permitted Exception for structural bats) — the new dual-parse bats fixture mixes structural and behavioural shapes; cite the Permitted Exception so TDD agent does not flag it.
- **ADR-013 Rule 5** (policy-authorised silent proceed) — the hook queue-write is silent on stdout; cite the rule that authorises silent action without per-action consent.
- **ADR-014** (Governance Skills Commit Their Own Work) — commit-grain authority. Hook writes that drift forward through unrelated commits violate ADR-014's "one ticket-unit-of-work per commit" — the BLOCKING concern that drove the queue-and-drain choice over direct-write.
- **ADR-016** (WIP verdict commit) — explicit decoupling rationale; the workspace-delta avoidance is exactly this ADR's concern.
- **ADR-022** (Problem lifecycle Verification Pending status) — pending-review entries enter the lifecycle as `Active` (not a new suffix). Cite the lifecycle authority being EXTENDED via Status-field qualifier (not modified).
- **ADR-026** (Agent Output Grounding) — `not estimated — no prior data` sentinel governs auto-scaffolded scoring fields. The agent's prose-prefill carries Description; Inherent/Residual scoring fields use the explicit-absence sentinel until human curation.
- **ADR-032** (Governance Skill Invocation Patterns) — pending-questions queue (`.afk-run-state/outstanding-questions.jsonl`) is the precedent shape for the cross-skill queue artefact.
- **ADR-044** (Decision Delegation Contract) — framework-mediated lifecycle authority. Lines 76-78 explicitly name "Lifecycle transitions ... Mechanical" — the agent-emit / hook-write boundary is settled by precedent.
- **ADR-045** (Hook Injection Budget) — Pattern 2 silent-on-write. The queue-write hook MUST emit zero bytes to stdout.
- **ADR-047** — parent ADR (Phase 1 scaffolding). Phase 2 directly consumes Phase 1's scaffolded directory.
- **ADR-052** — behavioural-tests default. Phase 2 implementation lands with bats coverage of hint-parse + queue-write shape (not structural grep). Doc-lint structural assertions on prompt content are the Permitted Exception per ADR-005 / P011.
- **ADR-055** — namespace-prefixed permalinks. Slug column in extended hint format MUST be filename-safe and dedupe-stable.

## Considered Options

### Option 1 — Pipeline agent writes register entries directly

Grant the pipeline agent `Write` tool, have it write `docs/risks/R<NNN>-*.active.md` directly during scoring runs.

- **Pros**: single-actor; no hook dependency; agent owns end-to-end flow.
- **Cons**: violates the established architecture (`packages/risk-scorer/agents/pipeline.md` lines 4-7 deliberately restrict to `Read, Glob`); breaks the agent-purity principle baked into the existing PostToolUse hook pattern (`risk-score-mark.sh` writes ALL artefacts deterministically from agent output); makes agent runs side-effecting in unpredictable ways; conflicts with ADR-044's framework-mediated boundary. **Rejected** by architect (Question A: "No ADR argues for agent-side write").

### Option 2 — Hook writes register entries directly (mid-conversation, uncommitted)

Extend `risk-score-mark.sh` to parse the existing `RISK_REGISTER_HINT:` block and write `docs/risks/R<NNN>-*.active.md` directly. Same shape as how the hook already writes `.risk-reports/`.

- **Pros**: minimal moving parts; one hook does everything.
- **Cons**: **BLOCKING workspace-delta problem** (architect Question E). The hook fires on PostToolUse:Agent inside many callers (`/wr-itil:work-problems` mid-loop, `/wr-itil:manage-problem` Step 11, `/wr-itil:assess-release`, `/install-updates`, ad-hoc invocations). None of those callers know to stage/commit `docs/risks/` deltas the hook produced. ADR-014 + ADR-016 are explicit on commit-grain discipline. A new `R<NNN>-*.active.md` written mid-loop drifts forward through the next unrelated commit, breaking ADR-014's "one ticket-unit-of-work per commit" grain. P057 staging-trap and P118 README-drift class are the same family of bug. **Rejected**.

### Option 3 — Hook writes register entries AND stages them for the next caller's commit

Same as Option 2 but the hook runs `git add docs/risks/R<NNN>-*.active.md` so the next caller's commit picks up the file.

- **Pros**: couples to existing single-commit-transaction discipline; no new artefact shape.
- **Cons**: the file rides whatever the next commit is — may be unrelated to risks (semantic-drift from ADR-014 commit-message convention). Requires every consumer skill to learn detect-and-rename their commit type when they include risk entries. Couples cross-skill state through git index. Acceptable only if ADR-014's commit-message table grows a "auto-scaffolded register entry rides parent commit" row + every SKILL.md gains awareness. High coordination cost. **Rejected** as inferior to Option 4.

### Option 4 — Hook queues, calling skill drains (CHOSEN)

Hook parses `RISK_REGISTER_HINT:` and appends a JSONL line to `.afk-run-state/risk-register-queue.jsonl` (already gitignored as a directory in `.gitignore`). Each consumer skill (`/wr-itil:work-problems`, `/wr-itil:manage-problem`, `/install-updates`, `/wr-risk-scorer:assess-release`) gains a Step-N drain that reads the queue, writes register entries, commits per ADR-014 with a dedicated `docs(risks): scaffold R<NNN> ...` message, and clears drained lines from the queue.

- **Pros**: decouples back-channel write from per-commit semantics. Preserves ADR-014's single-commit-transaction discipline. Mirrors ADR-032's outstanding-questions precedent. Mirrors ADR-014's P118 reconciliation pattern (read-only detector → dedicated skill applies + commits). Queue persists across sessions — survives subprocess boundaries the AFK iteration-worker pattern relies on (P130). The drain step is auditable by reading the queue file directly. The queue file lives under `.afk-run-state/` which is gitignored, so the queue itself never enters git.
- **Cons**: two-stage shape requires drain step in N consumer skills (additional surface area). Queue file lifetime needs governance (drain-and-clear semantics + max-age purge). Queue can grow unbounded between drains — bounded by the natural cadence of the consumer skills.
- **Architect verdict**: PASS, recommended.

## Decision Outcome

**Chosen option: Option 4 — queue-and-drain.** Hook writes the queue artefact; consumer skills drain it via dedicated commits.

### Hint-format extension (3-column shape) — DUAL-PARSE CONTRACT

The existing `RISK_REGISTER_HINT:` block (`packages/risk-scorer/agents/pipeline.md` lines 172-211) gains an explicit `risk-slug` column. The PREFERRED format becomes:

```
RISK_REGISTER_HINT:
- <reason-tag> | <risk-slug> | <one-line prefill describing the risk>
```

**Backward-compatible dual-parse contract** (REQUIRED for in-flight pipeline agents whose prompt cache still emits the legacy 2-column shape):

- Hook MUST accept BOTH shapes during the transition:
  1. **3-column (preferred)**: `<reason-tag> | <slug> | <prose>`. Slug is computed by the agent and trusted by the hook.
  2. **2-column (legacy)**: `<reason-tag> | <prose>`. Hook derives slug from `<reason-tag>` + first 5 word-stems of `<prose>` (lowercase, kebab, drop articles), capped at 60 chars per ADR-055 filename-safety. The derivation is deterministic so re-runs produce the same slug.
- Bats coverage MUST exercise BOTH parse paths (one fixture per shape).
- The dual-parse contract is **load-bearing for adoption** — without it, adopter sessions running cached old prompts would silently drop hints, perpetuating the very 99% miss rate this ADR closes.

Agent-side slug computation rules (preferred shape):

1. Lowercase, hyphen-separated.
2. Drop articles (the, a, an), prepositions in long phrases, and trailing date markers.
3. Stable across pipeline runs: identical risk shape → identical slug. The agent MUST NOT include timestamps, session IDs, or commit SHAs in the slug.
4. Maximum 60 characters; truncate at word boundary if longer.
5. If slug computation is genuinely ambiguous (rare), fall back to `<reason-tag>-<noun-phrase>` form.

Field definitions:

- **`<reason-tag>`** — unchanged from existing vocabulary: `above-appetite-residual`, `confidentiality-disclosure`, `user-stated-precondition`. Reserved tags; agents MUST NOT invent new tags.
- **`<risk-slug>`** — NEW. Filename-safe kebab-case identifier. Slug is the dedupe key — N reports producing the same slug collapse to ONE register entry.
- **`<prefill prose>`** — unchanged. Free-form one-line description; carried into the register entry's Description field.

### Queue artefact shape (`.afk-run-state/risk-register-queue.jsonl`)

One JSONL line per pipeline-emitted hint. Schema:

```json
{
  "ts": "2026-05-03T14:17:00Z",
  "session_id": "<session-id-or-empty>",
  "report_path": ".risk-reports/2026-05-03T14-17-00-commit.md",
  "reason_tag": "above-appetite-residual",
  "risk_slug": "cumulative-residual-commit-layer-above-appetite",
  "slug_source": "agent",
  "prefill": "Cumulative residual risk for commit layer reached 12/25 (High band) due to mass-edit across 17 files."
}
```

- `ts` — ISO-8601 UTC timestamp the hook ran.
- `session_id` — session identifier from the agent invocation; empty if unavailable. Used for AFK-iter cross-reference.
- `report_path` — relative path to the `.risk-reports/` file the hook just wrote. Becomes the Evidence Log citation in the eventual register entry.
- `reason_tag`, `risk_slug`, `prefill` — copied verbatim from the hint bullet (3-col path) OR derived (2-col path).
- `slug_source` — `agent` (3-col) or `derived` (2-col legacy). Drain step can prioritise agent-emitted slugs when slug-collision-with-prefix-mismatch needs adjudication.

Queue is append-only between drains. Drain is read-and-truncate per consumer-skill invocation. Queue file lives under `.afk-run-state/` which is gitignored — the queue itself never enters git history.

### Hook write contract (extension to `risk-score-mark.sh`)

Append a new section after the existing `Pipeline scorer` block (which writes `.risk-reports/` and the score files):

1. Parse the `RISK_REGISTER_HINT:` block from agent output.
2. For each bullet:
   a. Try 3-column parse (`<tag> | <slug> | <prose>`); fall back to 2-column (`<tag> | <prose>`) with derived slug.
   b. Validate the reason-tag is one of the three reserved values; skip malformed bullets (silent skip — do NOT halt the hook).
3. Compute the report path written in the existing pipeline block (`${REPORT_DIR}/${TIMESTAMP}-commit.md`). Pass it through as `report_path`.
4. Append one JSONL line per valid bullet to `.afk-run-state/risk-register-queue.jsonl` (create directory + file if absent — same pattern as existing `_risk_dir` helper).
5. Hook MUST emit zero bytes to stdout per ADR-045 Pattern 2 (side-effect-only silent).
6. Hook MUST NOT block or fail on queue-write errors. Wrap in `|| true`-style fault tolerance — queue persistence is best-effort, not transactional. Lost queue entries are recovered by Phase 3 backfill.

### Consumer-skill drain contract (deferred to Phase 2b — out of scope this iter)

Consumer skills are added in subsequent iters per the queue-and-drain decoupling principle. The contract for each drain step:

1. Read `.afk-run-state/risk-register-queue.jsonl` (skip step if absent / empty).
2. Group lines by `risk_slug` (dedupe).
3. For each unique slug:
   a. Glob `docs/risks/R*-<slug>.active.md`.
   b. If match: append timestamped Evidence Log entry citing all `report_path`s in the group; do NOT modify scoring fields.
   c. If no match: compute next R<NNN> per `/wr-risk-scorer:create-risk` SKILL Step 3 algorithm (local-max + origin-max, +1); write new file from `docs/risks/TEMPLATE.md` with:
      - `**Status**: Active (auto-scaffolded — pending review)`
      - `**Curation**: pending review (auto-scaffolded YYYY-MM-DD)`
      - Description = first non-empty `prefill` from the group.
      - Inherent / Residual fields = `not estimated — no prior data` per ADR-026 line 90.
      - Evidence Log section listing all `report_path`s in the group.
   d. Update `docs/risks/README.md` Register table (append row with stub scoring + pending-review marker).
4. Single commit per drain pass: `docs(risks): scaffold R<NNN> ... (N entries from queue)`.
5. Truncate the queue file (write empty file). If a write happens after truncation but before the next drain, those entries simply queue for the next drain.
6. Drain step is idempotent — safe to invoke when queue is empty.

This iter (Phase 2a) lands ONLY the hook queue-write side. Phase 2b (drain steps in `/wr-itil:work-problems`, `/wr-itil:manage-problem`, `/install-updates`, `/wr-risk-scorer:assess-release`) lands in subsequent iters per per-skill-grain commits.

### Pending-review treatment (per ADR-026 sentinel pattern)

Auto-scaffolded register entries MUST visibly mark themselves as pending human curation:

- **Filename suffix**: `.active.md` (per `docs/risks/README.md` line 29 vocabulary; no new lifecycle stage). Re-using existing suffix EXTENDS ADR-022's lifecycle authority via Status-field qualifier (a repo-canon pattern — see `docs/problems/107-...closed.md` `Status: Closed (Fix Released)`, `docs/problems/096-...verifying.md` `Status: Verification Pending — Phase 1 audit done...`). No ADR-022 modification required.
- **Status field**: `Active (auto-scaffolded — pending review)` — distinguishes from human-curated `Active` entries while staying in the same lifecycle bucket.
- **Curation marker**: explicit body field `**Curation**: pending review (auto-scaffolded YYYY-MM-DD)` — machine-detectable for follow-up tooling. Pairs with the human-readable Status qualifier; downstream parsers grep the Curation field rather than parsing the Status qualifier.
- **Scoring fields**: Inherent Impact / Likelihood / Score / Band AND Residual Impact / Likelihood / Score / Band ALL emit the ADR-026 sentinel `not estimated — no prior data`. Numeric defaults of `0` or `Low` would falsely look human-affirmed and violate audit-trail integrity (JTBD-201 caveat 3).
- **Within appetite?**: `pending — scoring not estimated` (cannot evaluate without scores).
- **README.md Register table** row: numeric columns render as `—` (em-dash) for stubbed values; Treatment column = `pending`.

### Phase 3 backfill is OUT OF SCOPE for this ADR

Phase 3 (one-time historical backfill over existing `.risk-reports/*.md`) warrants its own skill, NOT the hook-driven path. Architect verdict (Question D): backfill is marker-gated per-project (`.claude/.risk-register-backfill-done`), produces N writes deterministically as a single commit per ADR-014, and inverts the agent/hook flow (skill reads historical reports, dispatches pipeline agent for hint emission per report, then commits the batch). Recommended shape: `/wr-risk-scorer:backfill-register` skill invoked from `/install-updates` Phase 3 (separate ADR or amendment to ADR-047 Phase 3 spec).

## Scope

### In scope (this ADR / Phase 2a, this iter)

- Sub-ADR document (this file).
- `packages/risk-scorer/agents/pipeline.md` — extend hint format from 2-column to 3-column with `risk-slug`. Add slug-computation rules section. Document the dual-parse contract for hook compatibility.
- `packages/risk-scorer/hooks/risk-score-mark.sh` — extend pipeline-handler block to parse `RISK_REGISTER_HINT:` (both 2-col and 3-col shapes) and append to `.afk-run-state/risk-register-queue.jsonl`. ADR-045 Pattern 2 silent-on-write preserved.
- Behavioural bats fixture exercising the hint-parse + queue-append shape — both 3-col and 2-col legacy parse paths covered (per ADR-052).
- P033 ticket update — Phase 2a partial (queue-write only); Phase 2b drain steps + Phase 3 backfill remain deferred.
- Changeset for `risk-scorer` plugin (minor — additive hook capability, agent prompt extension; backward-compatible via dual-parse contract).

### Out of scope (deferred to Phase 2b / Phase 3 / future ADRs)

- **Phase 2b — Drain steps in consumer skills** (`/wr-itil:work-problems` Step N drain; `/wr-itil:manage-problem` Step 11 drain; `/install-updates` Step 6.6 drain; `/wr-risk-scorer:assess-release` drain). Each is a separate per-skill-grain commit with its own bats coverage. Subsequent iters.
- **Phase 3 — Backfill skill** `/wr-risk-scorer:backfill-register`. Separate ADR or amendment to ADR-047. Marker-gated per-project.
- **Phase 4 — Behavioural contract test** asserting every distinct `risk-id` in `.risk-reports/*.md` has a matching `docs/risks/R<NNN>-*.md` entry. Lands when Phase 2b + Phase 3 have populated the steady-state.
- **Final-report integration** — JTBD-006 caveat 2 recommends `/wr-itil:work-problems` final-iteration report adds a `Risk register: N entries auto-scaffolded, M pending review` line. Lands in Phase 2b alongside the drain step.
- **First-run-after-update notification** — JTBD-006 caveat 5 recommends a one-time SessionStart message naming Phase 2 enablement + initial backfill count. Lands in Phase 3 (the first backfill is the first user-visible event).
- **Pre-flight gating** — JTBD-202 caveat 4 explicitly says do NOT hard-block release on pending-review entries. `/wr-risk-scorer:assess-release` MAY surface them as findings; that is the entire integration. No new gate hook.
- **Curation skill** `/wr-risk-scorer:review-register` — JTBD-001 caveat 1 recommends a dedicated skill for draining pending-review entries (assigns scoring + flips Status to plain `Active`). Lands when adopter usage demonstrates demand.
- **Queue-file size bounding / TTL purge** — Phase 2a accepts unbounded growth between drains; the natural cadence of consumer skills bounds it in practice. Add purge logic only if operational evidence shows growth pathology.

## Consequences

### Good

- **Closes the trigger gap** that produced P033's 99% miss rate. Every pipeline run that emits a hint enqueues a register entry; the next consumer-skill drain materialises it. No reliance on assistant memory or undiscovered orchestrator hooks.
- **Preserves ADR-014 + ADR-016 commit-grain discipline.** Register entries land in dedicated `docs(risks): scaffold ...` commits authored by drain steps, not smuggled into unrelated commits. Audit-trail clean.
- **Preserves agent-purity boundary.** Pipeline agent stays `Read, Glob` only. Hook writes are deterministic and auditable. ADR-044 framework-mediated lifecycle authority honoured.
- **Mirrors established patterns.** Queue-and-drain mirrors ADR-032 outstanding-questions; pending-review state mirrors ADR-026 ungrounded-output sentinel; hint-format extension mirrors existing `RISK_REMEDIATIONS:` 5-column structured block. No new architectural primitive.
- **Phase 2a is independently shippable.** The hook can write the queue without any consumer skill draining it — the queue file is the audit trail until drain steps land. Adopter projects start producing queue entries on next plugin update; backfill recovers them once drain steps ship.
- **AFK-safe.** Hook is silent (ADR-045 Pattern 2); queue persists across sessions / subprocess boundaries (P130); drain steps are idempotent. Queue file is under `.afk-run-state/` which is already gitignored — never pollutes git history.
- **Cross-plugin coordination is honest.** The queue artefact makes the cross-skill dependency explicit rather than smuggling state through git index or session memory.
- **Adoption-safe via dual-parse contract.** In-flight pipeline agents on adopter machines whose prompt cache still emits 2-col hints continue to enqueue entries. Slug derivation handles the legacy shape transparently.

### Neutral

- `packages/risk-scorer/agents/pipeline.md` grows by ~10 lines (slug-computation rules + 3-column format spec + dual-parse note). Within budget per ADR-054.
- `packages/risk-scorer/hooks/risk-score-mark.sh` grows by ~30 lines (one new parse-and-append section, mirroring the existing 8-line `.risk-reports/` block plus per-bullet enumeration plus dual-parse fork).
- `.afk-run-state/risk-register-queue.jsonl` joins `outstanding-questions.jsonl` as a tracked queue artefact. Same lifecycle conventions; same gitignore inheritance.
- The 3-column hint format is BACKWARD-COMPATIBLE for existing consumers via the dual-parse contract — anything that parsed the first column (reason-tag) still works; anything that parsed `<tag> | <prose>` (the legacy shape) still works because the hook accepts both.

### Bad

- **Phase 2a ships without drain steps.** The queue accumulates entries that don't materialise as register files until Phase 2b. Adopter projects see queue growth but no `docs/risks/` population in the same session. Mitigation: P033 ticket Phase 2 status remains Known Error after this iter; Phase 2b is explicitly named as the next iter shape; queue file is the audit trail.
- **Slug-computation is agent-side prose work** — risk of slug drift across pipeline runs if the agent's slug logic is sloppy. Mitigation: rules above are explicit (lowercase, kebab, drop articles, no timestamps); bats fixture asserts a stable slug for a stable input. Long-tail catcher: drain step's slug-glob match handles minor variation by treating any `R*-<slug-prefix>.active.md` collision as the dedupe target (substring match optional, defer until evidence shows drift).
- **Queue file is best-effort, not transactional.** A crashed hook or filesystem error loses the entry. Mitigation: Phase 3 backfill is the recovery path — the `.risk-reports/` file IS the source of truth; the queue is a convenience for fresh entries. Backfill replays history.
- **Pending-review entries accumulate without curation.** Without `/wr-risk-scorer:review-register`, the register fills with stubbed-scoring entries that look incomplete. Mitigation: JTBD-001 caveat 1 documents the curation skill as Phase 2c future work; adopter pull demand triggers prioritisation. Pending-review IS still useful as identification + provenance even before scoring lands (JTBD-201 caveat 3).
- **Cross-skill drain coordination requires per-skill SKILL.md edits in subsequent iters** (Phase 2b). Each consumer skill that adds a drain step must learn the queue contract. Mitigation: drain logic can live in a shared library (`packages/risk-scorer/lib/drain-register-queue.sh` or similar) called from each SKILL.md — single source of truth, multiple invocation surfaces.

## Confirmation

### Source review (at implementation time, this iter)

- `docs/decisions/056-risk-register-back-channel-write-contract.proposed.md` exists with status `proposed`, decision `Option 4 queue-and-drain`, hint-format extension spec, **dual-parse contract** explicitly named, queue artefact schema with `slug_source` field, hook write contract, and explicit out-of-scope for Phase 2b / Phase 3 / Phase 4.
- `packages/risk-scorer/agents/pipeline.md` `Risk Register Hand-Off` section updated — Format block shows 3-column shape `<reason-tag> | <risk-slug> | <prose>`. Slug-computation rules section added. Reason-tag vocabulary table preserved. Dual-parse compatibility note for the 2-column → 3-column transition.
- `packages/risk-scorer/hooks/risk-score-mark.sh` pipeline-handler block has a new `RISK_REGISTER_HINT:` parse-and-append section after the existing `.risk-reports/` write. Appends to `.afk-run-state/risk-register-queue.jsonl`. Silent-on-write per ADR-045 Pattern 2. Dual-parse handling implemented (3-col preferred, 2-col fallback with derived slug).
- `docs/problems/033-no-persistent-risk-register.known-error.md` Phase 2 section updated with `Phase 2a — LANDED iter 19` annotation. Phase 2b drain steps explicitly named as deferred next-iter work. Status remains Known Error.
- Changeset file in `.changeset/` for `@windyroad/risk-scorer` minor bump documenting the new hook capability.
- `.afk-run-state/` confirmed gitignored at `.gitignore` (queue file path `git check-ignore` returns the path verbatim).

### Behavioural bats fixture (per ADR-052)

- `packages/risk-scorer/hooks/test/risk-score-mark-register-queue.bats` — fixture-driven tests. ADR-005 / P011 Permitted Exception applies for the small structural assertions on the prompt; behavioural-fixture is the dominant shape. Required test cases:
  1. **3-col hint with one bullet (above-appetite)** → queue file gains exactly one JSONL line with matching reason_tag, risk_slug (agent-emitted), prefill, and report_path matching the just-written `.risk-reports/` file. `slug_source` = `agent`.
  2. **3-col hint with three bullets (above-appetite + confidentiality + user-stated-precondition)** → queue file gains exactly three JSONL lines in order; each `slug_source` = `agent`.
  3. **2-col legacy hint with one bullet** → queue file gains one JSONL line with derived slug; `slug_source` = `derived`. Slug is deterministic for the same prefill.
  4. **Mixed 3-col and 2-col bullets in same block** → queue file gains all bullets; `slug_source` correctly tagged per bullet.
  5. **No hint emitted (silent-pass below-appetite)** → queue file unchanged (or absent if first run).
  6. **Malformed hint bullet (invalid reason-tag)** → bullet skipped; valid bullets in same block still appended.
  7. **Two consecutive hook runs with same hint** → queue file gains six lines total (no dedupe at queue level — dedupe is drain-step concern). This validates queue-as-append-only.
  8. **Empty agent output** → queue file unchanged; no hook crash.
  9. **`.afk-run-state/` directory absent** → hook creates it; queue file written successfully.
  10. **Hook stdout silent** → on success, hook emits zero bytes (ADR-045 Pattern 2); fixture asserts via `[ -z "$(...)" ]`.

### Behavioural replay (manual, post-merge)

1. Run `/wr-risk-scorer:assess-wip` against a workspace with above-appetite changes. Observe `.afk-run-state/risk-register-queue.jsonl` gains a JSONL line. Read it; confirm it cites the just-written `.risk-reports/` file and includes `slug_source: agent` (assuming the agent prompt update lands and the cache refreshes).
2. Run a clean below-appetite assessment. Observe queue file unchanged.
3. Confirm hook stdout is zero bytes (ADR-045 Pattern 2) by reading the session marker file or hook log.
4. Confirm `.afk-run-state/` is gitignored: `git check-ignore .afk-run-state/risk-register-queue.jsonl` returns the path.

## Reassessment Criteria

Revisit this decision if:

- **Queue accumulates without draining for 5+ consecutive sessions.** Signal: Phase 2b drain steps are too slow to land OR the natural cadence of consumer skills doesn't include any that fire across the surveyed adopter usage. Add a TTL purge or accelerate Phase 2b.
- **Slug drift across pipeline runs causes register fragmentation.** Signal: same risk shape produces multiple R<NNN> entries because the agent computed different slugs. Tighten slug-computation rules in pipeline.md or move slug derivation hook-side from a hash of the prose.
- **3-column hint format breaks downstream consumers we don't know about.** Signal: external user reports parse failures. The dual-parse contract is the primary mitigation; consider versioned hint blocks if the surface grows.
- **Auto-scaffolded entries stay pending-review indefinitely** (JTBD-001 caveat 1 materialises). Signal: 30+ days post-Phase-2b adoption with curation rate < 20%. Build `/wr-risk-scorer:review-register` skill.
- **Queue-and-drain shape proves under-decoupled** — e.g. drain step needs information the queue line doesn't carry. Signal: drain steps repeatedly need to re-parse the `.risk-reports/` file. Extend the JSONL schema or move drain logic into the hook (re-evaluate Option 2 with explicit ADR-014 commit-grain handling).
- **The 99% miss rate doesn't drop within a steady-state 30-day window post-Phase-2b.** Signal: Phase 2 is structurally insufficient. Re-evaluate whether the queue-and-drain shape is the right contract.

## Related

- **P033** — driver ticket; Phase 2 of multi-phase fix (Phase 2a this iter).
- **P102** — invocation surface for risk register; sibling-in-fix.
- **P110** — pipeline back-channel hint; consumer of this ADR's queue artefact.
- **ADR-005 / P011** — Permitted Exception for structural prompt-spec bats; cited so TDD agent does not flag the small structural assertions in the new fixture.
- **ADR-013** — Rule 5 (policy-authorised silent proceed); authorises the silent hook queue-write.
- **ADR-014** — commit-grain authority. Drove the queue-and-drain choice over direct-write.
- **ADR-016** — WIP verdict commit; the workspace-delta avoidance is exactly this ADR's concern.
- **ADR-022** — problem-lifecycle authority; pending-review entries enter as `Active` (no new suffix), extending the lifecycle vocabulary via Status-field qualifier rather than modifying it.
- **ADR-026** — `not estimated — no prior data` sentinel for ungrounded scoring fields in auto-scaffolded entries.
- **ADR-032** — outstanding-questions queue precedent for cross-session JSONL artefacts.
- **ADR-044** — framework-mediated lifecycle authority; agent-emit / hook-write boundary settled.
- **ADR-045** — hook injection budget Pattern 2 (silent-on-write); queue-write hook MUST emit zero bytes.
- **ADR-047** — parent ADR (Phase 1 scaffolding precondition). This ADR Phase 2 directly consumes Phase 1's scaffolded directory structure.
- **ADR-052** — behavioural-tests default for the bats fixture.
- **ADR-054** — SKILL.md / agent runtime budget policy; pipeline.md extension stays within budget.
- **ADR-055** — namespace-prefixed permalinks; slug column MUST be filename-safe.
- **JTBD-001** — primary fit (governance enforced without slowing down).
- **JTBD-006** — AFK transparency; queue-as-audit-trail.
- **JTBD-201** — register IS the ISO 31000 / 27001 audit-trail artefact; pending-review preserves provenance.
- **JTBD-202** — pre-flight governance; pending-review surfaces as finding (not hard block per JTBD review caveat 4).
- **`packages/risk-scorer/agents/pipeline.md`** — `Risk Register Hand-Off` section is the implementation site for the 3-column hint format extension.
- **`packages/risk-scorer/hooks/risk-score-mark.sh`** — implementation site for the queue-write hook extension.
- **`packages/risk-scorer/agents/test/risk-scorer-register-hint.bats`** — existing 2-column structural fixture; extended (not replaced) to cover both shapes.
- **`.afk-run-state/risk-register-queue.jsonl`** — queue artefact lifecycle. `.afk-run-state/` already in `.gitignore`.
- **`docs/risks/README.md`** — Register table format consumer of pending-review row shape (Phase 2b drain).
- **`docs/risks/TEMPLATE.md`** — template source for auto-scaffolded entry shape (Phase 2b drain).
