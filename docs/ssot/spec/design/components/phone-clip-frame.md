# Design SSOT — Component: Phone Clip Frame

**Status: PROPOSED v1 (Lee, 2026-09-21) — authored app-side, awaiting Xuan.** Written from paywall
ticket 14 (decisions mp-493 §1 and §6, mp-497 §4, approved as mp-498). No reference rendering yet;
Bevel's paywall is the layout it follows, in our branding.

**Component contract** — a short, silent recording of our own app playing inside a phone-shaped
frame. It owns the frame, the poster, and when the clip counts as over. It never decides what the
clip shows or what happens after it; the page that composes it does.

**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the bezel takes `glass` with
`lift` (floating chrome, not a content card). The screen behind the clip is `blackberry` while
nothing has drawn. The frame introduces no colour of its own and tints nothing it shows.

**First use:** the paywall's opening page (`paywall_screen.dart`), with the clip bundled at
`assets/video/paywall_clip.mp4` and its first frame at `assets/video/paywall_clip_first.jpg`.

## Contracts

- **PCF-1 — silent, once.** The clip plays muted, once, without looping, and mixes with other audio
  so it never stops the athlete's music. Until its first frame plays, the poster (the clip's first
  frame) holds the screen, so the frame never shows an empty box or a spinner.
- **PCF-2 — the end is always reported, once.** The frame tells its page the clip is over exactly
  once: when it ends, when it fails, or when it has not started within the load timeout (3 s by
  default). A page that waits on the clip never waits forever. A failed clip keeps the poster; no
  broken-video surface is drawn.
- **PCF-3 — still.** In the still form the frame shows the poster alone and no player is made. It is
  the Reduce Motion form.
- **PCF-4 — proportions.** The frame fills the width it is given at the clip's aspect ratio. The
  bezel is 3 % of the width and the outer corner 14 %; the screen's corner is the outer corner less
  the bezel. It keeps these at any size.
- **PCF-5 — semantics.** The frame is one image to a screen reader, labelled with what the clip
  shows. The video itself is excluded.

## Implementation

`lib/shared/widgets/kyle_design/data/phone_clip_frame.dart` — `PhoneClipFrame`, the
`PhoneClipPlayer` seam, and `VideoPhoneClipPlayer` (plays a bundled asset through `video_player`).
Widget tests pass a fake player (`test/shared/widgets/kyle_design/phone_clip_fakes.dart`).

## Open questions for Xuan

- **Q-PCF1** — the bezel on the light (cream) ground. `glass` is dark-first and its light variant is
  deferred, so on cream the bezel reads only by its lift shadow.
- **Q-PCF2** — whether the frame should draw a dynamic-island cut-out. The clip is recorded from the
  simulator, so its own status area already shows one; v1 draws none.
