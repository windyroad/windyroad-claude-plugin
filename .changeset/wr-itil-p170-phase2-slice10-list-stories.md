---
"@windyroad/itil": minor
---

P170 Phase 2 Slice 10 — `/wr-itil:list-stories` read-only display skill at `packages/itil/skills/list-stories/SKILL.md` (~160 lines) plus 7-test contract bats fixture. Mirrors `list-problems` precedent (P071 phased-landing split per ADR-010 amended Skill Granularity rule).

- Allowed-tools: `Read, Bash, Grep, Glob` only — read-only contract, no Write / Edit (the list-* family is pure view per ADR-010).
- **Unfiltered mode** renders five lifecycle-grouped markdown tables (draft / accepted / in-progress / done / archived). Empty sections are omitted rather than rendered as empty headers.
- **Filtered mode** (`--rfc RFC-<NNN>`) renders a single execution-order table sourced from the RFC's frontmatter `stories:` array per ADR-060 line 259 — load-bearing for Slice 13's working-the-problem traversal (the orchestrator's per-RFC iter dispatch picks the first not-done story from this same array).
- **Cache-freshness check** uses the `git log -1 --format=%H -- docs/stories/README.md` pattern per P031 — filesystem mtime is unreliable in worktrees and fresh checkouts, so git history is the authoritative staleness signal. Cache-fresh + no `--rfc` filter reads `docs/stories/README.md` directly; otherwise live-scans.
- **I11 no-WSJF-leak invariant** enforced behaviourally at the output surface — no WSJF column header in any rendered table. Phase 2 stories MUST NOT participate in WSJF ranking per ADR-060 line 253.

7-test contract bats (per ADR-052) covering: SKILL.md presence + canonical name; read-only allowed-tools contract; lifecycle enumeration (all 5 state subdirectories named); RFC-frontmatter-stories-array-driven ordering (not filesystem / lexical order); P031 git-log cache-freshness pattern; I11 no-WSJF-column invariant. All 7 tests green.

JTBD-008 + JTBD-006 anchors: JTBD-008 (Decompose a Fix Into Coordinated Changes) via the per-RFC ordered story view that operationalises the "first-class entity" Desired Outcome; JTBD-006 (Progress the Backlog While I'm Away) via the filtered mode that feeds the AFK orchestrator's per-RFC iter dispatch in Slice 13.

Markdown-only writes — voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.

packages/itil/README.md updated to add the list-stories row to the skills table — closes the P159 JTBD-currency drift gate.
