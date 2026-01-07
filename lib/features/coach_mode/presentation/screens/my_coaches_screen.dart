import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/coach_athlete_relationship.dart';
import '../providers/my_coaches_controller.dart';

/// Screen for athletes to view and manage their coach connections
class MyCoachesScreen extends ConsumerWidget {
  const MyCoachesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(myCoachesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Coaches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: 'View messages',
            onPressed: () {
              context.push('/athlete/feedback');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(myCoachesControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: coachesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString(), ref),
        data: (state) => _buildContent(context, state, ref),
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
                ref.read(myCoachesControllerProvider.notifier).refresh();
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
    MyCoachesState state,
    WidgetRef ref,
  ) {
    if (!state.hasCoaches && !state.hasPendingRequests) {
      return _buildEmptyView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(myCoachesControllerProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending requests section
          if (state.hasPendingRequests) ...[
            _buildSectionHeader(
              context,
              'Pending Requests',
              Icons.pending_actions,
            ),
            ...state.pendingRequests.map(
              (request) => _buildPendingRequestCard(context, request, ref),
            ),
            const SizedBox(height: 24),
          ],

          // Active coaches section
          _buildSectionHeader(
            context,
            'Active Coaches',
            Icons.verified_user,
          ),
          if (state.activeCoaches.isEmpty)
            _buildNoCoachesCard(context)
          else
            ...state.activeCoaches.map(
              (coach) => _buildCoachCard(context, coach),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(
    BuildContext context,
    CoachAthleteRelationship request,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coach Request',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        request.coachDisplayName ??
                            'Coach ${request.coachUserId.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(myCoachesControllerProvider.notifier)
                        .declineRequest(request.id);
                  },
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(myCoachesControllerProvider.notifier)
                        .acceptRequest(request.id);
                  },
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachCard(
    BuildContext context,
    CoachAthleteRelationship relationship,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          relationship.coachDisplayName ??
              'Coach ${relationship.coachUserId.substring(0, 8)}...',
        ),
        subtitle: Row(
          children: [
            _buildStatusBadge(context, relationship.status),
            const SizedBox(width: 8),
            Text(
              'Connected ${_formatDate(relationship.acceptedAt ?? relationship.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to messages with this coach
          context.push('/athlete/feedback');
        },
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, RelationshipStatus status) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      RelationshipStatus.active => ('Active', Colors.green),
      RelationshipStatus.pending => ('Pending', Colors.orange),
      RelationshipStatus.declined => ('Declined', Colors.red),
      RelationshipStatus.archived => ('Archived', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
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

  Widget _buildNoCoachesCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No coaches connected',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your coach to send you a connection request.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
              Icons.sports,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect with a Coach',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share your training and nutrition data with a coach to get personalized guidance and feedback.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ask your coach to invite you to connect.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 30) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? "s" : ""} ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return '$years year${years > 1 ? "s" : ""} ago';
    }
  }
}
