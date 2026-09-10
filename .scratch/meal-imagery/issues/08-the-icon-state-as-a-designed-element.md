# 08: The icon state as a designed element

**What to build:** A fifth of the library shows no picture, and that population is permanent — a
Transformed Meal with no obtainable photograph will never have one. A rail where several rows fall
back to an icon should read as deliberate rather than as failing to load.

Design direction, since no reference exists: keep the icon at the same footprint a picture would
occupy so rows stay aligned and the rail does not go ragged; treat it as a first-class state rather
than an absence, with no "missing image" affordance, no placeholder glyph implying something failed,
and no meal name in a box. Existing token registry only.

**Blocked by:** 03 (the size and character of the population)

**Status:** ready-for-agent

- [ ] A Meal with no honest picture shows its icon at the same footprint a picture would occupy.
- [ ] A rail mixing pictures and icons reads evenly, at the smallest supported width and in both
      themes.
- [ ] Only the existing token registry is used — no colour literals, no Material brand colours.
- [ ] If anything under the theme or shared design components changes, the design sync is run.
- [ ] Component tests cover the icon state alongside the existing Mosaic states.
