# 08: The icon state as a designed element

**What to build:** A fifth of the library shows no picture, and that population is permanent — a
Transformed Meal with no obtainable photograph will never have one. A rail where several rows fall
back to an icon should read as deliberate rather than as failing to load.

Design direction, since no reference exists: keep the icon at the same footprint a picture would
occupy so rows stay aligned and the rail does not go ragged; treat it as a first-class state rather
than an absence, with no "missing image" affordance, no placeholder glyph implying something failed,
and no meal name in a box. Existing token registry only.

**Blocked by:** 03 (the size and character of the population)

**Status:** done (2026-09-11), awaiting a look on a device

- [x] A Meal with no honest picture shows its icon at the same footprint a picture would occupy.
- [x] A rail mixing pictures and icons reads evenly, at the smallest supported width and in both
      themes.
- [x] Only the existing token registry is used — no colour literals, no Material brand colours.
- [ ] If anything under the theme or shared design components changes, the design sync is run.
- [x] Component tests cover the icon state alongside the existing Mosaic states.

**Done (2026-09-11).** `MealImageMosaic` takes a `fallback` and draws it in the
picture's own box and corners (`meal-image-mosaic.md` v1.1, MIM-9); `MealCard` passes the Meal's
icon as a rounded square. The same icon appears when every photograph fails to load, which closes
the blank 36px slot seen on the sim in ticket 07.

The icon is a flat tint of the card's ink (18%) with the glyph at the secondary-text weight
(55%), not the electrolyte circle it replaced. `tokens.md` limits electrolyte to burn and
per-workout fuel, and the electrolyte glyph almost vanished on the light card. The treatment was
checked at 320px in both themes in a widget render with stand-in photographs, not on a device;
the reading-evenly box is ticked on that render. Plan tiles, sheets and the swap screen's
"swapping out" row keep the electrolyte circle, since they never sit beside a picture.

The design sync was not run. It is user-invoked, and the Mosaic is still PROPOSED, so it is not
in the design library yet.
