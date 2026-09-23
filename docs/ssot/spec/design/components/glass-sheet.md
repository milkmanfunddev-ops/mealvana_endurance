# Design SSOT — Component: Glass Sheet (page form)

**Status: PROPOSED v1 (Lee, 2026-09-23) — authored app-side, awaiting Xuan.** Written from paywall
ticket 17 (decisions mp-493 §5 and §6, mp-457 §3, mp-496 §2, approved as mp-501), which needed a
whole screen to open as a summoned sheet. No reference rendering yet.

**Component contract** — a screen the router opens as a full-height `glass-sheet` over the screen
it was opened from, rather than as a new full-screen page. It owns the entrance, the scrim, the
ways to close and the theme its content renders in. It never decides whether a screen opens as a
sheet; the route that builds it does (for the paywall: a lapsed account's paywall pushed over a
read-only screen).

**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — `glass-sheet`, including its
scrim (blackberry 60 %), which every summoned glass surface inherits. No colour of its own.

## Contracts

- **GS-1 — the same entrance as every summoned glass sheet.** It rises from the bottom edge over
  the scrim on the same route the app's other glass sheets use (`showGlassSheet`), so a screen
  opened as a sheet enters exactly like a sheet a widget summons.
- **GS-2 — full height below the status bar.** The sheet runs from the bottom edge up to the
  status bar, with the `glass-sheet` top radius. The screen underneath stays where it was: dimmed
  by the scrim above the sheet, blurred through the glass.
- **GS-3 — closable, and closing returns.** A tap on the scrim, a drag down, or the content's own
  close button all close it the same way, back to the screen underneath, unchanged.
- **GS-4 — dark-first.** The content renders in the dark theme whatever the app's theme, because
  the tokens define the glass for the `blackberry` ground only (a light-surface variant is
  deferred). The Vana sheet does the same.
- **GS-5 — Reduce Motion.** With Reduce Motion on (the platform's "disable animations" or iOS's
  own switch) the sheet is at rest on the next frame, with no rise.

## Implementation

`lib/shared/widgets/kyle_design/materials/glass_sheet.dart` — `GlassSheetPage` (the page form) next
to `showGlassSheet` (the call form). Test: `test/shared/widgets/kyle_design/glass_sheet_page_test.dart`.
First use: the paywall's sheet presentation (`paywallRoutePage`,
`lib/features/subscription/presentation/screens/paywall_screen.dart`).

## Open questions for Xuan

- **Q-GS1** — the entrance's timing and curve are Material's bottom-sheet defaults; the token
  registry has no motion tokens yet.
- **Q-GS2** — no grabber. The other summoned sheets draw one; this form closes by its own close
  button, the scrim or a drag, and the paywall's top row already carries two buttons.
- **Q-GS3** — whether a whole screen opened as a sheet should leave a larger gap above it than the
  status bar, so more of the screen underneath shows.
