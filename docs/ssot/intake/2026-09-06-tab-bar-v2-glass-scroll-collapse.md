> **RESOLVED 2026-09-06 → spec/design/components/tab-bar.md v1 (home-shell@v1)**

type: ruling-request
bundle: home-shell@v1 (proposed name — the nav/header/calendar redesign of the fuel-timeline home screen; ratifier names the bundle)

## Why this matters
The shipped floating tab bar is unspecced (screenshot-held only); the redesign gives it a
state set and a scroll gesture, which are contracts — without a ruling they land as
implementation folklore, the exact drift `spec/design/source-authority.md` exists to stop.

## Companion artifact & scope
Xuan is sharing the design export `New Homepage with updated navbar calendar and chat.html`
(interactive artboard, Claude Design session). **This intake round covers only three areas of
that HTML: the tab bar, the date header, and the calendar sheet.** The HTML also contains AI
components — the companion pill/bubble (all four modes), the sparkle meal-suggestion toggle and
its dashed suggestion cards, the "Add to Dinner" sheet, the chat sheet, and a "Ride Fuel Plan"
editor screen. **All of those are out of scope this version — do not ratify, spec, or rule on
them.** (The AI layer is deferred pending convergence with the in-flight Vana work; the fuel-plan
editor contradicts ratified phase colours and gesture contracts and is parked.)

## The questions

**Q1 — the state set.** The bar gains two states: `expanded` (glass pill, icon+label items,
active-item highlight) and `collapsed` (one ~52 px circular glass button showing only the active
tab's icon). Scroll-down past a threshold collapses; scroll-up (or reaching top) re-expands;
content scrolls under it. Ratify the state pair and the trigger rule (thresholds/hysteresis to
be pinned by the app's goldens + a gesture manifest, not prose).

**Q2 — anchoring and the reserved utility slot.** Options:
- (a) **Left-anchored pill + a named, empty utility slot at the bottom-right corner**
  (recommended). The collapse morph already targets the left corner, so the motion stays
  coherent; a future occupant (the deferred AI companion is the known candidate) fills the slot
  *additively* with no contract change to the bar. The slot's occupant, whenever ratified,
  inherits the old FAB's clearance rule: it must not overlap a workout card's swipe-reveal
  travel (workout-card.md G1/G4).
- (b) Centered pill, full width. Cleaner today; adding any corner control later is a geometry
  change to the bar = re-ratification + regenerated goldens.

**Q3 — destination variants.** The shipped bar's destinations are Fuel Timeline, Food
(Pro-unlocked, optional), Coach (web-only, optional), Events/Learn — 3 to 5 items
(`lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart`). The spec must
cover both extremes for the expanded pill and confirm the collapsed button always shows the
active tab's icon regardless of count.

**Q4 — the Fuel Timeline tab icon.** The design proposes replacing the `calendar` glyph with a
house glyph, because the new date header introduces a calendar button top-left and two calendar
glyphs with different meanings would collide. Deliberate rename, needs a yes/no.

## Gates
App: TabBar v2 in `lib/shared/widgets/kyle_design/` (new screen implementation, dev-visible),
goldens for both states + morph, gesture manifest, then `/design-sync`. Depends on the glass
material ruling (`2026-09-06-glass-material-token-ruling.md`) for its surface treatment.

## Suggested spec home
New `spec/design/components/tab-bar.md` v1 (first spec for an existing shipped widget — the
redesign is the occasion to bring it under contract).
