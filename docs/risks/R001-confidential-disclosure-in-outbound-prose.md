# R001: Confidential / business-metric disclosure in outbound prose

A draft outbound prose body (gh issue/pr/api, npm publish content, `.changeset/*.md` body, ticket body that may be published in CHANGELOGs) contains content matching a `RISK-POLICY.md` `## Confidential Information` class — credentials, business-context-paired financial figures, user counts, client names, pricing, traffic volumes, internal roadmap. Once the prose lands on a public/permanent surface (CHANGELOG → npm tarball; published GitHub issue), retraction is partial-or-impossible.

Distinct from prompt-injection or source-content leakage to the LLM provider — this class is specifically about **prose drafted by the agent for outbound surfaces**. For credentials/secrets entering committed files (which is git-history-permanent immediately), see R008.

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 3 (Moderate) — `RISK-POLICY.md` L63 explicitly classes "confidential business metrics (client names, revenue, pricing) committed to repository" as Moderate. CHANGELOG → npm tarball amplifies the surface but the per-incident impact class is Moderate. (Auth-token / private-key sub-class would escalate to Severe but that's R008's surface.)
- **Likelihood**: 4 (Likely) — agent has Read access to confidential session context; without an outbound-prose gate, leakage on every drafted body is the default trajectory.
- **Inherent score**: 12
- **Inherent band**: High

## Residual risk

Residual reflects "controls firing-and-passing" (per-action lens, matching how the pipeline scorer empirically computes residual on a real outbound-prose action):

- **Likelihood after controls**: 1 (Rare) — when the external-comms gate fires AND its verdict is PASS (regex didn't deny + LLM-walk subagent emitted PASS), a leak slipping through requires BOTH stages to false-negative on the same draft. Empirically rare for the surface this gate covers. The two stages are independent within-hook (regex regression doesn't bypass LLM-walk; LLM-walk failure doesn't bypass regex) even though they share the hook-script-level failure mode.
- **Residual score**: 3
- **Residual band**: Low

**Within appetite** (≤ 4/Low). The blocking gate design (DENY on detection; PASS only on no-evidence-of-leak) means per-action evidence is dispositive. If the gate ever started missing a class systematically (false-negative rate climbs), this residual would rise — monitor via the rate of post-publish leak reports.

**Strict policy reading caveat**: under `RISK-POLICY.md` `## Control Composition` strict path-counting, regex and LLM-walk share the hook-script failure mode and count as **1 independent path**, giving residual 3 × 3 = 9 / Medium. The catalogue uses the per-action-controls-effective reading (matches how the pipeline scorer empirically scores outbound-prose actions); the strict reading would push this above appetite. The gap between the two readings is itself a signal — if the strict reading matters (e.g., for ISO-aligned audit), document it as a sub-residual.

## Controls

- `packages/risk-scorer/hooks/external-comms-gate.sh` (P064) — PreToolUse:Bash + PreToolUse:Edit gate on outbound-prose author surfaces; routes to regex pre-filter (`hooks/lib/leak-detect.sh`) and the `wr-risk-scorer:external-comms` subagent for prose-context review.
- PostToolUse marker hook keyed on `sha256(draft + '\n' + surface)` — skips re-prompt on the same draft+surface combination.
- `RISK-POLICY.md` `## Confidential Information` — names the canonical classes the gate scans for.
- `BYPASS_RISK_GATE=1` — explicit override (e.g., publishing-org's own namespace per ADR-055; not a leak when it's our own).

## Watch-out

- `.changeset/*.md` bodies count as outbound prose because they land verbatim in CHANGELOG.md and every published npm tarball (P073).
- The subagent path can emit a placeholder `EXTERNAL_COMMS_RISK_KEY` instead of the actual SHA, causing the marker hook to reject and the gate to re-fire (P163, P166). Precompute the SHA in the calling skill.
- "Cross-context leak" sub-class (an agent invoked for purpose A sees confidential info from prior turn purpose B and uses it in outbound prose) — the gate catches this on the regex/subagent path; doesn't catch suppression failure when the agent paraphrases.
