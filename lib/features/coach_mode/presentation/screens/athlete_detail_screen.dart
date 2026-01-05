import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_feedback.dart';
import '../providers/athlete_detail_controller.dart';

/// Screen showing detailed view of an athlete for coaches
class AthleteDetailScreen extends ConsumerWidget {
  final String relationshipId;

  const AthleteDetailScreen({
    super.key,
    required this.relationshipId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      athleteDetailControllerProvider(relationshipId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(athleteDetailControllerProvider(relationshipId).notifier)
                  .refresh();
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString(), ref),
        data: (state) => _buildContent(context, state, ref),
      ),
      floatingActionButton: detailAsync.value?.canAddFeedback == true
          ? FloatingActionButton.extended(
              onPressed: () => _showAddFeedbackDialog(context, ref),
              icon: const Icon(Icons.add_comment),
              label: const Text('Add Feedback'),
            )
          : null,
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
                ref
                    .read(athleteDetailControllerProvider(relationshipId).notifier)
                    .refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AthleteDetailState state,
    WidgetRef ref,
  ) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Athlete header
          _buildAthleteHeader(context, state),

          // Tab bar
          TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.directions_run),
                text: 'Activities (${state.activities.length})',
              ),
              Tab(
                icon: const Icon(Icons.restaurant),
                text: 'Nutrition',
              ),
              Tab(
                icon: const Icon(Icons.comment),
                text: 'Feedback (${state.feedback.length})',
              ),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                _buildActivitiesTab(context, state),
                _buildNutritionTab(context, state),
                _buildFeedbackTab(context, state, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteHeader(BuildContext context, AthleteDetailState state) {
    final theme = Theme.of(context);
    final relationship = state.relationship;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Athlete ${relationship.athleteUserId.substring(0, 8)}...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusChip(context, relationship.status),
                    const SizedBox(width: 8),
                    _buildPermissionChip(context, relationship.permissionLevel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, RelationshipStatus status) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      RelationshipStatus.active => ('Active', Colors.green),
      RelationshipStatus.pending => ('Pending', Colors.orange),
      RelationshipStatus.declined => ('Declined', Colors.red),
      RelationshipStatus.archived => ('Archived', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPermissionChip(BuildContext context, PermissionLevel level) {
    final theme = Theme.of(context);
    final label = switch (level) {
      PermissionLevel.viewOnly => 'View Only',
      PermissionLevel.fullAccess => 'Full Access',
      PermissionLevel.custom => 'Custom',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildActivitiesTab(BuildContext context, AthleteDetailState state) {
    if (!state.canViewActivities) {
      return _buildNoPermissionView(
        context,
        'Activities',
        Icons.directions_run,
      );
    }

    if (state.activities.isEmpty) {
      return _buildEmptyView(
        context,
        'No Activities',
        'This athlete has no activities yet.',
        Icons.directions_run,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.activities.length,
      itemBuilder: (context, index) {
        final activity = state.activities[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.directions_run),
            title: Text(activity.title),
            subtitle: Text(
              '${activity.distanceMiles?.toStringAsFixed(1) ?? "-"} mi - ${_formatDate(activity.scheduledDateTime)}',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _buildNutritionTab(BuildContext context, AthleteDetailState state) {
    if (!state.canViewNutritionPlans) {
      return _buildNoPermissionView(
        context,
        'Nutrition Plans',
        Icons.restaurant,
      );
    }

    return _buildEmptyView(
      context,
      'No Nutrition Plans',
      'Nutrition plan viewing coming soon.',
      Icons.restaurant,
    );
  }

  Widget _buildFeedbackTab(
    BuildContext context,
    AthleteDetailState state,
    WidgetRef ref,
  ) {
    if (state.feedback.isEmpty) {
      return _buildEmptyView(
        context,
        'No Feedback',
        'Tap the button below to add your first feedback.',
        Icons.comment,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.feedback.length,
      itemBuilder: (context, index) {
        final feedback = state.feedback[index];
        return _buildFeedbackCard(context, feedback, ref);
      },
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context,
    CoachFeedback feedback,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFeedbackTypeBadge(context, feedback.feedbackType),
                const Spacer(),
                Text(
                  _formatDate(feedback.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDeleteFeedback(context, ref, feedback);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feedback.feedbackText,
              style: theme.textTheme.bodyMedium,
            ),
            if (!feedback.isVisibleToAthlete) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Private note',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTypeBadge(BuildContext context, FeedbackType type) {
    final theme = Theme.of(context);
    final (label, icon) = switch (type) {
      FeedbackType.general => ('General', Icons.chat),
      FeedbackType.activity => ('Activity', Icons.directions_run),
      FeedbackType.nutrition => ('Nutrition', Icons.restaurant),
      FeedbackType.progress => ('Progress', Icons.trending_up),
      FeedbackType.goal => ('Goal', Icons.flag),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPermissionView(
    BuildContext context,
    String feature,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No Access to $feature',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have permission to view this athlete\'s $feature.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFeedbackDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    FeedbackType selectedType = FeedbackType.general;
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<FeedbackType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Feedback Type',
                    border: OutlineInputBorder(),
                  ),
                  items: FeedbackType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name[0].toUpperCase() + type.name.substring(1)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                    hintText: 'Enter your feedback for the athlete...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Private Note'),
                  subtitle: const Text('Only visible to you'),
                  value: isPrivate,
                  onChanged: (value) {
                    setState(() => isPrivate = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  ref
                      .read(athleteDetailControllerProvider(relationshipId).notifier)
                      .addFeedback(
                        feedbackText: textController.text.trim(),
                        feedbackType: selectedType,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFeedback(
    BuildContext context,
    WidgetRef ref,
    CoachFeedback feedback,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text('Are you sure you want to delete this feedback?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(athleteDetailControllerProvider(relationshipId).notifier)
                  .deleteFeedback(feedback.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
