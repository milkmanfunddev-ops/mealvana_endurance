import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/coach_feedback.dart';
import '../providers/activity_coach_feedback_provider.dart';

/// Widget to display coach feedback for a specific activity
/// Can be embedded in the ActivityDetailScreen
class ActivityCoachFeedbackWidget extends ConsumerWidget {
  const ActivityCoachFeedbackWidget({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(activityCoachFeedbackProvider(activityId));

    return feedbackAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (feedback) {
        if (feedback.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildFeedbackSection(context, feedback);
      },
    );
  }

  Widget _buildFeedbackSection(BuildContext context, List<CoachFeedback> feedback) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.comment,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Coach Feedback',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${feedback.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Feedback cards
          ...feedback.map((f) => _buildFeedbackCard(context, f)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, CoachFeedback feedback) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coach Feedback',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatDate(feedback.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feedback.feedbackText,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
