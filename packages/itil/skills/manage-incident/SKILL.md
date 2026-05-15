---
name: wr-itil:manage-incident
description: Declare, triage, mitigate, and close an incident using an evidence-first workflow. Restores service first, then hands off to manage-problem for root-cause work.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill
deprecated-arguments: true
---

# Incident Management Skill

Declare, triage, mitigate, and close an incident using an evidence-first, cool-headed workflow. This skill's primary goal is **restoring service**. Once service is restored, the skill hands off to `wr-itil:manage-problem` so the underlying cause is tracked.

Incidents are time-bound events. Problems are persistent root causes. One problem can cause many incidents; one incident may (or may not) link to a problem.

## Operations

- **Declare**: `incident <title or symptoms>` — creates a new investigating incident
- **Update**: `incident <NNN> <details>` — append observations, evidence, or actions
- **Mitigate**: `incident <NNN> mitigate <action>` — record a mitigation attempt and outcome
- **Restore**: `incident <NNN> restored` — transition to `.restored.md` and trigger problem handoff
- **Close**: `incident <NNN> close` — only allowed when the linked problem is Known Error or Closed (or an explicit "no problem required" justification is recorded)
- **List**: `incident list` — active incidents, severity-sorted
- **Link**: `incident <NNN> link P<MMM>` — link an incident to an existing problem

## Lifecycle

| Status | File suffix | Meaning | Entry criteria |
|--------|-------------|---------|----------------|
| **Investigating** | `.investigating.md` | Symptoms reported, scope being established | Incident declared |
| **Mitigating** | `.mitigating.md` | Mitigation(s) in flight | At least one ranked hypothesis with cited evidence |
| **Restored** | `.restored.md` | Service verified restored | Mitigation applied + verification signal recorded |
| **Closed** | `.closed.md` | Incident complete | Linked problem is Known Error or Closed (or "no problem required" justification documented) |

## Evidence-First Workflow (The Cool-Headed Commitment)

During an incident, the instinct to jump to conclusions is strong. This skill forces evidence-first discipline via a required template. **Do not act on a hypothesis without at least one cited evidence source.**

### Required sections in every incident file

```markdown
## Observations
- [timestamp] <what was seen, from where — e.g. "14:02 UTC, 500s on /api/orders in Datadog dashboard foo">

## Hypotheses
- [ranked] <hypothesis> — Evidence: <log/repro/diff/metric reference>. Confidence: <low|med|high>.

## Mitigation attempts
- [timestamp] <action> → <outcome / verification signal>
```

### Mitigation preference

Prefer **reversible** mitigations over forward fixes:

1. Rollback to a known-good version
2. Feature flag off
3. Restart / cycle the affected component
4. Route traffic away
5. Scale up
6. Only after reversibles are exhausted: forward fix

Record every attempt, successful or not.

## Severity, not WSJF

Incidents are severity-driven and time-boxed. **WSJF does not apply to incidents** — the "effort" divisor is meaningless during a live event. WSJF applies to the resulting problem created via handoff.

Severity uses the Impact × Likelihood matrix from `RISK-POLICY.md`, interpreted as "right now, what's the live business impact?" — not "in general, how bad could this be?".

## Steps

### 1. Parse the request

Determine the operation from `$ARGUMENTS`:

- If arguments start with "list" → **delegate to `/wr-itil:list-incidents`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments match `<I###> mitigate <action>` → **delegate to `/wr-itil:mitigate-incident <I###> <action>`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments match `<I###> restored` → **delegate to `/wr-itil:restore-incident <I###>`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments match `<I###> close` → **delegate to `/wr-itil:close-incident <I###>`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments match `<I###> link P<MMM>` → **delegate to `/wr-itil:link-incident <I###> P<MMM>`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments start with `I<NNN>` or a bare number → this is an update
- Otherwise → declare a new incident

#### Deprecated-argument forwarders (ADR-010 amended + P071)

Per ADR-010's amended Skill Granularity section, word-argument subcommands that name distinct user intents are being split into their own named skills. During the deprecation window, this skill's Step 1 parser retains the legacy argument routes as **thin-router forwarders** that re-invoke the new named skill via the Skill tool AND emit a one-line systemMessage with the canonical deprecation notice so the user learns the new invocation shape.

**Forwarder for `list`** (P071 split slice 5 — new skill `/wr-itil:list-incidents`):

When `$ARGUMENTS` contains the word `list` as a top-level argument (not inside an incident body edit), delegate to `/wr-itil:list-incidents` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-incident list is deprecated; use /wr-itil:list-incidents directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the list logic locally — it invokes the Skill tool with `wr-itil:list-incidents` and returns the new skill's output verbatim. Duplicating the scan logic would harden the deprecation window into a permanent fork.

**Forwarder for `<I###> mitigate <action>`** (P071 split slice 6a — new skill `/wr-itil:mitigate-incident`):

When `$ARGUMENTS` matches the shape `<I###> mitigate <action>` (an incident ID followed by the literal word `mitigate` followed by a free-text action), delegate to `/wr-itil:mitigate-incident <I###> <action>` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-incident <I###> mitigate <action> is deprecated; use /wr-itil:mitigate-incident <I###> <action> directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the mitigation logic locally — it invokes the Skill tool with `wr-itil:mitigate-incident`, passes `<I###> <action>` through as the data parameters, and returns the new skill's output verbatim. Duplicating the rename + evidence-gate + timeline-append logic would harden the deprecation window into a permanent fork. The data-parameter shape `<I###> <action>` is permitted under ADR-010 amended — only the verb word `mitigate` is being split out.

**Forwarder for `<I###> restored`** (P071 split slice 6b — new skill `/wr-itil:restore-incident`):

When `$ARGUMENTS` matches the shape `<I###> restored` (an incident ID followed by the literal word `restored`), delegate to `/wr-itil:restore-incident <I###>` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-incident <I###> restored is deprecated; use /wr-itil:restore-incident <I###> directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the restore logic locally — it invokes the Skill tool with `wr-itil:restore-incident`, passes `<I###>` through as the data parameter, and returns the new skill's output verbatim. Duplicating the rename + verification-signal prompt + manage-problem handoff logic would harden the deprecation window into a permanent fork.

**Forwarder for `<I###> close`** (P071 split slice 6c — new skill `/wr-itil:close-incident`):

When `$ARGUMENTS` matches the shape `<I###> close` (an incident ID followed by the literal word `close`), delegate to `/wr-itil:close-incident <I###>` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-incident <I###> close is deprecated; use /wr-itil:close-incident <I###> directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the close logic locally — it invokes the Skill tool with `wr-itil:close-incident`, passes `<I###>` through as the data parameter, and returns the new skill's output verbatim. Duplicating the linked-problem gate + rename logic would harden the deprecation window into a permanent fork.

**Forwarder for `<I###> link P<MMM>`** (P071 split slice 6d — new skill `/wr-itil:link-incident`):

When `$ARGUMENTS` matches the shape `<I###> link P<MMM>` (an incident ID followed by the literal word `link` followed by a problem ID), delegate to `/wr-itil:link-incident <I###> P<MMM>` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-incident <I###> link P<MMM> is deprecated; use /wr-itil:link-incident <I###> P<MMM> directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the link logic locally — it invokes the Skill tool with `wr-itil:link-incident`, passes `<I###> P<MMM>` through as the data parameters, and returns the new skill's output verbatim. Duplicating the problem-file-lookup + Linked Problem section write logic would harden the deprecation window into a permanent fork. The data-parameter shape `<I###> P<MMM>` is permitted under ADR-010 amended — only the verb word `link` is being split out.

### 2. For new incidents: Check for duplicates FIRST (ADR-044 category-1 direction-setting)

Before creating, search `docs/incidents/` for active (non-closed) incidents with overlapping symptoms or scope. The user may already have an incident open for this outage.

1. Extract keywords from the description (e.g., "500 errors", "checkout", "login").
2. `grep -l` the keywords across `docs/incidents/*.{investigating,mitigating,restored}.md`.
3. If matches are found, present them via `AskUserQuestion` (this is the ADR-044 **category-1 (direction-setting)** surface — only the user knows whether the new symptoms describe the same outage as an existing ticket; the framework cannot resolve semantic similarity deterministically). Construct the call as:
   - `header: "Active incidents found"`
   - `multiSelect: false`
   - `question` body (plain prose, no parenthetical option-letters and no prose-ask phrasing per ADR-013 Confirmation criterion #1; the structured `options[]` below replaces both): `"I found active incidents that may be related: I003 (checkout 500s, mitigating), I007 (login slowness, investigating). Choose how to proceed:"`
   - `options[]`:
     1. `Update an existing incident` — description: "Switch to the update flow for the chosen incident ID; you'll name the ID in the next step."
     2. `Declare a new incident anyway` — description: "Proceed to Step 3 (assign next ID) and treat this as a distinct event."
     3. `Cancel` — description: "Exit without creating or modifying any incident."
4. If the user chooses **Update an existing incident**, switch to the update flow for the user-named incident ID.
5. If no matches, proceed to create.

### 3. For new incidents: Assign the next ID

Create `docs/incidents/` if it does not exist. Then scan for the highest existing `I<NNN>` and increment:

```bash
mkdir -p docs/incidents
last=$(ls docs/incidents/I*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^I[0-9]+' | sed 's/^I//' | sort -n | tail -1)
next=$(printf 'I%03d' $((10#${last:-0} + 1)))
echo "$next"
```

### 4. For new incidents: Gather information (P132 derive-first; ADR-044 category-4 silent-framework on derivable fields; category-1 direction-setting fallback only on Scope)

**Derive-first dispatch.** Incident declarations carry observable evidence in the user's prose, the working tree, `RISK-POLICY.md`, and the wall-clock — the framework can resolve most fields without firing `AskUserQuestion`. Only **Scope** is genuinely user-judgment (semantic blast-radius the framework cannot infer); only **Scope** retains the AskUserQuestion gate.

The P132 inverse-P078 trap (`docs/problems/known-error/132-...md`) is the load-bearing motivation: the I001 declaration regression fired a 4-question AskUserQuestion with 3 of 4 sub-questions being lazy classifications (Title kebab-derivable, Severity matrix-derivable, Start time git-log-derivable). This dispatch closes that regression on the manage-incident surface and mirrors `/wr-itil:capture-problem` Step 1.5's worked-example pattern (P185 derive-first refactor).

Resolve each field via the following dispatch. **The order is load-bearing** — every field except Scope resolves silently with a stderr advisory citing the source; Scope alone fires `AskUserQuestion` as the genuine category-1 surface.

| Field | Dispatch | ADR-044 category |
|-------|----------|------------------|
| **Title** | Derive silently. Kebab-case the first 8-10 non-stopword tokens of the user's prose description (same slug derivation as `/wr-itil:capture-problem` Step 1.4 and `/wr-itil:manage-problem` Step 4). Emit stderr advisory: `manage-incident: derived title='<slug>' from description; re-invoke or rename the file if the slug is wrong`. Do NOT fire AskUserQuestion. | category-4 silent-framework |
| **Symptoms** | Pull from user prose verbatim — the description text IS the symptoms surface for declaration. Place into the `## Observations` section template at Step 5. Do NOT fire AskUserQuestion. | category-4 silent-framework |
| **Start time** | Derive silently, three sources in priority order: (a) explicit timestamp in description (regex `\b\d{4}-\d{2}-\d{2}([ T]\d{2}:\d{2})?\b`, or relative form `"<N> (minutes|hours|days) ago"` resolved against current wall-clock); (b) if the description cites a specific file/dir/changeset-holding-area, run `git log --diff-filter=A --follow -- <path> \| tail -1` for first-touch evidence (the I001 regression's "first hold at 2026-04-24" was this exact shape — `git log --diff-filter=A --follow -- docs/changesets-holding/`); (c) otherwise default to current wall-clock UTC. Emit stderr advisory: `manage-incident: start-time derived as <ts> from <source>; cite an additional evidence anchor in the Timeline section if symptoms began earlier`. Do NOT fire AskUserQuestion. | category-4 silent-framework |
| **Severity** | Derive silently when evidence maps to a clear `RISK-POLICY.md` Impact × Likelihood cell. Cross-reference description signals against the matrix: (a) impact signals (service disruption keywords like `down` / `degraded` / `unavailable` → high; latency / throughput keywords → moderate; cosmetic / typo keywords → low); (b) likelihood signals (`reproducible` / `every request` → high; `intermittent` / `flaky` → medium; `one-off` / `single user` → low); (c) named anchors (held-cluster age cited → use that age to map cell; scorer state cited → use the cited band). When the cross-reference produces a single clear cell, set it silently and emit stderr advisory: `manage-incident: severity derived as <score> (<label>) from RISK-POLICY matrix + evidence: <evidence list>; re-invoke or update if mis-rated`. **Ambiguous-evidence fallback** (no mappable signal in description, or signals point to conflicting cells): fire AskUserQuestion with the Impact (1-5) × Likelihood (1-5) options as the genuine ADR-044 **category-5 (taste)** fallback surface. The fallback is genuine ambiguity, NOT defaults. | category-4 silent-framework (derivable); category-5 fallback (ambiguous) |
| **Scope** | Retain AskUserQuestion. Scope is the user-judgment surface — only the user knows whether downstream-adopter-risk is in scope, whether mobile is affected, whether the blast radius extends past the cited symptoms. The framework cannot resolve semantic scope deterministically (same reasoning as Step 2 duplicate-check). Construct the call with `header: "Incident scope"`, `multiSelect: false` if a closed enum applies or free-text capture otherwise. This is the canonical ADR-044 **category-1 (direction-setting)** surface — *"only the user knows the goals that haven't been written down yet."* | category-1 direction-setting |

**Inferred fields (no ask, no advisory needed)**:

- **Reported**: today's date (UTC)
- **Status**: always "Investigating" for new incidents

**Stderr advisory contract**: each derived field emits a SINGLE line to stderr (NOT stdout, NOT in the ticket body) per the capture-problem Step 1.5 pattern. The advisory text shape is I2-isomorphic — identical sentence structure across fields beyond substituted values + source names. Embedding the advisory in stdout would risk machine-readers parsing it as a ticket-body line; embedding it in the ticket body would violate ADR-011's required-section schema. Stderr is the correct channel — visible to interactive maintainers in the terminal; invisible to ticket consumers; loggable by orchestrators that capture subprocess stderr.

**ADR-026 cost-source grounding**: each derived field cites its source in the advisory (description token sequence for Title; explicit-regex / `git log` / wall-clock for Start time; RISK-POLICY matrix cell + named evidence for Severity). The `re-invoke or update if mis-rated` clause carries the reversibility marker ADR-026 mandates for ungrounded outputs.

**AFK fail-safe (ADR-013 Rule 6)**: under AFK orchestration, all derivable fields resolve without interactive input; only Scope's AskUserQuestion can block. The orchestrator should halt-with-stderr citing which field needed input rather than guess (Scope is genuinely user-judgment per JTBD-006's "Problems requiring my judgment ... are queued for my return, not guessed at"). manage-incident is rarely AFK-invoked because incidents are interactive by design (JTBD-201), so the halt-on-Scope path is the expected behaviour, not a regression.

### 5. For new incidents: Write the incident file

**File path**: `docs/incidents/<I###>-<kebab-case-title>.investigating.md`

**Template**:

```markdown
# Incident <I###>: <Title>

**Status**: Investigating
**Reported**: <YYYY-MM-DD HH:MM UTC>
**Severity**: <score> (<label>) — Impact: <label> (<n>) x Likelihood: <label> (<n>)
**Scope**: <who/what is affected>

## Timeline

- [<start-time> UTC] Symptoms began
- [<reported-time> UTC] Incident declared

## Observations

- [<timestamp> UTC] <what was seen, from where>

## Hypotheses

- [ranked] <hypothesis> — Evidence: <log/repro/diff/metric reference>. Confidence: <low|med|high>.

## Mitigation attempts

*(none yet)*

## Linked Problem

*(none yet — added on restore transition)*
```

### 6. For updates: Edit the existing file (evidence gate is ADR-044 category-2 deviation-approval)

Find the file by ID:

```bash
ls docs/incidents/<I###>-*.md 2>/dev/null
```

Append new observations, hypotheses, or timeline entries. **Every hypothesis must cite evidence.** If the user proposes a hypothesis without evidence, fire the **3-option evidence gate** — same shape as `/wr-itil:mitigate-incident` Step 3, for cross-skill cool-headed-commitment consistency. This is the ADR-044 **category-2 (deviation-approval)** surface: ADR-011's evidence-first rule is the existing decision; "Record anyway" is the user-approved deviation in this specific case. The user is the right authority for the bypass shape.

Construct the `AskUserQuestion` call as:

- `header: "Evidence gate"`
- `multiSelect: false`
- `question` body: `"Hypothesis '<one-line summary>' has no cited evidence reference. Per ADR-011 evidence-first rule, every hypothesis must cite a log / repro / diff / metric reference. Choose how to proceed:"`
- `options[]`:
  1. `Add evidence now` — description: "Provide the evidence reference (log line, dashboard URL, repro steps, diff hash, etc.); the hypothesis lands with the cited evidence."
  2. `Record anyway with audit-trail bypass` — description: "Land the hypothesis without cited evidence; agent appends `[<timestamp> UTC] Evidence-gate bypassed by user — reason: <justification>` to the incident file's `## Audit trail` section."
  3. `Cancel` — description: "Discard the hypothesis; do not write it to the file."

On option 2 (bypass), append the `Evidence-gate bypassed by user — reason: <justification>` line to the `## Audit trail` section of the incident file before writing the hypothesis. If the section does not exist, create it. The bypass-marker prose is fixed verbatim so post-incident review can locate every bypassed gate via grep.

### 7. For mitigate: delegate to `/wr-itil:mitigate-incident` (P071 split slice 6a)

The `mitigate` subcommand is now hosted by the `/wr-itil:mitigate-incident` skill. This step exists as a thin-router forwarder — the Step 1 parser recognises the `<I###> mitigate <action>` shape and delegates via the Skill tool. This body is intentionally empty of implementation logic; the canonical documentation of the rename, Status update, evidence-gate pre-flight, and Mitigation attempts append lives in `/wr-itil:mitigate-incident`.

Do not re-implement the rename or the evidence gate here — delegate. See "Deprecated-argument forwarders" under Step 1 for the canonical systemMessage.

### 8. For restore: delegate to `/wr-itil:restore-incident` (P071 split slice 6b)

The `restored` subcommand is now hosted by the `/wr-itil:restore-incident` skill. This step exists as a thin-router forwarder — the Step 1 parser recognises the `<I###> restored` shape and delegates via the Skill tool. This body is intentionally empty of implementation logic; the canonical documentation of the pre-flight checks, rename, Status update, Timeline append, and manage-problem handoff lives in `/wr-itil:restore-incident`.

Do not re-implement the rename or the problem handoff here — delegate. See "Deprecated-argument forwarders" under Step 1 for the canonical systemMessage.

### 9. For close: delegate to `/wr-itil:close-incident` (P071 split slice 6c)

The `close` subcommand is now hosted by the `/wr-itil:close-incident` skill. This step exists as a thin-router forwarder — the Step 1 parser recognises the `<I###> close` shape and delegates via the Skill tool. This body is intentionally empty of implementation logic; the canonical documentation of the Linked-Problem gate (accepting `.known-error.md`, `.verifying.md`, and `.closed.md`), the No Problem bypass, and the rename lives in `/wr-itil:close-incident`.

Do not re-implement the close gate or the rename here — delegate. See "Deprecated-argument forwarders" under Step 1 for the canonical systemMessage.

### 10. For list: Show active incidents

Read all `.investigating.md`, `.mitigating.md`, and `.restored.md` files in `docs/incidents/`. Extract ID, title, severity, and status. Sort by severity (highest first). Display as a markdown table.

### 11. For link: delegate to `/wr-itil:link-incident` (P071 split slice 6d)

The `link` subcommand is now hosted by the `/wr-itil:link-incident` skill. This step exists as a thin-router forwarder — the Step 1 parser recognises the `<I###> link P<MMM>` shape and delegates via the Skill tool. This body is intentionally empty of implementation logic; the canonical documentation of the problem-file lookup and the `## Linked Problem` section write (including the retroactive-link-from-No-Problem case) lives in `/wr-itil:link-incident`.

Do not re-implement the link logic here — delegate. See "Deprecated-argument forwarders" under Step 1 for the canonical systemMessage.

### 12. Edge cases

- **No problem required** — record a **No Problem** section with justification; close immediately.
- **Multiple incidents → one problem** — each incident links to the same `P<NNN>`; the problem file accumulates "Reported by incident" entries via `manage-problem`'s update flow.
- **Problem re-opens after the incident closed** — the closed incident stays closed; a new incident is declared for the new occurrence, linked to the re-opened problem.
- **Low-severity / solo-developer lightweight path** — for Sev 4-5 incidents, the skill may skip the Hypotheses section if the user confirms no investigation is needed. Timeline, Observations, and at least one mitigation attempt remain mandatory.

### 13. Quality checks

After any operation, verify:

- **ID uniqueness**: no duplicate `I<NNN>` in `docs/incidents/`
- **Naming convention**: `I<NNN>-<kebab-case-title>.<status>.md`
- **Status consistency**: Status field matches filename suffix
- **Required sections**: Timeline, Observations, Hypotheses (or documented skip), Mitigation attempts
- **Evidence discipline**: every Hypothesis has a cited evidence reference
- **Linked Problem** section present and consistent (or **No Problem** with justification) once the incident reaches Restored

### 14. Report (risk-above-appetite commit is ADR-044 category-3 one-time-override)

After any operation, report:

- The file path created/modified
- The incident ID and title
- The current status
- For restore: the linked problem ID (or "No Problem" note)
- Any quality-check warnings

Commit the completed work per ADR-014 (governance skills commit their own work):
1. `git add` all created/modified files for this operation
2. Delegate to `wr-risk-scorer:pipeline` (subagent_type: `wr-risk-scorer:pipeline`) to assess the staged changes and create a bypass marker. If the subagent type is not available in the current tool set (e.g. this skill is running inside a spawned subagent), invoke `/wr-risk-scorer:assess-release` via the Skill tool instead — per ADR-015 it wraps the same pipeline subagent.
3. `git commit -m "<message>"` using the convention for the operation type:
   - New incident: `docs(incidents): open I<NNN> <title>`
   - Incident mitigated: `docs(incidents): I<NNN> mitigated — <mitigation summary>`
   - Incident restored: `docs(incidents): I<NNN> restored — <action>`
   - Incident closed: `docs(incidents): close I<NNN>`
4. If risk is above appetite: use `AskUserQuestion` to ask whether to commit anyway, remediate first, or park the work. This is the ADR-044 **category-3 (one-time-override)** surface — in incident-mitigation context the tech lead may need to ship a fix despite higher residual risk to restore service fast (JTBD-201); the rule (RISK-POLICY appetite) still stands but this specific case warrants an exception. The 3-option vocabulary (commit anyway / remediate / park) is the genuine category-3 surface. If `AskUserQuestion` is unavailable, skip the commit and report the uncommitted state clearly per ADR-013 Rule 6.

### 15. Auto-release when changesets are queued (ADR-020)

**Skip this step if the skill is running inside an AFK orchestrator.** Orchestrators handle release cadence themselves per ADR-018 (Step 6.5). When in doubt, defer to the orchestrator by skipping this step.

Otherwise, after the commit in step 14 lands, drain the release queue so the fix actually lands on npm without requiring manual user action.

**Mechanism — delegate, do not re-implement scoring (per ADR-015):**

1. Invoke the release scorer. Two paths are valid:
   - **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
   - **Fallback**: if that subagent type is not available, invoke skill `/wr-risk-scorer:assess-release` via the Skill tool. The skill wraps the same pipeline subagent.
2. Read the returned `RISK_SCORES: commit=X push=Y release=Z` line.
3. **Drain condition**: if `push` and `release` are both within appetite (≤ 4/25, "Low" band per `RISK-POLICY.md`), AND `.changeset/` is non-empty, proceed to the drain action. Otherwise, skip the drain and report the unreleased state.

**Drain action (non-interactive, policy-authorised per ADR-013 Rule 6):**

1. Run `npm run push:watch` (push + wait for CI to pass).
2. If `.changeset/` remains non-empty after push (i.e. a release PR is pending), run `npm run release:watch` (merge the release PR + wait for npm publish).
3. Report the release: "Released <package>@<version>. Fix is now live on npm."

**Failure handling**: If `release:watch` fails (CI failure, publish failure), stop and report the failure clearly. Do not retry non-interactively — the user must intervene.

**Above-appetite branch (per ADR-042)**: If push or release risk is above appetite (≥ 5/25), the skill MUST auto-apply scorer remediations incrementally until residual risk converges within appetite, OR halt the skill per ADR-042 Rule 5 if the scorer cannot produce a convergent plan. **The skill MUST NOT release above appetite under any circumstance.** The skill MUST NOT call `AskUserQuestion` as a shortcut out of the auto-apply loop.

**Auto-apply mechanism (ADR-042 Rule 2):**

1. Parse the scorer's `RISK_REMEDIATIONS:` block.
2. Read the descriptions. Decide what to do. The agent MAY follow a scorer suggestion, adapt it, or do something else entirely. There is no requirement to rank all suggestions upfront or iterate through them in order.
3. **Verification Pending carve-out (ADR-042 Rule 2b)**: skip remediations that target a commit attached to a `.verifying.md` ticket.
4. Apply the chosen action using standard primitives (git, Edit, Bash). Each auto-apply is its own commit (ADR-042 Rule 3 — non-AFK has no iteration wrapper to amend into); each commit goes through architect + JTBD + risk-scorer gates per ADR-014.
5. Re-score via the same delegation path as step 1 above.
6. **Loop**: within appetite → drain per the Drain action above. Still above → continue working to reduce risk. The agent reads the new remediations and decides what to do next. Loop. Exhausted → Rule 5 halt.

**Rule 5 halt (non-AFK mode)**: halt the skill. Emit the terminal report naming the final `RISK_SCORES:`, the Auto-apply trail, any Verification Pending ticket IDs implicated, and a one-line scorer-gap note. The user resolves interactively.

`push:watch` and `release:watch` are policy-authorised actions when residual risk is within appetite per RISK-POLICY.md, so no `AskUserQuestion` is required for the drain itself (ADR-013 Rule 5). Auto-apply actions under Rules 2–7 are also policy-authorised per ADR-013 Rule 5.

## Related

- **P136** (`docs/problems/136-adr-044-alignment-audit-master.open.md`) — ADR-044 alignment audit master. This skill is the third high-ask SKILL audited under Phase 2 (after work-problem singular and mitigate-incident).
- **ADR-044** (`docs/decisions/044-decision-delegation-contract.proposed.md`) — Decision-Delegation Contract. The skill's AskUserQuestion surfaces align with the 6-class authority taxonomy: Step 2 duplicate-check is **category-1 (direction-setting)**; Step 4 is **category-4 (silent-framework)** on Title / Symptoms / Start time / Severity-when-evidence-present + **category-1 (direction-setting)** on Scope + **category-5 (taste)** fallback on Severity-on-ambiguity (P132 derive-first refactor 2026-05-15 re-classified Step 4 from "single cat-1 declaration" to "derive-first dispatch with cat-1 / cat-5 fallback only"); Step 6 evidence-gate is **category-2 (deviation-approval)**; Step 14 risk-above-appetite is **category-3 (one-time-override)**.
- **P132** (`docs/problems/known-error/132-agents-over-ask-in-interactive-sessions-conflating-mechanical-stages-with-user-interactive-stages.md`) — Agents over-ask in interactive sessions (inverse-P078). Step 4 derive-first refactor closes the 2026-05-06 I001 declaration regression where 3 of 4 sub-questions were lazy classifications. Composes with P185 (capture-problem Step 1.5 derive-first refactor — the in-tree worked-example precedent).
- **P185** (`docs/problems/...`) — capture-problem Step 1.5 derive-first refactor. Step 4 mirrors the same dispatch shape (silent classifier + stderr advisory + AskUserQuestion only on ambiguity).
- **ADR-013 amended Rule 1** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — structured user interaction; narrowed in P135 to defer to ADR-044 for framework-resolution boundary. All four surfaces retain `AskUserQuestion` as genuine user-authority surfaces under categories enumerated in ADR-044.
- **ADR-013 Confirmation criterion #1** — `grep -inE "Options:.*\(a\)\|Your call:\|which would you like\|which way?"` returns zero matches. Step 2's prior prompt body violated this with `Would you like to (a) update...` phrasing; the P136 Phase 2 refactor (2026-04-28) closed the regression by lifting options into the `AskUserQuestion` `options[]` mechanism.
- **ADR-011** (`docs/decisions/011-manage-incident-skill.proposed.md`) — incident lifecycle; evidence-first workflow; reversible-mitigation preference; Sev 4-5 lightweight path. Step 6's evidence-gate refactor (2026-04-28) extends ADR-011's evidence-first rule with the documented `Record anyway` audit-trail bypass that mitigate-incident already used (cool-headed-commitment consistency across the two incident skills).
- **ADR-014** — governance skills commit their own work. Step 14 unchanged.
- **ADR-015** — release scorer delegation pattern. Step 15 unchanged.
- **ADR-018** + **ADR-020** — release cadence. Step 15 unchanged.
- **ADR-026** — cost-source grounding. Step 6's audit-trail bypass note preserves grounding by capturing the user's justification at deviation time.
- **ADR-042** — auto-apply scorer remediations. Step 15 above-appetite branch unchanged.
- **P071** — skill-split origin (slice 6 — manage-incident is the host with thin-router forwarders for `list`, `mitigate`, `restored`, `close`, `link`).
- **P081** — structural-grep retrofit; the `manage-incident-adr-044-contract.bats` companion test file carries the `tdd-review: structural-permitted` marker as the bridge until P081 Phase 2 retrofit lands.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — Surface 1 refactor preserves the duplicate-check governance gate while removing the prose-ask compliance gap; Surfaces 2 + 3 + 4 retain genuine consent-gate-for-the-genuinely-direction-setting / deviation-approval / one-time-override.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — Step 6 evidence-gate refactor brings manage-incident into pattern parity with mitigate-incident's slice-6a evidence-gate. Adopters get one consistent evidence-gate pattern across both incident skills.
- **JTBD-201** (`docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md`) — Step 6 explicit `Record anyway` bypass strengthens the audit-trail outcome (implicit-bypass becomes explicit-bypass-with-permanent-trail) without weakening the cool-headed-commitment outcome (`Add evidence` remains the friction-free default; bypass requires conscious second choice).

$ARGUMENTS
