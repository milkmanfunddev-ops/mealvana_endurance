import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach_message.dart';

part 'activity_coach_feedback_provider.g.dart';

/// Provider that loads coach messages/comments for a specific activity
/// Used to show feedback on the ActivityDetailScreen
@riverpod
Future<List<CoachMessage>> activityCoachFeedback(
  Ref ref,
  String activityId,
) async {
  final coachService = ref.read(coachServiceProvider);

  // Get activity comments directly using the new simplified messaging
  final comments = await coachService.getActivityComments(activityId);

  // Sort by date (newest first for display, oldest first for reading)
  comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return comments;
}
