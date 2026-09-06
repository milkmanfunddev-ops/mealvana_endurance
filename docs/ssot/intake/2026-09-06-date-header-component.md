> **RESOLVED 2026-09-06 → spec/design/components/date-header.md v1 + macro-dashboard.md home-shell recomposition (home-shell@v1)**

type: ruling-request
bundle: home-shell@v1 (proposed — see 2026-09-06-tab-bar-v2-glass-scroll-collapse.md)

## Why this matters
The home screen's persistent `ViewTabs` + `WeekStrip` block (~150 px of every view) is replaced
by a one-line date header; that is a surface-composition change to the fuel-timeline home AND a
new component, and it silently removes the WeekStrip's one-tap adjacent-day navigation — the
replacement affordance needs to be ruled, not assumed.

## Companion artifact & scope
Same HTML as the tab-bar intake (`New Homepage with updated navbar calendar and chat.html`).
**Only the tab bar, date header, and calendar sheet are in scope; ignore every AI element in
the file this version** (companion pill/modes, sparkle suggestions, Add-to-Dinner, chat sheet,
Ride Fuel Plan editor).

## The questions

**Q1 — the component and its two states.** `DateHeader`: at rest, a Sansita page-title line
"Today, August 31 ˅" (tappable — summons the calendar sheet) with the settings gear right. On
scroll, a compact sticky glass row: circular calendar button left, short centred date
("Aug 31, 2026"), gear right; content scrolls under with a fade. Ratify the state pair and that
BOTH the rest-state title tap and the compact-state calendar button summon the same calendar
sheet.

**Q2 — adjacent-day navigation.** The WeekStrip gave yesterday/tomorrow in one tap; the calendar
sheet makes it a two-tap round trip. Proposed: slim ‹ › chevrons flanking the rest-state title
("‹ Today, August 31 ˅ ›"). **Constraint (hard):** no screen-level horizontal swipe over the
timeline — horizontal gestures there belong to the workout card's ratified G1–G4 set
(`spec/design/components/workout-card.md` v3); a day-pager under those cards would make the G3
zero-translation guarantee untestable.

**Q3 — surface composition.** Rule that `ViewTabs` + `WeekStrip` leave the home surface
(both stay in the library — `WeekStrip` is reused inside the calendar sheet's month grid
context if the ratifier wishes, and other surfaces may still compose them). The month view
(`BY MONTH` tab) is superseded on this surface by the calendar sheet.

## Gates
App: `DateHeader` in `kyle_design/navigation/`, home-surface recomposition on the new screen,
goldens for both states, then `/design-sync`. Depends on the glass material ruling for the
compact state's treatment and on `2026-09-06-calendar-sheet-two-channel-cells.md` for what the
summon opens.

## Suggested spec home
New `spec/design/components/date-header.md` v1, plus a composition amendment to the home
surface spec (`spec/design/surfaces/macro-dashboard.md` family — ratifier picks the exact home).
