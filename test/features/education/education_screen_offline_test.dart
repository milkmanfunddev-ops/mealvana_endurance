// Finding 117-008 (ticket 141): Learn offline claimed "No videos available
// yet". A failed fetch with nothing cached now shows the offline state with
// Retry; the empty state stays for a good answer with nothing in it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/education/data/education_repository.dart';
import 'package:mealvana_endurance/features/education/domain/education_content.dart';
import 'package:mealvana_endurance/features/education/presentation/screens/education_screen.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _MockRepo extends Mock implements EducationRepository {}

final _content = loadDefaultContent();

EducationContent _lesson(String id) => EducationContent(
  id: id,
  title: 'Lesson $id',
  contentType: EducationContentType.free,
  sortOrder: 1,
  isPublished: true,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 2),
);

/// Learn over [repo], whose first answer is stubbed before the pump.
Future<void> pumpLearn(WidgetTester tester, _MockRepo repo) => smokeScreen(
  tester,
  const EducationScreen(),
  overrides: [
    educationRepositoryProvider.overrideWithValue(repo),
    contentServiceProvider.overrideWith(
      (ref) => TestContentService(ref, _content),
    ),
  ],
);

void main() {
  testWidgets('a failed fetch with no last answer shows the offline state '
      'with Retry, not "No videos available yet"', (tester) async {
    final repo = _MockRepo();
    when(() => repo.getPublishedContent()).thenAnswer(
      (_) async => throw const EducationUnavailableException('offline'),
    );
    await pumpLearn(tester, repo);

    expect(find.byKey(const ValueKey('learn.offline')), findsOneWidget);
    expect(find.text(_content['learn.offline_message']!), findsOneWidget);
    expect(find.byKey(const ValueKey('learn.retry')), findsOneWidget);
    expect(find.text('No videos available yet'), findsNothing);

    // Retry asks again; a good answer shows the lessons.
    when(
      () => repo.getPublishedContent(),
    ).thenAnswer((_) async => [_lesson('1')]);
    await tester.tap(find.byKey(const ValueKey('learn.retry')));
    await tester.pumpAndSettle();
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn.offline')), findsNothing);
  });

  testWidgets('a good answer with nothing in it keeps the empty state', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.getPublishedContent()).thenAnswer((_) async => []);
    await pumpLearn(tester, repo);

    expect(find.text('No videos available yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('learn.offline')), findsNothing);
  });
}
