import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../providers/settings_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';

/// Preferences Screen - Separate screen for editing preferences with explicit save
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  // Local state for editing
  Gender? _gender;
  DateTime? _birthday;
  int? _heightFeet;
  int? _heightInches;
  double? _weightPounds;
  bool? _runsWithWaterBottle;
  DistanceUnit? _preferredDistanceUnit;
  PaceUnit? _preferredPaceUnit;
  GutTraining? _gutTrainingLevel;

  bool _hasChanges = false;
  bool _isSaving = false;

  // TextEditingController for weight field to fix autopopulation issue
  final _weightController = TextEditingController();

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
          _heightFeet = settingsState.heightFeet;
          _heightInches = settingsState.heightInches;
          _weightPounds = settingsState.weightPounds;
          _runsWithWaterBottle = settingsState.runsWithWaterBottle;
          _preferredDistanceUnit = settingsState.preferredDistanceUnit;
          _preferredPaceUnit = settingsState.preferredPaceUnit;
          _gutTrainingLevel = settingsState.gutTrainingLevel;
        });
        // Set weight controller text after state is loaded
        if (settingsState.weightPounds != null) {
          _weightController.text = settingsState.weightPounds.toString();
        }
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _markChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    final controller = ref.read(settingsControllerProvider.notifier);

    try {
      // Save all preferences in a single batch operation
      // This avoids multiple invalidations that cause excessive UI refreshes
      await controller.saveAllPreferences(
        gender: _gender,
        birthday: _birthday,
        heightFeet: _heightFeet,
        heightInches: _heightInches,
        weightPounds: _weightPounds,
        runsWithWaterBottle: _runsWithWaterBottle,
        preferredDistanceUnit: _preferredDistanceUnit,
        preferredPaceUnit: _preferredPaceUnit,
        gutTrainingLevel: _gutTrainingLevel,
      );

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: AppColors.electrolyte,
            duration: Duration(seconds: 2),
          ),
        );

        // Go back to settings screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppColors.dragonfruit,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: settingsAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(FontAwesomeIcons.chevronLeft),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Preferences',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.electrolyte,
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
            'Error loading preferences',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Profile section
                _buildProfileSection(context, state),

                const SizedBox(height: AppSpacing.lg),

                // Preferences section
                _buildPreferencesSection(context, state),

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),

        // Save button at bottom
        _buildSaveButton(context, state),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, dynamic state) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.profileSectionTitle,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Gender selector
          _buildGenderSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Birthday selector
          _buildBirthdaySelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Height selector
          _buildHeightSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Weight selector
          _buildWeightSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Water bottle toggle
          _buildWaterBottleToggle(context, state),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context, dynamic state) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.preferenceSectionTitle,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Distance unit
          _buildDistanceUnitSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Pace unit
          _buildPaceUnitSelector(context, state),

          const SizedBox(height: AppSpacing.md),

          // Gut training level
          _buildGutTrainingSelector(context, state),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, dynamic state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: KylePrimaryButton(
            text: _isSaving ? 'Saving...' : (state.saveButtonText ?? 'Save Changes'),
            onPressed: _hasChanges && !_isSaving ? _saveChanges : null,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.genderLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<Gender>(
          segments: [Gender.male, Gender.female],
          selected: _gender ?? Gender.male,
          onChanged: (gender) {
            setState(() {
              _gender = gender;
            });
            _markChanged();
          },
        ),
      ],
    );
  }

  Widget _buildBirthdaySelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.birthdayLabel,
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

  Widget _buildHeightSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.heightLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            // Feet dropdown
            Expanded(
              child: _buildDropdown<int>(
                context: context,
                value: _heightFeet,
                hint: 'Feet',
                items: List.generate(6, (index) => index + 3),
                itemBuilder: (feet) => '$feet ft',
                onChanged: (feet) {
                  if (feet != null) {
                    setState(() {
                      _heightFeet = feet;
                    });
                    _markChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Inches dropdown
            Expanded(
              child: _buildDropdown<int>(
                context: context,
                value: _heightInches,
                hint: 'Inches',
                items: List.generate(12, (index) => index),
                itemBuilder: (inches) => '$inches in',
                onChanged: (inches) {
                  if (inches != null) {
                    setState(() {
                      _heightInches = inches;
                    });
                    _markChanged();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.weightLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter weight',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffixText: 'lbs',
            suffixStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
          onChanged: (value) {
            final weight = double.tryParse(value);
            if (weight != null && weight > 0) {
              setState(() {
                _weightPounds = weight;
              });
              _markChanged();
            }
          },
        ),
      ],
    );
  }

  Widget _buildWaterBottleToggle(BuildContext context, dynamic state) {
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

  Widget _buildDistanceUnitSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.distanceUnitLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<DistanceUnit>(
          segments: DistanceUnit.values,
          selected: _preferredDistanceUnit ?? DistanceUnit.miles,
          onChanged: (unit) {
            setState(() {
              _preferredDistanceUnit = unit;
            });
            _markChanged();
          },
        ),
      ],
    );
  }

  Widget _buildPaceUnitSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.paceUnitLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleSegmentedControl<PaceUnit>(
          segments: PaceUnit.values,
          selected: _preferredPaceUnit ?? PaceUnit.minPerMile,
          onChanged: (unit) {
            setState(() {
              _preferredPaceUnit = unit;
            });
            _markChanged();
          },
        ),
      ],
    );
  }

  Widget _buildGutTrainingSelector(BuildContext context, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.gutTrainingLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        KyleGutTrainingSegmentedControl(
          selected: _gutTrainingLevel ?? GutTraining.moderate,
          onChanged: (level) {
            setState(() {
              _gutTrainingLevel = level;
            });
            _markChanged();
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        borderRadius: AppRadius.inputRadius,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemBuilder(item),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}
