import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/coach_feedback.dart';
import '../providers/athlete_feedback_controller.dart';

/// Screen for athletes to view feedback from their coaches
class AthleteFeedbackScreen extends ConsumerWidget {
  const AthleteFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(athleteFeedbackControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Feedback'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(athleteFeedbackControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString(), ref),
        data: (state) => _buildContent(context, state),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(athleteFeedbackControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AthleteFeedbackState state) {
    if (state.isEmpty) {
      return _buildEmptyView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Can't use async refresh directly, just trigger invalidation
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.allFeedback.length,
        itemBuilder: (context, index) {
          final feedback = state.allFeedback[index];
          return _buildFeedbackCard(context, feedback, state.getCoachName(feedback.coachId));
        },
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Feedback Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'When your coach leaves feedback on your activities, it will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context,
    CoachFeedback feedback,
    String coachName,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with coach name and date
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coachName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(feedback.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFeedbackTypeBadge(context, feedback.feedbackType),
              ],
            ),

            const SizedBox(height: 12),

            // Feedback text
            Text(
              feedback.feedbackText,
              style: theme.textTheme.bodyMedium,
            ),

            // Activity link if applicable
            if (feedback.isLinkedToActivity) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_run,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View Activity',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTypeBadge(BuildContext context, FeedbackType type) {
    final theme = Theme.of(context);
    final (label, icon, color) = switch (type) {
      FeedbackType.general => ('General', Icons.chat_bubble_outline, theme.colorScheme.primary),
      FeedbackType.activity => ('Activity', Icons.directions_run, Colors.green),
      FeedbackType.nutrition => ('Nutrition', Icons.restaurant, Colors.orange),
      FeedbackType.progress => ('Progress', Icons.trending_up, Colors.blue),
      FeedbackType.goal => ('Goal', Icons.flag, Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
