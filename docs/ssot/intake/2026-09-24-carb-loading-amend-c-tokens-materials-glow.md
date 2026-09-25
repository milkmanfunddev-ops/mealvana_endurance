> **RESOLVED 2026-09-25 → ruling-desk block (Xuan): glow = GENERAL emphasis material with usage rules (option 2), folded into tokens.md §Materials; D7 ruled with it — macro strip keeps electrolyte as a NAMED Q-D3 exception**
type: ruling-request
bundle: carb-loading (release-1, pre-ship)

# Amendment (c) — tokens.md §Materials: glow materials vs "hairlines do the work"

## The question
The ruled loader anatomy (2026-09-24: continuous 26 px bar, faded track tail, uneven-intensity
orange fill hottest at the leading edge, glow; brighter glow on LOADED; plus the card glow)
introduces GLOW as an elevation/emphasis material. `spec/design/tokens.md` §Materials currently
tells the "hairlines do the work" elevation story — glow is undocumented material vocabulary.
Three materials were ruled today per the package; the token file must say what glow MEANS
(emphasis? live-state? completion?) and where it is permitted, or every future surface relitigates
it.

## Also carried by this ruling (already decided, needs folding)
- **Every carb figure is orange** per Q-D3 (daily intake); the HUD reference's cyan is
  `electrolyte` = burn-side and is **non-conformant** here. (Note: prototype v14's slot-page
  recommendation discs were teal carb-number discs; v15 corrected to the app's
  white-glyph-on-teal Add Food pattern — the disc is component chrome, not a carb figure. The
  token rule should be worded so both survive: carb *quantities* are orange; component chrome
  keeps its own contract.)
- **Yolk stays RESERVED** (unchanged; its meaning contract is still unruled).

## Options
1. Add a §Materials entry: glow = the live-fuelling-state material, permitted on the LOAD face
   loader + card only; hairlines remain the default elevation story everywhere else. (Narrowest.)
2. Add glow as a general emphasis material with usage rules. (Broader; invites spread.)

## Gates
The loader bar implementation; golden conformance for the LOAD face.

## Suggested home
`spec/design/tokens.md` §Materials, dated amendment per source-authority §3.3. Ratifier: Xuan.
Per the standing rule, this is a DESIGN ruling — expect the A/B visual (glow-narrow vs glow-general
usage rendered on the v15 face) before ratifying, not an MD-only decision.
