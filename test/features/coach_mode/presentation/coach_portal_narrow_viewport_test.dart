// Sentry MEALVANA-ENDURANCE-DEV-5S (ticket 24a): "A RenderFlex overflowed by
// 23 pixels on the right" on the coach-portal route, iPhone 17 Pro simulator
// (402x874 logical, from the event's contexts.device). The portal is a
// desktop split layout: a 280-wide sidebar plus a panel. At phone width the
// panel got ~121 px and its athlete header Row (avatar + name + refresh
// button, portal_athlete_detail_panel.dart) overflowed by exactly 23 px; the
// tab views overflowed further (the 85 / 123 px events in the same issue).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/athlete_detail_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_portal_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../../../helpers/widget_test_harness.dart';

CoachAthleteRelationship _athlete(int i) {
  final at = DateTime(2026, 9, 26);
  return CoachAthleteRelationship(
    id: 'rel-$i',
    coachUserId: 'coach-u1',
    athleteUserId: 'athlete-u$i',
    status: RelationshipStatus.active,
    requestedBy: 'coach',
    requestedAt: at,
    acceptedAt: at,
    createdAt: at,
    updatedAt: at,
    coachDisplayName: 'Sarah Johnson',
    athleteDisplayName: 'Alex Rivera $i',
  );
}

class _FakeDashboard extends CoachDashboardController {
  @override
  FutureOr<CoachDashboardState> build() async => CoachDashboardState(
    activeAthletes: [for (var i = 0; i < 3; i++) _athlete(i)],
  );
}

class _FakeDetail extends AthleteDetailController {
  @override
  FutureOr<AthleteDetailState> build(String relationshipId) async =>
      AthleteDetailState(relationship: _athlete(0));
}

Future<void> _pumpPortal(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  addTearDown(db.close);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const CoachPortalScreen())],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        appDatabaseProvider.overrideWithValue(db),
        preferencesServiceProvider.overrideWith(
          (ref) => PreferencesService(prefs),
        ),
        currentUserProvider.overrideWith((ref) async => null),
        coachDashboardControllerProvider.overrideWith(_FakeDashboard.new),
        athleteDetailControllerProvider.overrideWith(_FakeDetail.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // Dashboard resolves, the first athlete is auto-selected post-frame, the
  // detail panel resolves.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('DEV-5S: the portal lays out without overflow at 402x874', (
    tester,
  ) async {
    await _pumpPortal(tester, const Size(402, 874));

    expect(find.text('Alex Rivera 0'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every panel tab fits at the minimum layout width', (
    tester,
  ) async {
    await _pumpPortal(
      tester,
      const Size(CoachPortalScreen.minLayoutWidth, 874),
    );
    expect(tester.takeException(), isNull);

    for (final label in [
      'Targets',
      'Events (',
      'Carb Loading',
      'Activities (',
      'Chat',
      'Profile',
    ]) {
      await tester.tap(find.textContaining(label).last);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: 'tab $label');
    }
  });
}
