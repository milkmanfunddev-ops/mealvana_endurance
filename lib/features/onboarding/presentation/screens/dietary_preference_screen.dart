import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../../domain/dietary_preference.dart';
import '../../../auth/application/auth_service.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/core/screen_mode.dart';
import '../../../../shared/widgets/selection/figma_radio_option_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Dietary Preference Screen - Unified for both onboarding and settings
///
/// Allows users to select their dietary preference (single-select):
/// - Omnivore, Vegetarian, Pescatarian, Vegan, Mediterranean, Paleo, Keto, Low-Carb
///
/// This screen adapts its behavior based on the [mode] parameter:
/// - [ScreenMode.onboarding]: Shows progress bar and navigates forward in flow
/// - [ScreenMode.settings]: Shows app bar with save button and pops when done
class DietaryPreferenceScreen extends ConsumerStatefulWidget {
  const DietaryPreferenceScreen({
    super.key,
    this.mode = ScreenMode.onboarding,
    this.onContinue,
    this.onBack,
    this.stepIndex,
  });

  /// The screen mode determines visual style and navigation behavior
  final ScreenMode mode;

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null in settings mode, where the
  /// screen is not part of a funnel.
  final int? stepIndex;

  @override
  ConsumerState<DietaryPreferenceScreen> createState() =>
      _DietaryPreferenceScreenState();
}

class _DietaryPreferenceScreenState
    extends ConsumerState<DietaryPreferenceScreen> {
  DietaryPreference? _selectedPreference;
  DietaryPreference? _originalPreference;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isOnboarding => widget.mode == ScreenMode.onboarding;
  bool get _isSettings => widget.mode == ScreenMode.settings;

  @override
  void initState() {
    super.initState();
    final screenName = _isOnboarding
        ? 'Dietary Preference Onboarding'
        : 'Dietary Preference Settings';
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': screenName,
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );

    // In settings mode, load the current preference
    if (_isSettings) {
      _loadCurrentPreference();
    }
  }

  Future<void> _loadCurrentPreference() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();

      if (mounted) {
        setState(() {
          _selectedPreference = user?.dietaryPreference;
          _originalPreference = user?.dietaryPreference;
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
      final controller = ref.read(onboardingControllerProvider.notifier);

      if (_isOnboarding) {
        // ONBOARDING MODE (legacy — diet left the onboarding flow in the
        // 2026-08 redesign; saveAllOnboardingData writes the omnivore
        // default). Nothing to persist here; just advance if hosted.
        if (!mounted) return;
        widget.onContinue?.call();
      } else {
        // SETTINGS MODE: Save to database
        final success = await controller.saveDietaryPreference(
          _selectedPreference,
        );

        if (!mounted) return;

        if (success) {
          final analytics = ref.read(appExternalDepsProvider);
          await analytics.analytics.track(
            'dietary_preference_changed',
            properties: {
              'from': _originalPreference?.name ?? 'none',
              'to': _selectedPreference?.name ?? 'none',
              'source': 'settings',
            },
          );

          if (!mounted) return;

          // Invalidate settings controller to refresh the food preferences hub screen
          ref.invalidate(settingsControllerProvider);

          MealvanaSnackbar.showSuccess(context, 'Dietary preference updated');
          if (context.canPop()) context.pop();
        } else {
          MealvanaSnackbar.showError(
            context,
            'Failed to save dietary preference. Please try again.',
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
    final useDarkStyle = Theme.of(context).brightness == Brightness.dark;
    return _buildAdaptiveLayout(context, useDarkStyle: useDarkStyle);
  }

  // ==================== Adaptive Layout (Dark + Light Theme) ====================

  Widget _buildAdaptiveLayout(
    BuildContext context, {
    required bool useDarkStyle,
  }) {
    final theme = Theme.of(context);
    final backgroundColor = useDarkStyle
        ? AppColors.blackberry
        : theme.scaffoldBackgroundColor;
    final titleColor = useDarkStyle
        ? AppColors.orange
        : theme.colorScheme.onSurface;

    return AdaptivePageScaffold(
      backgroundColor: backgroundColor,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar for onboarding, back button for settings
          Container(
            color: backgroundColor,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: _isOnboarding
                ? const OnboardingProgressBar(
                    currentSegment: 3, // Diet + Allergies segment
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap:
                              widget.onBack ??
                              () {
                                if (context.canPop()) context.pop();
                              },
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
                        Text(
                          'Dietary Preference',
                          style: const TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ).copyWith(color: titleColor),
                        ),
                      ],
                    ),
                  ),
          ),

          // Content - vertically centered
          Expanded(
            child: AdaptiveScrollableBody(
              safeAreaTop: false,
              safeAreaBottom: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const SizedBox(height: 24),
                  Text(
                    key: const ValueKey('dietary_preference.title'),
                    'What is your dietary preference?',
                    style: const TextStyle(
                      fontFamily: 'Sansita',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ).copyWith(color: titleColor),
                  ),

                  const SizedBox(height: 28),

                  // Diet options
                  _buildFigmaDietOptions(useDarkStyle: useDarkStyle),
                ],
              ),
            ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: _continue,
            onBack: _isOnboarding
                ? (widget.onBack ??
                      () {
                        if (context.canPop()) context.pop();
                      })
                : null,
            canContinue: true, // Always allow continue/skip
            isLoading: _isSaving,
            buttonText: _isSettings ? 'Save' : 'Continue',
            showBackButton: _isOnboarding,
            continueButtonKey: const ValueKey(
              'dietary_preference.continue_button',
            ),
            backButtonKey: const ValueKey('dietary_preference.back_button'),
          ),
        ],
      ),
    );
  }

  // ==================== Shared Components ====================

  Widget _buildFigmaDietOptions({required bool useDarkStyle}) {
    // Use ordered list with omnivore first, excluding 'none'
    return FigmaRadioOptionList<DietaryPreference>(
      items: DietaryPreference.orderedForOnboarding.map((diet) {
        return FigmaRadioOptionItem(
          value: diet,
          label: diet.displayName,
          valueKey: ValueKey('dietary_preference.${diet.name}_chip'),
        );
      }).toList(),
      selectedValue: _selectedPreference,
      onSelected: (value) => setState(() => _selectedPreference = value),
      useDarkStyle: useDarkStyle,
    );
  }
}
