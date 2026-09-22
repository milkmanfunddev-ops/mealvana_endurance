/// A lapsed account cannot write in coach mode (mp-457 §4, mp-491, ticket
/// 12). There is no coach branch on the gate (mp-286): a coach's account is
/// gated like an athlete's, and a coach-on-athlete write is still a write.
///
/// Through the real coach-mode notifiers: each write path asks the write
/// guard first; refused, it opens the paywall once and never constructs the
/// coach service or repository, so nothing is written or queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/coach_mode/application/coach_service.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_chat_state.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/athlete_detail_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_chat_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_directory_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_registration_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/invite_athlete_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/my_coaches_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';

import '../../helpers/write_access.dart';

class _FakeAthleteDetail extends Fake implements AthleteDetailState {}

class _FakeActivityDetail extends Fake implements CoachActivityDetailState {}

class _FakeChat extends Fake implements CoachChatState {}

class _FakeDashboard extends Fake implements CoachDashboardState {}

class _FakeDirectory extends Fake implements CoachDirectoryState {}

class _FakeMyCoaches extends Fake implements MyCoachesState {}

class _FakeOverrides extends Fake implements NutritionTargetOverrides {}

class _SeededAthleteDetail extends AthleteDetailController {
  @override
  FutureOr<AthleteDetailState> build(String relationshipId) =>
      _FakeAthleteDetail();
}

class _SeededActivityDetail extends CoachActivityDetailController {
  @override
  FutureOr<CoachActivityDetailState> build(String activityId) =>
      _FakeActivityDetail();
}

class _SeededChat extends CoachChatController {
  @override
  FutureOr<CoachChatState> build(String relationshipId) => _FakeChat();
}

class _SeededDashboard extends CoachDashboardController {
  @override
  FutureOr<CoachDashboardState> build() => _FakeDashboard();
}

class _SeededDirectory extends CoachDirectoryController {
  @override
  FutureOr<CoachDirectoryState> build() => _FakeDirectory();
}

class _SeededRegistration extends CoachRegistrationController {
  @override
  FutureOr<void> build() {}
}

class _SeededInvite extends InviteAthleteController {
  @override
  FutureOr<void> build() {}
}

class _SeededMyCoaches extends MyCoachesController {
  @override
  FutureOr<MyCoachesState> build() => _FakeMyCoaches();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        coachServiceProvider.overrideWith(untouched('coachService')),
        coachRepositoryProvider.overrideWith(untouched('coachRepository')),
        carbLoadingServiceProvider.overrideWith(
          untouched('carbLoadingService'),
        ),
        activitiesRepositoryProvider.overrideWith(
          untouched('activitiesRepository'),
        ),
        activitiesServiceProvider.overrideWith(untouched('activitiesService')),
        appDatabaseProvider.overrideWith(untouched('appDatabase')),
        athleteDetailControllerProvider.overrideWith(_SeededAthleteDetail.new),
        coachActivityDetailControllerProvider.overrideWith(
          _SeededActivityDetail.new,
        ),
        coachChatControllerProvider.overrideWith(_SeededChat.new),
        coachDashboardControllerProvider.overrideWith(_SeededDashboard.new),
        coachDirectoryControllerProvider.overrideWith(_SeededDirectory.new),
        coachRegistrationControllerProvider.overrideWith(
          _SeededRegistration.new,
        ),
        inviteAthleteControllerProvider.overrideWith(_SeededInvite.new),
        myCoachesControllerProvider.overrideWith(_SeededMyCoaches.new),
      ],
    );
    addTearDown(container.dispose);
  });

  void refusedGroup<N>(
    String name,
    N Function() notifier,
    Map<String, Future<Object?> Function(N)> paths, {
    Future<void> Function()? warm,
  }) {
    group('$name, lapsed', () {
      for (final entry in paths.entries) {
        test('${entry.key} opens the paywall and writes nothing', () async {
          if (warm != null) await warm();
          await expectWriteRefused(opens, () => entry.value(notifier()));
        });
      }
    });
  }

  final athlete = athleteDetailControllerProvider('r1');
  refusedGroup<AthleteDetailController>(
    'AthleteDetailController',
    () => container.read(athlete.notifier),
    {
      'sendMessage': (c) => c.sendMessage(messageText: 'Great session'),
      'deleteMessage': (c) => c.deleteMessage('m1'),
      'saveNutritionTargets': (c) => c.saveNutritionTargets(_FakeOverrides()),
      'createCarbLoadingPlan': (c) => c.createCarbLoadingPlan(
        protocolDays: 3,
        raceDate: DateTime(2026, 10, 4),
        bodyWeightPounds: 160,
      ),
      'deleteCarbLoadingPlan': (c) => c.deleteCarbLoadingPlan(eventId: 'e1'),
    },
    warm: () => container.read(athlete.future),
  );

  final activity = coachActivityDetailControllerProvider('a1');
  refusedGroup<CoachActivityDetailController>(
    'CoachActivityDetailController',
    () => container.read(activity.notifier),
    {
      'saveActivity': (c) => c.saveActivity(),
      'deleteActivity': (c) => c.deleteActivity(),
      'swapFoodItem': (c) => c.swapFoodItem('f1', null, 'preRun'),
      'addFoodItem': (c) => c.addFoodItem(null, 'preRun'),
      'deleteFoodItem': (c) => c.deleteFoodItem('f1', 'preRun'),
      'updateFoodQuantity': (c) => c.updateFoodQuantity('f1', 'preRun', 2),
      'completeActivity': (c) => c.completeActivity(overallSatisfaction: 4),
      'updateCompletionRating': (c) => c.updateCompletionRating(4),
      'updateWorkoutNotes': (c) => c.updateWorkoutNotes('strong'),
    },
    warm: () => container.read(activity.future),
  );

  final chat = coachChatControllerProvider('r1');
  refusedGroup<CoachChatController>(
    'CoachChatController',
    () => container.read(chat.notifier),
    {
      'sendMessage': (c) => c.sendMessage('How was the run?'),
      'retryFailedMessages': (c) => c.retryFailedMessages(),
    },
    warm: () => container.read(chat.future),
  );

  refusedGroup<CoachDashboardController>(
    'CoachDashboardController',
    () => container.read(coachDashboardControllerProvider.notifier),
    {
      'acceptRequest': (c) => c.acceptRequest('r1'),
      'declineRequest': (c) => c.declineRequest('r1'),
      'archiveAthlete': (c) => c.archiveAthlete('r1'),
    },
    warm: () => container.read(coachDashboardControllerProvider.future),
  );

  refusedGroup<CoachDirectoryController>(
    'CoachDirectoryController',
    () => container.read(coachDirectoryControllerProvider.notifier),
    {'requestCoach': (c) => c.requestCoach('coach-1')},
    warm: () => container.read(coachDirectoryControllerProvider.future),
  );

  refusedGroup<CoachRegistrationController>(
    'CoachRegistrationController',
    () => container.read(coachRegistrationControllerProvider.notifier),
    {
      'submitApplication': (c) => c.submitApplication(
        firstName: 'Sam',
        lastName: 'Coach',
        email: 'sam@example.com',
      ),
    },
  );

  refusedGroup<InviteAthleteController>(
    'InviteAthleteController',
    () => container.read(inviteAthleteControllerProvider.notifier),
    {'inviteAthlete': (c) => c.inviteAthlete(athleteUserId: 'u2')},
  );

  refusedGroup<MyCoachesController>(
    'MyCoachesController',
    () => container.read(myCoachesControllerProvider.notifier),
    {
      'acceptRequest': (c) => c.acceptRequest('r1'),
      'declineRequest': (c) => c.declineRequest('r1'),
    },
    warm: () => container.read(myCoachesControllerProvider.future),
  );
}
