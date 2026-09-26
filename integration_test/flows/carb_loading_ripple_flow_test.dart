/// CD-2 frame-level walk under **Patrol** — the loading-day dashboard's core
/// contract (surfaces/carb-loading-dashboard.md §1/§5, carb-loading@v1):
/// ONE food-log write ripples EVERY carb surface together — the LOAD face's
/// figures, the slot card's header, and the breakdown's numbers all render
/// the single provider truth after one write and one settle; no surface
/// lags or disagrees.
///
/// Method: the walked Banana write, driven through the REAL meal-log
/// controller (the same local-first path the quick-log sheet lands in), then
/// every painted string is asserted EQUAL to the assembler's own derivation
/// read from the app's live Riverpod container — the UI may not disagree
/// with the source it claims to render.
///
/// Seeding: if today already sits in a carb plan (the dev account's live
/// plan), the flow uses it as-is and touches no plan rows. Otherwise it
/// seeds its own event + 3-day plan (race = tomorrow → today is the peak
/// day) through the real controllers and deletes them afterwards. The
/// seeded banana log is soft-deleted THROUGH THE CONTROLLER either way, so
/// the flow cleans up after itself by design and never double-counts a
/// second run (epoch-stamped name).
///
/// Self-skips: no session/credentials (standard), or the dashboard failing
/// to render.
///
/// Run:
///   patrol test --target integration_test/flows/carb_loading_ripple_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17"
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../helpers/flow_launcher.dart';

const _filterAll = ValueKey('macro_dashboard.filter_all');

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  patrolTest(
    'CD-2: one banana write ripples face, slot card and breakdown together',
    ($) async {
      await launchApp($);
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // Land on the dashboard's All lens.
      await $(
        _filterAll,
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(_filterAll).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));

      final container = ProviderScope.containerOf(
        $.tester.element(find.byKey(_filterAll)),
        listen: false,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateStr = _ymd(today);
      final stamp = DateTime.now().millisecondsSinceEpoch;

      // ---- 0. Sweep debris from any previously-aborted run -----------------
      // A mid-flow exception (rethrown at the next pump) can abort before
      // the tail cleanup runs; the seeded plan then OVERLAPS the account's
      // real plan — ruled-undefined territory. Sweep unconditionally, start
      // AND end, keyed by this flow's exclusive names.
      Future<void> sweepDebris() async {
        final events = await container.read(allEventsProvider.future);
        for (final e in events) {
          if ((e.eventName ?? '').startsWith('Patrol CarbRipple')) {
            debugPrint('CD-2 flow: sweeping leftover event ${e.eventName}');
            await container
                .read(carbLoadingControllerProvider.notifier)
                .deleteCarbLoadingPlan(e.id);
            await container
                .read(eventsControllerProvider.notifier)
                .deleteEvent(e.id);
          }
        }
        final logs = await container.read(
          mealLogsForDateProvider(dateStr).future,
        );
        for (final log in logs) {
          if (log.name.startsWith('Patrol Banana ')) {
            debugPrint('CD-2 flow: sweeping leftover log ${log.name}');
            await container
                .read(mealLogControllerProvider.notifier)
                .deleteLog(log.id);
          }
        }
        // No manual invalidation here: the controllers' own writes must
        // propagate (G24) — a manual invalidate would mask exactly the bug
        // class this flow exists to catch.
      }

      await sweepDebris();
      await $.pumpAndSettle();

      // ---- 0b. G22 invariant snapshot --------------------------------------
      // The account's PLAN SET must leave this flow exactly as it entered it
      // (post-sweep): same plan ids, same day rows, same stored targets. A
      // teardown mismatch is the synthetic-traffic bug class — test state
      // leaking into the real account.
      final repository = container.read(carbLoadingRepositoryProvider);
      Future<String> planFingerprint() async {
        final events = await container.read(allEventsProvider.future);
        final parts = <String>[];
        for (final e in events) {
          final plan = await repository.getCarbLoadingPlanForEvent(e.id);
          if (plan == null) continue;
          final days = await repository.getCarbLoadingDaysForPlan(plan.id);
          days.sort((a, b) => a.planDate.compareTo(b.planDate));
          parts.add(
            '${plan.id}:${plan.totalDays}:'
            '${days.map((d) => '${d.id}=${d.planDate.toIso8601String()}'
                '@${d.carbTargetGrams}').join(',')}',
          );
        }
        parts.sort();
        return parts.join('|');
      }

      final planSetBefore = await planFingerprint();

      // ---- 1. Ensure today is a loading day --------------------------------
      var carb = await container.read(
        carbDashboardForDateProvider(dateStr).future,
      );
      String? seededEventId;
      if (carb == null) {
        final eventId = await container
            .read(eventsControllerProvider.notifier)
            .createEvent(
              eventType: ActivityType.running,
              eventName: 'Patrol CarbRipple $stamp',
              startTime: today.add(const Duration(days: 1)).toIso8601String(),
            );
        seededEventId = eventId;
        await container
            .read(carbLoadingControllerProvider.notifier)
            .createCarbLoadingPlan(
              eventId: eventId,
              protocolDays: 3,
              raceDate: today.add(const Duration(days: 1)),
              bodyWeightPounds: 149.9,
            );
        // G24: createCarbLoadingPlan's own invalidation must surface the
        // new plan here — no manual invalidate (it masked the real gap).
        carb = await container.read(
          carbDashboardForDateProvider(dateStr).future,
        );
      }
      if (carb == null) {
        markTestSkipped('No carb plan renderable for today — seeding failed.');
        return;
      }
      await $.pumpAndSettle();

      final breakfastBefore = carb.slots.first.eatenG;

      // ---- 2. ONE write: the banana, slot-tagged, through the REAL path ----
      await container
          .read(mealLogControllerProvider.notifier)
          .logFromComponents(
            name: 'Patrol Banana $stamp',
            slot: MealSlot.breakfast,
            logDate: dateStr,
            source: MealLogSource.manual,
            components: const [
              MealComponent(
                name: 'Banana',
                portion: '1 medium',
                calories: 105,
                carbG: 27,
                proteinG: 1,
                fatG: 0,
              ),
            ],
            eatenAt: DateTime.now(),
          );
      await $.pumpAndSettle();

      // ---- 3. The single settled tree must render the single truth ---------
      final after = (await container.read(
        carbDashboardForDateProvider(dateStr).future,
      ))!;
      expect(
        after.slots.first.eatenG,
        breakfastBefore + 27,
        reason: 'the write landed in the provider truth',
      );

      // Face: label + both pace strings, painted exactly as derived.
      expect($(after.face.labelLine), findsWidgets, reason: 'face label');
      expect(
        $(after.face.paceMainStr),
        findsWidgets,
        reason: 'face pace main equals the assembler derivation',
      );
      expect(
        $(after.face.paceSubStr),
        findsWidgets,
        reason: 'face pace sub equals the assembler derivation',
      );
      // Slot card: the header figure moved WITH the face in the same tree.
      expect(
        $(after.slots.first.headerFigure),
        findsWidgets,
        reason: 'Breakfast card header equals the same derivation',
      );

      // Breakdown: same numbers one level deeper (read-only page).
      final expandKey = find.byKey(
        const ValueKey('macro_dashboard.energy_expand'),
      );
      await $.tester.tap(expandKey);
      await $.pumpAndSettle();
      await $.tester.tap(
        find.byKey(const ValueKey('macro_dashboard.carb_full_breakdown')),
      );
      await $.pumpAndSettle();
      expect(
        $(after.breakdown.eatenOfTargetStr),
        findsWidgets,
        reason: 'breakdown hero equals the same derivation',
      );
      expect(
        $(after.breakdown.titleLine),
        findsWidgets,
        reason: 'breakdown title present',
      );
      // The breakdown's back is a Semantics-labeled chevron, not a Tooltip.
      await $.tester.tap(find.byIcon(Icons.chevron_left).first);
      await $.pumpAndSettle();

      // ---- 4. Cleanup: the same unconditional sweep ------------------------
      // seededEventId rides the name sweep; referenced to keep the seeding
      // path explicit.
      expect(seededEventId == null || seededEventId.isNotEmpty, isTrue);
      await sweepDebris();
      await $.pumpAndSettle();

      // ---- 5. G22 teardown invariant ---------------------------------------
      final planSetAfter = await planFingerprint();
      expect(
        planSetAfter,
        planSetBefore,
        reason:
            'G22: the plan set (ids + rows + targets) must be IDENTICAL to '
            'the setup snapshot — anything else is test state leaking into '
            'the real account.',
      );
    },
  );
}
