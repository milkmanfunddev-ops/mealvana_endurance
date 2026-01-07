import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_message.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendMessageDialog(context, ref),
        icon: const Icon(Icons.add_comment),
        label: const Text('Send Message'),
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
              const Tab(
                icon: Icon(Icons.restaurant),
                text: 'Nutrition',
              ),
              Tab(
                icon: const Icon(Icons.comment),
                text: 'Messages (${state.messages.length})',
              ),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                _buildActivitiesTab(context, state),
                _buildNutritionTab(context, state),
                _buildMessagesTab(context, state, ref),
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
                  relationship.athleteDisplayName ??
                      'Athlete ${relationship.athleteUserId.substring(0, 8)}...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusChip(context, relationship.status),
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

  Widget _buildActivitiesTab(BuildContext context, AthleteDetailState state) {
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
    return _buildEmptyView(
      context,
      'No Nutrition Plans',
      'Nutrition plan viewing coming soon.',
      Icons.restaurant,
    );
  }

  Widget _buildMessagesTab(
    BuildContext context,
    AthleteDetailState state,
    WidgetRef ref,
  ) {
    if (state.messages.isEmpty) {
      return _buildEmptyView(
        context,
        'No Messages',
        'Tap the button below to send your first message.',
        Icons.comment,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _buildMessageCard(context, message, ref);
      },
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    CoachMessage message,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final isFromCoach = message.isSentByCoach;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isFromCoach
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isFromCoach
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: isFromCoach
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isFromCoach ? 'You' : 'Athlete',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (message.isActivityComment || message.isNutritionPlanComment)
                  _buildMessageTypeBadge(context, message),
                const SizedBox(width: 8),
                Text(
                  _formatDate(message.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // Only show delete option for messages sent by coach
                if (isFromCoach)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeleteMessage(context, ref, message);
                      }
                    },
                    itemBuilder: (context) => [
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
              message.messageText,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypeBadge(BuildContext context, CoachMessage message) {
    final theme = Theme.of(context);

    final (label, icon, color) = message.isActivityComment
        ? ('Activity', Icons.directions_run, Colors.green)
        : ('Nutrition', Icons.restaurant, Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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

  void _showSendMessageDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter your message for the athlete...',
                  border: OutlineInputBorder(),
                ),
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
                    .sendMessage(
                      messageText: textController.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(
    BuildContext context,
    WidgetRef ref,
    CoachMessage message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
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
                  .deleteMessage(message.id);
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
