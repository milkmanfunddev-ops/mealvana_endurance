import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/core/screen_mode.dart';
import '../../../../shared/widgets/selection/figma_toggle_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Cycling Details Screen - Unified for both onboarding and settings
///
/// Collects cycling-specific preferences:
/// - FTP (Functional Threshold Power)
/// - Number of water bottles
/// - Aero bottle availability
/// - Bento box availability
///
/// This screen adapts its behavior based on the [mode] parameter:
/// - [ScreenMode.onboarding]: Shows progress bar and navigates forward in flow
/// - [ScreenMode.settings]: Shows back button and saves/pops when done
class CyclingDetailsScreen extends ConsumerStatefulWidget {
  const CyclingDetailsScreen({
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
  ConsumerState<CyclingDetailsScreen> createState() => _CyclingDetailsScreenState();
}

class _CyclingDetailsScreenState extends ConsumerState<CyclingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ftpController = TextEditingController(text: '0');

  // Cycling preferences
  int _bikeBottles = 2;
  bool _hasAeroBottle = false;
  bool _hasBentoBox = false;

  // Settings mode state
  int _originalBikeBottles = 2;
  bool _originalHasAeroBottle = false;
  bool _originalHasBentoBox = false;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isOnboarding => widget.mode == ScreenMode.onboarding;
  bool get _isSettings => widget.mode == ScreenMode.settings;
  bool get _hasChanges =>
      _bikeBottles != _originalBikeBottles ||
      _hasAeroBottle != _originalHasAeroBottle ||
      _hasBentoBox != _originalHasBentoBox;

  @override
  void initState() {
    super.initState();
    final screenName = _isOnboarding
        ? 'Cycling Details Onboarding'
        : 'Cycling Details Settings';
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': screenName,
    });

    // In onboarding mode, initialize from cache
    if (_isOnboarding) {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final cachedPrefs = controller.cachedSportPreferences;
      if (cachedPrefs != null) {
        final ftpWatts = cachedPrefs['ftpWatts'] as int?;
        if (ftpWatts != null) {
          _ftpController.text = ftpWatts.toString();
        }
        final typicalBikeBottles = cachedPrefs['typicalBikeBottles'] as int?;
        if (typicalBikeBottles != null) {
          _bikeBottles = typicalBikeBottles;
        }
        final hasAeroBottle = cachedPrefs['hasAeroBottle'] as bool?;
        if (hasAeroBottle != null) {
          _hasAeroBottle = hasAeroBottle;
        }
        final hasBentoBox = cachedPrefs['hasBentoBox'] as bool?;
        if (hasBentoBox != null) {
          _hasBentoBox = hasBentoBox;
        }
      }
    }

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
          // Load FTP from user profile (if available)
          if (user?.ftpWatts != null) {
            _ftpController.text = user!.ftpWatts.toString();
          } else {
            _ftpController.text = '0';
          }

          // Load cycling gear preferences (Drift-only fields, might be null)
          _bikeBottles = user?.typicalBikeBottles ?? 2;
          _originalBikeBottles = user?.typicalBikeBottles ?? 2;
          _hasAeroBottle = user?.hasAeroBottle ?? false;
          _originalHasAeroBottle = user?.hasAeroBottle ?? false;
          _hasBentoBox = user?.hasBentoBox ?? false;
          _originalHasBentoBox = user?.hasBentoBox ?? false;

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
    _ftpController.dispose();
    super.dispose();
  }

  void _continue() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final analytics = ref.read(appExternalDepsProvider).analytics;
      final ftpWatts = int.tryParse(_ftpController.text) ?? 0;

      if (_isOnboarding) {
        // ONBOARDING MODE: Just cache data
        controller.cacheSportPreferences(
          ftpWatts: ftpWatts,
          typicalBikeBottles: _bikeBottles,
          hasAeroBottle: _hasAeroBottle,
          hasBentoBox: _hasBentoBox,
        );

        unawaited(analytics.track('cycling_details_completed', properties: {
          'ftp_watts': ftpWatts,
          'bike_bottles': _bikeBottles,
          'has_aero_bottle': _hasAeroBottle,
          'has_bento_box': _hasBentoBox,
        }));

        if (!mounted) return;

        // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
        if (widget.onContinue != null) {
          widget.onContinue!();
        } else {
          // Navigate to next screen
          if (widget.selectedSports.contains('swimming')) {
            context.push('/onboarding/swimming-details', extra: widget.selectedSports);
          } else {
            context.push('/onboarding/dietary-preference');
          }
        }
      } else {
        // SETTINGS MODE: Save to database
        final success = await controller.saveSportPreferences(
          ftpWatts: ftpWatts,
          typicalBikeBottles: _bikeBottles,
          hasAeroBottle: _hasAeroBottle,
          hasBentoBox: _hasBentoBox,
          giSensitivity: null,
          cssPacePer100mSeconds: null,
          typicalWetsuit: null,
          typicalSwimCapType: null,
        );

        if (!mounted) return;

        if (success) {
          unawaited(analytics.track('cycling_details_changed', properties: {
            'ftp_watts': ftpWatts,
            'bike_bottles': _bikeBottles,
            'has_aero_bottle': _hasAeroBottle,
            'has_bento_box': _hasBentoBox,
            'source': 'settings',
          }));

          if (!mounted) return;

          MealvanaSnackbar.showSuccess(context, 'Cycling details updated');
          context.pop();
        } else {
          MealvanaSnackbar.showError(context, 'Failed to save cycling details. Please try again.');
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
          child: CircularProgressIndicator(
            color: AppColors.orange,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.blackberry,
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
                            'Cycling Details',
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

            // Scrollable content
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          'Cycling details',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                            height: 1.0,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // FTP Section
                        _FTPSection(
                          controller: _ftpController,
                          figmaCream: AppColors.textDark,
                        ),

                        const SizedBox(height: 28),

                        // Water bottles section
                        _WaterBottlesSection(
                          selectedValue: _bikeBottles,
                          onSelected: (value) => setState(() => _bikeBottles = value),
                          figmaCream: AppColors.textDark,
                          figmaElectrolyte: AppColors.electrolyte,
                        ),

                        const SizedBox(height: 16),

                        // Aero bottle toggle
                        FigmaToggleCard(
                          label: 'I use Aero Bottles',
                          value: _hasAeroBottle,
                          onChanged: (value) => setState(() => _hasAeroBottle = value),
                        ),

                        const SizedBox(height: 16),

                        // Bento box toggle
                        FigmaToggleCard(
                          label: 'I use a Bento Box for food',
                          value: _hasBentoBox,
                          onChanged: (value) => setState(() => _hasBentoBox = value),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation footer
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
      ),
    );
  }
}

/// FTP input section matching Figma design
class _FTPSection extends StatelessWidget {
  const _FTPSection({
    required this.controller,
    required this.figmaCream,
  });

  final TextEditingController controller;
  final Color figmaCream;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'FTP (Functional Threshold Power)',
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
          'Maximum power you can sustain for ~1 hour. Enter 0 if unknown.',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: figmaCream,
            height: 1.0,
            letterSpacing: 0.192,
          ),
        ),

        const SizedBox(height: 16),

        // Input field with background container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: figmaCream.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
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
                    hintText: '0',
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
                    final ftp = int.tryParse(value!);
                    if (ftp == null || ftp < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'watts',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: figmaCream.withValues(alpha: 0.4),
                  height: 1.2,
                  letterSpacing: 0.24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Water bottles segmented selector matching Figma design
class _WaterBottlesSection extends StatelessWidget {
  const _WaterBottlesSection({
    required this.selectedValue,
    required this.onSelected,
    required this.figmaCream,
    required this.figmaElectrolyte,
  });

  final int selectedValue;
  final void Function(int) onSelected;
  final Color figmaCream;
  final Color figmaElectrolyte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'How many water bottles do you use?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: figmaCream,
            height: 1.2,
            letterSpacing: 0.24,
          ),
        ),

        const SizedBox(height: 16),

        // Buttons
        Row(
          children: [
            Expanded(
              child: _WaterBottleButton(
                label: '1',
                value: 1,
                isSelected: selectedValue == 1,
                onTap: () => onSelected(1),
                figmaCream: figmaCream,
                figmaElectrolyte: figmaElectrolyte,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WaterBottleButton(
                label: '2',
                value: 2,
                isSelected: selectedValue == 2,
                onTap: () => onSelected(2),
                figmaCream: figmaCream,
                figmaElectrolyte: figmaElectrolyte,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WaterBottleButton(
                label: '3+',
                value: 3,
                isSelected: selectedValue >= 3,
                onTap: () => onSelected(3),
                figmaCream: figmaCream,
                figmaElectrolyte: figmaElectrolyte,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WaterBottleButton extends StatelessWidget {
  const _WaterBottleButton({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.figmaCream,
    required this.figmaElectrolyte,
  });

  final String label;
  final int value;
  final bool isSelected;
  final VoidCallback onTap;
  final Color figmaCream;
  final Color figmaElectrolyte;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? figmaElectrolyte.withValues(alpha: 0.28)
              : figmaCream.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected
                ? figmaElectrolyte.withValues(alpha: 0.2)
                : figmaCream.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: figmaCream,
              height: 1.2,
              letterSpacing: 0.24,
            ),
          ),
        ),
      ),
    );
  }
}
