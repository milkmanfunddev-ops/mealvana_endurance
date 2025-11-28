import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/data/user_repository.dart';

/// User Profile Screen - Design System
/// User setup screen during onboarding - RESTORED with database integration
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core fields (mapped to database)
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  Gender _selectedGender = Gender.male;
  DateTime? _selectedBirthday;
  bool _runsWithWaterBottle = false;

  // Future fields (not yet in database schema - commented out for future use)
  // final _nameController = TextEditingController();
  // String _selectedActivityLevel = 'Intermediate';
  // String _selectedGoal = 'Marathon';

  @override
  void initState() {
    super.initState();
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'User Profile Onboarding',
    });
  }

  @override
  void dispose() {
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    // _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(context, asyncState),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Your Profile',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AsyncValue<void> asyncState) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input fields
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SizedBox(height: AppSpacing.lg),

            // Introduction text
            Text(
              'Tell us about yourself',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This helps us calculate accurate nutrition plans for your activities.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Personal information section
            _buildPersonalInfoSection(context),

            const SizedBox(height: AppSpacing.lg),

            // Physical information section
            _buildPhysicalInfoSection(context),

            const SizedBox(height: AppSpacing.lg),

            // Running habits section
            _buildRunningHabitsSection(context),

            const SizedBox(height: AppSpacing.xxxl),

            // Error message if any
            if (asyncState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dragonfruit.withOpacity(0.1),
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: AppColors.dragonfruit),
                  ),
                  child: Row(
                    children: [
                      const Icon(FontAwesomeIcons.circleExclamation,
                        color: AppColors.dragonfruit,
                        size: AppIconSizes.controlIcon,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          asyncState.error.toString(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.dragonfruit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Continue button
            KylePrimaryButton(
              text: asyncState.isLoading ? 'Saving...' : 'Continue',
              onPressed: asyncState.isLoading ? null : _submitProfile,
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Gender selector
          _buildGenderSelector(context),

          const SizedBox(height: AppSpacing.md),

          // Birthday selector
          _buildBirthdaySelector(context),
        ],
      ),
    );
  }

  Widget _buildPhysicalInfoSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Physical Information',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Height fields (feet + inches)
          Text(
            'Height',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  context: context,
                  controller: _heightFeetController,
                  label: 'Feet',
                  hint: 'ft',
                  icon: FontAwesomeIcons.rulerVertical,
                  keyboardType: TextInputType.number,
                  suffix: 'ft',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final feet = int.tryParse(value);
                    if (feet == null || feet < 3 || feet > 8) {
                      return 'Valid: 3-8';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTextField(
                  context: context,
                  controller: _heightInchesController,
                  label: 'Inches',
                  hint: 'in',
                  icon: FontAwesomeIcons.rulerVertical,
                  keyboardType: TextInputType.number,
                  suffix: 'in',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final inches = int.tryParse(value);
                    if (inches == null || inches < 0 || inches >= 12) {
                      return 'Valid: 0-11';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Weight field
          _buildTextField(
            context: context,
            controller: _weightController,
            label: 'Weight',
            hint: 'Enter your weight',
            icon: FontAwesomeIcons.weightScale,
            keyboardType: TextInputType.number,
            suffix: 'lbs',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your weight';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight < 80 || weight > 500) {
                return 'Please enter a valid weight (80-500 lbs)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRunningHabitsSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running Habits',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Water bottle toggle
          InkWell(
            onTap: () => setState(() => _runsWithWaterBottle = !_runsWithWaterBottle),
            borderRadius: AppRadius.cardRadius,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _runsWithWaterBottle
                    ? AppColors.blackberry.withOpacity(0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: _runsWithWaterBottle
                      ? AppColors.blackberry
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  width: _runsWithWaterBottle ? 2 : 1,
                ),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  // Checkbox
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _runsWithWaterBottle
                          ? AppColors.blackberry
                          : Colors.transparent,
                      border: Border.all(
                        color: _runsWithWaterBottle
                            ? AppColors.blackberry
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _runsWithWaterBottle
                        ? const Icon(
                            FontAwesomeIcons.check,
                            size: 14,
                            color: AppColors.cream,
                          )
                        : null,
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I run with a water bottle',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'This helps us estimate your hydration needs',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Gender options
        Row(
          children: [
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Male',
                subtitle: 'Select if you identify as male',
                value: Gender.male,
                groupValue: _selectedGender,
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Female',
                subtitle: 'Select if you identify as female',
                value: Gender.female,
                groupValue: _selectedGender,
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Non-binary',
                subtitle: 'Select if you identify as non-binary',
                value: Gender.other,
                groupValue: _selectedGender,
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBirthdaySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Birthday',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        InkWell(
          onTap: _selectBirthday,
          borderRadius: AppRadius.inputRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              borderRadius: AppRadius.inputRadius,
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.calendar,
                  size: AppIconSizes.controlIcon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _selectedBirthday != null
                        ? '${_selectedBirthday!.month}/${_selectedBirthday!.day}/${_selectedBirthday!.year}'
                        : 'Select your birthday',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedBirthday != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              icon,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffix: suffix != null
                ? Text(
                    suffix,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.orange,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.dragonfruit,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Gender value,
    required Gender groupValue,
    required ValueChanged<Gender> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = groupValue == value;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cream : AppColors.blackberry)
              : Colors.transparent,
          border: Border.all(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon based on gender
            Icon(
              value == Gender.male
                  ? FontAwesomeIcons.mars
                  : value == Gender.female
                      ? FontAwesomeIcons.venus
                      : FontAwesomeIcons.genderless,
              size: 28,
              color: isSelected
                  ? (isDark ? AppColors.blackberry : AppColors.cream)
                  : (isDark ? AppColors.cream.withValues(alpha: 0.5) : AppColors.blackberry.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 4),

            // Text content
            Text(
              title.toUpperCase(),
              style: AppTextStyles.smallLabel.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? AppColors.blackberry : AppColors.cream)
                    : (isDark ? AppColors.cream.withValues(alpha: 0.5) : AppColors.blackberry.withValues(alpha: 0.5)),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectBirthday() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _submitProfile() async {
    // Validate form and required fields
    if (!_formKey.currentState!.validate() || _selectedBirthday == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all fields'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
      return;
    }

    // Track form submission attempt
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track('user_profile_submit_attempt', properties: {
      'gender': _selectedGender.name,
      'runs_with_water_bottle': _runsWithWaterBottle,
      'height_feet': _heightFeetController.text,
      'height_inches': _heightInchesController.text,
      'weight': _weightController.text,
    });

    // Submit to controller
    final controller = ref.read(onboardingControllerProvider.notifier);

    final success = await controller.createUserProfile(
      gender: _selectedGender,
      birthday: _selectedBirthday!,
      heightFeet: int.parse(_heightFeetController.text),
      heightInches: int.parse(_heightInchesController.text),
      weightPounds: double.parse(_weightController.text),
      runsWithWaterBottle: _runsWithWaterBottle,
    );

    if (success && mounted) {
      // Track successful completion
      await analytics.track('user_profile_completed', properties: {
        'gender': _selectedGender.name,
      });

      // Track navigation
      await analytics.track('navigation', properties: {
        'destination': 'Sport Preferences Onboarding',
        'source': 'User Profile Submit',
      });

      // Invalidate providers to refresh user state
      ref.invalidate(currentUserProvider);
      ref.invalidate(userRepositoryProvider);

      if (mounted) {
        context.push('/onboarding/sport-preferences');
      }
    } else if (mounted) {
      // Error is already shown in the UI via asyncState.hasError
      // Additional SnackBar for user feedback
      final state = ref.read(onboardingControllerProvider);
      final errorMessage = state.error?.toString() ?? 'Failed to create profile';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }
}
