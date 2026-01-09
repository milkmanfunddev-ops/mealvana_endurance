import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/coach_athlete_relationship.dart';
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
          // Chat button - opens dedicated chat screen
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Open Chat',
            onPressed: () {
              context.push('/chat/$relationshipId');
            },
          ),
          // Refresh button - syncs athlete data from Supabase
          IconButton(
            icon: detailAsync.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh athlete data',
            onPressed: detailAsync.isLoading
                ? null
                : () {
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
      floatingActionButton: detailAsync.maybeWhen(
        data: (state) => _buildCreateWorkoutFab(context, state),
        orElse: () => null,
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
      length: 4,
      child: Column(
        children: [
          // Athlete header
          _buildAthleteHeader(context, state),

          // Tab bar
          TabBar(
            tabs: [
              const Tab(
                icon: Icon(Icons.person),
                text: 'Profile',
              ),
              Tab(
                icon: const Icon(Icons.calendar_today),
                text: 'Events (${state.events.length})',
              ),
              Tab(
                icon: const Icon(Icons.restaurant),
                text: 'Carb Loading',
              ),
              Tab(
                icon: const Icon(Icons.directions_run),
                text: 'Activities (${state.activities.length})',
              ),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                _buildProfileTab(context, state),
                _buildEventsTab(context, state),
                _buildCarbLoadingTab(context, state),
                _buildActivitiesTab(context, state),
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
    final athleteProfile = state.athleteProfile;

    // Use profile first/last name if available, fallback to relationship display name
    String athleteName;
    if (athleteProfile != null) {
      athleteName = athleteProfile.displayName;
    } else {
      athleteName = relationship.athleteDisplayName ??
          'Athlete ${relationship.athleteUserId.substring(0, 8)}...';
    }

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
                  athleteName,
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

  Widget _buildProfileTab(BuildContext context, AthleteDetailState state) {
    final theme = Theme.of(context);
    final profile = state.athleteProfile;

    if (profile == null) {
      return _buildEmptyView(
        context,
        'No Profile Data',
        'Profile information is not available yet. Try refreshing.',
        Icons.person_off,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Personal Information
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildProfileRow('Name', profile.displayName),
                if (profile.firstName != null)
                  _buildProfileRow('First Name', profile.firstName!),
                if (profile.lastName != null)
                  _buildProfileRow('Last Name', profile.lastName!),
                _buildProfileRow('Gender', profile.gender.name.toUpperCase()),
                _buildProfileRow('Birthday', _formatDate(profile.birthday)),
                _buildProfileRow(
                  'Height',
                  '${profile.heightFeet}\'${profile.heightInches}"',
                ),
                _buildProfileRow(
                  'Weight',
                  '${profile.weightPounds.toStringAsFixed(1)} lbs',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Training Preferences
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Training Preferences',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildProfileRow(
                  'Runs with Water Bottle',
                  profile.runsWithWaterBottle ? 'Yes' : 'No',
                ),
                _buildProfileRow(
                  'Gut Training Level',
                  profile.gutTraining.name.toUpperCase(),
                ),
                if (profile.giSensitivity != null)
                  _buildProfileRow(
                    'GI Sensitivity',
                    profile.giSensitivity! ? 'Yes' : 'No',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cycling Details (if available)
        if (profile.ftpWatts != null ||
            profile.typicalBikeBottles != null ||
            profile.hasAeroBottle != null ||
            profile.hasBentoBox != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_bike,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Cycling Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (profile.ftpWatts != null)
                    _buildProfileRow('FTP', '${profile.ftpWatts} watts'),
                  if (profile.typicalBikeBottles != null)
                    _buildProfileRow(
                      'Bike Bottles',
                      '${profile.typicalBikeBottles}',
                    ),
                  if (profile.hasAeroBottle != null)
                    _buildProfileRow(
                      'Has Aero Bottle',
                      profile.hasAeroBottle! ? 'Yes' : 'No',
                    ),
                  if (profile.hasBentoBox != null)
                    _buildProfileRow(
                      'Has Bento Box',
                      profile.hasBentoBox! ? 'Yes' : 'No',
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Swimming Details (if available)
        if (profile.cssPacePer100mSeconds != null ||
            profile.typicalWetsuit != null ||
            profile.typicalSwimCapType != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pool, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Swimming Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (profile.cssPacePer100mSeconds != null)
                    _buildProfileRow(
                      'CSS Pace',
                      '${profile.cssPacePer100mSeconds}s per 100m',
                    ),
                  if (profile.typicalWetsuit != null)
                    _buildProfileRow(
                      'Typical Wetsuit',
                      profile.typicalWetsuit! ? 'Yes' : 'No',
                    ),
                  if (profile.typicalSwimCapType != null)
                    _buildProfileRow(
                      'Swim Cap Type',
                      profile.typicalSwimCapType!,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
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
            onTap: () {
              context.push('/plan', extra: {
                'activityId': activity.id,
                'isCoachView': true,
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildEventsTab(BuildContext context, AthleteDetailState state) {
    if (state.events.isEmpty) {
      return _buildEmptyView(
        context,
        'No Events',
        'This athlete has no upcoming events.',
        Icons.calendar_today,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.events.length,
      itemBuilder: (context, index) {
        final event = state.events[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(event.eventName ?? 'Unnamed Event'),
            subtitle: Text(
              event.eventDate != null 
                ? _formatDate(event.eventDate!)
                : 'No Date',
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarbLoadingTab(BuildContext context, AthleteDetailState state) {
    if (state.carbLoadingPlans.isEmpty) {
      return _buildEmptyView(
        context,
        'No Carb Loading Plans',
        'This athlete has no active carb loading plans.',
        Icons.restaurant,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.carbLoadingPlans.length,
      itemBuilder: (context, index) {
        final plan = state.carbLoadingPlans[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: Text('${plan.raceDistance.displayName} - ${_formatDate(plan.raceDate)}'),
            subtitle: Text(
              '${plan.dailyCarbTargetG}g carbs/day • ${plan.dailyServingsTarget} servings',
            ),
            trailing: Icon(
              plan.isActive ? Icons.check_circle : Icons.pause_circle,
              color: plan.isActive ? Colors.green : Colors.grey,
            ),
            onTap: () {
              // TODO: Navigate to plan details
            },
          ),
        );
      },
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCreateWorkoutFab(BuildContext context, AthleteDetailState state) {
    return FloatingActionButton(
      onPressed: () => _showCreateWorkoutMenu(context, state),
      tooltip: 'Create Workout',
      child: const Icon(Icons.add),
    );
  }

  void _showCreateWorkoutMenu(BuildContext context, AthleteDetailState state) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Create Workout for Athlete',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Create Activity'),
              subtitle: const Text('Create a training activity'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/distancepacegut', extra: {
                  'forUserId': state.relationship.athleteUserId,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Create Event'),
              subtitle: const Text('Create a race or event'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/events/create', extra: {
                  'forUserId': state.relationship.athleteUserId,
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
