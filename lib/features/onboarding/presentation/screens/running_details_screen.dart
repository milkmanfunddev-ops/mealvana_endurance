import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/selection/figma_toggle_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../shared/core/screen_mode.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Running Details Screen - Unified for both onboarding and settings
///
/// Collects running-specific preferences:
/// - Water bottle usage during runs
///
/// This screen adapts its behavior based on the [mode] parameter:
/// - [ScreenMode.onboarding]: Shows progress bar and navigates forward in flow
/// - [ScreenMode.settings]: Shows back button and saves/pops when done
class RunningDetailsScreen extends ConsumerStatefulWidget {
  const RunningDetailsScreen({
    super.key,
    this.selectedSports = const [],
    this.mode = ScreenMode.onboarding,
    this.onContinue,
    this.onBack,
  });

  /// List of all selected sports (passed from sports selection in onboarding)
  final List<String> selectedSports;

  /// The screen mode determines visual style and navigation behavior
  final ScreenMode mode;

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  @override
  ConsumerState<RunningDetailsScreen> createState() =>
      _RunningDetailsScreenState();
}

class _RunningDetailsScreenState extends ConsumerState<RunningDetailsScreen> {
  // Running preferences
  bool _runsWithWaterBottle = false;
  bool _originalRunsWithWaterBottle = false;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isOnboarding => widget.mode == ScreenMode.onboarding;
  bool get _isSettings => widget.mode == ScreenMode.settings;
  bool get _hasChanges => _runsWithWaterBottle != _originalRunsWithWaterBottle;

  @override
  void initState() {
    super.initState();
    final screenName = _isOnboarding
        ? 'Running Details Onboarding'
        : 'Running Details Settings';
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track('screen_viewed', properties: {'screen_name': screenName});

    // In onboarding mode, initialize from cache
    if (_isOnboarding) {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final cachedPrefs = controller.cachedSportPreferences;
      if (cachedPrefs != null && cachedPrefs.containsKey('giSensitivity')) {
        final giSensitivity = cachedPrefs['giSensitivity'] as bool?;
        if (giSensitivity != null) {
          _runsWithWaterBottle = !giSensitivity;
        }
      }
    }

    // In settings mode, load the current preference
    if (_isSettings) {
      _loadCurrentPreferences();
    }
  }

  Future<void> _loadCurrentPreferences() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();

      if (mounted) {
        setState(() {
          _runsWithWaterBottle = user?.runsWithWaterBottle ?? false;
          _originalRunsWithWaterBottle = user?.runsWithWaterBottle ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _continue() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final giSensitivity = !_runsWithWaterBottle;
      final controller = ref.read(onboardingControllerProvider.notifier);
      final analytics = ref.read(appExternalDepsProvider).analytics;

      if (_isOnboarding) {
        // ONBOARDING MODE: Just cache data, don't save
        controller.cacheSportPreferences(giSensitivity: giSensitivity);

        // Track analytics (fire-and-forget)
        unawaited(
          analytics.track(
            'running_details_completed',
            properties: {
              'runs_with_water_bottle': _runsWithWaterBottle,
              'gi_sensitivity': giSensitivity,
            },
          ),
        );

        if (!mounted) return;

        // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
        if (widget.onContinue != null) {
          widget.onContinue!();
        } else {
          // Navigate to next sport detail screen or dietary preferences
          if (widget.selectedSports.contains('cycling')) {
            context.push(
              '/onboarding/cycling-details',
              extra: widget.selectedSports,
            );
          } else if (widget.selectedSports.contains('swimming')) {
            context.push(
              '/onboarding/swimming-details',
              extra: widget.selectedSports,
            );
          } else {
            context.push('/onboarding/dietary-preference');
          }
        }
      } else {
        // SETTINGS MODE: Save to database
        final success = await controller.saveSportPreferences(
          giSensitivity: giSensitivity,
          ftpWatts: null,
          typicalBikeBottles: null,
          hasAeroBottle: null,
          hasBentoBox: null,
          cssPacePer100mSeconds: null,
          typicalWetsuit: null,
          typicalSwimCapType: null,
        );

        if (!mounted) return;

        if (success) {
          unawaited(
            analytics.track(
              'running_details_changed',
              properties: {
                'from': _originalRunsWithWaterBottle,
                'to': _runsWithWaterBottle,
                'gi_sensitivity': giSensitivity,
                'source': 'settings',
              },
            ),
          );

          if (!mounted) return;

          MealvanaSnackbar.showSuccess(context, 'Running details updated');
          context.pop();
        } else {
          MealvanaSnackbar.showError(
            context,
            'Failed to save running details. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.blackberry,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }

    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar for onboarding, back button for settings
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: _isOnboarding
                ? const OnboardingProgressBar(
                    currentSegment: 2, // Still in Sports + Details segment
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onBack ?? () => context.pop(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.orange,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Running Details',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Content
          Expanded(
            child: AdaptiveScrollableBody(
              safeAreaTop: false,
              safeAreaBottom: false,
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      'Running details',
                      style: TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    const Text(
                      'Help us estimate your hydration needs.',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDark,
                        letterSpacing: 0.192,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Water bottle toggle
                    FigmaToggleCard(
                      label: 'I run with a water bottle',
                      value: _runsWithWaterBottle,
                      onChanged: (value) =>
                          setState(() => _runsWithWaterBottle = value),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: _continue,
            onBack: _isOnboarding
                ? (widget.onBack ?? () => context.pop())
                : null,
            canContinue: true,
            isLoading: _isSaving,
            buttonText: _isSettings ? 'Save' : 'Continue',
            showBackButton: _isOnboarding,
          ),
        ],
      ),
    );
  }
}
