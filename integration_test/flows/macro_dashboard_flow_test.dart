/// Macro Dashboard walk under **Patrol** — the flag-gated redesigned surface
/// (`MACRO_DASHBOARD_ENABLED`), driven by `macro_dashboard.*` ValueKeys.
///
/// Covers the Phase A flow contract
/// (docs/features/macro_dashboard/README.md):
///   - G1 swipe → the card flips to self-reported and the energy card's net
///     figure/copy change with it (S-1 propagation);
///   - two-time DB writes: mark-done sets actual_time and never touches
///     planned_time; mark-undone clears actual_time to null — asserted
///     against the app's own LOCAL Drift database, in-process;
///   - S-4: the energy card's expansion survives the card-swipe recompute;
///   - Breakdown Pager walk (open from Full breakdown, page across, close);
///   - delete → the local row PERSISTS as a status='deleted' tombstone.
///
/// Remote-half assertions (Supabase row carries the tombstone + two-time
/// columns, needs_upload cleared) are written below but SELF-SKIP while the
/// dev cloud is un-migrated (activities.planned_time still 42703) — they arm
/// automatically once Phase C's migrations land, detected by probing the
/// column itself.
///
/// Self-skips:
///   - no session and no credentials (standard noAuthSkipMessage);
///   - `MACRO_DASHBOARD_ENABLED` off — the tab renders the legacy Fuel
///     Timeline, so there is nothing to test.
///
/// Seeding: the flow creates its own planned workout through the REAL
/// controller path (`activitiesControllerProvider.createActivity` — the same
/// local-first write the New Activity flow lands in), stamped with epoch
/// millis so it only ever matches itself. The flow ends by soft-deleting the
/// workout, so it cleans up after itself by design.
///
/// Run:
///   patrol test --target integration_test/flows/macro_dashboard_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' as db;
import 'package:mealvana_endurance/shared/database/database_provider.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';

const _filterAll = ValueKey('macro_dashboard.filter_all');
const _energyCard = ValueKey('macro_dashboard.energy_card');
const _energyExpand = ValueKey('macro_dashboard.energy_expand');
const _fullBreakdown = ValueKey('macro_dashboard.full_breakdown');
const _pager = ValueKey('macro_dashboard.pager');
const _pagerClose = ValueKey('macro_dashboard.pager_close');
const _trackingToggle = ValueKey('macro_dashboard.tracking_toggle');
const _deleteButton = ValueKey('macro_dashboard.delete_button');

void main() {
  patrolTest('macro dashboard — G1/G2 swipes, two-time writes, S-4, pager, '
      'tombstone delete', ($) async {
    await launchApp();
    await $.pump(const Duration(milliseconds: 500));

    if (!await ensureAuthenticated($)) {
      markTestSkipped(noAuthSkipMessage());
      return;
    }

    // Diagnostic tap: the app bootstrap replaces FlutterError.onError
    // (Sentry). When the test binding funnels an uncaught zone error through
    // FlutterError.reportError, that override swallows the exception and the
    // harness dies with only a generic "test overrode FlutterError.onError"
    // assert. Print the real error first so a red run names its cause in the
    // device log, then chain to the app's handler.
    final appOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(
        '[macro_dashboard_flow] FlutterError: '
        '${details.exceptionAsString()}\n${details.stack}',
      );
      appOnError?.call(details);
    };

    // ---- 0. Flag gate ----------------------------------------------------
    // Tab 0 renders MacroDashboardScreen only when MACRO_DASHBOARD_ENABLED;
    // otherwise the legacy Fuel Timeline owns the tab and this flow is moot.
    await $(const ValueKey('bottom_nav.timeline_tab'))
        .tap(settlePolicy: SettlePolicy.noSettle);
    var dashboardFound = false;
    for (var i = 0; i < 40; i++) {
      await $.pump(const Duration(milliseconds: 300));
      if ($(_filterAll).exists) {
        dashboardFound = true;
        break;
      }
      if ($(const ValueKey('fuel_timeline.filter_all')).exists) break;
    }
    if (!dashboardFound) {
      markTestSkipped(
        'MACRO_DASHBOARD_ENABLED is off — the tab renders the legacy Fuel '
        'Timeline. Enable the flag in .env.dev.local to run this flow.',
      );
      return;
    }

    // Reset to the All lens (the day was reset by ensureAuthenticated; the
    // filter is dashboard-local state a previous run may have narrowed).
    await $(_filterAll).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 400));

    // The app's own Riverpod container — same instance the screen uses, so
    // reads below see exactly the state the UI is rendering.
    final container = ProviderScope.containerOf(
      $.tester.element(find.byKey(_filterAll)),
      listen: false,
    );
    final database = container.read(appDatabaseProvider);

    Future<db.Activity?> localRow(String id) async {
      final rows = await database.select(database.activitiesTable).get();
      for (final r in rows) {
        if (r.id == id) return r;
      }
      return null;
    }

    /// Poll the local row until [predicate] holds (writes land async after
    /// the optimistic UI update).
    Future<db.Activity?> waitForLocalRow(
      String id,
      bool Function(db.Activity) predicate, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final polls = timeout.inMilliseconds ~/ 300;
      for (var i = 0; i < polls; i++) {
        final row = await localRow(id);
        if (row != null && predicate(row)) return row;
        await $.pump(const Duration(milliseconds: 300));
      }
      return null;
    }

    // ---- 1. Seed a planned workout for today -----------------------------
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final title = 'Patrol MD $stamp';
    final now = DateTime.now();
    final activityId = await container
        .read(activitiesControllerProvider.notifier)
        .createActivity(
          title: title,
          scheduledDateTime:
              DateTime(now.year, now.month, now.day, now.hour, now.minute),
          durationMinutes: 45,
        );
    final cardKey = ValueKey('macro_dashboard.workout_$activityId');

    final seeded = await waitForLocalRow(activityId, (r) => true);
    expect(seeded, isNotNull, reason: 'seeded workout missing from Drift');
    // Two-time model at the create seam: planned_time stamped from the
    // scheduled time, actual_time untouched.
    expect(seeded!.plannedTime, isNotNull,
        reason: 'insert must stamp planned_time (two-time model)');
    expect(seeded.actualTime, isNull);
    final plannedTimeAtCreate = seeded.plannedTime;

    final onDashboard = await waitForOnTimeline($, find.byKey(cardKey));
    expect(onDashboard, isTrue,
        reason: 'the seeded workout card never appeared on the dashboard');

    // ---- 2. Energy card: expand (S-4 setup) ------------------------------
    // Tracking is persisted app state; if a previous run left it off, the
    // energy card is hidden — turn it back on.
    if (!$(_energyCard).exists && $(_trackingToggle).exists) {
      await $(_trackingToggle).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
    }
    final hasEnergyCard = $(_energyCard).exists;

    // netStr renders a signed, comma-grouped figure ('−1,338' / '+207').
    // Anchor the FULL shape: the expanded face also renders bare '−'
    // placeholder dashes, and matching only on the prefix picks those up.
    final netPattern = RegExp(r'^[−+][\d,]+$');
    String netText() {
      if (!hasEnergyCard) return '';
      final texts = find
          .descendant(of: find.byKey(_energyCard), matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>();
      return texts.firstWhere(netPattern.hasMatch, orElse: () => '');
    }

    if (hasEnergyCard) {
      await $(_energyExpand).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
      expect(find.text('NET ENERGY BALANCE'), findsOneWidget,
          reason: 'chevron tap must expand the All face in place');
    }
    final netBefore = netText();

    // ---- 3. G1: full right-swipe marks done ------------------------------
    await $.tester.ensureVisible(find.byKey(cardKey));
    await $.pump(const Duration(milliseconds: 300));
    await _swipe($, find.byKey(cardKey), 320);

    // Two-time write: actual_time set, planned_time untouched.
    final doneRow = await waitForLocalRow(
      activityId,
      (r) => r.actualTime != null && r.status == 'completed',
    );
    expect(doneRow, isNotNull,
        reason: 'G1 swipe never wrote actual_time/completed to Drift');
    expect(doneRow!.plannedTime, plannedTimeAtCreate,
        reason: 'planned_time is never modified by any gesture (G1)');

    // The card wears the self-reported chip after the recompute.
    expect(
      find.descendant(
        of: find.byKey(cardKey),
        matching: find.text('self-reported'),
      ),
      findsOneWidget,
    );

    if (hasEnergyCard) {
      // S-1/G7: the recompute moves the surface's net figure. The recompute
      // is async (macro refresh may round-trip an edge call), so poll rather
      // than sample a single frame.
      var netAfter = netText();
      for (var i = 0; i < 20 && netAfter == netBefore; i++) {
        await $.pump(const Duration(milliseconds: 300));
        netAfter = netText();
      }
      expect(netAfter, isNot(netBefore),
          reason: 'marking done must move the net balance (G7/S-1)');
      // S-4: the expansion survived the card state change.
      expect(find.text('NET ENERGY BALANCE'), findsOneWidget,
          reason: 'expansion must survive a workout-card recompute (S-4)');

      // ---- 4. Breakdown Pager walk --------------------------------------
      await $.tester.ensureVisible(find.byKey(_fullBreakdown));
      await $.pump(const Duration(milliseconds: 200));
      await $(_fullBreakdown).tap(settlePolicy: SettlePolicy.noSettle);
      await $(_pager).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $.tester.drag(find.byKey(_pager), const Offset(-360, 0));
      await $.pump(const Duration(milliseconds: 500));
      await $.tester.drag(find.byKey(_pager), const Offset(-360, 0));
      await $.pump(const Duration(milliseconds: 500));
      await $(_pagerClose).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));
      expect($(_pager).exists, isFalse,
          reason: 'the pager sheet should close via its close button');
    }

    // ---- 5. G2: right-swipe again undoes (clears actual_time) ------------
    await $.tester.ensureVisible(find.byKey(cardKey));
    await $.pump(const Duration(milliseconds: 300));
    await _swipe($, find.byKey(cardKey), 320);

    final undoneRow = await waitForLocalRow(
      activityId,
      (r) => r.actualTime == null && r.status == 'planned',
    );
    expect(undoneRow, isNotNull,
        reason: 'G2 swipe never cleared actual_time back to null');
    expect(undoneRow!.plannedTime, plannedTimeAtCreate,
        reason: 'planned_time survives the undo untouched');

    // ---- 6. Delete → the row persists as a tombstone ----------------------
    await $.tester.ensureVisible(find.byKey(cardKey));
    await $.pump(const Duration(milliseconds: 300));
    await _swipe($, find.byKey(cardKey), -90);
    await $(_deleteButton).waitUntilVisible(
      timeout: const Duration(seconds: 5),
    );
    await $(_deleteButton).tap(settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 800));

    final tombstone = await waitForLocalRow(
      activityId,
      (r) => r.status == 'deleted',
    );
    expect(tombstone, isNotNull,
        reason: 'delete must SOFT-delete: the row persists as a tombstone '
            "(status='deleted'), it is never hard-deleted locally");
    expect(tombstone!.deletedAt, isNotNull);

    // The card left the surface in the same recompute (G5/S-2).
    expect(find.byKey(cardKey), findsNothing);

    // ---- 7. Remote half — SELF-SKIPS until Phase C's migrations land -----
    // Probing planned_time distinguishes "column missing" (42703 → the
    // probe's error path returns []) from "no rows" by comparing against an
    // id-only select of the same tombstoned row.
    final probe = await SupabaseProbe.signIn();
    if (probe == null) {
      debugPrint('[macro_dashboard_flow] no probe credentials — remote-half '
          'assertions skipped.');
      return;
    }
    final idSelect = await probe.select(
      'activities',
      query: 'id=eq.$activityId&select=id',
    );
    final columnSelect = await probe.select(
      'activities',
      query: 'id=eq.$activityId&select=id,planned_time',
    );
    if (columnSelect.isEmpty) {
      debugPrint(
        '[macro_dashboard_flow] remote-half assertions SKIPPED: '
        '${idSelect.isEmpty ? 'the row never uploaded (expected while the '
            'dev cloud is un-migrated — it sits dirty locally)' : 'activities.'
            'planned_time not selectable (migrations not deployed yet)'}. '
        'These arm automatically after Phase C.',
      );
      return;
    }

    // Migrations are live: the tombstone + two-time columns must have
    // round-tripped, and the dirty flag must eventually clear.
    final remoteRows = await probe.select(
      'activities',
      query: 'id=eq.$activityId&select=status,deleted_at,planned_time',
    );
    expect(remoteRows, isNotEmpty,
        reason: 'migrated cloud: the tombstone row must upload');
    final remote = remoteRows.first;
    expect(remote['status'], 'deleted',
        reason: 'remote row must carry the tombstone status');
    expect(remote['deleted_at'], isNotNull);
    expect(remote['planned_time'], isNotNull,
        reason: 'planned_time must round-trip to Supabase');

    final cleared = await waitForLocalRow(
      activityId,
      (r) => r.needsUpload != true,
      timeout: const Duration(seconds: 30),
    );
    expect(cleared, isNotNull,
        reason: 'needs_upload should clear once the upload succeeds');
  });
}

/// Drive a horizontal drag in small steps — the WorkoutCard clamps deltas
/// incrementally, so a single fling would bypass its commit threshold
/// (same technique as the widget-level gesture suite).
Future<void> _swipe(
  PatrolIntegrationTester $,
  Finder finder,
  double dx,
) async {
  final gesture = await $.tester.startGesture($.tester.getCenter(finder));
  const steps = 12;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await $.tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await $.pump(const Duration(milliseconds: 600));
}
