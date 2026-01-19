import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../providers/settings_controller.dart';
import '../../../auth/domain/user_preferences.dart';

/// Preferences Screen - Settings version that matches onboarding UserProfileScreen
/// Saves immediately to database instead of caching
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final _formKey = GlobalKey<FormState>();

  // Local state for editing
  Gender? _gender;
  DateTime? _birthday;
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  bool? _runsWithWaterBottle;
  GutTraining? _gutTraining;
  SweatRateCat? _sweatRate;

  // Optional name fields for coach mode athlete identification
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize local state from controller on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsState = ref.read(settingsControllerProvider).value;
      if (settingsState != null && mounted) {
        setState(() {
          _gender = settingsState.gender;
          _birthday = settingsState.birthday;
          _runsWithWaterBottle = settingsState.runsWithWaterBottle;
          _gutTraining = settingsState.gutTrainingLevel;
          _sweatRate = settingsState.sweatRate;
        });
        // Set text controller values
        if (settingsState.heightFeet != null) {
          _heightFeetController.text = settingsState.heightFeet.toString();
        }
        if (settingsState.heightInches != null) {
          _heightInchesController.text = settingsState.heightInches.toString();
        }
        if (settingsState.weightPounds != null) {
          _weightController.text = settingsState.weightPounds.toString();
        }
        // Optional name fields
        if (settingsState.firstName != null) {
          _firstNameController.text = settingsState.firstName!;
        }
        if (settingsState.lastName != null) {
          _lastNameController.text = settingsState.lastName!;
        }
      }
    });
  }

  @override
  void dispose() {
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _markChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate birthday is selected
    if (_birthday == null) {
      MealvanaSnackbar.showWarning(context, 'Please select your birthday');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final controller = ref.read(settingsControllerProvider.notifier);

    try {
      // Parse height values
      final heightFeet = int.tryParse(_heightFeetController.text);
      final heightInches = int.tryParse(_heightInchesController.text);
      final weightPounds = double.tryParse(_weightController.text);

      // Save all preferences in a single batch operation
      await controller.saveAllPreferences(
        gender: _gender,
        birthday: _birthday,
        heightFeet: heightFeet,
        heightInches: heightInches,
        weightPounds: weightPounds,
        runsWithWaterBottle: _runsWithWaterBottle,
        gutTrainingLevel: _gutTraining,
        sweatRate: _sweatRate,
        firstName: _firstNameController.text.trim().isNotEmpty ? _firstNameController.text.trim() : null,
        lastName: _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });

        // Show success message
        MealvanaSnackbar.showSuccess(context, 'Preferences saved successfully');

        // Go back to settings screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        MealvanaSnackbar.showError(context, 'Error saving preferences: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Column(
        children: [
          // Content area
          Expanded(
            child: SafeArea(
              bottom: false,
              child: settingsAsync.when(
                data: (state) => _buildContent(context, state),
                loading: () => _buildLoadingState(context),
                error: (error, stack) => _buildErrorState(context, error),
              ),
            ),
          ),

          // Footer navigation (matching onboarding style)
          SafeArea(
            top: false,
            child: FigmaOnboardingFooter(
              onContinue: _hasChanges && !_isSaving ? _saveChanges : null,
              onBack: () => Navigator.of(context).pop(),
              canContinue: _hasChanges && !_isSaving,
              isLoading: _isSaving,
              buttonText: 'Save Changes',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.orange,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Error loading profile',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic state) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input fields
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Introduction text (matching onboarding)
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This helps us calculate accurate nutrition plans for your activities.',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textDark,
                  letterSpacing: 0.192,
                  height: 1.0,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Personal information section
              _buildPersonalInfoSection(context),

              const SizedBox(height: AppSpacing.lg),

              // Physical information section
              _buildPhysicalInfoSection(context),

              const SizedBox(height: AppSpacing.lg),

              // Nutrition settings section (gut training and sweat rate)
              _buildNutritionSettingsSection(context),

              const SizedBox(height: AppSpacing.xxxl),
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

          // Name fields (optional) - row with first and last name
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  context: context,
                  controller: _firstNameController,
                  hint: 'First name (optional)',
                  icon: FontAwesomeIcons.user,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTextField(
                  context: context,
                  controller: _lastNameController,
                  hint: 'Last name (optional)',
                  icon: FontAwesomeIcons.user,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Gender selector (matching onboarding style)
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

          // Height fields (feet + inches) with validation
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

          const SizedBox(height: AppSpacing.md),

          // Water bottle toggle
          _buildWaterBottleToggle(context),
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

        // Gender options (matching onboarding style with icons)
        Row(
          children: [
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Male',
                value: Gender.male,
                groupValue: _gender ?? Gender.male,
                onChanged: (value) {
                  setState(() => _gender = value);
                  _markChanged();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Female',
                value: Gender.female,
                groupValue: _gender ?? Gender.male,
                onChanged: (value) {
                  setState(() => _gender = value);
                  _markChanged();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildRadioOption(
                context: context,
                title: 'Non-binary',
                value: Gender.other,
                groupValue: _gender ?? Gender.male,
                onChanged: (value) {
                  setState(() => _gender = value);
                  _markChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRadioOption({
    required BuildContext context,
    required String title,
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
          onTap: () async {
            final selectedDate = await showAppDatePicker(
              context: context,
              initialDate: _birthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
            );
            if (selectedDate != null) {
              setState(() {
                _birthday = selectedDate;
              });
              _markChanged();
            }
          },
          borderRadius: AppRadius.inputRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                    _birthday != null
                        ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                        : 'Select your birthday',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _birthday != null
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
    String? label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          onChanged: (_) => _markChanged(),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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

  Widget _buildNutritionSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Settings',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Gut Training Level
          Text(
            'Gut Training Level',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your gut\'s ability to absorb carbs during exercise',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KyleGutTrainingSegmentedControl(
            selected: _gutTraining ?? GutTraining.moderate,
            onChanged: (value) {
              setState(() => _gutTraining = value);
              _markChanged();
            },
            showValues: true,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Sweat Rate
          Text(
            'Sweat Rate',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How much you typically sweat during exercise',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KyleSweatRateSegmentedControl(
            selected: _sweatRate ?? SweatRateCat.medium,
            onChanged: (value) {
              setState(() => _sweatRate = value);
              _markChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaterBottleToggle(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _runsWithWaterBottle = !(_runsWithWaterBottle ?? false);
        });
        _markChanged();
      },
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: (_runsWithWaterBottle ?? false)
              ? AppColors.blackberry.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: (_runsWithWaterBottle ?? false)
                ? AppColors.blackberry
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            width: (_runsWithWaterBottle ?? false) ? 2 : 1,
          ),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: (_runsWithWaterBottle ?? false)
                    ? AppColors.blackberry
                    : Colors.transparent,
                border: Border.all(
                  color: (_runsWithWaterBottle ?? false)
                      ? AppColors.blackberry
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: (_runsWithWaterBottle ?? false)
                  ? const Icon(
                      FontAwesomeIcons.check,
                      size: 14,
                      color: AppColors.cream,
                    )
                  : null,
            ),

            const SizedBox(width: AppSpacing.md),

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
    );
  }
}
