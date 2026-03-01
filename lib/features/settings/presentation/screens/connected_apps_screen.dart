import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/navigation/figma_onboarding_footer.dart';

import '../../../integrations/presentation/integration_sync_helpers.dart';
import '../../../integrations/presentation/providers/connect_training_controller.dart';
import '../../../integrations/presentation/widgets/integration_provider_card.dart';
import '../../../../shared/services/preferences_service.dart';

/// Connected Apps Screen - Used for both settings and onboarding flows
///
/// Settings Mode (default):
/// - Has AppBar with back button
/// - No skip option
/// - Shows "Notify Me" for coming soon providers
///
/// Onboarding Mode (when onContinue is provided):
/// - Has header text and onboarding footer
/// - Shows "Skip for now" option
/// - Auto-imports workouts after connecting
/// - Shows "Notify Me" for coming soon providers
class ConnectedAppsScreen extends ConsumerStatefulWidget {
  const ConnectedAppsScreen({
    super.key,
    this.onContinue,
    this.onBack,
  });

  /// Callback to advance to next page in onboarding PageView
  /// If null, screen is in settings mode
  final VoidCallback? onContinue;

  /// Callback to go back in onboarding PageView
  final VoidCallback? onBack;

  @override
  ConsumerState<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends ConsumerState<ConnectedAppsScreen> {
  /// Whether we're in onboarding mode (vs settings mode)
  bool get isOnboarding => widget.onContinue != null;

  /// Track which providers have synced this session (in-memory only)
  /// Resets when navigating away and back
  bool _finalSurgeSynced = false;
  bool _trainingPeaksSynced = false;
  final Set<String> _notifiedProviders = {};

  static const List<_ComingSoonProviderConfig> _comingSoonProviders = [
    _ComingSoonProviderConfig(name: 'TriDot', key: 'tridot'),
    _ComingSoonProviderConfig(name: 'Runna', key: 'runna'),
    _ComingSoonProviderConfig(name: 'VDOT', key: 'vdot'),
    _ComingSoonProviderConfig(
      name: 'Strava',
      key: 'strava',
      iconPath: 'assets/images/integrations/strava_compatible_white.svg',
      logoHeight: 18,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Refresh integration status when screen loads (especially important
    // for settings mode after connecting in onboarding)
    if (!isOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(connectTrainingControllerProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectTrainingControllerProvider);

    if (isOnboarding) {
      return _buildOnboardingLayout(context, ref, state);
    } else {
      return _buildSettingsLayout(context, ref, state);
    }
  }

  /// Settings mode layout with AppBar
  Widget _buildSettingsLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ConnectTrainingState> state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      appBar: AppBar(
        backgroundColor: AppColors.blackberry,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Connected Apps',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: state.when(
            data: (data) => _buildContent(context, ref, data),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.dragonfruit),
            ),
            error: (error, _) => _buildError(context, ref, error.toString()),
          ),
        ),
      ),
    );
  }

  /// Onboarding mode layout with header and footer
  Widget _buildOnboardingLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ConnectTrainingState> state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Column(
        children: [
          // Main content
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // Header
                    _buildOnboardingHeader(context),

                    const SizedBox(height: AppSpacing.xl),

                    // Integration providers list
                    Expanded(
                      child: state.when(
                        data: (data) => _buildOnboardingProvidersList(context, ref, data),
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.dragonfruit),
                        ),
                        error: (error, _) => _buildError(context, ref, error.toString()),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Skip button
                    _buildSkipButton(ref),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),

          // Footer navigation
          SafeArea(
            top: false,
            child: FigmaOnboardingFooter(
              onContinue: () => widget.onContinue?.call(),
              onBack: widget.onBack,
              canContinue: true,
              isLoading: state.isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Your Training',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.textDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Import your upcoming workouts to get personalized nutrition plans for each session.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
        ),
      ],
    );
  }

  /// Content for settings mode (shows Final Surge as "Coming Soon")
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ConnectTrainingState data,
  ) {
    return ListView(
      children: [
        // Header text
        Text(
          'Connect your training platforms to automatically import workouts and generate nutrition plans.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Final Surge - fully integrated
        // Logo includes wordmark - no separate text label needed
        IntegrationProviderCard(
          name: 'Final Surge',
          iconPath: 'assets/images/integrations/final_surge_wordmark_white.svg',
          logoHeight: 18,
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'final_surge',
          isSyncing: data.syncingProvider == 'final_surge',
          athleteName: data.finalSurgeAthleteName,
          lastSyncAt: data.finalSurgeLastSyncAt,
          onConnect: () => _connectFinalSurge(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
          onSync: () => _syncFinalSurgeWithState(context, ref),
          hasSynced: _finalSurgeSynced,
        ),

        // Show last sync info when connected
        if (data.isFinalSurgeConnected && data.importedWorkoutsCount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              'Last sync: ${data.importedWorkoutsCount} workouts imported',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // TrainingPeaks - Using horizontal logo with wordmark per Brand Guidelines
        // Larger height because logo has built-in dark background padding
        IntegrationProviderCard(
          name: 'TrainingPeaks',
          iconPath: 'assets/images/integrations/training_peaks_horizontal_dark.jpg',
          logoHeight: 38,
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'training_peaks',
          isSyncing: data.syncingProvider == 'training_peaks',
          athleteName: data.trainingPeaksAthleteName,
          lastSyncAt: data.trainingPeaksLastSyncAt,
          onConnect: () => _connectTrainingPeaks(context, ref),
          onDisconnect: () => _disconnectTrainingPeaks(context, ref),
          onSync: () => _syncTrainingPeaksWithState(context, ref),
          hasSynced: _trainingPeaksSynced,
        ),

        // Show last sync info and event when connected
        if (data.isTrainingPeaksConnected) ...[
          if (data.importedWorkoutsCount > 0 || data.hasNextEvent) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.importedWorkoutsCount > 0)
                    Text(
                      'Last sync: ${data.importedWorkoutsCount} workouts imported',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
                    ),
                  if (data.hasNextEvent && data.nextEventName != null)
                    Text(
                      'Next event: ${data.nextEventName}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                    ),
                ],
              ),
            ),
          ],
        ],

        // TP Write-Back toggle (only when TP is connected)
        if (data.isTrainingPeaksConnected) ...[
          const SizedBox(height: AppSpacing.md),
          _buildTpWritebackToggle(context, ref),
        ],

        const SizedBox(height: AppSpacing.lg),

        ..._buildComingSoonProviders(
          context,
          ref,
          isOnboardingMode: false,
          spacing: AppSpacing.md,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Error message if any
        if (data.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dragonfruit.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.dragonfruit, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    data.errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.dragonfruit),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Long press hint
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Tip: Long-press "Sync Now" to disconnect',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Content for onboarding mode
  /// - Coming soon providers show "Notify Me"
  /// - Workouts are automatically synced after connecting
  Widget _buildOnboardingProvidersList(
    BuildContext context,
    WidgetRef ref,
    ConnectTrainingState data,
  ) {
    return ListView(
      children: [
        // Final Surge - fully integrated
        // Logo includes wordmark - no separate text label needed
        IntegrationProviderCard(
          name: 'Final Surge',
          iconPath: 'assets/images/integrations/final_surge_wordmark_white.svg',
          logoHeight: 18,
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'final_surge',
          isSyncing: data.syncingProvider == 'final_surge',
          athleteName: data.finalSurgeAthleteName,
          lastSyncAt: data.finalSurgeLastSyncAt,
          onConnect: () => _connectFinalSurgeOnboarding(context, ref),
          onSync: () => _syncFinalSurgeWithState(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
          showSyncButton: true,
          hasSynced: _finalSurgeSynced,
        ),

        const SizedBox(height: AppSpacing.md),

        // TrainingPeaks - shows "Sync Now" when connected (allows re-sync)
        // Using horizontal logo with wordmark per Brand Guidelines
        // Larger height because logo has built-in dark background padding
        IntegrationProviderCard(
          name: 'TrainingPeaks',
          iconPath: 'assets/images/integrations/training_peaks_horizontal_dark.jpg',
          logoHeight: 38,
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'training_peaks',
          isSyncing: data.syncingProvider == 'training_peaks',
          athleteName: data.trainingPeaksAthleteName,
          lastSyncAt: data.trainingPeaksLastSyncAt,
          onConnect: () => _connectTrainingPeaksOnboarding(context, ref),
          onSync: () => _syncTrainingPeaksWithState(context, ref),
          onDisconnect: () => _disconnectTrainingPeaks(context, ref),
          showSyncButton: true,
          hasSynced: _trainingPeaksSynced,
        ),

        const SizedBox(height: AppSpacing.md),

        ..._buildComingSoonProviders(
          context,
          ref,
          isOnboardingMode: true,
          spacing: AppSpacing.md,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.dragonfruit,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Something went wrong',
            style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          KyleSecondaryButton(
            text: 'Try Again',
            onPressed: () => ref.invalidate(connectTrainingControllerProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipButton(WidgetRef ref) {
    return Center(
      child: TextButton(
        onPressed: () => _skipConnection(ref),
        child: Text(
          'Skip for now',
          style: AppTextStyles.buttonTertiary.copyWith(
            color: AppColors.textDarkSecondary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComingSoonProviders(
    BuildContext context,
    WidgetRef ref, {
    required bool isOnboardingMode,
    required double spacing,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < _comingSoonProviders.length; i++) {
      final provider = _comingSoonProviders[i];
      widgets.add(
        IntegrationProviderCard(
          name: provider.name,
          iconPath: provider.iconPath,
          logoHeight: provider.logoHeight,
          isAvailable: false,
          isConnected: false,
          isConnecting: false,
          statusText: 'Coming soon',
          onNotify: () => _notifyProvider(
            context,
            ref,
            provider.key,
            isOnboardingMode: isOnboardingMode,
          ),
          isNotified: _notifiedProviders.contains(provider.key),
        ),
      );

      if (i < _comingSoonProviders.length - 1) {
        widgets.add(SizedBox(height: spacing));
      }
    }
    return widgets;
  }

  void _notifyProvider(
    BuildContext context,
    WidgetRef ref,
    String provider, {
    required bool isOnboardingMode,
  }) {
    if (!mounted) return;
    if (_notifiedProviders.contains(provider)) return;

    setState(() {
      _notifiedProviders.add(provider);
    });

    ref.read(connectTrainingControllerProvider.notifier).trackNotifyMe(
          provider: provider,
          source: isOnboardingMode ? 'onboarding' : 'settings',
        );

    if (context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Notified!');
    }
  }

  // ============================================================
  // Settings Mode Connection Methods (no auto-import)
  // ============================================================

  Future<void> _connectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectFinalSurge();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Final Surge connected!');
    }
  }

  Future<void> _connectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'TrainingPeaks connected!');
    }
  }

  // ============================================================
  // Onboarding Mode Connection Methods (with auto-import)
  // ============================================================

  Future<void> _connectFinalSurgeOnboarding(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectFinalSurge();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'Final Surge connected! Importing workouts...',
      );

      // Auto-import workouts in onboarding mode
      final result = await controller.importFinalSurgeWorkouts();

      if (context.mounted) {
        final state = ref.read(connectTrainingControllerProvider).value;
        final message = buildWorkoutSyncMessage(
          newCount: result.newWorkouts,
          updatedCount: result.updated,
          deletedCount: result.deleted,
          unchangedCount: result.skipped,
        );

        if (result.success && result.hasChanges) {
          MealvanaSnackbar.showSuccess(
            context,
            message,
          );
        } else if (!result.success || state?.errorMessage != null) {
          MealvanaSnackbar.showError(
            context,
            'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
          );
        } else {
          MealvanaSnackbar.showInfo(
            context,
            message,
          );
        }
      }

      // Mark as synced after successful auto-import
      final latestState = ref.read(connectTrainingControllerProvider).value;
      if (mounted && result.success && latestState?.errorMessage == null) {
        setState(() {
          _finalSurgeSynced = true;
        });
      }
    }
  }

  Future<void> _connectTrainingPeaksOnboarding(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'TrainingPeaks connected! Importing workouts...',
      );

      // Auto-import workouts in onboarding mode
      final result = await controller.importTrainingPeaksWorkouts();

      if (context.mounted) {
        final state = ref.read(connectTrainingControllerProvider).value;
        final eventInfo = state?.hasNextEvent == true && state?.nextEventName != null
            ? '\nNext event: ${state!.nextEventName}'
            : '';
        final message = buildWorkoutSyncMessage(
          newCount: result.newWorkouts,
          updatedCount: result.updated,
          deletedCount: result.deleted,
          unchangedCount: result.unchanged,
        );

        if (result.success && result.hasChanges) {
          MealvanaSnackbar.showSuccess(
            context,
            '$message$eventInfo',
          );
        } else if (!result.success || state?.errorMessage != null) {
          MealvanaSnackbar.showError(
            context,
            'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
          );
        } else {
          MealvanaSnackbar.showInfo(
            context,
            '$message$eventInfo',
          );
        }
      }

      // Mark as synced after successful auto-import
      final latestState = ref.read(connectTrainingControllerProvider).value;
      if (mounted && result.success && latestState?.errorMessage == null) {
        setState(() {
          _trainingPeaksSynced = true;
        });
      }
    }
  }

  // ============================================================
  // Shared Disconnect Methods
  // ============================================================

  Future<void> _disconnectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectFinalSurge();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Final Surge disconnected');
    }
  }

  Future<void> _disconnectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectTrainingPeaks();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'TrainingPeaks disconnected');
    }
  }

  // ============================================================
  // Sync Methods with State Tracking
  // ============================================================

  /// Sync Final Surge and update local synced state
  Future<void> _syncFinalSurgeWithState(BuildContext context, WidgetRef ref) async {
    await syncFinalSurge(context, ref);

    // Check if sync was successful (no error message)
    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _finalSurgeSynced = true;
      });
    }
  }

  /// Sync TrainingPeaks and update local synced state
  Future<void> _syncTrainingPeaksWithState(BuildContext context, WidgetRef ref) async {
    await syncTrainingPeaks(context, ref);

    // Check if sync was successful (no error message)
    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _trainingPeaksSynced = true;
      });
    }
  }

  // ============================================================
  // Onboarding Navigation
  // ============================================================

  Widget _buildTpWritebackToggle(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesServiceProvider);
    final enabled = prefs.tpWritebackEnabled;
    final premiumBlocked = prefs.tpWritebackPremiumBlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Write-Back to TrainingPeaks',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: premiumBlocked
                        ? AppColors.textDarkSecondary
                        : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premiumBlocked
                      ? 'Requires TrainingPeaks Premium'
                      : 'Add nutrition plan summary to workout descriptions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: premiumBlocked
                ? null
                : (value) async {
                    await prefs.setTpWritebackEnabled(value);
                    // Force rebuild by invalidating the provider
                    ref.invalidate(preferencesServiceProvider);
                  },
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  void _skipConnection(WidgetRef ref) {
    // Track skip and continue
    ref.read(connectTrainingControllerProvider.notifier).trackSkip();
    widget.onContinue?.call();
  }
}

class _ComingSoonProviderConfig {
  const _ComingSoonProviderConfig({
    required this.name,
    required this.key,
    this.iconPath,
    this.logoHeight = 24,
  });

  final String name;
  final String key;
  final String? iconPath;
  final double logoHeight;
}
