import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../../domain/allergy.dart';
import '../../../auth/application/auth_service.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/core/screen_mode.dart';
import '../../../../shared/widgets/selection/figma_checkbox_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';

/// Allergies Screen - Unified for both onboarding and settings
///
/// Allows users to select their food allergies (multi-select):
/// - Dairy, Eggs, Fish, Gluten, Peanuts, Sesame, Shellfish, Soy, Tree nuts
///
/// This screen adapts its behavior based on the [mode] parameter:
/// - [ScreenMode.onboarding]: Shows progress bar and navigates forward in flow (dark theme)
/// - [ScreenMode.settings]: Shows app bar with save button and pops when done (light theme)
class AllergiesScreen extends ConsumerStatefulWidget {
  const AllergiesScreen({
    super.key,
    this.mode = ScreenMode.onboarding,
    this.onContinue,
    this.onBack,
  });

  /// The screen mode determines visual style and navigation behavior
  final ScreenMode mode;

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  @override
  ConsumerState<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends ConsumerState<AllergiesScreen> {
  final Set<Allergy> _selectedAllergies = {};
  Set<Allergy> _originalAllergies = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _noAllergies = false;

  bool get _isOnboarding => widget.mode == ScreenMode.onboarding;
  bool get _isSettings => widget.mode == ScreenMode.settings;

  @override
  void initState() {
    super.initState();
    final screenName = _isOnboarding
        ? 'Allergies Onboarding'
        : 'Allergies Settings';
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': screenName,
    });

    // In onboarding mode, initialize from cache
    if (_isOnboarding) {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final cachedAllergies = controller.cachedAllergies;
      if (cachedAllergies != null && cachedAllergies.isNotEmpty) {
        _selectedAllergies.addAll(cachedAllergies);
        _noAllergies = false;
      }
    }

    // In settings mode, load the current allergies
    if (_isSettings) {
      _loadCurrentAllergies();
    }
  }

  Future<void> _loadCurrentAllergies() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();

      if (mounted) {
        setState(() {
          if (user?.allergies != null && user!.allergies.isNotEmpty) {
            _selectedAllergies.addAll(user.allergies);
            _originalAllergies = Set.from(user.allergies);
            _noAllergies = false;
          } else {
            // Empty allergies list means "No allergies"
            _noAllergies = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasChanges {
    if (_selectedAllergies.length != _originalAllergies.length) return true;
    return !_selectedAllergies.every((a) => _originalAllergies.contains(a));
  }

  void _toggleAllergy(Allergy allergy) {
    setState(() {
      if (_selectedAllergies.contains(allergy)) {
        _selectedAllergies.remove(allergy);
      } else {
        _selectedAllergies.add(allergy);
        // When any allergen is selected, deselect "No allergies"
        _noAllergies = false;
      }
    });
  }

  void _toggleNoAllergies() {
    setState(() {
      _noAllergies = !_noAllergies;
      if (_noAllergies) {
        // When "No allergies" is selected, clear all allergen selections
        _selectedAllergies.clear();
      }
    });
  }

  void _continue() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(onboardingControllerProvider.notifier);

      if (_isOnboarding) {
        // ONBOARDING MODE: Cache allergies
        controller.cacheAllergies(_selectedAllergies.toList());

        if (!mounted) return;

        // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
        if (widget.onContinue != null) {
          widget.onContinue!();
        } else {
          // Navigate to food preferences
          context.push('/onboarding/food-preferences-v2', extra: {
            'allergies': _selectedAllergies.toList(),
          });
        }
      } else {
        // SETTINGS MODE: Save to database
        final success = await controller.saveAllergies(_selectedAllergies.toList());

        if (!mounted) return;

        if (success) {
          final analytics = ref.read(appExternalDepsProvider);
          await analytics.analytics.track('allergies_changed', properties: {
            'from_count': _originalAllergies.length,
            'to_count': _selectedAllergies.length,
            'allergies': _selectedAllergies.map((a) => a.name).toList(),
            'source': 'settings',
          });

          if (!mounted) return;

          // Invalidate settings controller to refresh the food preferences hub screen
          ref.invalidate(settingsControllerProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allergies updated'),
              backgroundColor: AppColors.electrolyte,
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save allergies. Please try again.'),
              backgroundColor: AppColors.dragonfruit,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _skip() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Save empty allergies via controller (skip)
      final controller = ref.read(onboardingControllerProvider.notifier);
      await controller.saveAllergies([]);

      if (!mounted) return;

      // Navigate to food preferences without allergies
      context.push('/onboarding/food-preferences-v2');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clearAll() {
    setState(() {
      _selectedAllergies.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use the same dark Figma layout for both onboarding and settings
    return _buildDarkLayout(context);
  }

  // ==================== Dark Figma Layout (Onboarding & Settings) ====================

  Widget _buildDarkLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Column(
        children: [
          // Progress bar for onboarding, back button for settings
          Container(
            color: AppColors.blackberry,
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
                          'Allergies',
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
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            const SizedBox(height: 22),

                            const Text(
                              'Do you have any allergies?',
                              style: TextStyle(
                                fontFamily: 'Sansita',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                                height: 1.0,
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Allergy options
                            _buildDarkAllergyOptions(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Navigation footer
          FigmaOnboardingFooter(
            onContinue: _continue,
            onBack: _isOnboarding
                ? (widget.onBack ?? () => context.pop())
                : null,
            isLoading: _isSaving,
            buttonText: _isSettings ? 'Save' : 'Continue',
            showBackButton: _isOnboarding,
          ),
        ],
      ),
    );
  }

  // ==================== Shared Components ====================

  // Dark theme allergy options (used for both onboarding and settings)
  Widget _buildDarkAllergyOptions() {
    return Column(
      children: [
        // "No allergies" option at the top
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FigmaCheckboxCard(
            label: 'No allergies',
            isSelected: _noAllergies,
            onTap: _toggleNoAllergies,
          ),
        ),

        // Individual allergen options
        ...Allergy.values.map((allergy) {
          final isSelected = _selectedAllergies.contains(allergy);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FigmaCheckboxCard(
              label: allergy.displayName,
              isSelected: isSelected,
              onTap: () => _toggleAllergy(allergy),
            ),
          );
        }),
      ],
    );
  }

  String _getEmoji(Allergy allergy) {
    switch (allergy) {
      case Allergy.dairy:
        return '🥛';
      case Allergy.eggs:
        return '🥚';
      case Allergy.fish:
        return '🐟';
      case Allergy.gluten:
        return '🌾';
      case Allergy.peanuts:
        return '🥜';
      case Allergy.sesame:
        return '🌱';
      case Allergy.shellfish:
        return '🦐';
      case Allergy.soy:
        return '🫘';
      case Allergy.treeNuts:
        return '🌰';
    }
  }
}
