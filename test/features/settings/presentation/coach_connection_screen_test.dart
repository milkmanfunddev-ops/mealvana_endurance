/// Coach Connection with a paired coach (Lee, 2026-09-26; 122-003): the
/// status line reads "Paired with `<coach>`", from the content system, or the
/// line without a name when the coach has none on record.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/coach_connection_screen.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';

class _MockCoachRepository extends Mock implements CoachRepository {}

final _content = loadDefaultContent();
const _paired = ValueKey('coach_connection.paired');

void main() {
  late _MockCoachRepository repo;

  setUp(() => repo = _MockCoachRepository());

  List<Override> overrides() => [
    contentServiceProvider.overrideWith(
      (ref) => TestContentService(ref, _content),
    ),
    userIdProvider.overrideWith((ref) async => 'athlete-1'),
    coachRepositoryProvider.overrideWithValue(repo),
  ];

  testWidgets('a paired coach reads "Paired with <coach>"', (tester) async {
    when(() => repo.getMyCoach('athlete-1')).thenAnswer(
      (_) async => (
        relationshipId: 'rel-1',
        coachUserId: 'coach-9',
        coachName: 'Kyle Coach',
      ),
    );
    await smokeScreen(
      tester,
      const CoachConnectionScreen(),
      overrides: overrides(),
    );

    expect(
      tester.widget<Text>(find.byKey(_paired)).data,
      'Paired with Kyle Coach',
    );
    expect(_content['coach_connection.paired_with'], 'Paired with {coach}');
    expect(find.textContaining('Connected to'), findsNothing);
  });

  testWidgets('a coach with no name on record reads the line without one', (
    tester,
  ) async {
    when(() => repo.getMyCoach('athlete-1')).thenAnswer(
      (_) async => (
        relationshipId: 'rel-1',
        coachUserId: 'coach-9',
        coachName: null,
      ),
    );
    await smokeScreen(
      tester,
      const CoachConnectionScreen(),
      overrides: overrides(),
    );

    expect(
      tester.widget<Text>(find.byKey(_paired)).data,
      _content['coach_connection.paired'],
    );
  });

  testWidgets('no pairing shows the code entry, not the paired line', (
    tester,
  ) async {
    when(() => repo.getMyCoach('athlete-1')).thenAnswer((_) async => null);
    await smokeScreen(
      tester,
      const CoachConnectionScreen(),
      overrides: overrides(),
    );

    expect(find.byKey(_paired), findsNothing);
  });
}
