# R001: Confidential / business-metric disclosure in outbound prose

A draft outbound-prose body contains content matching a `RISK-POLICY.md` `## Confidential Information` class — credentials, business-context-paired financial figures, user counts, client names, pricing, traffic volumes, internal roadmap. Once the prose lands on a public/permanent surface (CHANGELOG → npm tarball; published GitHub issue), retraction is partial-or-impossible. Distinct from R008 (credentials in committed files; git-history-permanent immediately) — R001 is specifically prose drafted by the agent for outbound surfaces.

## Recogniser

**Path patterns** (any match → consider this entry):

- `.changeset/*.md`
- `packages/*/CHANGELOG.md`
- (any Bash invoking `gh issue create`, `gh issue comment`, `gh issue edit`, `gh pr create`, `gh pr comment`, `gh pr edit`)
- (any Bash invoking `gh api .../security-advisories` or `gh api .../comments`)
- (any Bash invoking `npm publish`)

**Diff-content keywords** (any match → consider):

- revenue, pricing, ARR, MRR, client name, customer name, user count, traffic
- roadmap, internal strategy, confidential, NDA
- (numeric financial figures with business context — `$N` near client / company tokens)

**Anti-patterns** (looks like R001 but isn't):

- Auth-token / private-key / API-key in a committed source file → score as **R008** (committed credentials), not R001.
- README badge URLs / changeset-URL slugs that mention an org name (e.g., `@windyroad/...`) — own-namespace by ADR-055; not a leak.
- The phrase "Confidential Information" in policy docs / risk catalogue prose (it's a class label, not a disclosure).

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | `.changeset/*.md` author surface lands here |
| push | yes | cumulative |
| release | yes | cumulative; CHANGELOG flows to npm tarball at this layer |
| external-comms | **primary** | `gh issue/pr/api`, `npm publish` invocations are this stage's whole purpose |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 3 (Moderate) — `RISK-POLICY.md` L63 classes "confidential business metrics committed to repository" as Moderate. (Auth-token sub-class escalates to Severe but routes to R008.)
- **Likelihood**: 4 (Likely) — agent has Read access to confidential session context; without an outbound-prose gate, leakage on every drafted body is the default trajectory.
- **Inherent score**: 12
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| `external-comms-gate.sh` regex pre-filter (`hooks/lib/leak-detect.sh`) | Bash command targets a gated surface OR Edit/Write to `.changeset/*.md` | 1 | -1 likelihood (when fires-and-passes) | Bump residual likelihood +1 |
| `wr-risk-scorer:external-comms` subagent (LLM-walk) | Regex didn't deny; subagent invoked for prose-context review | 2 (within-hook, partial — see strict caveat) | -1 likelihood (when verdict is PASS) | Bump +1 |
| PostToolUse marker hook (`sha256(draft + '\n' + surface)`) | Subagent emitted `EXTERNAL_COMMS_RISK_VERDICT: PASS` with valid key | n/a (UX dedup) | 0 paths | n/a (just causes re-prompt; not a leak modulator) |
| `BYPASS_RISK_GATE=1` env override | User explicitly set the env var for the invocation | n/a (relaxation) | 0 paths | n/a |
| `RISK-POLICY.md` `## Confidential Information` class taxonomy | Always (declarative) | n/a (written policy) | 0 paths per `## Control Composition` | Lower author-mindfulness; not a runtime modulator |

Lifetime residual likelihood under regex + LLM-walk firing-and-passing = 1 (Rare; floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic — the most pessimistic modifier wins):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Diff content includes financial figures with business context (e.g., `$XM`, `$XB`, `N customers`, `N% MoM`) | +1 | Regex pre-filter likely fires; LLM-walk path is load-bearing for nuanced cases |
| Diff content includes a known-customer name from CLAUDE.md or an open ticket | +1 | LLM-walk subagent is load-bearing; may not catch paraphrased mentions |
| Outbound surface is `gh api .../security-advisories` (vendor private channel) | -1 | Vendor-private surface has more tolerance for confidential-classed content; risk is reputational not legal |
| Surface is `npm publish` for `@windyroad/*` (own namespace per ADR-055) and content is purely architectural prose | -1 | Own-namespace publishing of internal architecture descriptions is the typical case |
| Subagent SHA placeholder issue (P163/P166): subagent returned `EXTERNAL_COMMS_RISK_KEY` not matching gate's computed SHA | +2 | Marker hook rejects → gate re-fires; if user bypasses, controls effectively didn't fire |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — both regex and LLM-walk false-negative on the same draft is empirically rare.
- **Residual score**: 3
- **Residual band**: Low — within appetite.

**Strict policy reading caveat**: regex + LLM-walk share the hook-script failure mode → 1 independent path → residual 3 × 3 = 9 (Medium). The per-action lens (which the catalogue uses) credits both stages because their failure modes are independent at the within-hook stage level.

## Watch-out

- `.changeset/*.md` bodies count as outbound prose — they land verbatim in CHANGELOG.md and every published npm tarball (P073).
- "Cross-context leak" sub-class (agent invoked for purpose A sees confidential context from prior turn purpose B and uses it in outbound prose) — gate catches structured leaks; less reliable on paraphrased ones.
- The subagent SHA placeholder issue (P163/P166) is the canonical false-negative path: subagent emits placeholder key, marker doesn't write, gate re-fires; if user bypasses out of frustration, the residual gate evidence is thrown away.

## See also

- **Sibling**: R008 (credentials in committed files) — same confidentiality dimension, different surface (committed file vs outbound prose).
- **Drivers / ADRs**: P064 (gate driver), P073 (changeset-author gating), P163/P166 (subagent SHA issue), ADR-013 Rule 5 (silent proceed on PASS), ADR-055 (own-namespace exclusion).
