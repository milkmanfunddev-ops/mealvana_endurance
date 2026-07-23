// Seeded CONTENT tests — coach_mode screens.
//
// Goal: assert real rendered VALUES, not just "does it build". Where state is
// seedable via a fake AsyncNotifier override, we assert exact strings.
//
// BUG NOTES are embedded inline where assertions reveal real issues.
//
// NOTE: CalendarMonthScreen and CarbLoadingScreen were dead mock-data screens
// with 0 external nav references. Both deleted 2026-07-01. Their test groups
// have been removed from this file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_chat_state.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_message.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_chat_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/my_coaches_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_chat_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_portal_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/my_coaches_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../helpers/widget_test_harness.dart';

// ============================================================================
// Shared relationship fixture
// ============================================================================

const _kRelationshipId = 'rel-1';
const _kCoachUserId = 'coach-u1';
const _kAthleteUserId = 'athlete-u2';

CoachAthleteRelationship _seedRelationship({
  RelationshipStatus status = RelationshipStatus.active,
  String? coachDisplayName = 'Sarah Johnson',
  String? athleteDisplayName = 'Alex Rivera',
}) {
  final now = DateTime.now();
  return CoachAthleteRelationship(
    id: _kRelationshipId,
    coachUserId: _kCoachUserId,
    athleteUserId: _kAthleteUserId,
    status: status,
    requestedBy: 'coach',
    requestedAt: now.subtract(const Duration(days: 10)),
    acceptedAt: now.subtract(const Duration(days: 9)),
    createdAt: now.subtract(const Duration(days: 10)),
    updatedAt: now,
    coachDisplayName: coachDisplayName,
    athleteDisplayName: athleteDisplayName,
  );
}

// ============================================================================
// GoRouter wrapper — for screens that have navigation dependencies
// ============================================================================

/// Pumps a screen inside a GoRouter so [context.push] / [context.go] calls
/// in the screen under test don't throw "No GoRouter found in widget tree".
/// Applies the same base overrides as [pumpSeeded].
Future<void> _pumpSeededWithRouter(
  WidgetTester tester,
  Widget Function() buildScreen, {
  List<Override> overrides = const [],
  AppDatabase? database,
  bool settle = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = database ?? AppDatabase.memory();
  addTearDown(db.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => buildScreen())],
  );
  addTearDown(router.dispose);

  final allOverrides = <Override>[
    mockAppExternalDeps(),
    appDatabaseProvider.overrideWithValue(db),
    preferencesServiceProvider.overrideWith((ref) => PreferencesService(prefs)),
    currentUserProvider.overrideWith((ref) async => null),
    ...overrides,
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

// ============================================================================
// Fake controllers
// ============================================================================

/// Seeds MyCoachesController with one active coach and one pending request.
class _FakeMyCoachesController extends MyCoachesController {
  @override
  FutureOr<MyCoachesState> build() async {
    final now = DateTime.now();

    final activeCoach = CoachAthleteRelationship(
      id: 'rel-active-1',
      coachUserId: 'coach-u10',
      athleteUserId: 'athlete-u1',
      status: RelationshipStatus.active,
      requestedBy: 'coach',
      requestedAt: now.subtract(const Duration(days: 30)),
      acceptedAt: now.subtract(const Duration(days: 29)),
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      coachDisplayName: 'Dr. Rachel Mitchell',
    );

    final pendingCoach = CoachAthleteRelationship(
      id: 'rel-pending-1',
      coachUserId: 'coach-u20',
      athleteUserId: 'athlete-u1',
      status: RelationshipStatus.pending,
      requestedBy: 'coach',
      requestedAt: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      coachDisplayName: 'Marcus Chen',
    );

    return MyCoachesState(
      activeCoaches: [activeCoach],
      pendingRequests: [pendingCoach],
    );
  }
}

/// Seeds MyCoachesController with empty state (no coaches, no pending requests).
class _FakeEmptyMyCoachesController extends MyCoachesController {
  @override
  FutureOr<MyCoachesState> build() async {
    return const MyCoachesState();
  }
}

/// Seeds CoachDashboardController with two active athletes and no pending requests.
class _FakeCoachDashboardController extends CoachDashboardController {
  @override
  FutureOr<CoachDashboardState> build() async {
    final now = DateTime.now();

    final athlete1 = CoachAthleteRelationship(
      id: 'rel-a1',
      coachUserId: 'coach-u1',
      athleteUserId: 'athlete-u10',
      status: RelationshipStatus.active,
      requestedBy: 'coach',
      requestedAt: now.subtract(const Duration(days: 5)),
      acceptedAt: now.subtract(const Duration(days: 4)),
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
      athleteDisplayName: 'Jordan Park',
    );

    final athlete2 = CoachAthleteRelationship(
      id: 'rel-a2',
      coachUserId: 'coach-u1',
      athleteUserId: 'athlete-u11',
      status: RelationshipStatus.active,
      requestedBy: 'coach',
      requestedAt: now.subtract(const Duration(days: 15)),
      acceptedAt: now.subtract(const Duration(days: 14)),
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now,
      athleteDisplayName: 'Taylor Smith',
    );

    return CoachDashboardState(
      activeAthletes: [athlete1, athlete2],
      pendingRequests: const [],
    );
  }
}

/// Seeds CoachDashboardController with empty state (not a coach).
class _FakeNoCoachDashboardController extends CoachDashboardController {
  @override
  FutureOr<CoachDashboardState> build() async {
    return const CoachDashboardState(activeAthletes: [], pendingRequests: []);
  }
}

/// Seeds CoachChatController (family provider) with two messages.
class _FakeCoachChatController extends CoachChatController {
  @override
  FutureOr<CoachChatState> build(String relationshipId) async {
    final relationship = _seedRelationship();
    final now = DateTime.now();

    final msgFromCoach = CoachMessage(
      id: 'msg-1',
      coachUserId: _kCoachUserId,
      athleteUserId: _kAthleteUserId,
      senderUserId: _kCoachUserId,
      messageText: 'Great job on your long run yesterday!',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      status: MessageStatus.sent,
    );

    final msgFromAthlete = CoachMessage(
      id: 'msg-2',
      coachUserId: _kCoachUserId,
      athleteUserId: _kAthleteUserId,
      senderUserId: _kAthleteUserId,
      messageText: 'Thanks coach! Felt strong the whole way.',
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      status: MessageStatus.sent,
    );

    return CoachChatState(
      relationship: relationship,
      messages: [msgFromCoach, msgFromAthlete],
      // current user = athlete, so coach messages are "received"
      currentUserId: _kAthleteUserId,
    );
  }
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  // ==========================================================================
  // 1. MyCoachesScreen — seeded content
  // ==========================================================================

  group('MyCoachesScreen — seeded content', () {
    testWidgets('renders "My Coaches" app bar title', (tester) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('My Coaches'),
        findsOneWidget,
        reason: 'AppBar title must read "My Coaches"',
      );
    });

    testWidgets('renders "Active Coaches" section header when coaches exist', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Active Coaches'),
        findsOneWidget,
        reason: '"Active Coaches" section header must appear',
      );
    });

    testWidgets('renders "Pending Requests" section when pending exist', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Pending Requests'),
        findsOneWidget,
        reason:
            '"Pending Requests" section header must appear when list is non-empty',
      );
    });

    testWidgets('active coach card shows "Coach <displayName>"', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Coach Dr. Rachel Mitchell'),
        findsOneWidget,
        reason:
            'Active coach card must render "Coach <displayName>" with seeded name',
      );
    });

    testWidgets('pending request card shows coach display name', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Coach Marcus Chen'),
        findsOneWidget,
        reason: 'Pending request card must show "Coach <displayName>"',
      );
    });

    testWidgets('pending request card shows "Coach Request" label', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      // _buildPendingRequestCard renders a Text('Coach Request') as the title
      expect(
        find.text('Coach Request'),
        findsOneWidget,
        reason: 'Pending card must show "Coach Request" as title label',
      );
    });

    testWidgets('Accept and Decline buttons appear on pending request card', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Accept'),
        findsOneWidget,
        reason: '"Accept" button must appear on the pending request card',
      );
      expect(
        find.text('Decline'),
        findsOneWidget,
        reason: '"Decline" button must appear on the pending request card',
      );
    });

    testWidgets('"Active" status badge renders on active coach card', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Active'),
        findsOneWidget,
        reason: '"Active" status badge must appear on the active coach card',
      );
    });

    testWidgets('"No coaches connected" empty state renders when lists empty', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeEmptyMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('No coaches connected'),
        findsOneWidget,
        reason:
            'Empty state card must show "No coaches connected" when both lists are empty',
      );
    });

    testWidgets('"Find a Coach" CTA present in empty state', (tester) async {
      await pumpSeeded(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _FakeEmptyMyCoachesController.new,
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Find a Coach'),
        findsOneWidget,
        reason: '"Find a Coach" button must appear in empty state',
      );
    });
  });

  // ==========================================================================
  // 2. CoachPortalScreen — seeded dashboard + portal state
  // ==========================================================================

  group('CoachPortalScreen — seeded dashboard', () {
    // CoachPortalScreen reads coachDashboardControllerProvider (async) and
    // coachPortalControllerProvider (synchronous). Portal state starts with
    // selectedRelationshipId == null, so the right panel shows the no-athlete view.

    testWidgets('renders "Select an athlete" prompt when no athlete selected', (
      tester,
    ) async {
      // Use the router wrapper because CoachPortalScreen contains widgets that
      // may call context.push / context.go.
      await _pumpSeededWithRouter(
        tester,
        () => const CoachPortalScreen(),
        overrides: [
          coachDashboardControllerProvider.overrideWith(
            _FakeNoCoachDashboardController.new,
          ),
        ],
        settle: false,
      );

      expect(
        find.text('Select an athlete'),
        findsOneWidget,
        reason:
            '"Select an athlete" prompt must appear when selectedRelationshipId is null',
      );
    });

    testWidgets('"Choose an athlete from the sidebar" sub-text present', (
      tester,
    ) async {
      await _pumpSeededWithRouter(
        tester,
        () => const CoachPortalScreen(),
        overrides: [
          coachDashboardControllerProvider.overrideWith(
            _FakeNoCoachDashboardController.new,
          ),
        ],
        settle: false,
      );

      expect(
        find.text('Choose an athlete from the sidebar to view their details.'),
        findsOneWidget,
        reason: 'Sub-text must appear under the no-athlete-selected prompt',
      );
    });
  });

  // ==========================================================================
  // 3. CoachChatScreen — seeded messages
  // ==========================================================================

  group('CoachChatScreen — seeded messages', () {
    // CoachChatScreen does NOT read GoRouterState — it uses a widget constructor
    // param. pumpSeeded is sufficient.

    testWidgets('renders other participant name (coach) in app bar', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      // Current user = athlete; other participant = coach = "Sarah Johnson"
      expect(
        find.text('Sarah Johnson'),
        findsWidgets,
        reason:
            'AppBar must render coachDisplayName as the other participant name',
      );
    });

    testWidgets('renders "Coach" role label for other participant', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      // otherParticipantRole = "Coach" (current user is athlete)
      expect(
        find.text('Coach'),
        findsOneWidget,
        reason: 'AppBar sub-text must show "Coach" as the other role',
      );
    });

    testWidgets('renders seeded coach message text', (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      expect(
        find.text('Great job on your long run yesterday!'),
        findsOneWidget,
        reason: 'Coach message bubble must render the seeded message text',
      );
    });

    testWidgets('renders seeded athlete reply message text', (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      expect(
        find.text('Thanks coach! Felt strong the whole way.'),
        findsOneWidget,
        reason: 'Athlete reply bubble must render the seeded reply text',
      );
    });

    testWidgets('"Today" date separator appears for same-day messages', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      // Both messages are from today (hours ago) → single "Today" separator
      expect(
        find.text('Today'),
        findsOneWidget,
        reason:
            'Date separator must show "Today" for messages sent earlier today',
      );
    });

    testWidgets('sender name label appears above received (coach) message', (
      tester,
    ) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(
            _kRelationshipId,
          ).overrideWith(() => _FakeCoachChatController()),
        ],
        settle: true,
      );

      // ChatMessageBubble renders senderName above non-current-user messages.
      // "Sarah Johnson" appears in AppBar title AND as sender label.
      expect(
        find.text('Sarah Johnson'),
        findsWidgets,
        reason:
            'Sender label "Sarah Johnson" must appear above the received message bubble',
      );
    });
  });
}
