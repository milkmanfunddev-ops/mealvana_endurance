import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/coach.dart';
import '../providers/coach_directory_controller.dart';

/// Coach Directory Screen - Athletes can browse and request coaches
class CoachDirectoryScreen extends ConsumerWidget {
  const CoachDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryAsync = ref.watch(coachDirectoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(coachDirectoryControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: directoryAsync.when(
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
                ref.read(coachDirectoryControllerProvider.notifier).refresh();
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
    CoachDirectoryState state,
    WidgetRef ref,
  ) {
    if (!state.hasCoaches) {
      return _buildEmptyView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(coachDirectoryControllerProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.coaches.length,
        itemBuilder: (context, index) {
          final coach = state.coaches[index];
          return _buildCoachCard(context, coach, state, ref);
        },
      ),
    );
  }

  Widget _buildCoachCard(
    BuildContext context,
    CoachInfo coach,
    CoachDirectoryState directoryState,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    // Get coach display name from CoachInfo
    String displayName;
    if (coach.displayName != null && coach.displayName!.isNotEmpty) {
      displayName = 'Coach ${coach.displayName}';
    } else {
      displayName = 'Coach ${coach.userId.substring(0, 8)}...';
    }

    return BaseCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Coach info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Endurance Coach',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Request button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: directoryState.isLoading
                  ? null
                  : () => _requestCoach(context, coach, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Request Coach'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Coaches Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'There are no coaches available at this time. Please check back later.',
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

  Future<void> _requestCoach(
    BuildContext context,
    CoachInfo coach,
    WidgetRef ref,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Coach'),
        content: const Text(
          'Send a connection request to this coach? They will be able to view your activities and provide feedback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send request
    final success = await ref
        .read(coachDirectoryControllerProvider.notifier)
        .requestCoach(coach.userId);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coach request sent! You will be notified when they respond.'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to My Coaches screen
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send coach request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
