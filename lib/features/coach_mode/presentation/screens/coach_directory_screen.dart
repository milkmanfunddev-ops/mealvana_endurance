import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/coach.dart';
import '../providers/coach_directory_controller.dart';

/// Screen for athletes to browse and connect with coaches
class CoachDirectoryScreen extends ConsumerStatefulWidget {
  const CoachDirectoryScreen({super.key});

  @override
  ConsumerState<CoachDirectoryScreen> createState() =>
      _CoachDirectoryScreenState();
}

class _CoachDirectoryScreenState extends ConsumerState<CoachDirectoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(coachDirectoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Coach'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: directoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString()),
        data: (state) => _buildContent(context, state),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
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

  Widget _buildContent(BuildContext context, CoachDirectoryState state) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search coaches...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(coachDirectoryControllerProvider.notifier)
                            .search('');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              ref
                  .read(coachDirectoryControllerProvider.notifier)
                  .search(value);
            },
          ),
        ),

        // Specialization filters
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                context,
                label: 'All',
                isSelected: state.selectedSpecialization == null,
                onSelected: () {
                  ref
                      .read(coachDirectoryControllerProvider.notifier)
                      .filterBySpecialization(null);
                },
              ),
              const SizedBox(width: 8),
              ...CoachSpecialization.values.map((spec) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    context,
                    label: _getSpecializationLabel(spec),
                    isSelected: state.selectedSpecialization == spec,
                    onSelected: () {
                      ref
                          .read(coachDirectoryControllerProvider.notifier)
                          .filterBySpecialization(spec);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${state.filteredCoaches.length} coach${state.filteredCoaches.length == 1 ? '' : 'es'} found',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Coach list
        Expanded(
          child: state.filteredCoaches.isEmpty
              ? _buildEmptyView(context, state)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.filteredCoaches.length,
                  itemBuilder: (context, index) {
                    final coach = state.filteredCoaches[index];
                    return _buildCoachCard(context, coach, state);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildEmptyView(BuildContext context, CoachDirectoryState state) {
    final theme = Theme.of(context);
    final hasFilters = state.searchQuery?.isNotEmpty == true ||
        state.selectedSpecialization != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.person_search,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No coaches match your search' : 'No coaches available',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Check back later for available coaches',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  ref
                      .read(coachDirectoryControllerProvider.notifier)
                      .search('');
                  ref
                      .read(coachDirectoryControllerProvider.notifier)
                      .filterBySpecialization(null);
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoachCard(
    BuildContext context,
    Coach coach,
    CoachDirectoryState state,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    coach.coachName.isNotEmpty
                        ? coach.coachName[0].toUpperCase()
                        : 'C',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              coach.coachName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (coach.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      if (coach.businessName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          coach.businessName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (coach.bio != null && coach.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                coach.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            if (coach.specializationsTyped.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: coach.specializationsTyped.map((spec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getSpecializationLabel(spec),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _showCoachDetails(context, coach);
                  },
                  child: const Text('View Profile'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.isLoading
                      ? null
                      : () => _requestCoach(context, coach),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCoachDetails(BuildContext context, Coach coach) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Coach header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      coach.coachName.isNotEmpty
                          ? coach.coachName[0].toUpperCase()
                          : 'C',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                coach.coachName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (coach.isVerified) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.verified,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        if (coach.businessName != null)
                          Text(
                            coach.businessName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              if (coach.bio != null && coach.bio!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('About', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(coach.bio!, style: theme.textTheme.bodyMedium),
              ],

              if (coach.specializationsTyped.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Specializations', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coach.specializationsTyped.map((spec) {
                    return Chip(
                      avatar: Icon(_getSpecializationIcon(spec), size: 18),
                      label: Text(_getSpecializationLabel(spec)),
                    );
                  }).toList(),
                ),
              ],

              if (coach.certifications.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Certifications', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...coach.certifications.map((cert) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(cert),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _requestCoach(context, coach);
                  },
                  child: const Text('Request to Connect'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestCoach(BuildContext context, Coach coach) async {
    final success = await ref
        .read(coachDirectoryControllerProvider.notifier)
        .requestCoach(coach.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to ${coach.coachName}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getSpecializationLabel(CoachSpecialization spec) {
    return switch (spec) {
      CoachSpecialization.running => 'Running',
      CoachSpecialization.cycling => 'Cycling',
      CoachSpecialization.swimming => 'Swimming',
      CoachSpecialization.triathlon => 'Triathlon',
      CoachSpecialization.nutrition => 'Nutrition',
      CoachSpecialization.strengthAndConditioning => 'Strength',
      CoachSpecialization.mentalPerformance => 'Mental',
    };
  }

  IconData _getSpecializationIcon(CoachSpecialization spec) {
    return switch (spec) {
      CoachSpecialization.running => Icons.directions_run,
      CoachSpecialization.cycling => Icons.directions_bike,
      CoachSpecialization.swimming => Icons.pool,
      CoachSpecialization.triathlon => Icons.emoji_events,
      CoachSpecialization.nutrition => Icons.restaurant,
      CoachSpecialization.strengthAndConditioning => Icons.fitness_center,
      CoachSpecialization.mentalPerformance => Icons.psychology,
    };
  }
}
