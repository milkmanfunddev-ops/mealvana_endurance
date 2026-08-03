/// Events CRUD walk under **Patrol** — create → read → update → delete an event
/// end-to-end, driven entirely by `ValueKey` finders.
///
/// This is the first test to exercise a full data-mutation lifecycle (most of
/// the existing flows only cover auth / onboarding / integration entry points).
///
/// Flow:
///   ensureAuthenticated (reuse session, else email login)
///     → calendar → Events tab → New Event
///     → CREATE: enter name, tap Create → lands on Event Details
///     → READ:   assert the event name shows on the detail screen
///     → UPDATE: more ▸ Edit → replace name → Save → assert new name on detail
///     → DELETE: more ▸ Delete → confirm → View events list
///                → assert the (edited) name is gone from the list
///
/// Why the explicit "View events list" step after delete:
///   On delete the detail screen calls `context.go('/main')`, but the detail
///   route is pushed imperatively on top of the shell, so the go-router change
///   happens underneath and the (now-stale) detail screen stays on top — it does
///   NOT auto-pop. The test navigates to the list via the footer link to verify
///   the row is actually gone. (Tracked as a minor UX bug; see notes.)
///
/// Auth:
///   Boots via the shared launcher (helpers/flow_launcher.dart, flavor-aware)
///   and reuses an existing session if the app launches straight to the
///   calendar; otherwise ensureAuthenticated logs in with the flavor-matched
///   TestConfig.loginEmail/loginPassword. On a clean iOS install (no session,
///   no creds) the test self-skips with a clear message rather than failing.
///
/// Run:
///   patrol test --target integration_test/flows/events_crud_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"        # newest-SDK sim (Patrol-on-iOS needs it)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'create, edit, then delete an event end-to-end',
    ($) async {
      await launchApp();
      // Do NOT pumpAndSettle: startup may show a persistent spinner.
      // ensureAuthenticated polls with plain pumps instead.
      await $.pump(const Duration(milliseconds: 500));

      // ---- 0. Ensure we're authenticated on the calendar ----------------
      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // Unique name so repeated runs never collide / false-positive on stale
      // rows from a previous failed run.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final createName = 'Patrol CRUD $stamp';
      final editedName = 'Patrol CRUD $stamp EDITED';

      // ---- 1. Calendar → Events tab → New Event -------------------------
      await $(const ValueKey('bottom_nav.events_tab')).tap();
      await $(const ValueKey('my_events.new_event_button')).tap();

      // ---- 2. CREATE -----------------------------------------------------
      // The form pre-fills sport (Run), race distance, date and time, so a
      // valid event only needs a name.
      await $(const ValueKey('event_create.name_field')).enterText(createName);
      // enterText leaves the soft keyboard up, which overlays the Create button
      // at the bottom of the form and makes it un-hit-testable. Dismiss it and
      // scroll the button into view before tapping.
      await _submitEventForm($);

      // ---- 3. READ — landed on Event Details with our name --------------
      await $(
        const ValueKey('event_details.event_name'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(createName),
        findsWidgets,
        reason: 'Created event name should render on the detail screen.',
      );

      // ---- 4. UPDATE — more ▸ Edit → replace name → Save ----------------
      await $(const ValueKey('event_details.more_button')).tap();
      await $(const ValueKey('event_details.menu_edit')).tap();

      // Patrol's enterText replaces the field contents (no manual clear).
      await $(const ValueKey('event_create.name_field')).enterText(editedName);
      await _submitEventForm($);

      await $(
        const ValueKey('event_details.event_name'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(editedName),
        findsWidgets,
        reason: 'Edited event name should render on the detail screen.',
      );

      // ---- 5. DELETE — more ▸ Delete → confirm --------------------------
      await $(const ValueKey('event_details.more_button')).tap();
      await $(const ValueKey('event_details.menu_delete')).tap();
      await $(const ValueKey('event_details.delete_confirm')).tap();

      // The detail screen does NOT auto-pop after delete (see header note),
      // so navigate to the list explicitly via the footer link.
      await $(
        const ValueKey('event_details.view_events_link'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(const ValueKey('event_details.view_events_link')).tap();

      // ---- 6. Assert the event is gone from the list --------------------
      await $(
        const ValueKey('my_events.title'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        $(editedName),
        findsNothing,
        reason: 'Deleted event should no longer appear in My Events.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Dismiss the soft keyboard (left up by enterText) and scroll the form's
/// submit button into view, then tap it. Works for both "Create Event" and
/// "Save Changes" — same `event_create.create_button` key, different label.
Future<void> _submitEventForm(PatrolIntegrationTester $) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pump(const Duration(milliseconds: 400));
  await $(const ValueKey('event_create.create_button'))
      .scrollTo(
        maxScrolls: 12,
        settleBetweenScrollsTimeout: const Duration(milliseconds: 500),
      )
      .tap();
}
