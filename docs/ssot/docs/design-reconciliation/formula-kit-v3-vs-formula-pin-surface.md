# Reconciliation — Formula Kit v3 (Claude Design, 2026-09-03) vs the ratified pin policy

**Prototype:** `prototypes/formula-kit/v3.html` (walked in Chrome: library list, both conflict
states, expander, pin-filter face). **Authority:** `food-recommendation.md` §1a (RULED: labeled
override — pins honored unconditionally AND the conflict labeled) · `spec/design/components/
formula-pin-surface.md` FP-1..FP-8 (PROPOSED) · `spec/design/tokens.md` (dragonfruit meaning
contract, Q-D9).

## TRACED — consistent with what we ratified
| # | Finding |
|---|---|
| T-01 | **§1a labeled override implemented exactly as ruled:** the pinned Granola Bar is HONORED and carries "Pinned despite your gluten allergy"; the expander reads "Pins always win: this formula stays in your plans even though it conflicts with the profile you added later." Pin fidelity + informed disclosure, no silent removal ✓ |
| T-02 | **Q-FP2 (warn-timing) answered BOTH, and better than proposed:** pin-time warning ("This formula contains gluten… Pinning it means Mealvana will always include it" + Pin anyway / Choose another) AND the persistent honored-pin label. Both are INLINE IN THE CARD — no modal — which also satisfies the "edit the flow, not specimen tiles" rule |
| T-03 | **Allergies-changed-after-pin** (the sub-question left open on the intake file) is answered in copy: "…the profile you added later" — the pin persists, labeled, never auto-unpinned ✓ matches the ruling |
| T-04 | **Keep pin / Unpin** affordances present in the expanded state, as FP-4 anticipated |
| T-05 | Token use: the label, its icon, and the primary action render in **dragonfruit rgb(220,37,151)** — permitted by Q-D9's widened contract (destructive OR out-of-range caution) ✓ conformant. Yolk correctly NOT used (it has no meaning contract) |
| T-06 | FP-5 Formula Library anatomy preserved (Before/During/After, timing chips, Your Formulas + New, per-card pin toggle, macro chips) ✓ |
| T-07 | Pin-filter face (header pin glyph) shows only pinned formulas with the label intact — a state the app has and the spec had not recorded |

## DESIGN-FIX
| # | Finding |
|---|---|
| D-01 | **"Pin anyway" is styled as the FILLED PRIMARY in dragonfruit while "Choose another" is the outline.** In our system the filled dragonfruit primary reads as the *recommended/destructive-confirm* action. For an allergy conflict the safer default should carry the visual weight: make "Choose another" the primary and "Pin anyway" the outline (the ruling honors the pin either way — this is emphasis, not permission). RULING-adjacent; recorded as a fix since §1a doesn't dictate emphasis |
| D-02 | Conflict copy names only the allergy ("contains gluten"). FP-7/Q-FP3 asked for allergens **and diet** exclusions personalized; a vegan-conflict formula has no shown treatment. Extend the copy register to diet conflicts |

## SPEC-ADD
| # | Finding |
|---|---|
| S-01 | **Two distinct conflict states** exist and the spec has one (FP-4): (a) PRE-PIN warning (decision moment, offers Pin anyway / Choose another) and (b) POST-PIN label (persistent, collapsible, offers Keep pin / Unpin). Split FP-4 into FP-4a/FP-4b with their own copy and affordances |
| S-02 | The post-pin label is **collapsible** (chevron; collapsed = one line, expanded = explanation + actions). Persistence of that collapse state across sessions is unspecified — FP-4b needs the rule (proposal: collapsed by default, expansion not persisted) |
| S-03 | **CORRECTED on second walk:** the detail screen IS in v3 (reachable by card tap) and its DIETARY chips are already cleaned up — "Not Keto" instead of the app's raw "Not keto"/"Not gluten_free", so **Q-FP3's copy fix is partly delivered**. Still absent: allergen chips with personalization on that screen, and the authoring save-time surface (FP-8) |

## RULING-NEEDED
| # | Question |
|---|---|
| R-01 | D-01's emphasis: which action is the filled primary at the pin-time moment — "Choose another" (safety-first, recommended) or "Pin anyway" (as drawn)? |
| R-02 | Does the pre-pin warning fire for DIET conflicts too (vegan/keto), or allergies only? (D-02 depends on this) |

## Disposition
The prototype is **consistent with the ratified §1a policy** — pins win, conflicts are labeled,
nothing is silently removed — and it answers two open questions (warn-timing = both; allergies-
changed-later = pin persists labeled). Gaps are scope (detail + authoring screens missing) and
emphasis (D-01), not policy violations. Next: two rulings, then FP-4 splits into FP-4a/b and the
spec absorbs the pin-filter face.

---

# v4 PASS (2026-09-03) — the two rulings + the two missing surfaces

Prototype: `prototypes/formula-kit/v4.html`, walked in Chrome (library, both conflict variants,
Bagel detail, New-formula authoring).

## TRACED — all four requested changes delivered
| # | Finding |
|---|---|
| T-08 | **R-01 applied:** "Choose another" is now the filled dragonfruit primary; "Pin anyway" is the outline. Safer default carries the weight, pin still one tap ✓ |
| T-09 | **R-02 applied, differentiated exactly as ruled:** allergy conflict keeps the full warning + action pair; DIET conflict renders a single line with no actions — "Doesn't match your keto preference." on the Banana card ✓ FP-4a satisfied |
| T-10 | **Detail-screen allergen chips (Q-FP3) delivered:** Bagel + PB + Jam's DIETARY section now reads **"Contains gluten — your allergy"** (filled dragonfruit — personalized) · "Contains peanut" (neutral — an allergen the athlete does NOT have) · "Not Gluten-Free / Not Keto / Not Low Carb / Not Paleo" (clean copy, no machine strings). The personalized-vs-neutral distinction is a contract worth keeping: allergen chips are emphasized ONLY when they match the athlete's profile |
| T-11 | **Authoring save-time warning (FP-8) delivered:** the New-formula screen with a bagel added shows, above Save, "Bagel contains gluten, which you've listed as an allergy. **You can still save** — Mealvana will always include your own formulas." + the softer keto line beneath. Save stays enabled ✓ disclose-never-block, consistent with §1a |
| T-12 | Post-pin label (FP-4b) unchanged from v3 ✓; library anatomy, pin-filter face, tabs unchanged ✓ |

## SPEC-ADD
| # | Finding |
|---|---|
| S-04 | **Allergen chip emphasis rule** (from T-10): a chip naming an allergen the athlete HAS renders emphasized/personalized ("Contains gluten — your allergy"); an allergen they do not have renders neutral ("Contains peanut"). Add to FP-7. |
| S-05 | **"Coach insight" appeared in the authoring screen** ("Get a quick read on this formula", expandable) — NOT requested by the prompt and belonging to the AI-coach feature, not this surface. Either scope it out of the pin-surface spec (recorded as out-of-scope chrome) or file it as its own component. Not a defect; an unowned element. |

## Disposition
**v4 satisfies FP-4a, FP-4b, FP-7 (incl. Q-FP3) and FP-8.** The pin conflict-label system is
design-complete: pre-pin (allergy hard / diet soft), post-pin persistent label, detail-screen
disclosure, authoring save-time. Remaining: fold S-04 into FP-7, dispose S-05, then
`formula-pin-surface.md` is ready to ratify — **which unblocks the bundle.**
