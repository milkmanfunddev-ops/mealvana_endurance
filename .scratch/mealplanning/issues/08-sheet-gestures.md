# 08: Sheet gestures — three heights and the condense

**Status:** blocked
**Blocked by:** 06
**Next:** `/mattpocock-skills:implement 08` once 06 lands.

**What to build:** The grabber drags the sheet between its three heights: `auto` for a sheet that is
one message and a dismiss, 75% at rest with a card and replies, 100% expanded. Dragging down past the
shortest dismisses. Every dismissal — the grabber, the close button, the scrim, system back —
condenses the sheet back into the launcher over about 470ms, with the animation's origin at the
launcher's own corner, so what the athlete was reading ends where the thing that brings it back lives.

- [ ] The three heights exist and the grabber drags between them; the page behind stays visible at rest
- [ ] A drag down past the shortest height dismisses rather than sticking
- [ ] All four dismiss paths condense into the launcher; none slides the sheet off-screen
- [ ] The composer's focus is released on collapse, so the keyboard does not outlive the sheet
- [ ] Widget tests for each height transition and each dismiss path
- [ ] Simulator: the drag feels like the export, and nothing fights the scroll underneath

**Full history:** `../archive/issues-2026-09-10/12-sheet-gestures.md`
