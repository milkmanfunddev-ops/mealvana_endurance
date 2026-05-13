import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/navigation/figma_onboarding_footer.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../integrations/presentation/integration_sync_helpers.dart';
import '../../../integrations/presentation/providers/connect_training_controller.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';
import '../../../integrations/presentation/widgets/integration_provider_card.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../../../shared/widgets/content_area.dart';

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
/// - Shows "Connect" for Garmin, "Notify Me" for other coming soon providers
class ConnectedAppsScreen extends ConsumerStatefulWidget {
  const ConnectedAppsScreen({super.key, this.onContinue, this.onBack});

  /// Callback to advance to next page in onboarding PageView
  /// If null, screen is in settings mode
  final VoidCallback? onContinue;

  /// Callback to go back in onboarding PageView
  final VoidCallback? onBack;

  @override
  ConsumerState<ConnectedAppsScreen> createState() =>
      _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends ConsumerState<ConnectedAppsScreen> {
  /// Whether we're in onboarding mode (vs settings mode)
  bool get isOnboarding => widget.onContinue != null;

  /// Track which providers have synced this session (in-memory only)
  /// Resets when navigating away and back
  bool _finalSurgeSynced = false;
  bool _trainingPeaksSynced = false;

  /// Garmin's "Refresh" doesn't poll Garmin (their API is push-only) — it
  /// just re-fetches activities from Supabase. We track in-flight state so
  /// the integration card can render a spinner while the call is running.
  bool _isRefreshingGarmin = false;
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: const CustomAppBarBackButton(
          key: ValueKey('connected_apps.back_button'),
        ),
        title: Text(
          key: const ValueKey('connected_apps.title'),
          'Connected Apps',
          style: AppTextStyles.sectionTitle.copyWith(color: onSurface),
        ),
        centerTitle: true,
      ),
      body: ContentArea(
        child: SafeArea(
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        data: (data) =>
                            _buildOnboardingProvidersList(context, ref, data),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.dragonfruit,
                          ),
                        ),
                        error: (error, _) =>
                            _buildError(context, ref, error.toString()),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Skip button
                    _buildSkipButton(context, ref),

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
              continueButtonKey: const ValueKey(
                'connect_training.continue_button',
              ),
              backButtonKey: const ValueKey('connect_training.back_button'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingHeader(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const ValueKey('connect_training.title'),
          'Connect Your Training',
          style: AppTextStyles.pageTitle.copyWith(color: onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          key: const ValueKey('connect_training.description'),
          'Import your upcoming workouts to get personalized nutrition plans for each session.',
          style: AppTextStyles.bodyMedium.copyWith(color: onSurfaceVariant),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final finalSurgeLogo = isDark
        ? 'assets/images/integrations/final_surge_wordmark_white.svg'
        : 'assets/images/integrations/final_surge_wordmark.svg';
    // TP horizontal logo always uses the dark-background version — the
    // "light" PNG has white text on a transparent background which is
    // invisible on light cards.
    const trainingPeaksLogo =
        'assets/images/integrations/training_peaks_horizontal_dark.jpg';

    return ListView(
      children: [
        // Header text
        Text(
          key: const ValueKey('connected_apps.description'),
          'Connect your training platforms to automatically import workouts and generate nutrition plans.',
          style: AppTextStyles.bodyMedium.copyWith(color: onSurfaceVariant),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Final Surge - fully integrated
        // Logo includes wordmark - no separate text label needed
        IntegrationProviderCard(
          key: const ValueKey('connected_apps.finalsurge_connect_button'),
          name: 'Final Surge',
          iconPath: finalSurgeLogo,
          logoHeight: 18,
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'final_surge',
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
              style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // TrainingPeaks - Using horizontal logo with wordmark per Brand Guidelines
        // Larger height because logo has built-in dark background padding
        IntegrationProviderCard(
          key: const ValueKey('connected_apps.trainingpeaks_connect_button'),
          name: 'TrainingPeaks',
          iconPath: trainingPeaksLogo,
          logoHeight: 38,
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'training_peaks',
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: onSurfaceVariant,
                      ),
                    ),
                  if (data.hasNextEvent && data.nextEventName != null)
                    Text(
                      'Next event: ${data.nextEventName}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
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

        // Garmin Connect — push-only integration.
        // Brand Guidelines: Use the official Garmin Connect badge (per Garmin
        // Connect Developer Program review, ticket 206017).
        // The "Refresh" button doesn't poll Garmin (their Health API has no
        // on-demand list endpoint). It re-pulls activities from our Supabase
        // DB so any push that arrived while the app was closed surfaces in
        // the calendar/list immediately.
        IntegrationProviderCard(
          key: const ValueKey('connected_apps.garmin_connect_button'),
          name: 'Garmin Connect',
          iconPath: 'assets/images/integrations/garmin_connect_badge.png',
          logoHeight: 40,
          isAvailable: true,
          isConnected: data.isGarminConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'garmin',
          isSyncing: _isRefreshingGarmin,
          athleteName: data.garminAthleteName,
          onConnect: () => _connectGarmin(context, ref),
          onDisconnect: () => _disconnectGarmin(context, ref),
          onSync: () => _refreshGarminWithState(context, ref),
          showSyncButton: data.isGarminConnected,
        ),
        if (data.isGarminConnected)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.xs,
            ),
            child: Text(
              'Garmin syncs automatically when your watch uploads to Garmin '
              'Connect. Tap Refresh to pull any activities that arrived while '
              'the app was closed.',
              style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
            ),
          ),

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
                Icon(
                  Icons.error_outline,
                  color: AppColors.dragonfruit,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    data.errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.dragonfruit,
                    ),
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
          style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
          textAlign: TextAlign.center,
        ),

        // Push-notification reset escape hatch.
        //
        // OneSignal v5.x sometimes leaves an iOS device on a stale or invalid
        // APNs token (especially after iOS upgrades or re-installs that
        // happened over an existing build). This button forces OneSignal to
        // opt out and re-opt in, which clears cached subscription state and
        // re-runs registerForRemoteNotifications. Most users will never need
        // it; surfacing it here as a "Tip" keeps it discoverable for support
        // without cluttering the main flow.
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: () => _resetPushNotifications(context),
            icon: Icon(Icons.refresh, size: 16, color: onSurfaceVariant),
            label: Text(
              'Reset push notifications',
              style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            "Not getting workout alerts? Tap to re-register this device with "
            "Mealvana's push service.",
            style: AppTextStyles.bodySmall.copyWith(
              color: onSurfaceVariant,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalSurgeLogo = isDark
        ? 'assets/images/integrations/final_surge_wordmark_white.svg'
        : 'assets/images/integrations/final_surge_wordmark.svg';
    // TP horizontal logo always uses the dark-background version — the
    // "light" PNG has white text on a transparent background which is
    // invisible on light cards.
    const trainingPeaksLogo =
        'assets/images/integrations/training_peaks_horizontal_dark.jpg';

    return ListView(
      children: [
        // Final Surge - fully integrated
        // Logo includes wordmark - no separate text label needed
        IntegrationProviderCard(
          key: const ValueKey('connect_training.finalsurge_connect_button'),
          name: 'Final Surge',
          iconPath: finalSurgeLogo,
          logoHeight: 18,
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'final_surge',
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
          key: const ValueKey('connect_training.trainingpeaks_connect_button'),
          name: 'TrainingPeaks',
          iconPath: trainingPeaksLogo,
          logoHeight: 38,
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'training_peaks',
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

        // Garmin Connect — push-only integration.
        // Brand Guidelines: Use the official Garmin Connect badge (per Garmin
        // Connect Developer Program review, ticket 206017).
        // Refresh re-pulls from Supabase (Garmin's API is push-only).
        IntegrationProviderCard(
          key: const ValueKey('connect_training.garmin_connect_button'),
          name: 'Garmin Connect',
          iconPath: 'assets/images/integrations/garmin_connect_badge.png',
          logoHeight: 40,
          isAvailable: true,
          isConnected: data.isGarminConnected,
          isConnecting:
              data.isConnecting && data.connectingProvider == 'garmin',
          isSyncing: _isRefreshingGarmin,
          athleteName: data.garminAthleteName,
          onConnect: () => _connectGarminOnboarding(context, ref),
          onDisconnect: () => _disconnectGarmin(context, ref),
          onSync: () => _refreshGarminWithState(context, ref),
          showSyncButton: data.isGarminConnected,
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
            style: AppTextStyles.sectionTitle.copyWith(color: onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
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

  Widget _buildSkipButton(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        key: const ValueKey('connect_training.skip_button'),
        onPressed: () => _skipConnection(ref),
        child: Text(
          'Skip for now',
          style: AppTextStyles.buttonTertiary.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyPrefix = isOnboardingMode ? 'connect_training' : 'connected_apps';
    final widgets = <Widget>[];
    for (var i = 0; i < _comingSoonProviders.length; i++) {
      final provider = _comingSoonProviders[i];
      final iconPath = provider.key == 'strava'
          ? (isDark
                ? 'assets/images/integrations/strava_compatible_white.svg'
                : 'assets/images/integrations/strava_compatible_logo.png')
          : provider.iconPath;
      widgets.add(
        IntegrationProviderCard(
          key: ValueKey('$keyPrefix.${provider.key}_notify_button'),
          name: provider.name,
          iconPath: iconPath,
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

    ref
        .read(connectTrainingControllerProvider.notifier)
        .trackNotifyMe(
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

  Future<void> _connectTrainingPeaks(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'TrainingPeaks connected!');
    }
  }

  Future<void> _connectGarmin(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectGarmin();

    if (success && context.mounted) {
      final notificationsGranted =
          await NotificationService.requestPermissions();
      if (!context.mounted) return;
      MealvanaSnackbar.showSuccess(
        context,
        notificationsGranted
            ? 'Garmin Connect connected! Activity upload alerts are enabled.'
            : 'Garmin Connect connected! Activities will sync automatically.',
      );

      if (!notificationsGranted && context.mounted) {
        MealvanaSnackbar.showInfo(
          context,
          'Enable notifications in Settings to get Garmin activity upload alerts.',
        );
      }
    }
  }

  // ============================================================
  // Onboarding Mode Connection Methods (with auto-import)
  // ============================================================

  Future<void> _connectFinalSurgeOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
          MealvanaSnackbar.showSuccess(context, message);
        } else if (!result.success || state?.errorMessage != null) {
          MealvanaSnackbar.showError(
            context,
            'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
          );
        } else {
          MealvanaSnackbar.showInfo(context, message);
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

  Future<void> _connectTrainingPeaksOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
        final eventInfo =
            state?.hasNextEvent == true && state?.nextEventName != null
            ? '\nNext event: ${state!.nextEventName}'
            : '';
        final message = buildWorkoutSyncMessage(
          newCount: result.newWorkouts,
          updatedCount: result.updated,
          deletedCount: result.deleted,
          unchangedCount: result.unchanged,
        );

        if (result.success && result.hasChanges) {
          MealvanaSnackbar.showSuccess(context, '$message$eventInfo');
        } else if (!result.success || state?.errorMessage != null) {
          MealvanaSnackbar.showError(
            context,
            'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
          );
        } else {
          MealvanaSnackbar.showInfo(context, '$message$eventInfo');
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

  Future<void> _connectGarminOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectGarmin();

    if (success && context.mounted) {
      final notificationsGranted =
          await NotificationService.requestPermissions();
      if (!context.mounted) return;
      MealvanaSnackbar.showSuccess(
        context,
        notificationsGranted
            ? 'Garmin Connect connected! We will alert you when activities upload.'
            : 'Garmin Connect connected! Activities will sync automatically when you use your Garmin device.',
      );

      if (!notificationsGranted && context.mounted) {
        MealvanaSnackbar.showInfo(
          context,
          'Turn on notifications later in app settings for activity upload alerts.',
        );
      }
    }
  }

  // ============================================================
  // Shared Disconnect Methods
  // ============================================================

  Future<void> _disconnectFinalSurge(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectFinalSurge();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Final Surge disconnected');
    }
  }

  Future<void> _disconnectTrainingPeaks(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectTrainingPeaks();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'TrainingPeaks disconnected');
    }
  }

  Future<void> _disconnectGarmin(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectGarmin();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Garmin Connect disconnected');
    }
  }

  // ============================================================
  // Sync Methods with State Tracking
  // ============================================================

  /// Sync Final Surge and update local synced state
  Future<void> _syncFinalSurgeWithState(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await syncFinalSurge(context, ref, showLoadingSnackbar: false);

    // Check if sync was successful (no error message)
    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _finalSurgeSynced = true;
      });
    }
  }

  /// Sync TrainingPeaks and update local synced state
  Future<void> _syncTrainingPeaksWithState(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await syncTrainingPeaks(context, ref, showLoadingSnackbar: false);

    // Check if sync was successful (no error message)
    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _trainingPeaksSynced = true;
      });
    }
  }

  /// Re-pulls the activities table from Supabase so any Garmin push that
  /// arrived while the app was closed (or the local DB missed) shows up
  /// in the calendar/list. Garmin's Health API is push-only — this is the
  /// closest thing to a manual sync we can offer.
  Future<void> _refreshGarminWithState(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_isRefreshingGarmin) return;
    setState(() => _isRefreshingGarmin = true);
    try {
      await syncGarmin(context, ref, showLoadingSnackbar: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingGarmin = false);
      }
    }
  }

  /// Forces OneSignal to opt out and immediately opt back in, which clears
  /// any cached subscription state (e.g., invalid_identifier flagged tokens)
  /// and re-runs registerForRemoteNotifications. Used as a manual escape
  /// hatch when push notifications stop arriving despite iOS Settings
  /// reporting permission as granted.
  Future<void> _resetPushNotifications(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    MealvanaSnackbar.showLoading(context, 'Resetting push notifications...');
    try {
      await OneSignal.User.pushSubscription.optOut();
      // Tiny delay so OneSignal has time to register the optOut state
      // before we flip it back. Without this the second call sometimes
      // races and the cached state isn't fully cleared.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await OneSignal.User.pushSubscription.optIn();
    } catch (e) {
      messenger?.hideCurrentSnackBar();
      if (!context.mounted) return;
      MealvanaSnackbar.showError(
        context,
        'Reset failed: $e',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    messenger?.hideCurrentSnackBar();
    if (!context.mounted) return;
    MealvanaSnackbar.showSuccess(
      context,
      'Push notifications reset. Restart the app to complete.',
      duration: const Duration(seconds: 5),
    );
  }

  // ============================================================
  // Onboarding Navigation
  // ============================================================

  Widget _buildTpWritebackToggle(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesServiceProvider);
    final enabled = prefs.tpWritebackEnabled;
    final premiumBlocked = prefs.tpWritebackPremiumBlocked;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
                    color: premiumBlocked ? onSurfaceVariant : onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premiumBlocked
                      ? 'Requires TrainingPeaks Premium'
                      : 'Add nutrition plan summary to workout descriptions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
                if (premiumBlocked) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _recheckTpWritebackEligibility(context, ref),
                    child: Text(
                      'Re-check account status',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dragonfruit,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          KyleSwitch(
            key: const ValueKey('connected_apps.tp_writeback_toggle'),
            value: enabled,
            enabled: !premiumBlocked,
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

  Future<void> _recheckTpWritebackEligibility(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = ref
        .read(connectTrainingControllerProvider.notifier)
        .currentUserId;
    if (userId == null) {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Unable to verify account right now',
        );
      }
      return;
    }

    final service = await ref.read(tpWritebackServiceProvider.future);
    final premium = await service.refreshPremiumEligibility(userId: userId);
    ref.invalidate(preferencesServiceProvider);

    if (!context.mounted) return;

    if (premium == true) {
      MealvanaSnackbar.showSuccess(
        context,
        'Write-back is available for this account',
      );
    } else if (premium == false) {
      MealvanaSnackbar.showInfo(
        context,
        'TrainingPeaks reports this account as non-Premium for planned workout write-back.',
      );
    } else {
      MealvanaSnackbar.showError(
        context,
        'Could not verify TrainingPeaks account status. Please try again.',
      );
    }
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
