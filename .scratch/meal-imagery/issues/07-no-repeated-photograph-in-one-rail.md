# 07: No repeated photograph in one rail

**What to build:** 135 photographs are shared by more than one Meal — two different oatmeals point
at the same Wikimedia file. Reuse across the library is fine and was agreed; the same photograph
appearing twice in one rail on screen is not, because the rail reads as though it is repeating
itself.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Two Meals visible in the same rail never show the same photograph.
- [ ] The choice is deterministic: the same data produces the same result every time.
- [ ] A Meal that loses its photograph to this rule still shows something — its Mosaic if it has one,
      otherwise its icon.
- [ ] Reuse across different rails, and across the library, is unaffected.

**Added by ticket 05 (2026-09-10).** Pass 10's "already in use" check now keys on
a photograph's source page as well as its address, so a mirrored archive photo is
recognised after a restart. Still shared: an açaí bowl (`S-058`, with two other
açaí meals) and "White bread with jam" (`S-008`, with "White bread & jam"); and
`D-037` / `L-027` (chicken tikka masala) wear two different Wikimedia files of
what looks like one picture — the perceptual case.
