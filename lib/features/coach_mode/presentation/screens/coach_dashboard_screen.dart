import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/coach_athlete_relationship.dart';
import '../providers/coach_dashboard_controller.dart';
import '../widgets/athlete_card.dart';

/// Coach Dashboard Screen - main hub for coaches to manage athletes
class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  /// External Notion form URL for coach registration
  static const String _coachRegistrationUrl =
      'https://mealvana.notion.site/Coach-Registration-Form';

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
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            _buildErrorView(context, error.toString(), ref),
        data: (state) => _buildDashboard(context, state, ref),
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
    if (!state.isCoach) {
      return _buildNotCoachView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(coachDashboardControllerProvider.notifier).refresh();
      },
      child: CustomScrollView(
        slivers: [
          // Stats header
          SliverToBoxAdapter(child: _buildStatsHeader(context, state)),

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
            SliverToBoxAdapter(child: _buildEmptyAthletesView(context))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final athlete = state.activeAthletes[index];
                return AthleteCard(
                  relationship: athlete,
                  onTap: () {
                    context.push('/coach/athlete/${athlete.id}');
                  },
                  onMessage: () {
                    context.push('/chat/${athlete.id}');
                  },
                  onArchive: () {
                    _showArchiveConfirmation(context, ref, athlete);
                  },
                );
              }, childCount: state.activeAthletes.length),
            ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, CoachDashboardState state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.tertiary.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            state.athleteCount.toString(),
            'Athletes',
            Icons.people,
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
        Text(label, style: theme.textTheme.bodySmall),
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
          Text('No athletes yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Athletes can request to connect with you from the Coach Directory',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotCoachView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Become a Coach',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You are not currently registered as a coach. Apply to become a certified Mealvana coach and help athletes optimize their nutrition.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(_coachRegistrationUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apply to Be a Coach'),
            ),
          ],
        ),
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
