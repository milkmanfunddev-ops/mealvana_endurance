# Claude Design prompt — Formula Kit v4 (iterate v3)

> **Standing rule:** MODIFY THE WORKING SCREENS IN PLACE. Full phone frames, surrounding controls
> intact, the flow clickable. Extra states = additional whole screens or in-prototype toggles —
> never cropped widget studies.

## Paste this
"Open the current Formula Kit prototype and iterate it in place. Four changes, all ruled by the
product owner on 2026-09-03 — keep everything else exactly as it is (the labeled-override system,
the collapsible post-pin label, the library anatomy, the pin-filter face are all approved).

1. **Swap the button emphasis in the pre-pin warning.** In the in-card warning (the one reading
'This formula contains gluten, which you've listed as an allergy…'), make **'Choose another' the
filled primary** and **'Pin anyway' the outline** button. Rationale: the safer choice should carry
the visual weight; pinning stays one tap away and is still fully permitted.

2. **Add a diet-conflict variant of that warning — deliberately softer.** When a formula conflicts
with a DIET preference rather than an allergy (keto, vegan, low-carb), show a single-line note
inside the card — no action pair, no interruption — e.g. 'Doesn't match your keto preference.'
Use the same caution color at lower emphasis so it reads as information, not a stop. Show it on a
formula that is 'Not Keto' in the library list.

3. **Add the allergen chips to the formula detail screen.** The detail screen's DIETARY section
currently shows diet exclusions only ('Not Keto'). Add the athlete's own allergens for that
formula, personalized — e.g. a chip reading 'Contains gluten — your allergy' in the caution color,
alongside the existing diet chips. Keep the section where it is.

4. **Draw the missing authoring surface: the save-time warning.** In the 'New formula' screen
(Name / Phase / Timing / Add Food / Notes / Save formula), show the state where the athlete has
added a food that conflicts with their profile: an inline note above 'Save formula' naming the
conflict, with saving still permitted — same policy as pinning (pins and personal formulas always
win; we disclose, we never block). Include both the allergy version and the softer diet version.

Return these as complete, interactive screens in the existing prototype — the library list with
both warning variants, the detail screen with allergen + diet chips, and the authoring screen in
both conflict states. Palette and type unchanged: plum #381633, cream #F8F6EB, orange #F78B14,
teal #12C9A8, caution #DC2597; Sansita display, Manrope body."

## After the session
Save the export to `~/Downloads`, hand it back here → reconcile (register:
`docs/design-reconciliation/formula-kit-v3-vs-formula-pin-surface.md` gets a v4 pass) → the pin
surface ratifies → **the bundle unblocks**.
