import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_date_divider.dart';

import '../helpers/test_content.dart';

/// Plan §5 Phase 6.4 — "Today" / "Yesterday" / "Mon 1 Sep" between turns
/// that span days.
void main() {
  final content = TestContentService(
    ProviderContainer().read(_refProvider),
    loadDefaultContent(),
  );
  final now = DateTime(2026, 9, 3, 14, 30);

  test('crossesDay compares local calendar days', () {
    expect(
      VanaDateDivider.crossesDay(
        DateTime(2026, 9, 2, 23, 59),
        DateTime(2026, 9, 3, 0, 1),
      ),
      isTrue,
    );
    expect(
      VanaDateDivider.crossesDay(
        DateTime(2026, 9, 3, 8),
        DateTime(2026, 9, 3, 22),
      ),
      isFalse,
    );
  });

  test('labelFor: today / yesterday / short date', () {
    expect(
      VanaDateDivider.labelFor(content, DateTime(2026, 9, 3, 9), now),
      'Today',
    );
    expect(
      VanaDateDivider.labelFor(content, DateTime(2026, 9, 2, 23), now),
      'Yesterday',
    );
    expect(
      VanaDateDivider.labelFor(content, DateTime(2026, 8, 31, 12), now),
      'Mon 31 Aug',
    );
  });

  testWidgets('renders the label centred between two rules', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: VanaDateDivider(date: DateTime(2026, 9, 1), now: now),
          ),
        ),
      ),
    );
    expect(find.text('Tue 1 Sep'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });
}

final _refProvider = Provider<Ref>((ref) => ref);
