> **RESOLVED 2026-09-06 → spec/design/components/calendar-sheet.md v1 (home-shell@v1); today/selected: export governs**

type: ruling-request
bundle: home-shell@v1 (proposed — see 2026-09-06-tab-bar-v2-glass-scroll-collapse.md)

## Why this matters
The calendar sheet is mostly a design contract, but two thin **logic** contracts hide in its day
cells: the training dot must map from the ratified workout state machine (all four states), and
the fueling tint needs a definition of "logged day". Left unruled, the coding agent decides both
silently — and one wrong default (a hollow ring on a skipped day) recreates exactly the
"absence reads as failure" signal the design was built to avoid.

## Companion artifact & scope
Same HTML as the tab-bar intake (`New Homepage with updated navbar calendar and chat.html`).
**Only the tab bar, date header, and calendar sheet are in scope; ignore every AI element in
the file this version.**

## The design contract (ratify as drawn)
Full-height glass sheet summoned from the DateHeader (title tap or compact calendar button),
with a dim scrim beneath (see the glass material intake — the scrim is load-bearing: without it,
page chrome bleeds through and impersonates cell glyphs). Chrome: "August 2026 ˅" + month
chevrons; SUN–SAT eyebrow labels; weeks as rows, out-of-month cells empty; floating "Today"
glass pill bottom-left. Day cell anatomy is THREE FIXED SLOTS — day number, dot slot, tint slot
— and the extension contract is that future features only ever repaint the tint slot (this
sentence belongs in the spec verbatim; it is what keeps later lenses from re-architecting the
grid). Today = cream ring; selected = cream-filled cell. Tap a day → home navigates to that
date, sheet dismisses.

## The two logic rulings

**Q1 — dot slot ← workout state machine.** The dot derives from
`spec/design/components/workout-card.md` v3 states. Proposed mapping:
- `PLANNED` → hollow orange ring (2 px stroke, visibly dark centre — the 1-px version reads
  solid at cell size; fixed in the round-2 artboards)
- `DONE_CONFIRMED` and `DONE_VERIFIED` → filled electrolyte dot (no per-source distinction at
  cell size; provenance stays the cards' business)
- `SKIPPED` (active or passive) → **no dot** — a hollow ring on a past skipped day is the
  failure-signal the surface bans; the calendar stays neutral about skips
- rest day (no workout) → no dot
- Multiple workouts/brick day: one dot, "best" state wins (any completed → filled; else any
  planned → hollow). Ratifier may prefer a count — recommendation is against it at cell size.

**Q2 — tint slot ← "day has logged fueling".** Proposed v1 definition: the day has ≥ 1 athlete
food log entry (any source counts as the athlete's; a day with only engine-planned items is NOT
tinted). Tint intensity MAY scale with entry count in v1 or ship binary — ratifier's call;
recommendation: ship binary, scale later. The tint encodes **presence only** — an unlogged day
keeps the plain ground; no negative state, no dragonfruit anywhere on this surface. Day
boundaries follow the app's existing daily-macros day definition — reference it, do not invent
one here. (Instrumentation note: per-day rollup of fueling logs doesn't exist yet — the
app-side gate includes building that derivation; ops sibling to be filed if it needs backend
work.)

## Gates
App: `CalendarSheet` in `kyle_design/navigation/` on the new screen; goldens for a dense month
(channels diverging: tinted rest days AND untinted completed days), a sparse month (3 workouts,
3 tints — must read calm), and the enlarged cell-spec card; gesture manifest for summon/dismiss/
month-nav/day-tap; then `/design-sync`. Depends on the glass material ruling.

## Suggested spec home
New `spec/design/components/calendar-sheet.md` v1 (design contract + both mappings — the dot
mapping cross-references workout-card.md rather than restating its states).
