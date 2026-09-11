# 11: The launcher stays off flow screens

**Status:** built 2026-09-11; the simulator check is still owed (the simulator was mid Kroger
sign-in in another session, so it was left alone)
**Blocked by:** None (independent of 09 and 10)
**Next:** simulator: open New Activity and check "Generate Plan"; then ticket 12 (needs grilling)

**Ruled (Lee, 2026-09-11):** hide the launcher on flow screens rather than giving each screen a
clearance inset. Found on the device in 06: the launcher covers the right end of full-width bottom
buttons ("Generate Plan" on the new-activity screen) and the right edge of the pre-workout card on
the session screen.

**What to build.** A flow screen is one whose job ends in a full-width bottom action: creating or
editing something, a wizard step, a form. On those, the launcher has no node, the same way it has
none on auth or the paywall (VS-6). Browsing screens keep it.

- [x] Survey the router for screens with a full-width bottom CTA. List them in this ticket, with
      the reason for each. (Survey below.)
- [x] Add them to the rule in `lib/features/meal_planning/domain/vana_launcher_rule.dart`, as a
      named set beside the existing exclusions, not as scattered checks. (`_flowPatterns`: exact
      route patterns, a `:param` matching one segment, never a subtree.)
- [x] The VS-6 router test covers the new set: no launcher node on each, one on a browsing screen.
      (`vana_launcher_rule_test.dart` over every route the real router declares;
      `vana_companion_test.dart` VS-6 over three flow screens, `/food/cook/D-048`, and a flow
      screen pushed without the router.)
- [x] The session screen's pre-workout card: if the screen is a browsing screen, say so in this
      ticket and leave it for Q-VS4 rather than hiding the launcher there. (`/plan` and
      `/current-plan` are browsing screens; the card is left for Q-VS4.)
- [ ] Simulator: "Generate Plan" is fully visible on the new-activity screen.
- [x] Add a line to `vana-sheet.md` ("Where the launcher does not appear") naming flow screens.

## Survey (2026-09-11)

Every route in `lib/shared/core/app_router.dart`, read screen by screen. A flow screen's job ends
in a full-width action at the bottom, pinned or at the end of the form.

**Flow screens (no launcher):**

| Route | Screen | Bottom action |
|---|---|---|
| `/distancepacegut`, `/distance-pace-gut-entry` | New activity | "Generate Plan" + "Use Template", pinned (the device finding) |
| `/adjust-macros` | Adjust macros | "Create Plan", the step after new activity |
| `/events/create` | Event form | "Create Event" / "Save Changes" |
| `/settings/preferences` | Preferences | Onboarding footer "Save", pinned |
| `/settings/sweat-profile` | Sweat profile | "Save", pinned |
| `/settings/sport-settings` | Sport settings | "Save" at the end of the form |
| `/settings/nutrition-targets` | Nutrition targets | "Save Changes" |
| `/settings/food-preferences-consolidated` | Food settings | "Save Changes", pinned |
| `/settings/food-preferences` | Food likes | "Save Changes", pinned |
| `/settings/dietary-preference`, `/allergies`, `/running-details`, `/cycling-details`, `/swimming-details` | Onboarding steps in settings mode | Onboarding footer "Save", pinned |
| `…/formula-library/personal/create`, `…/personal/:id` | Formula editor | "Save formula", pinned |
| `/swap-food` | Swap food | "Add food" / "Swap food", pinned once a food is picked |
| `/food-detail` | Food detail (create / edit / add) | "Create Food" / "Save Changes" / "Add…", pinned |
| `/carb-loading-select-food` | Carb-loading food pick | "Add to <meal>" (before a food is picked it shows a bottom-right "Create Custom Food" FAB, which the launcher would also sit on) |
| `/create-custom-carb-loading-food` | Custom carb-loading food | "Save Food", pinned |
| `/coach/apply` | Coach registration | "Submit Application" |
| `/chat/:relationshipId` | Coach chat | Full-width composer; its send button sits under the launcher |
| `/meal-log/edit`, `/manual`, `/describe`, `/review` | Meal logging | "Save changes" / "Save" / "Analyze" / "Log this meal" |
| `/meal-log/recent-saved` | Recent and saved picker | "Log N", pinned in multi-select |
| `/meal-log/build` *(pushed, not routed)* | Build a meal | "Log meal", pinned once the draft has food |
| `/meal-log/scanned` *(pushed, not routed)* | Log a scanned food | "Log Food", pinned |
| `/food/cook/:id` | Cooking mode | Back / Next step, pinned; Next is at the right end |
| `/food/kroger/:planId` | Shop with Kroger | "Send to Kroger" at the end of the review |

**Kept the launcher (browsing, or no full-width bottom action):** `/main`, `/coach-portal`, `/plan`
and `/current-plan` (the session screen), `/fuel-log`, `/learn`, `/learn/video`, `/events`,
`/events/:eventId/checklist`, `/settings` (its "Create Account" button is mid-page),
`/settings/connected-apps`, `/settings/privacy`, the two preference hubs,
`/settings/nutrition-profile` (Save is in the app bar), `/settings/templates`,
`/settings/coach-connection` (its full-width Connect / Message / Disconnect buttons sit in a card
near the top, not at the bottom),
`/settings/food-preferences/add-food` (search, tap a result), the formula library and formula
detail, `/help`, `/barcode-scanner` (a viewfinder; its buttons are in dialogs), the coach screens,
`/my-coaches`, `/athlete/feedback`, `/coach-directory`, `/meal-log/photo` (option cards at the
top), `/meal-log/recipe` (its action is in a sheet, which hides the launcher already), `/food`,
`/food/meals/recents`, `/food/meals/:id` (a meal page to read: in plain browsing it ends in notes, and "Swap in" / "Add to
plan" appear only when opened from the swap or Vana-browse flow, which a path cannot tell apart —
unlike Kroger, whose one job is the send),
`/food/swap/:planMealId` (tap a meal to swap).

**Flow screens pushed without the router.** A `MaterialPageRoute` push leaves the router's location
on the screen underneath, so the path rule alone missed the athlete's own way into the event form
(from `/events`) and food detail from the scanner. `VanaCompanionObserver.pagelessOnTop` now reports
the top page's `RouteSettings.name` when the router did not push it, and the host reads that name
before the router's location. The flow screens pushed this way carry a `routeSettings` constant used
at every push: `EventFormScreen` (`/events/create`, 4 sites), `FoodDetailScreen` (`/food-detail`, 5
sites), `BuildMealScreen` (`/meal-log/build`), `LogScannedFoodScreen` (`/meal-log/scanned`). The
other pages pushed this way (event detail, weather detail, carb-loading day detail, video player,
the events list, connected apps, add food, protocol selection, the quick-log screen — a tabbed search; only its AI tab ends in
"Analyze") are browsing
screens and stay unnamed, which keeps the launcher over them as before.

**Calls Lee may want to reverse:** the coach chat (a composer, not a form button, but the launcher
covers send), cooking mode (a Vana question mid-cook is plausible, but Next sits under the
launcher), and Kroger (a review that ends in a send).
