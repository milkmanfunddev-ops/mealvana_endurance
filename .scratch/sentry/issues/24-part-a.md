# 24, part A: dev layout, key and lifecycle bugs

**Agent:** 24a (wave 5). Part B (N+1 queries 88/89/97, Vana reclassification 90/91/9C/9A) is 24b's.

**Status:** done except the mealplanning-only fixes listed under `## Owed`

## What the events can and cannot tell us

Every overflow event (5S, 5H, 5G, 7W) was sent by the legacy reporter before ticket 02. They carry
only the first line of the FlutterError ("A RenderFlex overflowed by N pixels on the right"), no
stack, no `flutter_error_details` context, so no widget name. Sentry groups overflows by that one
line, so each of these issues is a bucket of unrelated widgets. Attribution below comes from
breadcrumbs (route, last tap), the device's logical size (`contexts.device`
`screen_width_pixels`/`screen_height_pixels`), and reproducing at that size in a widget test.

All overflow events were debug builds on simulators (`dart_context.compile_mode: debug`).
RenderFlex overflow is a debug-only assertion, so none of these can reach prod.

The 1.26/1.27 dev builds were cut from `mealplanning`, which `sentry` does not contain (merge base
`e323f238`). Several of these bugs live in code that exists only on `mealplanning` (the paywall
clip, the expiry redirect, the Vana companion, the rebuilt Vana browse rails). Those cannot be
fixed on this branch; their fixes are written out under `## Owed`.

Since ticket 02 the SDK's own `FlutterErrorIntegration` installs the error handler, and Sentry
Flutter 9.6 attaches `flutter_error_details` (the `information` block names the error-causing
widget with its `file:line` in debug builds). The next overflow from a current build will name
its widget.

## Root cause

### DEV-5S: RenderFlex overflowed on the right (26 events, 4 users, unresolved)
Three sources in one bucket:
- **coach-portal, 23 / 85 / 123 px, iPhone 17 Pro 402x874, 1.27.1+4, 09-26.** The route was
  reached on a phone (a deep link: no tap before it, `app.lifecycle foreground` right after).
  `CoachPortalScreen` is a desktop split layout: a fixed 280 px `PortalSidebar` plus the panel.
  At 402 px the panel got 121 px. Its athlete header Row (48 px avatar + 16 px gap + 48 px refresh
  button inside 16 px padding, `portal_athlete_detail_panel.dart`) needs 144 px and overflowed by
  exactly 23 px, the issue's headline. The tab views overflowed further (the 85 / 123 px events
  in the same frame). Reproduced at 402x874.
- **EventDetailScreen, 26 / 35 / 36 px, iPhone 17 Pro Max 402x874, 1.27.1+4, 09-25.** Each event
  fired as `my_events.event_card_*` pushed `EventDetailScreen`. `EventHeaderCard`'s date Row put
  an unflexed `Text` ("Wednesday, September 30, 2026", `bodyLarge`) beside the calendar icon, so
  long weekday + month names ran off the card. The amount varies with the date's length, which
  is why the three events differ. Reproduced at 402x874.
- **food-meal-detail, 31 / 41 px, 1.26.0+1, 09-08/09.** Not reproducible on `sentry`'s
  `MealDetailScreen` at 402, 390 or 375 px. The screen has been rebuilt on `mealplanning` since
  (a 492-line diff), and the event names no widget. Not attributed.

### DEV-5H: RenderFlex overflowed by 7.0 px on the bottom (5 events in one frame, 09-25 20:20Z)
Last route `vana-browse`. Five identical overflows in one frame means one widget repeated: the
`MealRailCard`s in the browse screen's `MealRail`, a fixed 132 px strip with a fixed 51 px name
box, where a card whose badge Wrap needed a third row overflowed. `mealplanning` fixed this
70 minutes after the last event: `885db994` (2026-09-25 16:33 CDT, findings 88-008 / 88-014,
"rails grow with the text size... badges clip instead of overflowing", with
`meal_rail_card_test.dart`). `sentry` still has the old rail. Attribution is from the
breadcrumbs, the repeat count and that commit; the event names no widget.

### DEV-5G: RenderFlex overflowed on the bottom (39 events, 2 users)
Four sources, none named, all in `mealplanning`-only code:
- **20550 px, `onboarding`, 1.27.1+4, 09-26 02:23Z,** on the personal-info page right after the
  keyboard hid. Not reproducible on `sentry`: Personal info, Body composition, Nutrition settings
  and the PageView shell, pumped at 402x874 with and without a 336 px keyboard inset, lay out clean.
  The `mealplanning` onboarding differs (`personal_info_screen.dart` +96 lines). An overflow that
  large means content tens of thousands of px tall laid out in a non-scrolling Column. Exploring
  the portal turned up one instance of that class: an error view that prints `error.toString()`
  into a fixed Column (17,720 px in the test; fixed below). The onboarding event cannot be tied to
  it without the widget name.
- **37 px, `vana-browse`, 09-25 20:20Z.** Same frame as DEV-5H; the same rail fix (`885db994`)
  very likely covers it.
- **24 / 80 px, 1.27.0+3, 09-24.** Each fired after a `meal_planning.day_note` tap pushed the Vana
  sheet. That surface is `mealplanning`-only.

### DEV-7W: RenderFlex overflowed by 8.6 px on the right (3 events, 1 user, unresolved)
In the unresolved list. iPhone SE (375x667), route `main` at cold start, 1.25.0+1 only, last seen
09-07. No events since. The home dashboard has been recomposed since 1.25.0, and no widget is
named. Not attributed. `responsive_smoke_test.dart` does not cover the home dashboard at small
sizes.

### DEV-9Y (11 events) / DEV-9Z (2 events): Duplicate keys found
`Column ... has multiple children with key [MealComponent#3c207]`. `MealComponentEditor` keyed
each row's `Dismissible` with `ObjectKey(item)`. Build-a-meal seeds its draft by copying a logged
meal's `components` (`build_meal_screen.dart`, `_draft.addComponents(log.components)`). The
breadcrumbs show the same `MealCard` picked twice, which put the same `MealComponent` instances
into the list twice. `ObjectKey` compares identity, so the two rows had the same key. 9Y and 9Z
are the same error from two rebuild paths, at the same second. Reproduced.

### DEV-9R: VideoPlayerController was used after being disposed (1 event, 09-26 02:41Z)
The stack is `VideoPlayerController.seekTo -> _updatePosition -> ValueNotifier.value= ->
notifyListeners`. `seekTo` awaits the platform seek and then writes the position, with no
disposed check after the await (still true in video_player 2.14). The event fired 5 s after a
cold start with `subscription active: false`, on the `mealplanning` paywall. At that time
(`80faf834`, before `0fec46b3` made it loop on 09-26 11:02 CDT) the paywall played its
`PhoneClipFrame` clip once and slid to the features page on `onEnded`. When the clip ended,
video_player itself called `pause().then(seekTo(duration))`, `onEnded` slid the page, the frame
disposed `VideoPhoneClipPlayer`, and the late seek wrote into the disposed controller. The same
race exists in `VideoPlayerScreen` on this branch: chewie seeks when the athlete scrubs or leaves
full screen, and a pop during that seek disposes the controller under it.

### DEV-9G / DEV-9F: navigator assertions (1 event each, same 60 ms, 09-25 20:33Z)
9G `navigator.dart:3249 '!navigator._debugLocked'` in `_RouteEntry.handlePush`; 9F
`navigator.dart:5781 'entry.currentState == _RouteLifecycle.popping'` in `finalizeRoute`. The
breadcrumbs show the sandbox subscription expiring (`active: true -> false`) while the previous
plans bottom sheet (pageless, opened from `meal_planning.plan_overflow`) was still on top of
`main`. The `mealplanning` router re-evaluates the location on the subscription answer and
redirects to the full-screen paywall, replacing the page stack. The pageless sheet route attached
to the removed `main` page was torn down mid-flush without being popped, so its transition
finished on a route that was not `popping` (9F), and the paywall push completed inside the same
locked flush (9G). The expiry redirect is `mealplanning`-only (`app_router.dart` "an expiry
closes the app onto the paywall"); `sentry` has no such redirect.

### DEV-81: Looking up a deactivated widget's ancestor is unsafe (5 events, 1.26.0+1, unresolved)
In the unresolved list. Stack: `GoRouterDelegate.setNewRoutePath` notifies listeners during a
fresh `Router` state's `restoreState`, and `_VanaCompanionHostState._onRoute` runs
`ref.read(vanaSituationControllerProvider.notifier)` on an element that is deactivated (the host
was moving in the tree) but not yet disposed. `mounted` is still true for a deactivated element,
so the existing `_set` guard does not help, and `ref.read` does an ancestor lookup.
`vana_companion.dart` is `mealplanning`-only.

### DEV-A1: VanaServerException(400): meal not found: log:1 medium apple... (owner only)
Not a ticket-24 issue and not listed in any ticket. The Vana chat linked a plan meal whose id was a
fabricated `log:<label>` pseudo-id. `food-meal-detail` passed it to
`MealLibraryRemoteDataSource.getMeal`, and the server answered 400. Already fixed on `mealplanning`
by `82b3ce71` (2026-09-26 10:52 CDT, 28 min after the event):
`supabase/functions/_shared/vana/tools.ts:193` no longer emits `log:` ids. Owner: the Vana /
meal-planning line on `mealplanning`. It needs no ticket, only the edge-function deploy.

## Fix

On `sentry`:
- `lib/features/coach_mode/presentation/screens/coach_portal_screen.dart`: below
  `CoachPortalScreen.minLayoutWidth` (`Breakpoints.medium`, 840) the split layout keeps that
  width inside a horizontal `SingleChildScrollView` with a bounded height. At 840 px and wider
  nothing changes. (DEV-5S)
- `lib/features/events/presentation/widgets/event_header_card.dart`: the date `Text` is wrapped in
  `Flexible`. (DEV-5S)
- `lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart` and
  `lib/features/coach_mode/presentation/screens/coach_chat_screen.dart`: the error views scroll
  (`Center > SingleChildScrollView`) instead of a fixed `Padding > Column`, so an error string of
  any length no longer runs thousands of px off the bottom. Found while cycling the portal's tabs
  at 840 px (the Chat tab overflowed by 17,720 px). Also moved a misplaced `@override` in the panel
  from `_distanceUnit` to `build` (an analyzer warning).
- `lib/features/meal_logging/presentation/widgets/meal_component_editor.dart`: rows are keyed by
  `ValueKey<int>` from a per-row id list kept in step with `_items` (assigned in `initState`,
  removed on delete, kept on edit and swap), never by the component instance. (DEV-9Y, DEV-9Z)
- `lib/shared/utils/disposal_safe_video_controller.dart` (new):
  `DisposalSafeVideoPlayerController` (`.networkUrl`, `.asset`) drops `value` writes once
  `dispose()` has been called. `VideoPlayerScreen` builds its controller with it. (DEV-9R class)
- `pubspec.yaml`: `video_player_platform_interface: ^6.6.0` as a dev dependency (already
  resolved transitively at 6.6.0; the lock only changes `transitive` to `direct dev`), so the test
  can install a fake platform.

Tests. Each new test was red before its fix, checked by reverting the `lib/` changes and
running them: 6 failures, including "Duplicate keys found", "overflowed by 161 px on the right",
and "Multiple exceptions (9)" at 402 px.
- `test/features/coach_mode/presentation/coach_portal_narrow_viewport_test.dart`: the portal at
  402x874 (the event's device) with an athlete selected has no exception. At the 840 px minimum,
  every panel tab (Profile, Targets, Events, Carb Loading, Activities, Chat) has no exception.
- `test/features/events/event_detail_narrow_viewport_test.dart`: `EventDetailScreen` at 402x874,
  with an event date and with an activity date, has no exception.
- `test/features/meal_logging/meal_component_editor_duplicate_key_test.dart`: the same
  `MealComponent` instance twice builds clean, and removing one copy leaves the other.
- `test/shared/utils/disposal_safe_video_controller_test.dart`: uses a fake platform whose seek
  completes on demand. One test pins the hazard: a plain `VideoPlayerController` disposed during a
  seek throws `FlutterError`. If the package ever guards this itself, that test fails and the
  wrapper can go. The others check that the safe controller completes the same sequence cleanly
  and still reports position before dispose.

Verification: `dart analyze` on every changed file shows only pre-existing `withOpacity`
deprecation infos. These pass: the four files above, plus `meal_component_editor_tap_test`,
`meal_items_editor_scaling_test`, `seeded_tests/coach_calendar_carb_content_test`,
`seeded_tests/events_meal_logging_content_test`, `smoke_tests/auth_misc_smoke_test` and
`test/shared/source_guard`. No full suite run, per the wave rule.

## Owed

`mealplanning`-only fixes. These cannot land on `sentry` because the code is not there:
- **DEV-9R:** in `lib/shared/widgets/kyle_design/data/phone_clip_frame.dart`, build
  `VideoPhoneClipPlayer._controller` with `DisposalSafeVideoPlayerController.asset(asset,
  videoPlayerOptions: ...)` once `sentry` is merged in. The looping clip no longer fires
  `onEnded`, so today's trigger is gone, but PCF-1's play-once mode still has the race.
- **DEV-9G / 9F:** before the expiry redirect takes the stack to the paywall, pop the root
  navigator's pageless routes (sheets, dialogs), e.g.
  `navigator.popUntil((r) => r.settings is Page)`, in the listener that refreshes the router on
  the subscription answer. Then the redirect replaces pages only. A widget test: open the previous
  plans sheet, flip the entitlement to false, pump, and expect no exception.
- **DEV-81:** in `_VanaCompanionHostState`, track activation (`deactivate()` sets `_active =
  false`, `activate()` sets it true and re-runs `_onRoute`), and make `_onRoute` return early when
  inactive before touching `ref`.
- **DEV-5H / DEV-5G 37 px:** nothing to write. They ride `885db994` when `mealplanning` reaches
  the build.
- **DEV-A1:** confirm the `vana` edge function carrying `82b3ce71` is deployed to dev.

Not done:
- **DEV-5G 20550 px (onboarding), 24 / 80 px (Vana sheet), DEV-5S food-meal-detail, DEV-7W:** not
  reproduced or attributed (reasons above). Once a current build sends an overflow, its
  `flutter_error_details.information` names the widget and file:line.
- **No device check.** The portal at phone width and the event header were verified by widget test
  only; neither was run on a simulator.
- An event-time check that a current dev build's overflow events really carry
  `flutter_error_details` was not done (no new overflow event exists yet).

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-DEV-5S | resolve | Coach portal at phone width now scrolls sideways at its 840 px minimum; event header date is Flexible. Both reproduced at 402x874 and fixed with tests (ticket 24a). The 1.26.0 meal-detail events predate that screen's rebuild; a regression reopens with widget details. |
| MEALVANA-ENDURANCE-DEV-5H | leave-open: fixed on mealplanning `885db994`, not on sentry | Vana browse rail cards overflowed at a fixed 132 px. Fixed by mealplanning 885db994 (rails grow with text, badges clip). Resolve when mealplanning ships. |
| MEALVANA-ENDURANCE-DEV-5G | leave-open: mixed, mealplanning-only sources, unattributed | Onboarding 20550 px, Vana sheet 24/80 px and browse 37 px all live in mealplanning-only code with no widget in the legacy events. 37 px rides 885db994. Revisit once events carry flutter_error_details. |
| MEALVANA-ENDURANCE-DEV-7W | leave-open: unattributed, last seen 1.25.0 | iPhone SE home at cold start, 3 events on 1.25.0 only, no widget named; dashboard recomposed since. Resolve as stale at the lead's call. |
| MEALVANA-ENDURANCE-DEV-9Y | resolve | MealComponentEditor keyed rows by ObjectKey(component); the same instance twice (same meal picked twice in build-a-meal) clashed. Rows now keyed by stable row ids (ticket 24a). |
| MEALVANA-ENDURANCE-DEV-9Z | resolve | Same cause and fix as DEV-9Y (ticket 24a). |
| MEALVANA-ENDURANCE-DEV-9R | leave-open: mealplanning one-liner owed | video_player writes the seek position after an await with no disposed check. DisposalSafeVideoPlayerController added (sentry, ticket 24a) and used by VideoPlayerScreen; the paywall clip on mealplanning must adopt it. |
| MEALVANA-ENDURANCE-DEV-9G | leave-open: mealplanning-only | Expiry redirect to the paywall replaced the page stack while a pageless sheet was open. Fix owed on mealplanning: pop pageless routes before the redirect. |
| MEALVANA-ENDURANCE-DEV-9F | leave-open: mealplanning-only | Same event as DEV-9G (finalizeRoute on a non-popping sheet route). |
| MEALVANA-ENDURANCE-DEV-81 | leave-open: mealplanning-only | VanaCompanionHost._onRoute calls ref.read from a deactivated element during a Router restore. Fix owed on mealplanning: activation guard. |
| MEALVANA-ENDURANCE-DEV-A1 | leave-open: resolve after deploy | Fabricated `log:` meal ids from Vana tools; fixed in mealplanning 82b3ce71 (tools.ts). Resolve once that vana function is on dev. Not a ticket-24 item. |
