import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../onboarding/domain/dietary_preference.dart';
import '../../../onboarding/domain/allergy.dart';
import '../../../auth/application/auth_service.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/selection/figma_radio_option_card.dart';
import '../../../../shared/widgets/selection/figma_checkbox_card.dart';

/// Consolidated Food Settings Screen
///
/// Combines three food-related settings into one screen:
/// 1. Dietary Preference (single-select)
/// 2. Allergies (multi-select)
/// 3. Food Preferences (like/dislike with levels)
///
/// This provides a streamlined settings experience for all food-related options.
class FoodSettingsConsolidatedScreen extends ConsumerStatefulWidget {
  const FoodSettingsConsolidatedScreen({super.key});

  @override
  ConsumerState<FoodSettingsConsolidatedScreen> createState() => _FoodSettingsConsolidatedScreenState();
}

class _FoodSettingsConsolidatedScreenState extends ConsumerState<FoodSettingsConsolidatedScreen> {
  // State for dietary preference
  DietaryPreference? _selectedDietaryPreference;
  DietaryPreference? _originalDietaryPreference;

  // State for allergies
  final Set<Allergy> _selectedAllergies = {};
  Set<Allergy> _originalAllergies = {};

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;

  // Section expansion states
  bool _dietaryPreferenceExpanded = true;
  bool _allergiesExpanded = true;

  @override
  void initState() {
    super.initState();
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Food Settings Consolidated',
    });
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();

      if (mounted) {
        setState(() {
          // Load dietary preference
          _selectedDietaryPreference = user?.dietaryPreference;
          _originalDietaryPreference = user?.dietaryPreference;

          // Load allergies
          if (user?.allergies != null) {
            _selectedAllergies.addAll(user!.allergies);
            _originalAllergies = Set.from(user.allergies);
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
    // Check if dietary preference changed
    if (_selectedDietaryPreference != _originalDietaryPreference) return true;

    // Check if allergies changed
    if (_selectedAllergies.length != _originalAllergies.length) return true;
    if (!_selectedAllergies.every((a) => _originalAllergies.contains(a))) return true;

    return false;
  }

  Future<void> _saveAllSettings() async {
    if (_isSaving || !_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(onboardingControllerProvider.notifier);

      // Save dietary preference
      final dietSuccess = await controller.saveDietaryPreference(_selectedDietaryPreference);

      // Save allergies
      final allergySuccess = await controller.saveAllergies(_selectedAllergies.toList());

      if (!mounted) return;

      if (dietSuccess && allergySuccess) {
        // Track changes
        final analytics = ref.read(appExternalDepsProvider);

        if (_selectedDietaryPreference != _originalDietaryPreference) {
          analytics.analytics.track('dietary_preference_changed', properties: {
            'from': _originalDietaryPreference?.name ?? 'none',
            'to': _selectedDietaryPreference?.name ?? 'none',
            'source': 'consolidated_settings',
          });
        }

        if (_selectedAllergies != _originalAllergies) {
          analytics.analytics.track('allergies_changed', properties: {
            'from_count': _originalAllergies.length,
            'to_count': _selectedAllergies.length,
            'allergies': _selectedAllergies.map((a) => a.name).toList(),
            'source': 'consolidated_settings',
          });
        }

        MealvanaSnackbar.showSuccess(context, 'Food preferences updated successfully');
        context.pop();
      } else {
        MealvanaSnackbar.showError(context, 'Failed to save preferences. Please try again.');
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
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            _buildHeader(),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Section 1: Dietary Preference
                    _buildDietaryPreferenceSection(),

                    const SizedBox(height: 24),

                    // Section 2: Allergies
                    _buildAllergiesSection(),

                    const SizedBox(height: 24),

                    // Section 3: Food Preferences (link to existing screen)
                    _buildFoodPreferencesSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Save button at bottom
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
          const Expanded(
            child: Text(
              'Food Preferences',
              style: TextStyle(
                fontFamily: 'Sansita',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferenceSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          GestureDetector(
            onTap: () {
              setState(() {
                _dietaryPreferenceExpanded = !_dietaryPreferenceExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.leaf,
                  color: AppColors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dietary Preference',
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                Icon(
                  _dietaryPreferenceExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.orange,
                  size: 24,
                ),
              ],
            ),
          ),

          if (_dietaryPreferenceExpanded) ...[
            const SizedBox(height: 16),

            // Subtitle
            const Text(
              'Select your dietary preference (optional)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.cream,
              ),
            ),

            const SizedBox(height: 16),

            // Dietary preference options (using allValues to exclude 'none')
            FigmaRadioOptionList<DietaryPreference>(
              items: DietaryPreference.allValues.map((diet) {
                return FigmaRadioOptionItem(
                  value: diet,
                  label: diet.displayName,
                );
              }).toList(),
              selectedValue: _selectedDietaryPreference,
              onSelected: (value) {
                setState(() {
                  _selectedDietaryPreference = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllergiesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          GestureDetector(
            onTap: () {
              setState(() {
                _allergiesExpanded = !_allergiesExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.triangleExclamation,
                  color: AppColors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Allergies',
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                Icon(
                  _allergiesExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.orange,
                  size: 24,
                ),
              ],
            ),
          ),

          if (_allergiesExpanded) ...[
            const SizedBox(height: 16),

            // Subtitle
            Text(
              _selectedAllergies.isEmpty
                  ? 'No allergies selected'
                  : '${_selectedAllergies.length} ${_selectedAllergies.length == 1 ? 'allergy' : 'allergies'} selected',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.cream,
              ),
            ),

            const SizedBox(height: 16),

            // Allergy options
            Column(
              children: Allergy.values.map((allergy) {
                final isSelected = _selectedAllergies.contains(allergy);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FigmaCheckboxCard(
                    label: allergy.displayName,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedAllergies.remove(allergy);
                        } else {
                          _selectedAllergies.add(allergy);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to existing food preferences screen
          context.push('/settings/food-preferences');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(
                FontAwesomeIcons.utensils,
                color: AppColors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Food Likes & Dislikes',
                      style: TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage your specific food preferences',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.orange,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: KylePrimaryButton(
          text: 'Save Changes',
          onPressed: _hasChanges && !_isSaving ? _saveAllSettings : null,
          isLoading: _isSaving,
        ),
      ),
    );
  }
}
