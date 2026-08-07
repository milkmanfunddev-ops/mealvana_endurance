import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../integrations/domain/runna_defaults.dart';
import '../../../integrations/presentation/integration_sync_helpers.dart';
import '../../../integrations/presentation/providers/connect_training_controller.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';
import '../../../integrations/presentation/widgets/integration_provider_card.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../../onboarding/presentation/theme/onboarding_design_tokens.dart';
import '../../../onboarding/presentation/widgets/onboarding_multi_select_step.dart';
import '../../../onboarding/presentation/widgets/onboarding_week_chart_card.dart';
import '../../../../shared/services/app_external_deps.dart';
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
  const ConnectedAppsScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.stepIndex,
    this.isRevisit = false,
  });

  /// Callback to advance to next page in onboarding PageView
  /// If null, screen is in settings mode
  final VoidCallback? onContinue;

  /// Callback to go back in onboarding PageView
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null in settings mode.
  final int? stepIndex;

  /// Spec revisit mode — the page pushed by the plan-reveal / daily-preview
  /// "Connect now" nudges. Same providers list and behavior, but the intro
  /// block (orange title, subtitle, chart card) collapses to the teal
  /// "CONNECT TRAINING" kicker, and both Back and Continue return to the
  /// pushing page (the callbacks pop the route) instead of moving the
  /// PageView.
  final bool isRevisit;

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
  bool _vdotSynced = false;
  bool _runnaSynced = false;

  /// Garmin's "Refresh" doesn't poll Garmin (their API is push-only) — it
  /// just re-fetches activities from Supabase. We track in-flight state so
  /// the integration card can render a spinner while the call is running.
  bool _isRefreshingGarmin = false;
  final Set<String> _notifiedProviders = {};

  static const List<_ComingSoonProviderConfig> _comingSoonProviders = [
    _ComingSoonProviderConfig(name: 'TriDot', key: 'tridot'),
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

    // This is onboarding step 0, and until now it fired no `screen_viewed` at
    // all — so the funnel had no denominator: we could see users completing
    // step 0 but never how many reached it. Every other step already tracks
    // this in initState; match them.
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': isOnboarding
                ? 'Connect Training Onboarding'
                : 'Connected Apps Settings',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
            // Distinguishes the pushed revisit page (from the reveal/daily
            // nudges) from the step-3 funnel view.
            if (widget.isRevisit) 'is_revisit': true,
          },
        );

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

  /// Onboarding mode layout — pixel port of the HTML spec's connect-training
  /// screen: shared spec header (back circle + progress segments), flat
  /// OnbTokens.bg scaffold, left-aligned Sansita/orange title, the
  /// "YOUR WEEK, FUELED" chart card, spec-styled provider rows, skip link,
  /// and the shared Continue pill. (Settings mode is untouched.)
  Widget _buildOnboardingLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ConnectTrainingState> state,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: OnbTokens.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            OnboardingStepHeader(
              stepIndex: widget.stepIndex ?? 3,
              onBack: widget.onBack,
              backButtonKey: const ValueKey('connect_training.back_button'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Spec: the connect screen's scroll content carries its
                    // own 22px top padding (header block already ends with
                    // 6px), distinct from the 48px rhythm the other step
                    // screens use.
                    const SizedBox(height: 22),
                    if (widget.isRevisit)
                      // Spec revisit intro: just the teal kicker
                      // (Apercu 500 11, ls .14em, uppercase, 18px below).
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Text(
                          key: ValueKey('connect_training.revisit_kicker'),
                          'CONNECT TRAINING',
                          style: TextStyle(
                            fontFamily: OnbTokens.fontBody,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.54,
                            color: OnbTokens.teal,
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        key: ValueKey('connect_training.title'),
                        'Your training changes daily. Your fueling should too.',
                        style: TextStyle(
                          fontFamily: OnbTokens.fontDisplay,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: OnbTokens.orange,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        key: const ValueKey('connect_training.description'),
                        'Connect your training calendar so we can import your '
                        'workouts and periodize your nutrition.',
                        style: TextStyle(
                          fontFamily: OnbTokens.fontBody,
                          fontSize: 14,
                          height: 1.45,
                          color: OnbTokens.creamA(0.62),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Carries its own 22px bottom margin per spec.
                      const OnboardingWeekChartCard(),
                    ],
                    state.when(
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                2,
                24,
                bottomInset > 34 ? bottomInset : 34,
              ),
              child: OnboardingSpecCta(
                label: 'Continue',
                buttonKey: const ValueKey('connect_training.continue_button'),
                onTap: () => widget.onContinue?.call(),
              ),
            ),
          ],
        ),
      ),
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

        // V.O2 (VDOT) — OAuth + pull-based workout sync.
        IntegrationProviderCard(
          key: const ValueKey('connected_apps.vdot_connect_button'),
          name: 'V.O2',
          isAvailable: true,
          isConnected: data.isVdotConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'vdot',
          isSyncing: data.syncingProvider == 'vdot',
          athleteName: data.vdotAthleteName,
          lastSyncAt: data.vdotLastSyncAt,
          onConnect: () => _connectVdot(context, ref),
          onDisconnect: () => _disconnectVdot(context, ref),
          onSync: () => _syncVdotWithState(context, ref),
          showSyncButton: data.isVdotConnected,
          hasSynced: _vdotSynced,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Runna — calendar-feed (.ics) import, no OAuth. "Connect" opens a
        // dialog where the user pastes their Runna calendar-sync link.
        IntegrationProviderCard(
          key: const ValueKey('connected_apps.runna_connect'),
          name: 'Runna',
          isAvailable: true,
          isConnected: data.isRunnaConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'runna',
          isSyncing: data.syncingProvider == 'runna',
          lastSyncAt: data.runnaLastSyncAt,
          onConnect: () => _connectRunna(context, ref),
          onDisconnect: () => _disconnectRunna(context, ref),
          onSync: () => _syncRunnaWithState(context, ref),
          showSyncButton: data.isRunnaConnected,
          hasSynced: _runnaSynced,
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

  /// Content for onboarding mode — spec row order (TrainingPeaks, Final
  /// Surge, V.O2, Runna, Garmin Connect, TriDot coming-soon, declined tile)
  /// with the spec's 10px row gap and spec-styled cards. Workouts are
  /// automatically synced after connecting.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          windowCaption: 'Imports ~30 days of history',
          onConnect: () => _connectTrainingPeaksOnboarding(context, ref),
          onSync: () => _syncTrainingPeaksWithState(context, ref),
          onDisconnect: () => _disconnectTrainingPeaks(context, ref),
          showSyncButton: true,
          hasSynced: _trainingPeaksSynced,
          specStyle: true,
        ),

        const SizedBox(height: 10),

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
          windowCaption: 'Imports ~7 days of history',
          onConnect: () => _connectFinalSurgeOnboarding(context, ref),
          onSync: () => _syncFinalSurgeWithState(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
          showSyncButton: true,
          hasSynced: _finalSurgeSynced,
          specStyle: true,
        ),

        const SizedBox(height: 10),

        // V.O2 (VDOT) — OAuth + pull-based workout sync.
        IntegrationProviderCard(
          key: const ValueKey('connect_training.vdot_connect_button'),
          name: 'V.O2',
          isAvailable: true,
          isConnected: data.isVdotConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'vdot',
          isSyncing: data.syncingProvider == 'vdot',
          athleteName: data.vdotAthleteName,
          lastSyncAt: data.vdotLastSyncAt,
          onConnect: () => _connectVdotOnboarding(context, ref),
          onSync: () => _syncVdotWithState(context, ref),
          onDisconnect: () => _disconnectVdot(context, ref),
          showSyncButton: true,
          hasSynced: _vdotSynced,
          specStyle: true,
        ),

        const SizedBox(height: 10),

        // Runna — calendar-feed (.ics) import, no OAuth.
        IntegrationProviderCard(
          key: const ValueKey('connect_training.runna_connect'),
          name: 'Runna',
          isAvailable: true,
          isConnected: data.isRunnaConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'runna',
          isSyncing: data.syncingProvider == 'runna',
          lastSyncAt: data.runnaLastSyncAt,
          onConnect: () => _connectRunna(context, ref),
          onSync: () => _syncRunnaWithState(context, ref),
          onDisconnect: () => _disconnectRunna(context, ref),
          showSyncButton: true,
          hasSynced: _runnaSynced,
          specStyle: true,
        ),

        const SizedBox(height: 10),

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
          specStyle: true,
        ),

        const SizedBox(height: 10),

        // Coming-soon rows with outlined Notify Me pills. TriDot is the
        // spec's enumerated row; Strava added back per the design owner's
        // 2026-08 ruling (count-worthy interest signal).
        _ComingSoonSpecRow(
          name: 'TRIDOT',
          notifyKey: const ValueKey('connect_training.tridot_notify_button'),
          isNotified: _notifiedProviders.contains('tridot'),
          onNotify: () =>
              _notifyProvider(context, ref, 'tridot', isOnboardingMode: true),
        ),

        const SizedBox(height: 10),

        _ComingSoonSpecRow(
          name: 'STRAVA',
          notifyKey: const ValueKey('connect_training.strava_notify_button'),
          isNotified: _notifiedProviders.contains('strava'),
          onNotify: () =>
              _notifyProvider(context, ref, 'strava', isOnboardingMode: true),
        ),

        const SizedBox(height: 10),

        // "I don't use training plan apps." — an affirmative answer,
        // distinct from Skip-for-now (which stays below): it records a
        // survey flag + its own analytics event, then advances.
        _DeclinedTrainingAppsTile(onTap: _declineTrainingApps),
      ],
    );
  }

  /// "I don't use training plan apps." tile handler (onboarding only).
  void _declineTrainingApps() {
    ref
        .read(onboardingControllerProvider.notifier)
        .recordDeclinedTrainingApps();
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track('connect_training_declined');
    } catch (_) {
      // Analytics must never block onboarding navigation.
    }
    widget.onContinue?.call();
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

    if (isOnboardingMode) {
      // 2026-08 redesign funnel event (replaces the legacy
      // integration_notify_requested in onboarding; settings keeps it).
      if (provider == 'tridot') {
        ref
            .read(onboardingControllerProvider.notifier)
            .recordTridotNotifyRequested();
      }
      try {
        ref
            .read(appExternalDepsProvider)
            .analytics
            .track(
              'integration_notify_me_tapped',
              properties: {'provider': provider, 'source': 'onboarding'},
            );
      } catch (_) {
        // Analytics must never block onboarding.
      }
    } else {
      ref
          .read(connectTrainingControllerProvider.notifier)
          .trackNotifyMe(provider: provider, source: 'settings');
    }

    if (context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Noted!');
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

  /// Connect-failure surface for onboarding mode: MealvanaSnackbar with the
  /// controller's error. The provider card is already back in its Connect
  /// state (the controller resets isConnecting in its catch), so the same
  /// button is the retry path. Sentry capture happens controller-side.
  void _showConnectFailure(
    BuildContext context,
    WidgetRef ref,
    String providerName,
  ) {
    if (!context.mounted) return;
    final message = ref
        .read(connectTrainingControllerProvider)
        .value
        ?.errorMessage;
    MealvanaSnackbar.showError(
      context,
      message != null
          ? 'Could not connect $providerName: $message. '
                'Tap Connect to try again.'
          : 'Could not connect $providerName. Tap Connect to try again.',
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _connectFinalSurgeOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectFinalSurge();

    if (!success && context.mounted) {
      _showConnectFailure(context, ref, 'Final Surge');
      return;
    }

    if (success && context.mounted) {
      ref
          .read(onboardingControllerProvider.notifier)
          .recordConnectedProvider('final_surge');
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

    if (!success && context.mounted) {
      _showConnectFailure(context, ref, 'TrainingPeaks');
      return;
    }

    if (success && context.mounted) {
      ref
          .read(onboardingControllerProvider.notifier)
          .recordConnectedProvider('training_peaks');
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
    // Onboarding: defer the garmin_user_mappings upsert until the user's `users`
    // row exists (created at onboarding completion). See connectGarmin docs /
    // Sentry MEALVANA-ENDURANCE-AF.
    final success = await controller.connectGarmin(isOnboarding: true);

    if (!success && context.mounted) {
      _showConnectFailure(context, ref, 'Garmin Connect');
      return;
    }

    if (success && context.mounted) {
      ref
          .read(onboardingControllerProvider.notifier)
          .recordConnectedProvider('garmin');
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
  // V.O2 (VDOT) handlers
  // ============================================================

  Future<void> _connectVdot(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectVdot();

    if (!success || !context.mounted) return;

    MealvanaSnackbar.showSuccess(
      context,
      'V.O2 connected! Importing workouts...',
    );

    final result = await controller.importVdotWorkouts();
    if (!context.mounted) return;

    final state = ref.read(connectTrainingControllerProvider).value;
    final message = buildWorkoutSyncMessage(
      newCount: result.newWorkouts,
      updatedCount: result.updated,
      deletedCount: result.deleted,
      unchangedCount: result.skipped,
    );

    if (!result.success) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
      );
    } else if (state?.errorMessage != null) {
      // Synced into the app, but the upload to Supabase didn't finish. Surface
      // it (instead of a false "success") so the user knows the workouts aren't
      // backed up yet; the controller retries automatically.
      MealvanaSnackbar.showWarning(context, state!.errorMessage!);
    } else if (result.hasChanges) {
      MealvanaSnackbar.showSuccess(context, message);
    } else {
      MealvanaSnackbar.showInfo(context, message);
    }

    if (mounted && result.success && state?.errorMessage == null) {
      setState(() {
        _vdotSynced = true;
      });
    }
  }

  Future<void> _connectVdotOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectVdot();

    if (!context.mounted) return;
    if (!success) {
      _showConnectFailure(context, ref, 'V.O2');
      return;
    }

    ref
        .read(onboardingControllerProvider.notifier)
        .recordConnectedProvider('vdot');
    MealvanaSnackbar.showSuccess(
      context,
      'V.O2 connected! Importing workouts...',
    );

    final result = await controller.importVdotWorkouts();
    if (!context.mounted) return;

    final state = ref.read(connectTrainingControllerProvider).value;
    final message = buildWorkoutSyncMessage(
      newCount: result.newWorkouts,
      updatedCount: result.updated,
      deletedCount: result.deleted,
      unchangedCount: result.skipped,
    );

    if (!result.success) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
      );
    } else if (state?.errorMessage != null) {
      // Synced into the app, but the upload to Supabase didn't finish. Surface
      // it (instead of a false "success") so the user knows the workouts aren't
      // backed up yet; the controller retries automatically.
      MealvanaSnackbar.showWarning(context, state!.errorMessage!);
    } else if (result.hasChanges) {
      MealvanaSnackbar.showSuccess(context, message);
    } else {
      MealvanaSnackbar.showInfo(context, message);
    }

    if (mounted && result.success && state?.errorMessage == null) {
      setState(() {
        _vdotSynced = true;
      });
    }
  }

  Future<void> _disconnectVdot(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectVdot();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'V.O2 disconnected');
    }
  }

  // ============================================================
  // Runna (calendar feed) handlers
  // ============================================================

  /// Dialog explaining where to find the Runna calendar link, with a paste
  /// field. Returns the entered URL or null if cancelled.
  Future<String?> _showRunnaConnectDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => const _RunnaConnectDialog(),
    );
  }

  /// Shared connect flow (settings + onboarding): prompt for the feed URL,
  /// validate by fetching it, then auto-import — mirroring the V.O2 flow.
  Future<void> _connectRunna(BuildContext context, WidgetRef ref) async {
    final feedUrl = await _showRunnaConnectDialog(context);
    if (feedUrl == null || feedUrl.isEmpty || !context.mounted) return;

    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectRunna(feedUrl);

    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(connectTrainingControllerProvider).value;
      MealvanaSnackbar.showError(
        context,
        state?.errorMessage ?? 'Could not connect Runna',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    if (isOnboarding) {
      ref
          .read(onboardingControllerProvider.notifier)
          .recordConnectedProvider('runna');
    }

    MealvanaSnackbar.showSuccess(
      context,
      'Runna connected! Importing workouts...',
    );

    final result = await controller.importRunnaWorkouts();
    if (!context.mounted) return;

    final state = ref.read(connectTrainingControllerProvider).value;
    final message = buildWorkoutSyncMessage(
      newCount: result.newWorkouts,
      updatedCount: result.updated,
      deletedCount: result.deleted,
      unchangedCount: result.skipped,
    );

    if (!result.success) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
      );
    } else if (state?.errorMessage != null) {
      // Synced locally, but the Supabase upload didn't finish — surface it
      // instead of a false "success"; the controller retries automatically.
      MealvanaSnackbar.showWarning(context, state!.errorMessage!);
    } else if (result.hasChanges) {
      MealvanaSnackbar.showSuccess(context, message);
    } else {
      MealvanaSnackbar.showInfo(context, message);
    }

    if (mounted && result.success && state?.errorMessage == null) {
      setState(() {
        _runnaSynced = true;
      });
    }
  }

  Future<void> _disconnectRunna(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectRunna();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Runna disconnected');
    }
  }

  Future<void> _syncRunnaWithState(BuildContext context, WidgetRef ref) async {
    await syncRunna(context, ref, showLoadingSnackbar: false);

    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _runnaSynced = true;
      });
    }
  }

  Future<void> _syncVdotWithState(BuildContext context, WidgetRef ref) async {
    await syncVdot(context, ref, showLoadingSnackbar: false);

    final state = ref.read(connectTrainingControllerProvider).value;
    if (state?.errorMessage == null && mounted) {
      setState(() {
        _vdotSynced = true;
      });
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
}

/// Spec coming-soon row (onboarding only): provider name + italic
/// 'COMING SOON' on the left, outlined 'Notify Me' pill on the right, in
/// the same card chrome as the spec provider rows (radius 15, cream-5%
/// fill, 1px cream-12% border, padding 15/16, min-height 70).
class _ComingSoonSpecRow extends StatelessWidget {
  const _ComingSoonSpecRow({
    required this.name,
    required this.notifyKey,
    required this.isNotified,
    required this.onNotify,
  });

  final String name;
  final Key notifyKey;
  final bool isNotified;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.05),
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        border: Border.all(color: OnbTokens.creamA(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: OnbTokens.fontLabel,
                    fontSize: 15,
                    color: OnbTokens.creamA(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: OnbTokens.creamA(0.45),
                  ),
                ),
              ],
            ),
          ),
          // Outlined Notify Me pill; the 'Noted' disabled state keeps the
          // same chrome so the row doesn't shift.
          GestureDetector(
            key: notifyKey,
            onTap: isNotified ? null : onNotify,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(OnbTokens.rPill),
                border: Border.all(color: OnbTokens.creamA(0.75), width: 1.5),
              ),
              child: Text(
                isNotified ? 'Noted' : 'Notify Me',
                style: const TextStyle(
                  fontFamily: OnbTokens.fontBody,
                  fontSize: 14,
                  color: OnbTokens.cream,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spec declined tile (onboarding only): same card chrome as the provider
/// rows but min-height 47, with the italic fontLabel copy. Tapping it is an
/// affirmative "I don't use training plan apps" answer (survey flag +
/// analytics + advance) — wiring lives in the owning screen.
class _DeclinedTrainingAppsTile extends StatelessWidget {
  const _DeclinedTrainingAppsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OnbTokens.creamA(0.05),
      borderRadius: BorderRadius.circular(OnbTokens.rCard),
      child: InkWell(
        key: const ValueKey('connect_training.declined_tile'),
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 47),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OnbTokens.rCard),
            border: Border.all(color: OnbTokens.creamA(0.12)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            "I don't use training plan apps.",
            style: TextStyle(
              fontFamily: OnbTokens.fontLabel,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: OnbTokens.creamA(0.6),
            ),
          ),
        ),
      ),
    );
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

/// Paste-the-calendar-link dialog for Runna.
///
/// Stateful so the [TextEditingController] is owned by the dialog and disposed
/// in [State.dispose] — disposing it in a `finally` after `showDialog` returns
/// tears it down while the route is still animating out, and the still-mounted
/// [TextField] then throws "used after being disposed".
class _RunnaConnectDialog extends StatefulWidget {
  const _RunnaConnectDialog();

  @override
  State<_RunnaConnectDialog> createState() => _RunnaConnectDialogState();
}

class _RunnaConnectDialogState extends State<_RunnaConnectDialog> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _openRunnaSupportArticle() async {
    final uri = Uri.parse(RunnaDefaults.supportArticleUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    MealvanaSnackbar.showError(context, 'Could not open Runna\'s guide');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return AlertDialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        'Connect Runna',
        style: AppTextStyles.sectionTitle.copyWith(color: onSurface),
      ),
      // Scrollable: with the keyboard up the dialog's content box is short, and
      // a plain Column overflows instead of scrolling.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RunnaDefaults.feedUrlInstructions,
              style: AppTextStyles.bodySmall.copyWith(color: onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Runna owns this flow and renames screens from time to time; link
            // the canonical instructions rather than relying on our copy.
            GestureDetector(
              key: const ValueKey('connected_apps.runna_help_link'),
              onTap: _openRunnaSupportArticle,
              child: Text(
                'Can\'t find it? See Runna\'s guide',
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('connected_apps.runna_url_field'),
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: AppTextStyles.bodySmall.copyWith(color: onSurface),
              decoration: const InputDecoration(
                hintText: 'webcal://... or https://...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('connected_apps.runna_connect_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('connected_apps.runna_connect_confirm'),
          onPressed: () =>
              Navigator.of(context).pop(_urlController.text.trim()),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
