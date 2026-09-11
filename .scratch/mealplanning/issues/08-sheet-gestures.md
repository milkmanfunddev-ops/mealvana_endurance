# 08: Sheet gestures — three heights and the condense

**Status:** built; the drag checked on the simulator (2026-09-10)
**Blocked by:** None
**Next:** Rulings on the three questions under "For the ruling desk", then 09 when its trigger set is decided.

**What to build:** The grabber drags the sheet between its three heights: `auto` for a sheet that is
one message and a dismiss, 75% at rest with a card and replies, 100% expanded. Dragging down past the
shortest dismisses. Every dismissal — the grabber, the close button, the scrim, system back —
condenses the sheet back into the launcher over about 470ms, with the animation's origin at the
launcher's own corner, so what the athlete was reading ends where the thing that brings it back lives.

- [x] The three heights exist and the grabber drags between them; the page behind stays visible at rest
- [x] A drag down past the shortest height dismisses rather than sticking
- [x] All four dismiss paths condense into the launcher; none slides the sheet off-screen
- [x] The composer's focus is released on collapse, so the keyboard does not outlive the sheet
- [x] Widget tests for each height transition and each dismiss path
- [x] Simulator: the drag feels like the export, and nothing fights the scroll underneath

## Simulator pass (iPhone 17 Pro, dev, 2026-09-10)

On the Timeline, the day's conversation opened at 75 % with the page legible above it. Dragging the
grabber up expanded it to the status bar. Scrolling the transcript at 100 % scrolled the text and left
the sheet where it was. With the composer focused, a drag down collapsed the sheet to 75 % and the
composer lost focus. A second drag down dismissed it: a screenshot taken mid-dismissal shows the sheet
shrinking into the bottom-right corner, and it closed onto the Timeline. The simulator had the hardware
keyboard attached, so no on-screen keyboard was seen; focus was read from the accessibility tree.
`auto` was not seen on the device: the day's conversation already had a thread (see below for when
`auto` applies).

## Notes (2026-09-10)

**Where things are.** The heights and the drag are in `VanaSheet`, now stateful
(`lib/shared/widgets/kyle_design/navigation/vana_sheet.dart`). The feature only picks the rest height
(`VanaSheet.rest`). `VanaSheetRoute` places the sheet on the keyboard and under the status bar, and
runs the rise and the condense; the sheet's height inside that room is the sheet's own. The rule for
`auto` is `VanaExchange.oneMessage` in the domain.

**How it behaves.**
- **The export's thresholds**, from its `chHUp`: 24 px up expands; 90 px down collapses from 100 % or
  dismisses from rest; a tap on the grabber toggles; an upward pull at rest gives at 35 %. A flick
  faster than 700 px/s counts as passing the threshold; the export has no flick.
- **Past the shortest height from 100 %.** A drag from 100 % that ends 90 px past the rest line
  dismisses (VS-7). A shorter drag collapses, as the export does.
- **The drag target** is the whole 48 px chrome row, less the two buttons. The tap toggle is only the
  88 × 36 area around the grabber, so a near miss on close does not expand the sheet. The transcript
  keeps its own scroll.
- **100 % stops under the status bar**, not at the screen's top edge.
- **`auto`** is as tall as what the sheet holds, up to 75 %. The sheet rests there only if the first
  transcript it sees is one settled message of Vana's with no card and at most one reply. An empty
  conversation starts at 75 % and stays there, because the opener streams in and VS-4 forbids a resize
  while streaming. `auto` is therefore rare today; it is built for 09's "return" sheet.
- **Focus.** Collapsing from 100 % unfocuses the composer, as the export does. Every dismissal
  unfocuses it when the pop starts: the route's focus scope drops focus while the animation runs in
  reverse. Tests hold this for all four paths.
- **One tree shape at every height.** Moving between `auto` and a fixed height changes only
  parameters, never widget types. The first build changed shape here, which on a device would have
  remounted the sheet mid-drag and dropped the keyboard after the first send. The review caught it, and
  a frame-by-frame drag test now covers it.

**For the ruling desk.**
- **Send from `auto`.** The athlete's first send grows an `auto` sheet to 75 %, in the frame the send
  lands. VS-4 says send does not change the height. But `auto` is as tall as what it holds, so holding
  it through the turn would grow it with every streamed word, which is worse. The export goes further
  and expands to 100 % on every send. That was not built, because VS-4 governs.
- **"A dismiss"** is read as any single reply, whatever its label. A lone action ("Plan my week") also
  rests at `auto`. A receipt part (memory saved, logged) counts as a card, so the sheet rests at 75 %.
- **Condense origin.** The ticket says the launcher's corner, but the code (unchanged since 06) uses
  the launcher's centre. On the device it reads as closing into the corner.

**Seen on the device, not fixed (from 06):** under the scrim, the page's accessibility nodes report
the barrier's "Close" label. This comes from the route's barrier, not from this ticket.

**Full history:** `../archive/issues-2026-09-10/12-sheet-gestures.md`
