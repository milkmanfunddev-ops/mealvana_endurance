import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/coach.dart';
import '../providers/coach_profile_setup_controller.dart';

/// Screen for setting up or editing coach profile
class CoachProfileSetupScreen extends ConsumerStatefulWidget {
  const CoachProfileSetupScreen({super.key});

  @override
  ConsumerState<CoachProfileSetupScreen> createState() =>
      _CoachProfileSetupScreenState();
}

class _CoachProfileSetupScreenState
    extends ConsumerState<CoachProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  final Set<CoachSpecialization> _selectedSpecializations = {};

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(coachProfileSetupControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Profile Setup'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: setupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString()),
        data: (state) {
          // Pre-populate form if editing existing profile
          if (state.existingProfile != null && _displayNameController.text.isEmpty) {
            _displayNameController.text = state.existingProfile!.displayName;
            _bioController.text = state.existingProfile!.bio ?? '';
            _selectedSpecializations.addAll(state.existingProfile!.specializationsTyped);
          }
          return _buildForm(context, state);
        },
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
                ref.invalidate(coachProfileSetupControllerProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, CoachProfileSetupState state) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            state.existingProfile != null
                ? 'Edit Your Coach Profile'
                : 'Set Up Your Coach Profile',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a profile to connect with athletes and share your expertise.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Display Name
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'How athletes will see you',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a display name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Bio
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Bio (optional)',
              hintText: 'Tell athletes about your coaching experience...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // Specializations
          Text(
            'Specializations',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select areas you specialize in (optional)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CoachSpecialization.values.map((spec) {
              final isSelected = _selectedSpecializations.contains(spec);
              return FilterChip(
                label: Text(_getSpecializationLabel(spec)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSpecializations.add(spec);
                    } else {
                      _selectedSpecializations.remove(spec);
                    }
                  });
                },
                avatar: Icon(
                  _getSpecializationIcon(spec),
                  size: 18,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Error message
          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit Button
          FilledButton(
            onPressed: state.isSubmitting ? null : _submit,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    state.existingProfile != null
                        ? 'Update Profile'
                        : 'Create Profile',
                  ),
          ),
          const SizedBox(height: 16),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Once your profile is created, athletes can connect with you. You\'ll be able to view their activities and nutrition plans, and provide feedback.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSpecializationLabel(CoachSpecialization spec) {
    return switch (spec) {
      CoachSpecialization.running => 'Running',
      CoachSpecialization.cycling => 'Cycling',
      CoachSpecialization.swimming => 'Swimming',
      CoachSpecialization.triathlon => 'Triathlon',
      CoachSpecialization.nutrition => 'Nutrition',
      CoachSpecialization.strengthAndConditioning => 'Strength & Conditioning',
      CoachSpecialization.mentalPerformance => 'Mental Performance',
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(coachProfileSetupControllerProvider.notifier).saveProfile(
          displayName: _displayNameController.text.trim(),
          bio: _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          specializations: _selectedSpecializations.toList(),
          onSuccess: () {
            if (mounted) {
              context.go('/coach');
            }
          },
        );
  }
}
