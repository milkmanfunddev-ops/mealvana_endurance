# Claude Design prompts — pin conflict label (Q-FR1 ruling, labeled override)

> **HOW TO USE THESE (standing rule, Xuan 2026-09-03):** every prompt below MODIFIES THE WORKING
> APP SCREENS IN PLACE — full phone frames, surrounding controls intact, the flow still
> interactive. Do NOT accept zoomed-in specimen tiles of the label or cropped widget close-ups:
> extra states come back as ADDITIONAL FULL SCREENS (or a toggle inside the prototype), because
> the downstream pipeline drives these screens in a browser and promotes them to renderings.

Copy-paste these into the Claude Design project (pre-workout redesign). Ruling: pins are honored
unconditionally; the UI must label any allergen/diet conflict visibly. Open design question:
warn at pin time, plan-generation time, or both.

## Prompt 1 — the conflict label, ON the real screens
"Reconstruct these Mealvana Endurance screens as full, interactive phone artboards (plum/cream
palette: ink #381633, cream #F8F6EB, orange accent #F78B14, teal #12C9A8, caution #DC2597;
Sansita display, Manrope body), then MODIFY THEM IN PLACE to add the conflict label. Keep every
surrounding control and keep the flow clickable — no cropped widget studies. Context: the athlete
pinned 'Oatmeal' and later declared a gluten allergy; the plan honors the pin (deliberate) but must
say so. Screens to produce, each a whole screen: (a) Formula Library list with the pinned Oatmeal
card carrying its conflict badge; (b) the Oatmeal detail screen with its existing DIETARY section
upgraded to personalized allergen+diet copy; (c) the plan-detail pin banner expanded with the
labeled row; (d) the same banner row in its tapped/expanded state offering Keep pin / Unpin for
this plan. Context: the athlete pinned 'Oatmeal' as their meal formula and later
declared a gluten allergy; the plan honors the pin (this is deliberate — pins always win) but must
say so visibly. Design the labeled state of the feeding slot: a compact warning affordance on the
row (not a blocking banner) reading like 'Pinned despite your gluten allergy', with (a) a resting
state that is noticeable but not alarming — this is informed consent, not an error, so avoid
red/danger styling; consider the yolk #E0AB12 caution hue, (b) a tapped/expanded state explaining
the rule in one sentence with a 'Keep pin' / 'Unpin for this plan' pair, and (c) how it coexists
with the existing pin banner ('Some pins honored, some skipped'). Show light and dark themes."

## Prompt 2 — pin-time warning moment (whole screens again)
"Same design system, same rule: modify the actual screens, full frames, flow intact. Produce the
PIN-TIME variant as complete screens: the athlete is about to pin a formula that
conflicts with a saved allergy (pinning 'Oatmeal + Banana + Honey', gluten allergy on file).
Design the confirmation moment inside the pin flow: a single inline notice above the confirm
button — 'This formula contains gluten, which you've listed as an allergy. Pinning it means
Mealvana will always include it.' — with 'Pin anyway' as the primary action and 'Choose another'
secondary. No modal unless the inline form can't carry it. Show both themes, and show the
after-state (the pinned row already carrying the Prompt-1 label so the two moments feel like one
system)."

## Prompt 3 — the timing decision aid (the ONE exception)
"This single prompt may produce a comparison board rather than a working screen — it is a decision
aid, not a design deliverable, and nothing downstream drives it. Produce a board comparing: warn at pin time only, at plan time only, and both —
each as a tiny storyboard (3 frames: pin moment → plan card → athlete reaction), annotated with
one line on where each fails (pin-time only: the athlete forgets by race week; plan-time only:
feels like nagging every plan; both: needs de-duplication so it doesn't feel doubled). This is a
decision aid for ratifying warn-timing."

## Attachment set (updated 2026-09-03 — the full click-through, per Xuan)
Attach ALL of these; the label must work across the whole flow:
1. `runs/2026-09-03-design-recording/11-formula-kit-app.png` — library top (tabs, Your Formulas, cards)
2. `runs/2026-09-03-design-recording/12-library-scroll.png` — pinned (Oatmeal, filled pin) vs unpinned card states
3. `runs/2026-09-03-design-recording/13-oatmeal-detail.png` — detail view. KEY DISCOVERY: a DIETARY
   section already exists (raw "Not gluten_free" chips, diet-exclusions only, no allergens, no
   personalization) — the design should UPGRADE this section, not invent a new one
4. `runs/2026-09-03-design-recording/15-new-formula.png` — authoring screen (save-time is the third
   conflict surface for personal formulas)
5. `runs/2026-09-03-design-recording/pin-banner-ref.png` — plan-detail banner rows
Add to Prompt 1's scope: card-level conflict badge in the library list; detail-view DIETARY section
upgraded to personalized allergen+diet copy; save-time warning in authoring. Prototype
formula-kit-v2.html is RETIRED (verified inconsistent — FP-6).
