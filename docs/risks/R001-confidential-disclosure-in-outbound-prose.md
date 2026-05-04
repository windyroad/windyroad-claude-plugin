# R001: Confidential / business-metric disclosure in outbound prose

A draft outbound prose body (gh issue/pr/api, npm publish content, `.changeset/*.md` body, ticket body that may be published in CHANGELOGs) contains content matching a `RISK-POLICY.md` `## Confidential Information` class — credentials, business-context-paired financial figures, user counts, client names, pricing, traffic volumes, internal roadmap. Once the prose lands on a public/permanent surface (CHANGELOG → npm tarball; published GitHub issue), retraction is partial-or-impossible.

Distinct from prompt-injection or source-content leakage to the LLM provider — this class is specifically about **prose drafted by the agent for outbound surfaces**.

## Controls

- `packages/risk-scorer/hooks/external-comms-gate.sh` (P064) — PreToolUse:Bash + PreToolUse:Edit gate on outbound-prose author surfaces; routes to regex pre-filter (`hooks/lib/leak-detect.sh`) and the `wr-risk-scorer:external-comms` subagent for prose-context review.
- PostToolUse marker hook keyed on `sha256(draft + '\n' + surface)` — skips re-prompt on the same draft+surface combination.
- `RISK-POLICY.md` `## Confidential Information` — names the canonical classes the gate scans for.
- `BYPASS_RISK_GATE=1` — explicit override (e.g., publishing-org's own namespace per ADR-055; not a leak when it's our own).

## Watch-out

- `.changeset/*.md` bodies count as outbound prose because they land verbatim in CHANGELOG.md and every published npm tarball (P073).
- The subagent path can emit a placeholder `EXTERNAL_COMMS_RISK_KEY` instead of the actual SHA, causing the marker hook to reject and the gate to re-fire (P163, P166). Precompute the SHA in the calling skill.
- "Cross-context leak" sub-class (an agent invoked for purpose A sees confidential info from prior turn purpose B and uses it in outbound prose) — the gate catches this on the regex/subagent path; doesn't catch suppression failure when the agent paraphrases.
