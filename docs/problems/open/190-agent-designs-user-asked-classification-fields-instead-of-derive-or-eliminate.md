# Problem 190: Agent designs schemas with user-asked classification fields when the framework should derive silently OR eliminate the classification entirely — deeper generalisation of P185 derive-first-don't-ask

**Status**: Open
**Reported**: 2026-05-14
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

User correction 2026-05-14, in response to the Phase 3 + Phase 4 design I just shipped (commits `599e3be` ADR-060 amendment + `9b3a288` capture-problem Step 1.5b): *"NOOOO! The skill needs to be smart. It should match to an existing JTBD or create the missing JTBD. Also, it applies to ALL problems, not just business problems. The user should not have to say if it's a technical or business problem and MUST not be asked."*

The user is correcting three load-bearing properties of the design that just landed:

1. **JTBD trace must apply universally to ALL problems**, not just `type: user-business`. The bifurcation introduced by Phase 1 item 8c (the `type` tag) and entrenched by Phase 4 P4.2/P4.3/I12 (type-conditional invariant) is the wrong abstraction.

2. **The skill must be smart enough to match descriptions semantically against existing JTBD files, OR auto-create a missing JTBD** seeded from the problem description — not lexically detect `JTBD-NNN` ID citations and hard-block when absent. The Phase 3 P3.1 I shipped (lexical-detection-or-hard-block) is the wrong dispatch shape: it requires the user to already know which JTBD the problem serves, instead of letting the skill resolve it from the problem description's semantic content.

3. **The user MUST NEVER be asked technical-vs-business.** Not via AskUserQuestion (P185 already fixed that case), not via the `--type=` flag (anything the user shouldn't have to say, they shouldn't have a flag for either), not via the schema's `**Type**:` field on the ticket. The type field as a user-facing dimension is wrong; if it exists at all, it must be derived silently from the JTBD trace's persona-anchoring or eliminated entirely.

**Class-of-behaviour**: agent designs schemas with explicit user-asked classification fields when the framework should derive silently OR eliminate the classification entirely. P185 fixed the AskUserQuestion fallback (derive-first instead of always-ask); this correction goes one step deeper — *the field itself is the wrong abstraction*. Both the asking AND the field's presence-as-user-facing-dimension are signals of the same anti-pattern: the framework outsources a meta-property classification to the user when the framework could (or should not need to) compute it.

**Held cohort encodes the wrong design**: the three changesets at `docs/changesets-holding/` (P165 patch + P4.1 patch + P3.1+P4.2 minor) embed the type-conditional I12 invariant + lexical-only JTBD-trace dispatch + `--type=` flag surface + `**Type**:` body-field. The P4.1 patch (update-jtbd-references-section.sh `Related problems` lookup row) is salvageable because it's a reverse-trace helper that doesn't depend on the type bifurcation. P3.1+P4.2 minor is NOT salvageable — it needs full re-design before it ships to adopters.

## Symptoms

- Phase 3 + Phase 4 design has a `type` field as a user-asked dimension (--type= flag, **Type**: body field, AskUserQuestion fallback when ambiguous).
- I12 invariant keyed on `type: user-business` instead of universal — `type: technical` problems can have empty `jtbd:` traces, breaking the JTBD-as-source-of-truth invariant for any problem that doesn't happen to be tagged user-business.
- JTBD-trace dispatcher requires explicit `JTBD-NNN` lexical citation in description OR `--jtbd=` flag — does not semantically match against existing JTBD files; does not auto-create missing JTBDs.
- ADR-060 Phase 3 + Phase 4 amendment 2026-05-13 encodes all three drifts in its design subsections (A1/A3/A5 from architect review + F2/F4 from JTBD review).
- The user-facing UX requires the user to know type AND know which JTBD the problem serves — exactly the friction the JTBD-301 firewall is supposed to prevent on the plugin-user-side intake, but reintroduced on the maintainer-side intake.

## Workaround

- Don't graduate the held cohort. The P3.1+P4.2 minor encodes the wrong design.
- Use the cached `@windyroad/itil@0.27.1` capture-problem (P185 derive-first classifier) in the interim — it has the wrong type-classification field but at least doesn't ask the user.
- Capture user-business problems by passing `--type=user-business` AND citing a JTBD-NNN ID in the description, OR by capturing as `--type=technical` and re-classifying during /wr-itil:manage-problem ingestion.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: every problem captured under the Phase 3+4 design that ships; secondary: every adopter who consumes the Windy Road problem-management framework as a model and inherits the wrong abstraction.
- **Frequency**: (deferred to investigation) — every capture-problem invocation fires the wrong dispatch.
- **Severity**: (deferred to investigation) — High, because the design ships into a load-bearing skill surface; shipping the wrong design entrenches the friction across the adopter base.
- **Analytics**: (deferred to investigation) — sweep `docs/problems/` for `**Type**:` field presence; count how many user-business problems lack `**JTBD**:` traces despite the I12 spec.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Decide the type field's fate: eliminate entirely OR retain as derived-from-JTBD-persona but never user-facing. Architect+JTBD review needed.
- [ ] Design the semantic JTBD-matching algorithm: lexical signal classes (current) → fuzzy match against JTBD-NNN job-statements (next) → semantic similarity scoring (full). Threshold for "matched silently" vs "auto-create new JTBD".
- [ ] Design the JTBD auto-create flow: when no existing JTBD matches, the skill **collaborates with the user IN THE MOMENT** to draft the new JTBD — agent proposes job-statement / persona / desired-outcomes from the problem-description's signals; user confirms or amends; JTBD file is written RIGHT NOW (not deferred to a later /wr-itil:manage-jtbd call). User correction 2026-05-14: *"you and the user fill it out NOW."* The skill is collaborative-create, not placeholder-defer. AskUserQuestion is legitimate here per ADR-044 category 1 (direction-setting) for substantive design fields (job-statement, persona, desired-outcomes); the agent does what it can derive (slug, ID, frontmatter scaffolding) silently per ADR-044 category 4.
- [ ] Revert / amend the held cohort to align with the new design. P4.1 (reverse-trace helper) is salvageable; P3.1+P4.2 needs re-design.
- [ ] Author ADR-060 follow-up amendment 2026-05-14 reverting the type-conditional shape to universal-JTBD-trace + semantic-match-or-create.

## Dependencies

- **Blocks**: P170 graduation to user verification (the held Phase 3+4 cohort cannot ship until this redesign lands).
- **Blocked by**: (none — design space is clear; user direction is unambiguous).
- **Composes with**: [[P185]] (derive-first-don't-ask, sibling at the AskUserQuestion surface; this correction extends to the schema-field surface), [[P132]] (agents over-ask in interactive sessions; this correction extends to "agents over-classify in schema design"), [[P189]] (agent invents framing without user direction; same class — agent designs without user direction), [[P170]] (RFC framework parent — this is a Phase 3+4 redesign), ADR-060 (needs follow-up amendment 2026-05-14).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **User direction recorded 2026-05-14**: *"NOOOO! The skill needs to be smart. It should match to an existing JTBD or create the missing JTBD. Also, it applies to ALL problems, not just business problems. The user should not have to say if it's a technical or business problem and MUST not be asked."*
- **P185** — derive-first-don't-ask at AskUserQuestion surface; P190 extends to schema-field surface.
- **P132** — agents over-ask in interactive sessions; P190 extends to "agents over-classify in schema design".
- **P189** — agent invents framing without user direction; same class of agent-designs-without-user-grounding.
- **P170** — RFC framework parent; held Phase 3+4 cohort needs re-architecture.
- **ADR-060** — Phase 3+4 amendment 2026-05-13 needs a follow-up amendment 2026-05-14.
- **CLAUDE.md** — MANDATORY capture-on-correction P078 triggered this capture.
