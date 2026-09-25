import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/vana_conversation.dart';

/// A meal-plan conversation's title (testing-wave 97, 16-006 / 18-007):
/// the week and state of the plan it holds — "Sep 20 week · Draft",
/// "Sep 13 week · Confirmed", "Sep 6 week · Archived" — or "No plan yet"
/// when it holds none, or only an empty draft. The conversations list and
/// the resumed chat's header both read it, so they never disagree.
String planConversationTitle(
  ContentService content,
  VanaConversationSummary conversation,
) => planTitle(
  content,
  weekStart: conversation.plan?.weekStart,
  status: conversation.plan?.status,
  mealCount: conversation.plan?.mealCount ?? 0,
);

/// The same title from a plan's own fields (the draft the chat holds is
/// fresher than the list's snapshot after a confirm in that chat).
String planTitle(
  ContentService content, {
  required String? weekStart,
  required MealPlanStatus? status,
  required int mealCount,
}) {
  if (weekStart == null || status == null || mealCount == 0) {
    return content.getValue(ContentKeys.mpConvPlanNone);
  }
  final start = DateTime.tryParse(weekStart);
  final week = start == null ? weekStart : DateFormat('MMM d').format(start);
  return ContentKeys.format(content.getValue(ContentKeys.mpConvPlanTitle), {
    'week': week,
    'state': planStateLabel(content, status),
  });
}

/// "Draft" / "Confirmed" / "Archived" — the state word the titles and the
/// Previous plans sheet's tag share.
String planStateLabel(ContentService content, MealPlanStatus status) =>
    content.getValue(switch (status) {
      MealPlanStatus.draft => ContentKeys.mpPlanStateDraft,
      MealPlanStatus.confirmed => ContentKeys.mpPlanStateConfirmed,
      MealPlanStatus.archived => ContentKeys.mpPlanStateArchived,
    });
