import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach_feedback.dart';

part 'activity_coach_feedback_provider.g.dart';

/// Provider that loads coach feedback for a specific activity
/// Used to show feedback on the ActivityDetailScreen
@riverpod
Future<List<CoachFeedback>> activityCoachFeedback(
  Ref ref,
  String activityId,
) async {
  final coachService = ref.read(coachServiceProvider);

  // Get all coach relationships for this athlete
  final coaches = await coachService.getMyCoaches();

  if (coaches.isEmpty) {
    return [];
  }

  // Collect all feedback for this activity from all coaches
  final activityFeedback = <CoachFeedback>[];

  for (final relationship in coaches) {
    final feedback = await coachService.getFeedbackForRelationship(
      relationship.id,
    );

    // Filter to only feedback for this activity that's visible to athlete
    final relevant = feedback.where(
      (f) => f.activityId == activityId && f.isVisibleToAthlete,
    );
    activityFeedback.addAll(relevant);
  }

  // Sort by date (newest first)
  activityFeedback.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return activityFeedback;
}
