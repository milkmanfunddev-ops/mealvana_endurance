import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/coach_athlete_relationship.dart';
import '../providers/coach_dashboard_controller.dart';
import '../widgets/athlete_card.dart';
import '../widgets/pending_request_card.dart';

/// Coach Dashboard Screen - main hub for coaches to manage athletes
class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(coachDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(coachDashboardControllerProvider.notifier).refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to coach settings
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString(), ref),
        data: (state) => _buildDashboard(context, state, ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to invite athlete screen
          _showInviteDialog(context);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Athlete'),
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
                ref.read(coachDashboardControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    CoachDashboardState state,
    WidgetRef ref,
  ) {
    if (!state.hasProfile) {
      return _buildNoProfileView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(coachDashboardControllerProvider.notifier).refresh();
      },
      child: CustomScrollView(
        slivers: [
          // Coach info header
          SliverToBoxAdapter(
            child: _buildCoachHeader(context, state),
          ),

          // Pending requests section
          if (state.hasPendingRequests) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                'Pending Requests',
                count: state.pendingRequests.length,
                icon: Icons.pending_actions,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final request = state.pendingRequests[index];
                  return PendingRequestCard(
                    relationship: request,
                    onAccept: () {
                      ref
                          .read(coachDashboardControllerProvider.notifier)
                          .acceptRequest(request.id);
                    },
                    onDecline: () {
                      ref
                          .read(coachDashboardControllerProvider.notifier)
                          .declineRequest(request.id);
                    },
                  );
                },
                childCount: state.pendingRequests.length,
              ),
            ),
          ],

          // Active athletes section
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              context,
              'My Athletes',
              count: state.athleteCount,
              icon: Icons.people,
            ),
          ),

          if (state.activeAthletes.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyAthletesView(context),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final athlete = state.activeAthletes[index];
                  return AthleteCard(
                    relationship: athlete,
                    onTap: () {
                      // TODO: Navigate to athlete detail
                    },
                    onArchive: () {
                      _showArchiveConfirmation(context, ref, athlete);
                    },
                  );
                },
                childCount: state.activeAthletes.length,
              ),
            ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachHeader(BuildContext context, CoachDashboardState state) {
    final coach = state.coach!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  coach.coachName.isNotEmpty
                      ? coach.coachName[0].toUpperCase()
                      : 'C',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.coachName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (coach.isVerified)
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified Coach',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                state.athleteCount.toString(),
                'Athletes',
                Icons.people,
              ),
              _buildStatItem(
                context,
                state.pendingRequests.length.toString(),
                'Pending',
                Icons.pending,
              ),
              _buildStatItem(
                context,
                '${coach.maxAthletes}',
                'Max',
                Icons.groups,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    int? count,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyAthletesView(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No athletes yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Invite Athlete" to connect with your first athlete',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Set Up Your Coach Profile',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create your coach profile to start connecting with athletes and helping them achieve their nutrition goals.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to coach profile setup
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Athlete'),
        content: const Text(
          'Athlete invitation feature coming soon!\n\n'
          'You will be able to invite athletes via email or share an invite link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(
    BuildContext context,
    WidgetRef ref,
    CoachAthleteRelationship relationship,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Athlete'),
        content: const Text(
          'Are you sure you want to archive this athlete relationship? '
          'You will no longer have access to their data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(coachDashboardControllerProvider.notifier)
                  .archiveAthlete(relationship.id);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}
