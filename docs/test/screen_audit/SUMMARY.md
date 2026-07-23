# Screen Audit Summary

**Captured:** 2026-05-12
**Device:** iPhone 15 Pro Max simulator (iOS 17.5)
**App:** `com.milkman.mealvanaendurance.dev` v1.18.1 (80)
**Throwaway profile email used during anonymous-onboarding walk:**
`audit_1778613869@example.com`

## Totals

- **99 screenshots** across 14 areas + `_inbox/` (initial captures kept for traceability)
- **14 area READMEs**, **1,390 total lines** of element/key documentation

## Screen counts per area

| #  | Folder              | Screens |
|----|---------------------|---------|
| 01 | welcome_auth        | 4       |
| 02 | onboarding          | 13      |
| 03 | calendar            | 4       |
| 04 | event_create        | 2       |
| 05 | event_details       | 10      |
| 06 | activity_create     | 7       |
| 07 | nutrition_plan      | 5       |
| 08 | carb_loading        | 7       |
| 09 | settings            | 12      |
| 10 | integrations        | 2       |
| 11 | fuel_log            | 4       |
| 12 | food_management     | 7       |
| 13 | brick               | 2       |
| 14 | other               | 6       |

## Flows successfully walked end-to-end

1. Anonymous onboarding (welcome → connect → profile → sport → diet → allergies → food → create account → calendar).
2. Sign out from anonymous state (with confirmation dialog).
3. Calendar view modes (BY WEEK / BY MONTH).
4. Activity creation (FAB → adjust macros → create plan → save → activity appears on calendar with dot).
5. Event creation (My Events → New Event → Event Details with all 3 plan buttons).
6. Carb loading plan creation (3-Day Classic, per-day food chips, menu with Reset / Mark Complete).
7. Activity Details (delete confirm, edit, scrolled to AFTER section with Save/Complete buttons).
8. All 4 bottom-nav tabs (Calendar, Nutrition Diary + Weekly chart, My Events, Learn + lesson video).
9. Every settings row (Profile edit, Appearance modal, Food Prefs subtree including Barcode + Custom Food, Sport Prefs all 3 sport details, Nutrition Profile, Nutrition Targets, Coach Connection, Connected Apps, Help & Feedback NPS + bug report).

## Flows blocked / skipped

- **`test@test.com / test` login: BLOCKED.** The orange "Log In" button on the email-login screen did not respond to `mobile_click_on_screen_at_coordinates` at any tested position, including exactly (215, 481) which is the WDA-reported center. The "Back" button immediately below DID respond, confirming coordinate space is correct. The keyboard's "Done" key also failed to submit. Almost certainly a Flutter hit-test issue where the synthetic tap doesn't reach the inner `InkWell`/`MaterialButton`. **Audit completed in anonymous-onboarded state.**
- "Forgot Password" link — same hit-test failure.
- Apple/Google OAuth, real integration connects (Garmin, FinalSurge, TrainingPeaks, Strava) — would need credentials.
- Carb-plan day-tab navigation, Race Day Checklist below Gear section, Generate Plan with Bike / Swim / Brick — partially captured but not deeply exercised.

## Notable observations

- **Several primary action buttons consistently fail synthetic taps** (Log In, Forgot Password, occasionally Generate Plan / Save Workout). This is the single highest-impact finding: adding `ValueKey` to the outermost interactive widget (not a `Padding`/`SizedBox` wrapper) is the fix.
- Profile-form text-entry race condition: typing into the height "ft" field then tapping "in" sends additional characters into "ft" until the keyboard transitions. Workaround: double-tap → Select All → retype. Tests should prefer `tester.enterText()` over synthetic typing.
- Food selection search for "apple" returned "No foods available" — the common-food list does NOT include fresh-fruit apple. Likely intentional (endurance focus) but worth flagging.
- Sentry NPS / bug-report overlays are hard to dismiss programmatically; their X/Close buttons live in a non-WDA-enumerable layer.
- No native crashes. App was terminated twice and relaunched cleanly each time.

## Decisions made under uncertainty (recorded for reproducibility)

- Onboarding email: `audit_1778613869@example.com` (timestamped throwaway).
- Profile defaults: Audit / User / Male / 1990 / 5'10" / 170 lbs / Imperial.
- Sport selection: Running only on first walk, then all 3 on a second pass to verify conditional screens.
- Diet: Omnivore. Allergies: None. Foods: Banana, Carb Drink Mix, Energy Gel.
- Event: "Test Race" / Half Marathon / system-default date + time.
- Carb protocol: 3-Day Classic.

## Highest-priority widgets for the instrumentation PR

Adding `ValueKey()` here unblocks the audit re-walk in the logged-in state and unblocks the Patrol/integration test suite:

1. `login.log_in_button` and `login.forgot_password_button` — currently un-tappable via synthetic taps.
2. `activity_details.complete_button` / `activity_details.save_button` — intermittent failures.
3. `adjust_macros.create_plan_button` — intermittent failures.
4. All `back_button` widgets (top-left arrow circle) — consistent pattern across 20+ screens.
5. All `continue_button` widgets on the 8 onboarding screens.

Full ValueKey proposals are tabulated in each `{NN_area}/README.md`.

## Re-walk plan (after instrumentation PR lands)

Once ValueKeys are in place and tests can address widgets by key:

1. Re-run login as `test@test.com / test`. Capture the user-specific variants of the screens already audited (user name in Settings header, no "Sign Out Anyway" disclaimer in the sign-out dialog, etc.).
2. Capture any post-login-only screens that the anonymous walk couldn't reach (sync status indicators, integration connect flows with real OAuth, coach connection state, etc.).
3. Capture the edge-case states still missing: empty plan generation error, generation timeout, integration disconnected banner, network-offline banner.
