// Seeded CONTENT tests — coach_mode, calendar, and carb_loading screens.
//
// Goal: assert real rendered VALUES, not just "does it build". Where state is
// seedable via a fake AsyncNotifier override, we assert exact strings. Where
// a screen renders static/mock data (CarbLoadingScreen, CalendarMonthScreen)
// we assert the hardcoded values ARE what we think they are — so a future
// refactor that silently changes them gets caught.
//
// BUG NOTES are embedded inline where assertions reveal real issues.

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
import 'package:mealvana_endurance/features/calendar/presentation/screens/calendar_month_screen.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_loading_screen.dart';
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
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => buildScreen(),
      ),
    ],
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

      expect(find.text('My Coaches'), findsOneWidget,
          reason: 'AppBar title must read "My Coaches"');
    });

    testWidgets('renders "Active Coaches" section header when coaches exist',
        (tester) async {
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

      expect(find.text('Active Coaches'), findsOneWidget,
          reason: '"Active Coaches" section header must appear');
    });

    testWidgets('renders "Pending Requests" section when pending exist',
        (tester) async {
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

      expect(find.text('Pending Requests'), findsOneWidget,
          reason:
              '"Pending Requests" section header must appear when list is non-empty');
    });

    testWidgets('active coach card shows "Coach <displayName>"',
        (tester) async {
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

      expect(find.text('Coach Dr. Rachel Mitchell'), findsOneWidget,
          reason:
              'Active coach card must render "Coach <displayName>" with seeded name');
    });

    testWidgets('pending request card shows coach display name', (tester) async {
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

      expect(find.text('Coach Marcus Chen'), findsOneWidget,
          reason: 'Pending request card must show "Coach <displayName>"');
    });

    testWidgets('pending request card shows "Coach Request" label',
        (tester) async {
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
      expect(find.text('Coach Request'), findsOneWidget,
          reason: 'Pending card must show "Coach Request" as title label');
    });

    testWidgets('Accept and Decline buttons appear on pending request card',
        (tester) async {
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

      expect(find.text('Accept'), findsOneWidget,
          reason: '"Accept" button must appear on the pending request card');
      expect(find.text('Decline'), findsOneWidget,
          reason: '"Decline" button must appear on the pending request card');
    });

    testWidgets('"Active" status badge renders on active coach card',
        (tester) async {
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

      expect(find.text('Active'), findsOneWidget,
          reason: '"Active" status badge must appear on the active coach card');
    });

    testWidgets('"No coaches connected" empty state renders when lists empty',
        (tester) async {
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

      expect(find.text('No coaches connected'), findsOneWidget,
          reason:
              'Empty state card must show "No coaches connected" when both lists are empty');
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

      expect(find.text('Find a Coach'), findsOneWidget,
          reason: '"Find a Coach" button must appear in empty state');
    });
  });

  // ==========================================================================
  // 2. CoachPortalScreen — seeded dashboard + portal state
  // ==========================================================================

  group('CoachPortalScreen — seeded dashboard', () {
    // CoachPortalScreen reads coachDashboardControllerProvider (async) and
    // coachPortalControllerProvider (synchronous). Portal state starts with
    // selectedRelationshipId == null, so the right panel shows the no-athlete view.

    testWidgets('renders "Select an athlete" prompt when no athlete selected',
        (tester) async {
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

      expect(find.text('Select an athlete'), findsOneWidget,
          reason:
              '"Select an athlete" prompt must appear when selectedRelationshipId is null');
    });

    testWidgets('"Choose an athlete from the sidebar" sub-text present',
        (tester) async {
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
        find.text(
          'Choose an athlete from the sidebar to view their details.',
        ),
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

    testWidgets('renders other participant name (coach) in app bar',
        (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
        ],
        settle: true,
      );

      // Current user = athlete; other participant = coach = "Sarah Johnson"
      expect(find.text('Sarah Johnson'), findsWidgets,
          reason:
              'AppBar must render coachDisplayName as the other participant name');
    });

    testWidgets('renders "Coach" role label for other participant',
        (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
        ],
        settle: true,
      );

      // otherParticipantRole = "Coach" (current user is athlete)
      expect(find.text('Coach'), findsOneWidget,
          reason: 'AppBar sub-text must show "Coach" as the other role');
    });

    testWidgets('renders seeded coach message text', (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
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
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
        ],
        settle: true,
      );

      expect(
        find.text('Thanks coach! Felt strong the whole way.'),
        findsOneWidget,
        reason: 'Athlete reply bubble must render the seeded reply text',
      );
    });

    testWidgets('"Today" date separator appears for same-day messages',
        (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
        ],
        settle: true,
      );

      // Both messages are from today (hours ago) → single "Today" separator
      expect(find.text('Today'), findsOneWidget,
          reason:
              'Date separator must show "Today" for messages sent earlier today');
    });

    testWidgets('sender name label appears above received (coach) message',
        (tester) async {
      await pumpSeeded(
        tester,
        const CoachChatScreen(relationshipId: _kRelationshipId),
        overrides: [
          coachChatControllerProvider(_kRelationshipId).overrideWith(
            () => _FakeCoachChatController(),
          ),
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

  // ==========================================================================
  // 4. CalendarMonthScreen — static / mock data assertions
  // ==========================================================================
  //
  // BUG: CalendarMonthScreen renders HARDCODED mock data:
  //
  //   A. _hasEventsOnDay(day) uses: `day % 3 == 0 || day % 7 == 0`
  //      This shows event indicator dots on days 3, 6, 7, 9, 12, 14, 18, 21...
  //      regardless of any real CalendarController data. Users see misleading dots.
  //
  //   B. Week view's _getMockTodaysActivities() returns "10 MILE RUN" and
  //      "HILL REPEATS" hardcoded — CalendarController is never watched.
  //
  //   C. Week view's _getMockUpcomingEvents() returns "KULTURE CITY HALF
  //      MARATHON" (Nov 22) and "TEAM TRAINING SESSION" (Nov 30) — always,
  //      regardless of the user's actual events.
  //
  // These tests lock in the hardcoded values so a future change is caught,
  // and document the bug with explicit reason strings.

  group('CalendarMonthScreen — static mock data content', () {
    testWidgets('renders current month+year header', (tester) async {
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);

      final now = DateTime.now();
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final expected = '${months[now.month - 1]} ${now.year}';

      // Month header appears in both AppBar and the navigation row
      expect(find.text(expected), findsWidgets,
          reason: 'Current month+year must appear in AppBar and nav row');
    });

    testWidgets('renders "BY MONTH" and "BY WEEK" view toggle', (tester) async {
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);

      expect(find.text('BY MONTH'), findsOneWidget,
          reason: '"BY MONTH" toggle option must be present');
      expect(find.text('BY WEEK'), findsOneWidget,
          reason: '"BY WEEK" toggle option must be present');
    });

    testWidgets('day-of-week headers render in month view', (tester) async {
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);

      // Headers: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      expect(find.text('M'), findsOneWidget, reason: 'Monday header present');
      expect(find.text('W'), findsOneWidget, reason: 'Wednesday header present');
      expect(find.text('F'), findsOneWidget, reason: 'Friday header present');
      // 'S' appears twice (Sun + Sat), 'T' appears twice (Tue + Thu)
      expect(find.text('S'), findsWidgets, reason: 'S headers present (Sun + Sat)');
    });

    // BUG: week view hardcoded activities
    //
    // ADDITIONAL BUG: _buildWeekView uses a non-scrollable Column that overflows
    // by 96px at standard phone size (528×800 logical). A taller viewport is
    // required to render the content without overflow. This overflow is itself a
    // layout bug — the week view should use a scrollable container.
    //
    // Tests use a taller physicalSize (800×1200) to work around the overflow so
    // that content assertions can still be made. The overflow is documented below.

    testWidgets(
        'week view shows "Today\'s Activities" section header',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text("Today's Activities"), findsOneWidget,
          reason: '"Today\'s Activities" section header must appear in week view');
    });

    testWidgets(
        'BUG: week view shows hardcoded "10 MILE RUN" — not real user data',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('10 MILE RUN'), findsOneWidget,
          reason:
              'BUG: "10 MILE RUN" is hardcoded mock data; CalendarController is never read in week view');
    });

    testWidgets(
        'BUG: week view shows hardcoded "HILL REPEATS" — not real user data',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('HILL REPEATS'), findsOneWidget,
          reason:
              'BUG: "HILL REPEATS" is hardcoded mock data, not from real user activities');
    });

    testWidgets(
        'BUG: week view shows hardcoded "KULTURE CITY HALF MARATHON" event',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Events'), findsOneWidget,
          reason: '"Upcoming Events" section must appear in week view');
      expect(find.text('KULTURE CITY HALF MARATHON'), findsOneWidget,
          reason:
              'BUG: "KULTURE CITY HALF MARATHON" is hardcoded mock data, not real events');
    });

    testWidgets(
        'BUG: week view shows hardcoded "TEAM TRAINING SESSION" event',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('TEAM TRAINING SESSION'), findsOneWidget,
          reason:
              'BUG: "TEAM TRAINING SESSION" is hardcoded mock data, not real events');
    });

    testWidgets(
        'BUG: week view shows hardcoded "Nov 22" date badge — always November',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('Nov 22'), findsOneWidget,
          reason:
              'BUG: "Nov 22" is hardcoded; will always show November regardless of real event date');
    });

    testWidgets(
        'BUG: week view shows hardcoded "18.8 mi" activity detail',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSeeded(tester, const CalendarMonthScreen(), settle: true);
      await tester.tap(find.text('BY WEEK'));
      await tester.pumpAndSettle();

      expect(find.text('18.8 mi • 10:30/mi'), findsOneWidget,
          reason:
              'BUG: "18.8 mi" is hardcoded mock data, not from user activity');
    });
  });

  // ==========================================================================
  // 5. CarbLoadingScreen — static/mock data assertions
  // ==========================================================================
  //
  // BUG: CarbLoadingScreen is a pure mock-data screen. It contains NO provider
  // reads beyond analytics. CarbLoadingController is never watched. All content
  // is driven by _getMockDay1Meals / _getMockDay2Meals / _getMockDay3Meals which
  // return hardcoded MockMeal structs.
  //
  // Specific bugs:
  //  A. "Starts: Tomorrow • Duration: 3 days" — hardcoded string, not derived
  //     from any real event date or plan. "Tomorrow" is always wrong.
  //
  //  B. "3-Day Loading Protocol" — hardcoded name, not from the user's protocol.
  //
  //  C. Nutrition dialog computes protein as `(calories * 0.15).round()` and fat
  //     as `(calories * 0.08).round()`. For Oatmeal with Berries (320 cal) this
  //     yields protein=48g — ~4x the actual value. These are fabricated numbers.
  //
  //  D. Day calorie totals (705, 830, 800) are arithmetic sums of hardcoded
  //     MockMeal.calories values — not from the user's actual food log.

  group('CarbLoadingScreen — static mock data content', () {
    testWidgets('renders "Carb Loading" AppBar title', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Carb Loading'), findsOneWidget,
          reason: 'AppBar title must read "Carb Loading"');
    });

    testWidgets('renders "Current Protocol" card header', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Current Protocol'), findsOneWidget,
          reason: '"Current Protocol" card must be present');
    });

    testWidgets(
        'BUG: renders hardcoded "3-Day Loading Protocol" — ignores real data',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('3-Day Loading Protocol'), findsOneWidget,
          reason:
              'BUG: Protocol name is hardcoded "3-Day Loading Protocol" regardless of actual user protocol');
    });

    testWidgets(
        'BUG: renders hardcoded "Starts: Tomorrow • Duration: 3 days"',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(
        find.text('Starts: Tomorrow • Duration: 3 days'),
        findsOneWidget,
        reason:
            'BUG: "Starts: Tomorrow" is hardcoded — start date is never computed from a real event',
      );
    });

    testWidgets('renders "Today\'s Plan" section with Day 1, Day 2, Day 3',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text("Today's Plan"), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('Day 3'), findsOneWidget);
    });

    testWidgets('Day 1 calorie total is 705 (320 + 280 + 105 hardcoded)',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      // MockMeal day-1 sums: 320 + 280 + 105 = 705
      expect(find.text('705 calories'), findsOneWidget,
          reason:
              'BUG: Day 1 shows "705 calories" — hardcoded arithmetic, not real food log data');
    });

    testWidgets('Day 2 calorie total is 830 (450 + 240 + 140 hardcoded)',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('830 calories'), findsOneWidget,
          reason:
              'BUG: Day 2 shows "830 calories" — hardcoded arithmetic, not real food log data');
    });

    testWidgets('Day 3 calorie total is 800 (520 + 180 + 100 hardcoded)',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('800 calories'), findsOneWidget,
          reason:
              'BUG: Day 3 shows "800 calories" — hardcoded arithmetic, not real food log data');
    });

    testWidgets('Day 1 shows "Oatmeal with Berries" meal name', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Oatmeal with Berries'), findsOneWidget,
          reason: 'Day 1 mock meal "Oatmeal with Berries" must render');
    });

    testWidgets('Day 1 shows "Whole Wheat Toast" meal name', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Whole Wheat Toast'), findsOneWidget,
          reason: 'Day 1 mock meal "Whole Wheat Toast" must render');
    });

    testWidgets('Day 1 "Banana" meal renders with "2x" quantity tag',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Banana'), findsOneWidget,
          reason: 'Day 1 mock meal "Banana" must render');
      // MockMeal.quantity = 2 → quantity badge shows "2x"
      expect(find.text('2x'), findsWidgets,
          reason: 'Quantity badge "2x" must appear for Banana (quantity: 2)');
    });

    testWidgets('Day 2 shows "Grilled Chicken Sandwich"', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Grilled Chicken Sandwich'), findsOneWidget,
          reason: 'Day 2 mock meal "Grilled Chicken Sandwich" must render');
    });

    testWidgets('Day 3 shows "Pasta with Tomato Sauce"', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Pasta with Tomato Sauce'), findsOneWidget,
          reason: 'Day 3 mock meal "Pasta with Tomato Sauce" must render');
    });

    testWidgets('meal item subtitle shows "320 cal • 65g carbs" for Oatmeal',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      // MockMeal renders: "${calories} cal • ${carbs}g carbs"
      expect(find.text('320 cal • 65g carbs'), findsOneWidget,
          reason:
              'Oatmeal with Berries subtitle must render "320 cal • 65g carbs"');
    });

    testWidgets('renders "Protocol Options" section card', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Protocol Options'), findsOneWidget,
          reason: '"Protocol Options" card must render');
    });

    testWidgets('renders "Change Protocol" option', (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Change Protocol'), findsOneWidget,
          reason: '"Change Protocol" option must appear in Protocol Options card');
    });

    testWidgets('renders "Quick Add Foods" section with category chips',
        (tester) async {
      await pumpSeeded(tester, const CarbLoadingScreen(), settle: true);

      expect(find.text('Quick Add Foods'), findsOneWidget,
          reason: '"Quick Add Foods" section must render');
      expect(find.text('Grains'), findsOneWidget);
      expect(find.text('Fruits'), findsOneWidget);
      expect(find.text('Proteins'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Drinks'), findsOneWidget);
    });
  });
}
