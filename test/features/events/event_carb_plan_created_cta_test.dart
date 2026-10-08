// CE-3 (spec/fueling/carb-loading-entryway.md): after creating a plan whose
// window is already underway, the success snackbar's "Go to today's fuel"
// reaches the dashboard TIMELINE on today's date. 1.30.0 bugfix: the CTA
// used `popUntil(isFirst)`, which unwound to the shell but never selected a
// tab, so the athlete landed on whatever tab they entered Event Details
// from (My Events in the repro). The fix asks the shell for the Timeline
// tab and sets the selected date to today before unwinding; this pins both
// asks. A plan whose window has not started offers no CTA at all.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/widgets/event_action_buttons_card.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/providers/home_shell_tab_request.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mocktail/mocktail.dart';

const _cta = "Go to today's fuel";

class _FakeCarbController extends CarbLoadingController {
  static final created = <int>[];

  @override
  Future<void> build() async {}

  @override
  Future<void> createCarbLoadingPlan({
    required String eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
    String? forUserId,
  }) async {
    created.add(protocolDays);
  }
}

class _MockUserRepository extends Mock implements UserRepository {}

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

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Event _event({required int daysUntilRace}) {
  // The create path takes the race date from `startTime` (or the linked
  // activity), the row's feasibility from `eventDate` — a saved event
  // carries both.
  final race = _today().add(Duration(days: daysUntilRace));
  return Event(
    id: 'event-1',
    userId: 'u1',
    eventType: ActivityType.running,
    eventDate: race,
    startTime: race.toIso8601String(),
    hasCarbLoading: false,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

void main() {
  late ProviderContainer container;

  setUp(() => _FakeCarbController.created.clear());

  Future<void> pumpCard(WidgetTester tester, Event e) async {
    final userRepo = _MockUserRepository();
    when(() => userRepo.getUserProfile()).thenAnswer((_) async => _profile());
    container = ProviderContainer(
      overrides: [
        carbLoadingControllerProvider.overrideWith(_FakeCarbController.new),
        userRepositoryProvider.overrideWith((_) async => userRepo),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventActionButtonsCard(
                activity: null,
                event: e,
                eventId: e.id,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Set Up → chooser → 1-Day → back on the card with the success snackbar.
  Future<void> createOneDayPlan(WidgetTester tester) async {
    await tester.tap(find.text('Set Up Carb Loading'));
    await tester.pumpAndSettle();
    final select = find.byKey(
      const ValueKey('carb_loading.select_1_day_button'),
    );
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(_FakeCarbController.created, [1]);
    expect(find.text('Created 1-day carb loading plan!'), findsOneWidget);
  }

  testWidgets(
    'window underway: "Go to today\'s fuel" asks the shell for the Timeline '
    'tab on today (CE-3)',
    (tester) async {
      // Race tomorrow, 1-day protocol → day 1 is today → underway.
      await pumpCard(tester, _event(daysUntilRace: 1));
      await createOneDayPlan(tester);
      expect(find.text(_cta), findsOneWidget);

      // Make both asks observable: the shell has had no request yet and the
      // timeline is parked on yesterday.
      expect(container.read(homeShellTabRequestProvider), isNull);
      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(_today().subtract(const Duration(days: 1)));

      await tester.tap(find.text(_cta));
      await tester.pumpAndSettle();

      expect(
        container.read(homeShellTabRequestProvider),
        HomeShellTabRequest.timeline,
        reason: 'the CTA must select the Timeline tab, not just unwind',
      );
      expect(container.read(calendarSelectedDateProvider), _today());
    },
  );

  testWidgets('window not started: no CTA, no forced navigation (CE-3)', (
    tester,
  ) async {
    // Race in 3 days, 1-day protocol → day 1 is the day after tomorrow.
    await pumpCard(tester, _event(daysUntilRace: 3));
    await createOneDayPlan(tester);
    expect(find.text(_cta), findsNothing);
    expect(container.read(homeShellTabRequestProvider), isNull);
  });
}
