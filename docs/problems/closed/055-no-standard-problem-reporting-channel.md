# Problem 055: No standard problem-reporting channel for plugin users, and no reusable pattern for downstream projects to report upstream

**Status**: Closed
**Reported**: 2026-04-19
**Closed**: 2026-04-20
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: L — Part A (intake scaffolding) shipped 2026-04-20 AFK iter 3; Part B (`/wr-itil:report-upstream` skill per ADR-024) shipped 2026-04-20 in `@windyroad/itil@0.8.0` (commit 8788489).

**WSJF**: 0 — Closed.

## Closed (2026-04-20)

User direction via AskUserQuestion pre-AFK: close P055 because the original scope shipped. Corrections to the shape (intake template problem-first framing, skill classifier problem-first framing) are tracked separately as P066 and P067; scaffolding for downstream projects is tracked as P065; trigger wiring between manage-problem and report-upstream is tracked as P063; the risk-scoring gate on external comms is tracked as P064. These follow-ups do NOT rollback P055's shipped work — they extend and correct it.

## Part A shipped (2026-04-20, AFK iter 3)

Six new repo intake files landed in commit `<TBD>`:

- `.github/ISSUE_TEMPLATE/config.yml` — Discussions + Security Advisories contact links; blank issues disabled.
- `.github/ISSUE_TEMPLATE/bug-report.yml` — structured bug report (plugin, version, Claude Code version, OS, repro, expected, actual).
- `.github/ISSUE_TEMPLATE/feature-request.yml` — structured feature request (scope, target plugin, problem, proposed solution, alternatives).
- `SECURITY.md` — GitHub Security Advisories disclosure path; in-scope/out-of-scope; 90-day timeline; credit policy.
- `SUPPORT.md` — routing matrix (Discussions for questions, Issues for bugs, Security Advisories for vulnerabilities, per-plugin READMEs for plugin-specific behaviour).
- `CONTRIBUTING.md` — repo layout pointer to ADR-002 + ADR-030; npm test workflow per ADR-005; PR + changeset flow with ADR-021 manifest-sync gate; ADR + problem-ticket process pointers; governance-skill commit pattern per ADR-014.

Architect + JTBD reviews PASS. ADR-024 (Cross-project problem-reporting contract) explicitly scopes Part A as out-of-its-own-scope and "ships without its own ADR".

Part B remaining work: implement `packages/itil/skills/report-upstream/SKILL.md` against ADR-024's contract, plus a bats fixture-based test exercising mock upstream repos with and without templates. Estimated M effort given ADR-024 already governs the design.



## Direction decision (2026-04-20, user — AFK loop stop-condition #2)

**Reusable pattern surface** (part B): **New skill in `@windyroad/itil`**. A `/wr-itil:report-upstream` skill drafts a bug report targeting the upstream repo via `gh issue create`, reusing the ITIL plugin's problem-ticket conventions for structure, reproduction evidence, and severity tagging. No new plugin, no ADR-002 graph change.

(User note 2026-04-20: "this has been asked and answered previously" — if there is a prior record of this decision anywhere in the ticket history or session memory, it corroborates this choice; if not, this direction decision is the authoritative source.)

**Part A** (repo intake scaffolding for `@windyroad/agent-plugins` itself): proceeds in any case — `.github/ISSUE_TEMPLATE/`, `CONTRIBUTING.md`, `SUPPORT.md`, `SECURITY.md`.

Implication: effort drops from XL to L. No new plugin, no new ADR (the skill follows existing itil conventions). Next AFK iteration can: (1) scaffold the intake files in this repo, (2) add the `report-upstream` skill to `packages/itil/skills/report-upstream/SKILL.md` with a bats doc-lint test, (3) release both together.

## Description

Two related gaps, combined into one ticket because the intent is to let the cross-project pattern design (B) be driven by this repo's concrete need (A):

**(A) No intake for users of `@windyroad/*` plugins.** This repository has no `.github/ISSUE_TEMPLATE/` directory, no `CONTRIBUTING.md`, no `SUPPORT.md`, and no `SECURITY.md`. External users (developers who install the plugins via `npx @windyroad/agent-plugins` or individual packages) have no structured path to:

- File a bug report (e.g. hook fires incorrectly, skill fails to load, installer errors)
- Request a feature
- Report a security vulnerability privately (no GPG key, no advisory channel — so today a reporter would have to open a public issue or find the maintainer's email out-of-band)
- Ask a usage question without creating noise in the issue tracker
- Understand how to contribute patches

The consequence: problems users hit go uncaptured. The project loses signal about real-world failure modes, and users lose confidence that the project is maintained. For a public repo promoting a professional services brand, this is a reputation-shaped gap.

**(B) No reusable pattern for downstream projects to report to their upstream dependencies.** Every downstream project (addressr, bbstats, the user's own work) consuming `@windyroad/*` — or any npm package, or any upstream library — has to invent its own "report a problem to a dependency" workflow. There is no Windy Road plugin, skill, or convention that scaffolds this. The gap is the mirror image of (A): (A) is how an upstream receives; (B) is how a downstream sends.

Today the agent can open a GitHub issue on an upstream repo via `gh issue create`, but there is no standard about:

- Which upstream to report to (the direct dependency, or a transitive one?)
- What template to use (many upstreams have no templates; the agent fabricates free-form prose)
- How to attach reproduction evidence (test case, transcript link, log excerpt)
- Whether to CC the local problem ticket so both ends are linked
- How to classify severity in terms the upstream's own risk policy would understand
- What to do when the upstream has a SECURITY.md vs when it does not

These gaps are independently fixable but logically entangled: defining (A) well produces an intake format that (B) can target generically. The user's direction is to drive (B)'s design by solving (A) first as a concrete working example, then extract the reusable pattern.

## Symptoms

- Zero `.github/ISSUE_TEMPLATE/` in this repo — new issues arrive as free-form prose with no structured metadata (repro steps, environment, version).
- No `CONTRIBUTING.md`, `SUPPORT.md`, or `SECURITY.md` at repo root — GitHub's default sidebar "Contributing" and "Security" links resolve to 404.
- No discoverable way for external users to ask usage questions without opening an issue (no linked GitHub Discussions, no forum).
- Downstream projects (addressr confirmed, bbstats likely) maintain local "report this upstream" workarounds in their session memory rather than a structured flow.
- Agents working in downstream projects open upstream issues with free-form text and no cross-linking to the downstream's own problem ticket, making the audit trail uni-directional.
- No SECURITY.md means a vulnerability disclosure has to either (a) go via a public issue (exposure window), (b) rely on out-of-band contact (which external reporters don't have), or (c) not happen at all.

## Workaround

**For (A)**: Users discover the issue tracker on their own, file a free-form issue, and hope the maintainer can infer enough context to triage. Maintainer asks follow-up questions manually. Security issues go through out-of-band channels when reporters happen to know one; otherwise they go public or go unreported.

**For (B)**: Each downstream project invents its own workaround. Addressr has a session-memory note describing how to report upstream for specific plugins. The agent free-forms the upstream issue, often without linking the local problem ticket, producing a one-way audit trail.

## Impact Assessment

- **Who is affected**:
  - **Plugin users** (JTBD-101 consumers of `@windyroad/*`) — cannot report issues in a way that maps to this project's intake, cannot disclose security issues privately.
  - **Downstream project maintainers** (any team using `@windyroad/*` or other npm/library dependencies) — no plugin/skill scaffolds dependency-report flows.
  - **Solo-developer persona (JTBD-001)** — the agent has no structured pattern to follow when it notices an upstream bug while working on something else; falls back to free-form prose or silent abandonment.
  - **Tech-lead persona** — audit trail is broken: downstream problem tickets have no structured cross-reference to upstream issues they triggered.
- **Frequency**: Every external user who hits a problem; every downstream project whose agent notices an upstream defect; every security-researcher-style reporter who would normally look for `SECURITY.md`.
- **Severity**: Moderate. No installed plugin breakage, but intake signal is lost and reputation suffers. Security-disclosure path specifically has latent higher-impact risk (public exposure of undisclosed vulnerability) but Likelihood is Possible rather than Likely.
- **Analytics**: N/A for (A) — GitHub doesn't report on issue-template-less projects. For (B), addressr's session-memory note is one confirmed instance of downstream workaround.

## Root Cause Analysis

### Structural

Neither (A) nor (B) has ever been scoped in this project. The repo's scaffolding effort focused on plugin distribution (ADR-001 → ADR-003), monorepo structure (ADR-002), and governance pipelines (risk-scorer, architect, jtbd, tdd, etc.). The intake surface for external users was never included. Downstream reporting was similarly out of scope because the suite focused on governance WITHIN a project, not on cross-project flows.

### Candidate fixes

**(A) — concrete intake for this repo (low-effort, well-understood):**

1. Add `.github/ISSUE_TEMPLATE/config.yml` with `blank_issues_enabled: false` and `contact_links` pointing to Discussions + SECURITY.md.
2. Add bug-report, feature-request, and question templates under `.github/ISSUE_TEMPLATE/` — include fields for plugin name, plugin version, Claude Code version, reproduction steps, expected vs actual.
3. Add `SECURITY.md` at repo root with a private-disclosure path (tidelift, security@, or GitHub Security Advisories).
4. Add `SUPPORT.md` at repo root pointing users to Discussions for usage questions, the issue tracker for bugs, and SECURITY.md for disclosures.
5. Add `CONTRIBUTING.md` at repo root describing how to submit PRs, how to run tests, how to propose ADRs.
6. Optionally: enable GitHub Discussions and wire the "Ask a question" link to it.

**(B) — reusable pattern for downstream projects (design, needs ADR):**

7. Define the "report to upstream" skill contract — candidate: `@windyroad/itil` gains a new `report-upstream` skill. The skill takes (upstream-repo-url, local-problem-id, severity, summary, evidence) and produces:
    - A structured upstream issue via `gh issue create` respecting the upstream's template if one exists, or a sensible default if not.
    - A cross-reference link back-written into the local `docs/problems/NNN` ticket's Related section.
    - A "Reported Upstream" section in the local ticket with the upstream URL and date.
8. Define the reciprocal receiver contract — what upstream templates expose so downstream agents can target them deterministically. Falls out of (A) — the templates this repo ships become the reference shape.
9. Handle the "no template" case — when an upstream has no `.github/ISSUE_TEMPLATE/`, the skill emits a structured default prose form derived from the local problem ticket's sections (Description, Symptoms, Root Cause Analysis, Workaround, Impact Assessment).
10. Security path — when the local ticket is classified as a security issue, the skill routes to the upstream's SECURITY.md disclosure path rather than opening a public issue.

**New ADR candidate**: `docs/decisions/NNN-cross-project-problem-reporting.proposed.md` covering (7)-(10) — the contract between downstream "report-upstream" skills and upstream intake surfaces.

### Investigation Tasks

**For (A) — intake scaffolding:**

- [ ] Survey what other high-quality AI/developer-tool repos ship (Anthropic's own repos, modelcontextprotocol, changesets/changesets) for `.github/ISSUE_TEMPLATE/` patterns worth reusing.
- [ ] Draft `.github/ISSUE_TEMPLATE/bug-report.yml` with plugin-name, plugin-version, Claude Code version, repro steps, expected/actual fields.
- [ ] Draft `.github/ISSUE_TEMPLATE/feature-request.yml`.
- [ ] Draft `.github/ISSUE_TEMPLATE/question.yml` or route questions to GitHub Discussions via `config.yml`.
- [ ] Draft `SECURITY.md` with private-disclosure path. Decide whether to use GitHub Security Advisories (preferred, no infra needed) or a security@ mailbox.
- [ ] Draft `SUPPORT.md` pointing to the templates, Discussions, and SECURITY.md.
- [ ] Draft `CONTRIBUTING.md` describing PR flow, test commands (`npm test`), ADR process (`wr-architect:create-adr`), problem-ticket process (`/wr-itil:manage-problem`).
- [ ] Decide whether to enable GitHub Discussions and wire the intake config to it.
- [ ] Add a bats / docs-lint test asserting the files exist and contain the expected sections.

**For (B) — reusable pattern:**

- [ ] Architect review: should the "report to upstream" capability live in `@windyroad/itil` (new skill) or its own plugin? Factor in the itil package's current scope (problem management) — a `report-upstream` skill is a natural extension.
- [ ] Draft the ADR covering the contract (template discovery, default prose shape, local↔upstream cross-reference, security-path routing).
- [ ] Design the skill's argument shape and output contract (including the back-write to the local ticket's Related section).
- [ ] Decide SECURITY-path behaviour when upstream has no `SECURITY.md` (fall through to a public issue with a `security` label? refuse and escalate to the user? use GitHub Security Advisories if the upstream is on GitHub?).
- [ ] Write a fixture-based bats test exercising the skill against a mock upstream repo (one with templates, one without).
- [ ] Exercise the skill by having a downstream project (addressr or bbstats) dogfood it for a real upstream report.

**Ordering**: Do (A) first (scaffolding ships quickly, produces the reference intake shape). Then (B) drafts the skill against the patterns established by (A). Splitting the commits preserves the incremental-delivery pattern — (A) lands as a governance docs commit; (B) lands as a separate `feat(itil)` commit with an ADR.

## Related

- **JTBD-001** (Enforce Governance Without Slowing Down) — solo-developer persona; the agent needs a structured "report upstream" flow rather than free-form prose.
- **JTBD-101** (Extend the Suite with Clear Patterns) — plugin-developer persona; a reusable pattern for (B) is exactly the "clear patterns, not reverse-engineering" promise.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — tech-lead persona; bi-directional issue linkage (downstream ticket ↔ upstream issue) is the auditability core of this JTBD.
- **P034** (Centralise risk reports for cross-project skill improvement) — sibling "cross-project flow" ticket; informs the delivery shape of (B).
- **P045** (Auto plugin install after governance release) — upstream-blocked on Claude Code capability; demonstrates the need for a structured upstream-report path.
- **ADR-003** (Marketplace-only distribution) — names users as consumers of `@windyroad/*`; this ticket closes the intake gap that ADR-003's distribution model assumes.
- **ADR-015** (On-demand assessment skills) — precedent for a new skill's contract shape.
- Upstream survey targets: `anthropics/claude-code`, `modelcontextprotocol/servers`, `changesets/changesets`, `vercel/next.js` for `.github/ISSUE_TEMPLATE/` reference shapes.
- Addressr session-memory note (user's local) — one confirmed downstream workaround instance for (B).

## Fix Released

Both halves of P055 are now live:

- **Part A (repo intake scaffolding)** — shipped 2026-04-20 in commit `e36cf84` (`docs: add OSS intake scaffolding — issue templates, SECURITY, SUPPORT, CONTRIBUTING`). The six files documented above (`.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/bug-report.yml`, `.github/ISSUE_TEMPLATE/feature-request.yml`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`) are present at repo root / under `.github/`.
- **Part B (`/wr-itil:report-upstream` skill per ADR-024)** — shipped 2026-04-20 in commit `8788489` (`feat(itil): add /wr-itil:report-upstream skill (P055 Part B, ADR-024)`), released as `@windyroad/itil@0.8.0` via the changeset release PR (merge commit `80841fd`). The 8-step contract from ADR-024 Decision Outcome is implemented in `packages/itil/skills/report-upstream/SKILL.md`; a 9-assertion doc-lint bats test (`packages/itil/skills/report-upstream/test/report-upstream-contract.bats`) guards the ADR-024 Confirmation criterion 2 checks plus the architect-required ADR-027 Step-0 deferral, ADR-028 voice-tone gate, and three-distinct-AFK-branches documentation. All 9 tests PASS as of this transition.

ADR-024 Confirmation cross-reference checks (criterion 3) are satisfied:

- `packages/itil/skills/manage-problem/SKILL.md` names the optional `## Reported Upstream` section as an allowed appendage (confirmed at line 50).
- `docs/decisions/002-monorepo-per-plugin-packages.proposed.md`'s `itil/` inventory lists `report-upstream` (confirmed at lines 102 / 109).
- `packages/itil/package.json` does not enumerate individual skills, so the "if" clause of criterion 3 does not apply.

Awaiting user verification. Candidate verification paths per ADR-024 criterion 4 (behavioural replay):

- Install `@windyroad/itil@0.8.0` into a downstream project (addressr or bbstats) and invoke `/wr-itil:report-upstream` against a real upstream with and without `.github/ISSUE_TEMPLATE/`.
- Confirm the `## Reported Upstream` section is back-written into the local ticket and the `## Related` section gains a `Reported upstream: <URL>` line.
- Confirm the upstream issue body carries the `Cross-reference: <downstream URL>` line.
- For the security path: confirm `gh api .../security-advisories` routing when upstream declares GitHub Security Advisories in `SECURITY.md`, and the `AskUserQuestion` halt-and-surface when upstream has no `SECURITY.md`.

Criterion 6 (downstream adoption by addressr or bbstats within 3 months) is advisory/non-blocking per ADR-024 and is not required to close this ticket.
