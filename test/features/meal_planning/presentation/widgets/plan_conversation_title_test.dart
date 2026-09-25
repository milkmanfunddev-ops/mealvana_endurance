import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_conversation_title.dart';

import '../helpers/test_content.dart';

/// Ticket 97 (16-006, 18-007): a meal-plan conversation is titled by its
/// week and the state of the plan it holds, so the list tells them apart.
void main() {
  late ContentService content;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [contentServiceProvider.overrideWith(testContentService)],
    );
    content = container.read(contentServiceProvider);
  });

  tearDown(() => container.dispose());

  VanaConversationSummary row(Map<String, dynamic>? plan) =>
      VanaConversationSummary.fromJson({
        'id': 'conv-1',
        'kind': 'meal_planning',
        'title': "This week's plan",
        'createdAt': '2026-09-20T08:00:00Z',
        'plan': plan,
      });

  test('a draft with meals is "<week> week · Draft"', () {
    final r = row({
      'weekStart': '2026-09-20',
      'status': 'draft',
      'mealCount': 2,
    });
    expect(planConversationTitle(content, r), 'Sep 20 week · Draft');
  });

  test('a confirmed plan is "<week> week · Confirmed"', () {
    final r = row({
      'weekStart': '2026-09-13',
      'status': 'confirmed',
      'mealCount': 4,
    });
    expect(planConversationTitle(content, r), 'Sep 13 week · Confirmed');
  });

  test('a plan a later one replaced is "<week> week · Archived"', () {
    final r = row({
      'weekStart': '2026-09-06',
      'status': 'archived',
      'mealCount': 1,
    });
    expect(planConversationTitle(content, r), 'Sep 6 week · Archived');
  });

  test('no plan, or an empty draft, is "No plan yet"', () {
    expect(planConversationTitle(content, row(null)), 'No plan yet');
    final empty = row({
      'weekStart': '2026-09-13',
      'status': 'draft',
      'mealCount': 0,
    });
    expect(planConversationTitle(content, empty), 'No plan yet');
  });

  test('the same title from a plan the chat holds', () {
    expect(
      planTitle(
        content,
        weekStart: '2026-09-20',
        status: MealPlanStatus.confirmed,
        mealCount: 3,
      ),
      'Sep 20 week · Confirmed',
    );
  });

  test('the plan survives the wire round trip', () {
    final r = row({
      'weekStart': '2026-09-20',
      'status': 'draft',
      'mealCount': 2,
    });
    final again = VanaConversationSummary.fromJson(r.toJson());
    expect(again.plan?.weekStart, '2026-09-20');
    expect(again.plan?.status, MealPlanStatus.draft);
    expect(again.plan?.mealCount, 2);
    expect(VanaConversationSummary.fromJson(row(null).toJson()).plan, isNull);
  });
}
