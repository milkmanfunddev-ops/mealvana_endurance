/// Event → race-day checklist → carb-loading entry flow under **Patrol** —
/// extends the events CRUD coverage into the two race-prep surfaces hanging
/// off the event detail screen.
///
/// Flow:
///   launchApp → ensureAuthenticated (reuse session, else email login)
///     → Events tab → New Event → CREATE a uniquely-named event
///       (form pre-fills sport/distance/date, only the name is required —
///        same keys as events_crud_flow_test.dart)
///     → Event Details renders the created name
///     → RACE DAY CHECKLIST: scroll to event_details.checklist_button → tap
///       → checklist screen renders (checklist.title) → back
///     → CARB LOADING: scroll to event_details.carb_loading_button → tap
///       → protocol-selection screen renders (carb_loading.title)
///       → back WITHOUT selecting a protocol (no plan is created)
///     → DELETE the event (more ▸ Delete ▸ confirm → View events list)
///     → the event name is gone from My Events.
///
/// Why manual drags instead of `.scrollTo()` on the detail screen: the detail
/// page hosts async widgets (weather, plan status) whose spinners make
/// Patrol's settle-between-scrolls burn up to 75 s per scrollTo call; bounded
/// fixed drags with explicit polls are deterministic.
///
/// Auth: reuses an existing session, else the flavor-matched
/// INTEGRATION_TEST creds; self-skips when neither is available.
///
/// Run:
///   patrol test \
///     --target integration_test/flows/event_checklist_carbload_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'event race-day checklist + carb-loading entry render, then event deleted',
    ($) async {
      await launchApp();
      // No pumpAndSettle: startup may show persistent spinners.
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final eventName = 'Patrol RacePrep $stamp';

      // ---- 1. Events tab → New Event → CREATE ------------------------------
      await $(
        const ValueKey('bottom_nav.events_tab'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('my_events.new_event_button'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('my_events.new_event_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      // The form pre-fills sport (Run), distance, date and time — a valid
      // event only needs a name.
      await $(
        const ValueKey('event_create.name_field'),
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $(
        const ValueKey('event_create.name_field'),
      ).enterText(eventName, settlePolicy: SettlePolicy.noSettle);
      // Dismiss the keyboard (it overlays the Create button) and submit.
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 400));
      await $(const ValueKey('event_create.create_button')).scrollTo().tap();

      // Landed on Event Details with our name.
      await $(
        const ValueKey('event_details.event_name'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(eventName),
        findsWidgets,
        reason: 'Created event name should render on the detail screen.',
      );

      // ---- 2. Race Day Checklist -------------------------------------------
      const checklistButton = ValueKey('event_details.checklist_button');
      expect(
        await _dragUntilFound($, checklistButton),
        isTrue,
        reason: 'Race Day Checklist button should exist on event detail.',
      );
      await $(checklistButton).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('checklist.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(const ValueKey('checklist.title')),
        findsOneWidget,
        reason: 'Race-day checklist screen should render.',
      );

      await $(
        const ValueKey('checklist.back_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('event_details.event_name'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 3. Carb Loading protocol selection (open + back, no create) -----
      const carbButton = ValueKey('event_details.carb_loading_button');
      expect(
        await _dragUntilFound($, carbButton),
        isTrue,
        reason: 'Carb Loading button should exist on event detail.',
      );
      await $(carbButton).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      await $(
        const ValueKey('carb_loading.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(const ValueKey('carb_loading.protocol_3_day_card')),
        findsOneWidget,
        reason: 'Protocol-selection screen should render its 3-day option.',
      );

      // Back WITHOUT picking a protocol — no carb plan gets created, so the
      // event delete below is the only cleanup needed. The screen uses a
      // stock AppBar, so the implicit BackButton is the way out.
      await $.tester.tap(find.byType(BackButton).first);
      await $(
        const ValueKey('event_details.event_name'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // ---- 4. DELETE the event (cleanup) ------------------------------------
      await $(
        const ValueKey('event_details.more_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('event_details.menu_delete'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('event_details.delete_confirm'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // The detail screen does NOT auto-pop after delete (known quirk, see
      // events_crud_flow_test.dart) — use the footer link to reach the list.
      await $(
        const ValueKey('event_details.view_events_link'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('event_details.view_events_link'),
      ).tap(settlePolicy: SettlePolicy.noSettle);

      // ---- 5. Verify gone ----------------------------------------------------
      await $(
        const ValueKey('my_events.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // Poll rather than assert instantly. The delete is offline-first: the
      // row goes on a queue and the list rebuilds from the local DB, so there
      // is a short window where My Events still renders the deleted event.
      // Asserting on the first frame after navigation raced that window and
      // then cost the run this test's entire timeout on 2026-07-31.
      //
      // Fixed pumps, never settles — the events list can hold a sync spinner.
      var gone = false;
      for (var i = 0; i < 40; i++) {
        if (!$(eventName).exists) {
          gone = true;
          break;
        }
        await $.pump(const Duration(milliseconds: 300));
      }
      expect(
        gone,
        isTrue,
        reason:
            'Deleted event "$eventName" was still listed in My Events after '
            '12s of polling. If this persists, the delete is not reaching the '
            'local events list — check the repository write, not this test.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Bounded manual scroll on the event-detail page until [key] is in the tree.
/// Fixed drags + fixed pumps — never settles, so async spinners on the detail
/// page can't stall the walk.
Future<bool> _dragUntilFound(
  PatrolIntegrationTester $,
  ValueKey<String> key,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if ($(key).exists) {
      try {
        await $.tester.ensureVisible(find.byKey(key).first);
      } catch (_) {
        // Best-effort — the subsequent tap fails loudly if still hidden.
      }
      await $.pump(const Duration(milliseconds: 200));
      return true;
    }
    await $.tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await $.pump(const Duration(milliseconds: 300));
  }
  return $(key).exists;
}
