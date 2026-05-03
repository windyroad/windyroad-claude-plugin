---
"@windyroad/architect": minor
---

P156: ship `/wr-architect:capture-adr` skill — lightweight aside-invocation surface for ADR capture during foreground work

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

| Decision | Resolution |
|---|---|
| Considered Options ≥2 | Mechanical skeleton placeholder (`1. Option A (chosen)` + `2. (deferred — see /wr-architect:create-adr canonical review)`); MADR enforcement deferred to canonical-acceptance review. |
| Decision Drivers / Consequences / Confirmation / Pros-Cons / Reassessment-criteria | Framework-policy deferred flag (literal pointer string `(deferred to /wr-architect:create-adr canonical review)`). |
| Reassessment-date | Framework-policy default 3 months from today (matches create-adr Step 4). |
| decision-makers / consulted / informed | Framework-policy sentinel `[unspecified — fill at canonical review]`. |
| Multi-decision split | Out of scope; route to `/wr-architect:create-adr` Step 2b. |
| Empty `$ARGUMENTS` | Halt-with-stderr-directive (AFK-safe). |

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
