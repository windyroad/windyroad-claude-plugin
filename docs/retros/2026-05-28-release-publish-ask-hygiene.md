# Ask Hygiene — 2026-05-28 (release/publish + install-updates delta)

Per ADR-044 framework-resolution boundary. Lazy count is the regression metric (target 0). Second retro of 2026-05-28; covers the delta after `260d43b` — the `#168` merge/publish of `@windyroad/jtbd@0.8.4` and the install-updates pass.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| — | (none) | — | No AskUserQuestion calls in this delta. The user issued direct directives — `Push`, `Create the problem ticket for the node 20 stuff`, `Why is #168 waiting?` (→ merge+publish), `Run the retro` — each acted on without a confirmation ask. |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Note: the two correction signals this delta ("I shouldn't have to ask" re the Node-20 ticket; "Why is #168 waiting?" re the held release) were handled by **acting + capturing** (P325 created, P326 created, P148 + P320 appended, #168 merged+published), not by asking — consistent with don't-prose-ask + capture-on-correction. Both corrections are logged as recurrences of the P148 "defers completing instead of acting" parent class (conversational-capture surface + authorized-action-completion surface).
