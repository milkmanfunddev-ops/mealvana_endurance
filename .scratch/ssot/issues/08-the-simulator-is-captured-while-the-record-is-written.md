# 08: The simulator is captured while the record is written

**Status:** done
**Blocked by:** 03.
**Next:** `/mattpocock-skills:implement 09`

**What to build:** A card that names a screen gets a real picture of that screen from the booted
simulator, taken while the proposal is written, not a placeholder. Existing goldens and design
frames are matched first; the simulator runs only for the rest. Each capture is saved under the
feature's images folder with the commit and app version it was taken at. The blocker from the
handoff is cleared first: `mobile-mcp` taps time out and `idb` is not installed. Stories 14 and
16 and the Pictures section.

- [x] The capture blocker is cleared and the fix is written in the README (what to install, how to check)
- [x] A capture command takes a screen name, drives the booted simulator there, and saves the image with commit and app version recorded beside it
- [x] Matching prefers an existing golden or design frame and records which one it reused
- [x] The epilogue captures for every card with a named screen and no picture, and uploads the asset once
- [x] Ten mealplanning cards that said "No picture yet" show a current capture after one run

**Done 2026-09-14.** The blocker was not idb: the dev app on the booted simulator was frozen under
a debug session left from the day before, painted but deaf, so every tap "succeeded" and nothing
moved. `scripts/ssot-capture-setup.sh` installs the idb client (pipx) and Facebook's prebuilt
companion under `~/.local` (the Homebrew tap fails on current Homebrew); `sync.mjs capture
--check` reports what is missing, including an app that answers with an empty accessibility
tree; every capture starts with terminate + launch so a frozen app never reaches a picture.
`_page/capture.mjs` drives by accessibility label from `_page/screens.json` (one entry per
screen: match phrases, an optional `reuse` golden, a `drive`), saves `<key>.png` with a
`<key>.json` sidecar (commit, app version, device, runtime), and `attach-image` records the
origin as a dated history line on the card. `sync.mjs pictures` is the epilogue's step 0b.
First run: 7 screens captured (timeline, settings, calendar sheet, meals tab, meal detail,
cooking mode, Vana chat), 3 reused goldens, 34 cards pictured; mp-266 and mp-270 (Paywall) stay
unpictured because only a Pro-required error reaches that screen and the dev account is Pro. The
Vana sheet cards reuse the golden: no drive opens the sheet on the simulator (the launcher opens
the full-screen chat). "Captured at" on the page and staleness are ticket 09.
