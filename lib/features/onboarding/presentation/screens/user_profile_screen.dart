import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/birth_year_picker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/onboarding_widgets.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../integrations/presentation/providers/connect_training_controller.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// User Profile Screen - Design System
/// User setup screen during onboarding - RESTORED with database integration
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, this.onContinue, this.onBack});

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

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
  UnitSystem _unitSystem = UnitSystem.imperial;

  // Optional name fields (for coach mode athlete identification)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Email field
  final _emailController = TextEditingController();

  // Track whether we've attempted to load integration data
  bool _hasLoadedIntegrationData = false;
  bool _weightFromGarmin = false;

  @override
  void initState() {
    super.initState();

    // Initialize from controller cache if available
    final controller = ref.read(onboardingControllerProvider.notifier);
    final cachedData = controller.cachedUserProfileData;
    if (cachedData != null) {
      _selectedGender = cachedData['gender'] as Gender;
      _selectedBirthday = cachedData['birthday'] as DateTime;
      _heightFeetController.text = cachedData['heightFeet'].toString();
      _heightInchesController.text = cachedData['heightInches'].toString();
      _weightController.text = cachedData['weightPounds'].toString();
      _runsWithWaterBottle = cachedData['runsWithWaterBottle'] as bool;
      _unitSystem =
          cachedData['unitSystem'] as UnitSystem? ?? UnitSystem.imperial;
      // Optional name fields
      if (cachedData['firstName'] != null) {
        _firstNameController.text = cachedData['firstName'] as String;
      }
      if (cachedData['lastName'] != null) {
        _lastNameController.text = cachedData['lastName'] as String;
      }
      // Email field
      if (cachedData['email'] != null) {
        _emailController.text = cachedData['email'] as String;
      }
    } else {
      // No cached data - try to load from connected integrations
      // Use post-frame callback since we can't do async in initState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadIntegrationProfileData();
        // Auto-populate email from Supabase auth if available
        if (_emailController.text.isEmpty) {
          final authEmail = ref
              .read(appExternalDepsProvider)
              .supabaseClient
              .auth
              .currentUser
              ?.email
              ?.trim();
          if (authEmail != null && authEmail.isNotEmpty) {
            _emailController.text = authEmail;
          }
        }
      });
    }

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {'screen_name': 'User Profile Onboarding'},
        );
  }

  /// Load profile data from connected integrations (Training Peaks takes precedence)
  ///
  /// Training Peaks provides: weight (kg), birthMonth (YYYY-MM), sex (m/f)
  /// Final Surge provides: name only (no biometric data)
  Future<void> _loadIntegrationProfileData() async {
    if (_hasLoadedIntegrationData) return;
    _hasLoadedIntegrationData = true;

    try {
      final connectController = ref.read(
        connectTrainingControllerProvider.notifier,
      );
      final userId = connectController.currentUserId;
      if (userId == null) return;

      final integrationsRepo = ref.read(integrationsRepositoryProvider);

      // Try Training Peaks first (has profile data), fall back to Final Surge
      var integration = await integrationsRepo.getIntegration(
        userId,
        'training_peaks',
      );
      integration ??= await integrationsRepo.getIntegration(
        userId,
        'final_surge',
      );

      // Also check Garmin for body comp data (weight, body fat %)
      final garminIntegration = await integrationsRepo.getIntegration(
        userId,
        'garmin',
      );

      if ((integration == null || !integration.isActive) &&
          (garminIntegration == null || !garminIntegration.isActive)) {
        return;
      }

      if (kDebugMode) {
        if (integration?.isActive == true) {
          print('🔄 Auto-populating profile from ${integration!.provider}');
          print('   Weight (kg): ${integration.providerAthleteWeightKg}');
          print('   Birth month: ${integration.providerAthleteBirthMonth}');
          print('   Gender: ${integration.providerAthleteGender}');
        }
        if (garminIntegration?.isActive == true) {
          print('🔄 Garmin body comp: '
              'weight=${garminIntegration!.providerAthleteWeightKg}kg, '
              'bodyFat=${garminIntegration.providerAthleteBodyFatPct}%');
        }
      }

      if (!mounted) return;

      setState(() {
        // Name (from TP/FS — Garmin doesn't provide real names)
        if (integration?.isActive == true &&
            integration!.providerAthleteName != null &&
            _firstNameController.text.isEmpty) {
          final nameParts = integration.providerAthleteName!.split(' ');
          if (nameParts.isNotEmpty) {
            _firstNameController.text = nameParts.first;
            if (nameParts.length > 1) {
              _lastNameController.text = nameParts.sublist(1).join(' ');
            }
          }
        }

        // Weight: prefer Garmin (scale data) over TP/FS
        if (_weightController.text.isEmpty) {
          final useGarmin = garminIntegration?.isActive == true &&
              garminIntegration?.providerAthleteWeightKg != null;
          final weightSource = useGarmin ? garminIntegration : integration;
          if (weightSource?.providerAthleteWeightLbs != null) {
            _weightController.text =
                weightSource!.providerAthleteWeightLbs!.toStringAsFixed(1);
            if (useGarmin) _weightFromGarmin = true;
          }
        }

        // Birthday (from TP only — Garmin doesn't expose this)
        if (integration?.isActive == true &&
            integration!.providerAthleteBirthday != null &&
            _selectedBirthday == null) {
          _selectedBirthday = integration.providerAthleteBirthday;
        }

        // Gender (from TP only — Garmin doesn't expose this)
        if (integration?.isActive == true) {
          if (integration!.providerAthleteGender == 'm') {
            _selectedGender = Gender.male;
          } else if (integration.providerAthleteGender == 'f') {
            _selectedGender = Gender.female;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load integration profile data: $e');
      }
    }
  }

  @override
  void dispose() {
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    return AdaptivePageScaffold(
      backgroundColor: backgroundColor,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar at the very top (no SafeArea padding)
          Container(
            color: backgroundColor,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: const OnboardingProgressBar(
              currentSegment: 1, // Profile segment
            ),
          ),

          // Content
          Expanded(child: _buildContent(context, asyncState)),

          // Footer navigation
          _buildFooter(asyncState),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AsyncValue<void> asyncState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.orange : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input fields
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: AdaptiveScrollableBody(
        safeAreaTop: false,
        safeAreaBottom: false,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Introduction text
              Text(
                'Tell us about yourself',
                style: const TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ).copyWith(color: titleColor),
              ),
              const SizedBox(height: 12),
              Text(
                'This helps us calculate accurate nutrition plans for your activities.',
                style: const TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.192,
                  height: 1.0,
                ).copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Personal information section
              _buildPersonalInfoSection(context),

              const SizedBox(height: AppSpacing.lg),

              // Physical information section
              _buildPhysicalInfoSection(context),

              const SizedBox(height: AppSpacing.lg),

              // Unit Preferences section
              _buildUnitPreferencesSection(context),

              // const SizedBox(height: AppSpacing.lg),

              // Running habits section
              // _buildRunningHabitsSection(context),
              const SizedBox(height: AppSpacing.xxxl),

              // Error message if any
              if (asyncState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.dragonfruit.withValues(alpha: 0.1),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: AppColors.dragonfruit),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          FontAwesomeIcons.circleExclamation,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(AsyncValue<void> asyncState) {
    return FigmaOnboardingFooter(
      onContinue: _submitProfile,
      onBack: widget.onBack ?? () => context.pop(),
      canContinue: !asyncState.isLoading,
      isLoading: asyncState.isLoading,
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
                  label: 'First Name',
                  hint: 'First name',
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
                  label: 'Last Name',
                  hint: 'Last name',
                  icon: FontAwesomeIcons.user,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Email field
          _buildTextField(
            context: context,
            controller: _emailController,
            label: 'Email',
            hint: 'Email address',
            icon: FontAwesomeIcons.envelope,
            keyboardType: TextInputType.emailAddress,
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
            label: _weightFromGarmin ? 'Weight (from Garmin Connect)' : 'Weight',
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

  Widget _buildUnitPreferencesSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Preferences',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Unit System',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Controls display of distance, pace, fluids, and measurements',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KyleSegmentedControl<UnitSystem>(
            segments: UnitSystem.values,
            selected: _unitSystem,
            onChanged: (value) {
              setState(() => _unitSystem = value);
            },
          ),
        ],
      ),
    );
  }

  // Widget _buildRunningHabitsSection(BuildContext context) {
  //   return BaseCard(
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Running Habits',
  //           style: AppTextStyles.subtitle.copyWith(
  //             color: Theme.of(context).colorScheme.onSurface,
  //           ),
  //         ),
  //
  //         const SizedBox(height: AppSpacing.md),
  //
  //         // Water bottle toggle
  //         InkWell(
  //           onTap: () => setState(() => _runsWithWaterBottle = !_runsWithWaterBottle),
  //           borderRadius: AppRadius.cardRadius,
  //           child: Container(
  //             padding: const EdgeInsets.all(AppSpacing.md),
  //             decoration: BoxDecoration(
  //               color: _runsWithWaterBottle
  //                   ? AppColors.blackberry.withOpacity(0.1)
  //                   : Colors.transparent,
  //               border: Border.all(
  //                 color: _runsWithWaterBottle
  //                     ? AppColors.blackberry
  //                     : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
  //                 width: _runsWithWaterBottle ? 2 : 1,
  //               ),
  //               borderRadius: AppRadius.cardRadius,
  //             ),
  //             child: Row(
  //               children: [
  //                 // Checkbox
  //                 Container(
  //                   width: 24,
  //                   height: 24,
  //                   decoration: BoxDecoration(
  //                     color: _runsWithWaterBottle
  //                         ? AppColors.blackberry
  //                         : Colors.transparent,
  //                     border: Border.all(
  //                       color: _runsWithWaterBottle
  //                           ? AppColors.blackberry
  //                           : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
  //                       width: 2,
  //                     ),
  //                     borderRadius: BorderRadius.circular(6),
  //                   ),
  //                   child: _runsWithWaterBottle
  //                       ? const Icon(
  //                           FontAwesomeIcons.check,
  //                           size: 14,
  //                           color: AppColors.cream,
  //                         )
  //                       : null,
  //                 ),
  //
  //                 const SizedBox(width: AppSpacing.md),
  //
  //                 // Text content
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'I run with a water bottle',
  //                         style: AppTextStyles.bodyMedium.copyWith(
  //                           color: Theme.of(context).colorScheme.onSurface,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                       const SizedBox(height: AppSpacing.xs),
  //                       Text(
  //                         'This helps us estimate your hydration needs',
  //                         style: AppTextStyles.bodyMedium.copyWith(
  //                           color: Theme.of(context).colorScheme.onSurfaceVariant,
  //                           fontSize: 14,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
          'Birth Year',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        InkWell(
          onTap: _selectBirthYear,
          borderRadius: AppRadius.inputRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.2),
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
                        ? '${_selectedBirthday!.year}'
                        : 'Select your birth year',
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
    TextCapitalization textCapitalization = TextCapitalization.none,
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
          textCapitalization: textCapitalization,
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(color: AppColors.orange, width: 2),
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
                  : (isDark
                        ? AppColors.cream.withValues(alpha: 0.5)
                        : AppColors.blackberry.withValues(alpha: 0.5)),
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
                    : (isDark
                          ? AppColors.cream.withValues(alpha: 0.5)
                          : AppColors.blackberry.withValues(alpha: 0.5)),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectBirthYear() async {
    final year = await showBirthYearPicker(
      context: context,
      initialYear: _selectedBirthday?.year,
    );

    if (year != null) {
      setState(() {
        _selectedBirthday = DateTime(year, 1, 1);
      });
    }
  }

  Future<void> _submitProfile() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    // Validate form and required fields
    if (!_formKey.currentState!.validate() || _selectedBirthday == null) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Please fill in all fields');
      }
      return;
    }

    // Track form submission attempt
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(
      'user_profile_submit_attempt',
      properties: {
        'gender': _selectedGender.name,
        'runs_with_water_bottle': _runsWithWaterBottle,
        'height_feet': _heightFeetController.text,
        'height_inches': _heightInchesController.text,
        'weight': _weightController.text,
        'unit_system': _unitSystem.name,
      },
    );

    // Cache the data instead of saving to database
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.cacheUserProfileData(
      gender: _selectedGender,
      birthday: _selectedBirthday!,
      heightFeet: int.parse(_heightFeetController.text),
      heightInches: int.parse(_heightInchesController.text),
      weightPounds: double.parse(_weightController.text),
      runsWithWaterBottle: _runsWithWaterBottle,
      firstName: _firstNameController.text.trim().isNotEmpty
          ? _firstNameController.text.trim()
          : null,
      lastName: _lastNameController.text.trim().isNotEmpty
          ? _lastNameController.text.trim()
          : null,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      unitSystem: _unitSystem,
    );

    if (mounted) {
      // Track successful completion
      await analytics.track(
        'user_profile_completed',
        properties: {'gender': _selectedGender.name},
      );

      // Track navigation
      await analytics.track(
        'navigation',
        properties: {
          'destination': 'Sports Selection Onboarding',
          'source': 'User Profile Submit',
        },
      );

      // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
      if (widget.onContinue != null) {
        widget.onContinue!();
      } else {
        context.push('/onboarding/sports-selection');
      }
    }
  }
}
