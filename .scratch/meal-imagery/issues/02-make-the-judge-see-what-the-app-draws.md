# 02: Make the judge see what the app draws

**What to build:** The judging pass renders a Mosaic in order to grade it, and it does so in a
different language from the widget that draws it for the athlete. Nothing currently enforces that the
two agree. If they drift, every stored verdict describes a picture no one has ever seen, and the
measurement ticket spends real money to learn nothing.

Give both sides one description of the grid geometry and assert against it.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] One shared description of the grid — the cell rectangles for one, two, three and four Tiles —
      that both the Flutter component and the judging compositor are checked against.
- [ ] A test fails if either side's geometry changes without the other.
- [ ] Cover-crop behaviour and the separator match between the two.
- [ ] A rendered composite for a known Meal is visually identical to the widget's output for the
      same Tiles.
- [ ] It is written down that a divergence invalidates every stored verdict, so a future change to
      either side forces a re-measure.
