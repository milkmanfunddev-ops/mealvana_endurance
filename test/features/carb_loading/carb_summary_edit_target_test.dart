// G17 / CE-10 L2 rows (RULED Xuan 2026-09-26): `summary-row-opens-edit-dialog`,
// `past-day-row-inert`, `edit-save-rederives`.
//
// The plan summary's day rows are the athlete's edit-target entry: today's
// and future rows open the EXISTING Edit Target dialog (no new editor
// surface); past rows are inert; a save persists the stored grams and the
// row re-derives — new figure, stored g/kg, EDITED chip. The dialog keeps
// its own Cancel (CE-9 does not bind it). The MATH of rederivation is the
// G6 vectors' job; this pins the surface behavior.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_plan_summary_screen.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Event;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

// Mutable backing store: the fake controller writes here and the overridden
// days provider re-reads it, mirroring the real invalidate-and-recompute
// loop.
final _store = <String, CarbLoadingDay>{};
var _savedCalls = <(String, int)>[];

CarbLoadingDay _day(int n, DateTime date, int target) => CarbLoadingDay(
  id: 'day-$n',
  carbLoadingPlanId: 'plan-1',
  planDate: date,
  dayNumber: n,
  carbTargetGrams: target,
  carbProtocolGPerKg: 8.0,
  mealCount: 6,
  breakfastPercent: 0.25,
  morningSnackPercent: 0.10,
  lunchPercent: 0.25,
  afternoonSnackPercent: 0.15,
  dinnerPercent: 0.20,
  eveningSnackPercent: 0.05,
  loggedCarbsGrams: 0,
  loggedCalories: 0,
  completed: false,
  needsUpload: false,
  localUpdatedAt: DateTime(2026, 9, 1),
);

class _FakeCarbController extends CarbLoadingController {
  @override
  Future<void> build() async {}

  @override
  Future<void> updateDayTarget({
    required String carbLoadingDayId,
    required double carbsPerKg,
    required int dailyTargetG,
  }) async {
    _savedCalls.add((carbLoadingDayId, dailyTargetG));
    final old = _store[carbLoadingDayId]!;
    _store[carbLoadingDayId] = _day(old.dayNumber, old.planDate, dailyTargetG);
    ref.invalidate(carbLoadingDaysForPlanProvider);
  }
}

UserProfile _profile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 149.9,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
);

void main() {
  late DateTime today;
  late DateTime race;

  setUp(() {
    _savedCalls = [];
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    race = today.add(const Duration(days: 2));
    // A live plan: day 1 was YESTERDAY (past, inert), day 2 is today,
    // day 3 tomorrow. Race in 2 days.
    _store
      ..clear()
      ..['day-1'] = _day(1, today.subtract(const Duration(days: 1)), 544)
      ..['day-2'] = _day(2, today, 544)
      ..['day-3'] = _day(3, today.add(const Duration(days: 1)), 680);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carbLoadingControllerProvider.overrideWith(_FakeCarbController.new),
          carbLoadingPlanProvider.overrideWith(
            (ref, eventId) async => _FakePlan(),
          ),
          carbLoadingDaysForPlanProvider.overrideWith(
            (ref, planId) async =>
                _store.values.toList()
                  ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber)),
          ),
          eventDetailProvider.overrideWith(
            (ref, eventId, {forUserId}) async => (
              activity: null,
              event: Event(
                id: 'event-1',
                userId: 'u1',
                eventType: ActivityType.running,
                eventDate: race,
                hasCarbLoading: true,
                createdAt: DateTime(2026, 9, 1),
                updatedAt: DateTime(2026, 9, 1),
              ),
            ),
          ),
          currentUserProvider.overrideWith((ref) async => _profile()),
        ],
        child: const MaterialApp(
          home: CarbPlanSummaryScreen(eventId: 'event-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('summary-row-opens-edit-dialog: today and future rows open '
      'the EXISTING Edit Target dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('carb_summary.day_row_2')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Carb Target'), findsOneWidget);
    // The dialog keeps its OWN Cancel (CE-9 does not bind it).
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_savedCalls, isEmpty, reason: 'cancel writes nothing');

    await tester.tap(find.byKey(const ValueKey('carb_summary.day_row_3')));
    await tester.pumpAndSettle();
    expect(
      find.text('Edit Carb Target'),
      findsOneWidget,
      reason: 'future rows edit too',
    );
  });

  testWidgets('past-day-row-inert: yesterday opens nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('carb_summary.day_row_1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Carb Target'), findsNothing);
    expect(_savedCalls, isEmpty);
  });

  testWidgets('edit-save-rederives: new figure, stored rate, EDITED chip', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('EDITED'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('carb_summary.day_row_2')));
    await tester.pumpAndSettle();
    // Drive the dialog: default mode edits g/kg (one TextField). 9.2 g/kg
    // at 149.9 lb (67.99 kg) rounds to 626 g.
    await tester.enterText(find.byType(TextField).first, '9.2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_savedCalls, [('day-2', 626)]);
    expect(find.textContaining('626 g', findRichText: true), findsOneWidget);
    expect(
      find.text('EDITED'),
      findsOneWidget,
      reason: 'stored ≠ derivation → the chip re-derives on save',
    );
  });
}

class _FakePlan {
  final String id = 'plan-1';
  final int totalDays = 3;
}
