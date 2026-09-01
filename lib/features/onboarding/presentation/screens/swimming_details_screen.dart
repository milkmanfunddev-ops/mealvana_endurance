import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/selection/figma_toggle_card.dart';
import '../../../../shared/widgets/selection/figma_radio_option_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../shared/core/screen_mode.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Swimming Details Screen - Unified for both onboarding and settings
///
/// Collects swimming-specific preferences:
/// - CSS (Critical Swim Speed) per 100m
/// - Wetsuit usage
/// - Swim cap type
///
/// This screen adapts its behavior based on the [mode] parameter:
/// - [ScreenMode.onboarding]: Shows progress bar and navigates forward in flow
/// - [ScreenMode.settings]: Shows back button and saves/pops when done
class SwimmingDetailsScreen extends ConsumerStatefulWidget {
  const SwimmingDetailsScreen({
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
  ConsumerState<SwimmingDetailsScreen> createState() =>
      _SwimmingDetailsScreenState();
}

class _SwimmingDetailsScreenState extends ConsumerState<SwimmingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cssMinutesController = TextEditingController();
  final _cssSecondsController = TextEditingController();

  // Swimming preferences
  bool _typicalWetsuit = false;
  String _swimCapType = 'none';

  // For settings mode - track original values
  int _originalCssMinutes = 0;
  int _originalCssSeconds = 0;
  bool _originalTypicalWetsuit = false;
  String _originalSwimCapType = 'none';
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isOnboarding => widget.mode == ScreenMode.onboarding;
  bool get _isSettings => widget.mode == ScreenMode.settings;

  @override
  void initState() {
    super.initState();
    final screenName = _isOnboarding
        ? 'Swimming Details Onboarding'
        : 'Swimming Details Settings';
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track('screen_viewed', properties: {'screen_name': screenName});

    // In settings mode, load the current preferences
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
          // Load CSS from user profile (if available)
          if (user?.cssPacePer100mSeconds != null) {
            final totalSeconds = user!.cssPacePer100mSeconds!;
            _cssMinutesController.text = (totalSeconds ~/ 60).toString();
            _cssSecondsController.text = (totalSeconds % 60).toString();
            _originalCssMinutes = totalSeconds ~/ 60;
            _originalCssSeconds = totalSeconds % 60;
          } else {
            // Defaults if not set
            _cssMinutesController.text = '2';
            _cssSecondsController.text = '30';
            _originalCssMinutes = 2;
            _originalCssSeconds = 30;
          }

          // Load wetsuit and swim cap type (Drift-only fields, might be null)
          _typicalWetsuit = user?.typicalWetsuit ?? false;
          _originalTypicalWetsuit = user?.typicalWetsuit ?? false;
          _swimCapType = user?.typicalSwimCapType ?? 'none';
          _originalSwimCapType = user?.typicalSwimCapType ?? 'none';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _cssMinutesController.dispose();
    _cssSecondsController.dispose();
    super.dispose();
  }

  int _calculateCssSeconds() {
    final minutes = int.tryParse(_cssMinutesController.text) ?? 0;
    final seconds = int.tryParse(_cssSecondsController.text) ?? 0;
    return minutes * 60 + seconds;
  }

  void _continue() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final cssSeconds = _calculateCssSeconds();

      if (_isOnboarding) {
        // ONBOARDING MODE (legacy — sport details left the onboarding flow in
        // the 2026-08 redesign; nothing to persist here).
        unawaited(
          analytics.track(
            'swimming_details_completed',
            properties: {
              'css_seconds': cssSeconds,
              'typical_wetsuit': _typicalWetsuit,
              'swim_cap_type': _swimCapType,
            },
          ),
        );

        if (!mounted) return;

        // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
        if (widget.onContinue != null) {
          widget.onContinue!();
        } else {
          // Navigate to dietary preference
          context.push('/onboarding/dietary-preference');
        }
      } else {
        // SETTINGS MODE: Save to database
        final success = await controller.saveSportPreferences(
          cssPacePer100mSeconds: cssSeconds,
          typicalWetsuit: _typicalWetsuit,
          typicalSwimCapType: _swimCapType,
          giSensitivity: null,
          ftpWatts: null,
          typicalBikeBottles: null,
          hasAeroBottle: null,
          hasBentoBox: null,
        );

        if (!mounted) return;

        if (success) {
          unawaited(
            analytics.track(
              'swimming_details_changed',
              properties: {
                'css_seconds': cssSeconds,
                'typical_wetsuit': _typicalWetsuit,
                'swim_cap_type': _swimCapType,
                'source': 'settings',
              },
            ),
          );

          if (!mounted) return;

          MealvanaSnackbar.showSuccess(context, 'Swimming details updated');
          context.pop();
        } else {
          MealvanaSnackbar.showError(
            context,
            'Failed to save swimming details. Please try again.',
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Progress bar for onboarding, back button for settings
            Container(
              color: AppColors.blackberry,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
              child: _isOnboarding
                  ? const OnboardingProgressBar(
                      currentSegment: 2, // Sports + Details segment
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            key: const ValueKey('swimming_prefs.back_button'),
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
                            'Swimming Details',
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

            // Scrollable content - vertically centered
            Expanded(
              child: AdaptiveScrollableBody(
                safeAreaTop: false,
                safeAreaBottom: false,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        const Text(
                          key: ValueKey('swimming_prefs.title'),
                          'Swimming details',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                            height: 1.0,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // CSS Section
                        _CSSSection(
                          minutesController: _cssMinutesController,
                          secondsController: _cssSecondsController,
                          figmaCream: AppColors.textDark,
                          minutesFieldKey: const ValueKey(
                            'swimming_prefs.css_minutes_field',
                          ),
                          secondsFieldKey: const ValueKey(
                            'swimming_prefs.css_seconds_field',
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Wetsuit toggle
                        FigmaToggleCard(
                          key: const ValueKey('swimming_prefs.wetsuit_toggle'),
                          label: 'I typically wear a wetsuit',
                          value: _typicalWetsuit,
                          onChanged: (value) =>
                              setState(() => _typicalWetsuit = value),
                        ),

                        const SizedBox(height: 28),

                        // Swim cap type
                        const Text(
                          'Swim Cap Type',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                            height: 1.2,
                            letterSpacing: 0.24,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Swim cap options
                        FigmaRadioOptionList<String>(
                          items: const [
                            FigmaRadioOptionItem(
                              value: 'none',
                              label: 'None',
                              valueKey: ValueKey(
                                'swimming_prefs.cap_none_button',
                              ),
                            ),
                            FigmaRadioOptionItem(
                              value: 'latex',
                              label: 'Latex',
                              valueKey: ValueKey(
                                'swimming_prefs.cap_latex_button',
                              ),
                            ),
                            FigmaRadioOptionItem(
                              value: 'silicone',
                              label: 'Silicone',
                              valueKey: ValueKey(
                                'swimming_prefs.cap_silicone_button',
                              ),
                            ),
                            FigmaRadioOptionItem(
                              value: 'neoprene',
                              label: 'Neoprene',
                              valueKey: ValueKey(
                                'swimming_prefs.cap_neoprene_button',
                              ),
                            ),
                          ],
                          selectedValue: _swimCapType,
                          onSelected: (value) =>
                              setState(() => _swimCapType = value),
                        ),
                      ],
                    ),
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
              continueButtonKey: const ValueKey('swimming_prefs.save_button'),
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS time input section matching Figma design
class _CSSSection extends StatelessWidget {
  const _CSSSection({
    required this.minutesController,
    required this.secondsController,
    required this.figmaCream,
    this.minutesFieldKey,
    this.secondsFieldKey,
  });

  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final Color figmaCream;
  final Key? minutesFieldKey;
  final Key? secondsFieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'CSS (Critical Swim Speed)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: figmaCream,
            height: 1.2,
            letterSpacing: 0.24,
          ),
        ),

        const SizedBox(height: 12),

        // Description
        Text(
          'Fastest pace per 100 meters you can sustain for 30 minutes. MM:SS format',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: figmaCream,
            height: 1.0,
            letterSpacing: 0.192,
          ),
        ),

        const SizedBox(height: 20),

        // Time input fields with separate background containers
        Row(
          children: [
            // Minutes field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: figmaCream.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  key: minutesFieldKey,
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: figmaCream,
                    height: 1.2,
                    letterSpacing: 0.24,
                  ),
                  decoration: InputDecoration(
                    hintText: 'minutes',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: figmaCream.withValues(alpha: 0.4),
                      height: 1.2,
                      letterSpacing: 0.24,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final minutes = int.tryParse(value!);
                    if (minutes == null || minutes < 0 || minutes > 10) {
                      return '0-10';
                    }
                    return null;
                  },
                ),
              ),
            ),

            // Colon separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: figmaCream.withValues(alpha: 0.4),
                  height: 1.2,
                  letterSpacing: 0.24,
                ),
              ),
            ),

            // Seconds field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: figmaCream.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  key: secondsFieldKey,
                  controller: secondsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: figmaCream,
                    height: 1.2,
                    letterSpacing: 0.24,
                  ),
                  decoration: InputDecoration(
                    hintText: 'seconds',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: figmaCream.withValues(alpha: 0.4),
                      height: 1.2,
                      letterSpacing: 0.24,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final seconds = int.tryParse(value!);
                    if (seconds == null || seconds < 0 || seconds >= 60) {
                      return '0-59';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
