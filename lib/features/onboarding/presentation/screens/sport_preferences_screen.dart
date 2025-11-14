import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../providers/onboarding_controller.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Sport Preferences Screen - Kyle's Design System
/// Allows users to select which sports they participate in and provide sport-specific details
class SportPreferencesScreen extends ConsumerStatefulWidget {
  const SportPreferencesScreen({super.key});

  @override
  ConsumerState<SportPreferencesScreen> createState() => _SportPreferencesScreenState();
}

class _SportPreferencesScreenState extends ConsumerState<SportPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();

  // Sport selection
  bool _doesRunning = true; // Default to true since this is a running app
  bool _doesCycling = false;
  bool _doesSwimming = false;

  // GI Sensitivity (shared across all sports)
  bool _giSensitivity = false;

  // Cycling preferences
  final _ftpController = TextEditingController(text: '0');
  int _bikeBottles = 2;
  bool _hasAeroBottle = false;
  bool _hasBentoBox = false;

  // Swimming preferences
  final _cssMinutesController = TextEditingController(text: '2');
  final _cssSecondsController = TextEditingController(text: '00');
  bool _typicalWetsuit = false;
  String _swimCapType = 'none';

  @override
  void initState() {
    super.initState();
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Sport Preferences Onboarding',
    });
  }

  @override
  void dispose() {
    _ftpController.dispose();
    _cssMinutesController.dispose();
    _cssSecondsController.dispose();
    super.dispose();
  }

  void _submitPreferences() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one sport selected
    if (!_doesRunning && !_doesCycling && !_doesSwimming) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select at least one sport'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
      return;
    }

    // Track form submission
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track('sport_preferences_submit', properties: {
      'does_running': _doesRunning,
      'does_cycling': _doesCycling,
      'does_swimming': _doesSwimming,
      'gi_sensitivity': _giSensitivity,
      'ftp_watts': _doesCycling ? int.parse(_ftpController.text) : null,
      'bike_bottles': _doesCycling ? _bikeBottles : null,
      'css_seconds': _doesSwimming ? _calculateCssSeconds() : null,
    });

    final controller = ref.read(onboardingControllerProvider.notifier);

    // Prepare sport preferences data
    final ftpWatts = _doesCycling ? (int.tryParse(_ftpController.text) ?? 0) : null;
    final cssSeconds = _doesSwimming ? _calculateCssSeconds() : null;

    final success = await controller.saveSportPreferences(
      giSensitivity: _giSensitivity,
      ftpWatts: ftpWatts,
      typicalBikeBottles: _doesCycling ? _bikeBottles : null,
      hasAeroBottle: _doesCycling ? _hasAeroBottle : null,
      hasBentoBox: _doesCycling ? _hasBentoBox : null,
      cssPacePer100mSeconds: cssSeconds,
      typicalWetsuit: _doesSwimming ? _typicalWetsuit : null,
      typicalSwimCapType: _doesSwimming ? _swimCapType : null,
    );

    if (success && mounted) {
      // Track successful navigation
      await analytics.track('navigation', properties: {
        'destination': 'Food Preferences Onboarding',
        'source': 'Sport Preferences Submit',
      });

      if (mounted) {
        context.push('/onboarding/food-preferences');
      }
    } else if (mounted) {
      // Show error if save failed
      final state = ref.read(onboardingControllerProvider);
      final errorMessage = state.asError?.error.toString() ?? 'Failed to save sport preferences';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }

  int _calculateCssSeconds() {
    final minutes = int.tryParse(_cssMinutesController.text) ?? 0;
    final seconds = int.tryParse(_cssSecondsController.text) ?? 0;
    return minutes * 60 + seconds;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              ClipRRect(
                borderRadius: AppRadius.circularRadius,
                child: LinearProgressIndicator(
                  value: 0.67, // 67% through onboarding (step 2 of 3)
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Title and subtitle
              Text(
                'Which sports do you do?',
                style: AppTextStyles.pageTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                'We\'ll customize your nutrition plans for each sport.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Sport selection cards
              _buildSportSelectionCard(
                icon: FontAwesomeIcons.personRunning,
                label: 'Running',
                isSelected: _doesRunning,
                onTap: () => setState(() => _doesRunning = !_doesRunning),
              ),

              const SizedBox(height: AppSpacing.md),

              _buildSportSelectionCard(
                icon: FontAwesomeIcons.personBiking,
                label: 'Cycling',
                isSelected: _doesCycling,
                onTap: () => setState(() => _doesCycling = !_doesCycling),
              ),

              const SizedBox(height: AppSpacing.md),

              _buildSportSelectionCard(
                icon: FontAwesomeIcons.personSwimming,
                label: 'Swimming',
                isSelected: _doesSwimming,
                onTap: () => setState(() => _doesSwimming = !_doesSwimming),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // GI Sensitivity section
              _buildGISensitivitySection(),

              // Cycling details (conditional)
              if (_doesCycling) ...[
                const SizedBox(height: AppSpacing.xxl),
                _buildCyclingDetailsSection(),
              ],

              // Swimming details (conditional)
              if (_doesSwimming) ...[
                const SizedBox(height: AppSpacing.xxl),
                _buildSwimmingDetailsSection(),
              ],

              const SizedBox(height: AppSpacing.xxxl),

              // Continue button
              KylePrimaryButton(
                text: 'Continue',
                onPressed: asyncState.isLoading ? null : _submitPreferences,
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Custom back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: AppIconSizes.controlIcon,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Sport Preferences',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportSelectionCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: BaseCard(
        backgroundColor: isSelected ? AppColors.orange : null,
        border: Border.all(
          color: isSelected ? AppColors.orange : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        child: Row(
          children: [
            // Sport icon
            Container(
              width: AppIconSizes.activityIcon,
              height: AppIconSizes.activityIcon,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blackberry : AppColors.electrolyte,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.cream : AppColors.blackberry,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Sport label
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.subtitle.copyWith(
                  color: isSelected ? AppColors.blackberry : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Checkmark indicator
            if (isSelected)
              Icon(
                FontAwesomeIcons.check,
                size: AppIconSizes.controlIcon,
                color: AppColors.blackberry,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGISensitivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gut Sensitivity',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        BaseCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensitive stomach during exercise',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Helps us recommend easier-to-digest foods',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: _giSensitivity,
                onChanged: (value) => setState(() => _giSensitivity = value),
                activeColor: AppColors.orange,
                activeTrackColor: AppColors.orange.withOpacity(0.5),
                inactiveThumbColor: AppColors.cream,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCyclingDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cycling Details',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // FTP input
        BaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FTP (Functional Threshold Power)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Maximum power you can sustain for ~1 hour (enter 0 if unknown)',
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ftpController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'e.g., 250',
                  suffixText: 'watts',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
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
                    borderSide: BorderSide(
                      color: AppColors.orange,
                      width: 2,
                    ),
                  ),
                  contentPadding: AppSpacing.inputPadding,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final ftp = int.tryParse(value!);
                  if (ftp == null || ftp < 0) return 'Enter valid FTP (0 or higher)';
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Bike bottles
        BaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Water Bottles',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [1, 2, 3].map((bottles) {
                  final isSelected = _bikeBottles == bottles;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _bikeBottles = bottles),
                      child: Container(
                        margin: EdgeInsets.only(right: bottles != 3 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.blackberry : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.blackberry : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            width: 2,
                          ),
                          borderRadius: AppRadius.inputRadius,
                        ),
                        child: Text(
                          bottles == 3 ? '3+' : '$bottles',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected ? AppColors.cream : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Aero bottle switch
        BaseCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aero Bottle',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Do you have an aero bottle?',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: _hasAeroBottle,
                onChanged: (value) => setState(() => _hasAeroBottle = value),
                activeColor: AppColors.orange,
                activeTrackColor: AppColors.orange.withOpacity(0.5),
                inactiveThumbColor: AppColors.cream,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Bento box switch
        BaseCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bento Box',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Do you have a bento box for food?',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: _hasBentoBox,
                onChanged: (value) => setState(() => _hasBentoBox = value),
                activeColor: AppColors.orange,
                activeTrackColor: AppColors.orange.withOpacity(0.5),
                inactiveThumbColor: AppColors.cream,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwimmingDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Swimming Details',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // CSS input
        BaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CSS (Critical Swim Speed)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Fastest pace per 100m you can sustain for 30 min (MM:SS format)',
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cssMinutesController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Minutes',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
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
                          borderSide: BorderSide(
                            color: AppColors.orange,
                            width: 2,
                          ),
                        ),
                        contentPadding: AppSpacing.inputPadding,
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final minutes = int.tryParse(value!);
                        if (minutes == null || minutes < 0 || minutes > 10) {
                          return 'Enter 0-10';
                        }
                        return null;
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      ':',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),

                  Expanded(
                    child: TextFormField(
                      controller: _cssSecondsController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Seconds',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
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
                          borderSide: BorderSide(
                            color: AppColors.orange,
                            width: 2,
                          ),
                        ),
                        contentPadding: AppSpacing.inputPadding,
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final seconds = int.tryParse(value!);
                        if (seconds == null || seconds < 0 || seconds >= 60) {
                          return 'Enter 0-59';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Wetsuit switch
        BaseCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wetsuit',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Do you typically wear a wetsuit?',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: _typicalWetsuit,
                onChanged: (value) => setState(() => _typicalWetsuit = value),
                activeColor: AppColors.orange,
                activeTrackColor: AppColors.orange.withOpacity(0.5),
                inactiveThumbColor: AppColors.cream,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Swim cap type
        BaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Swim Cap Type',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Column(
                children: [
                  _buildSwimCapOption('none', 'None'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildSwimCapOption('latex', 'Latex'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildSwimCapOption('silicone', 'Silicone'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildSwimCapOption('neoprene', 'Neoprene'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwimCapOption(String value, String label) {
    final isSelected = _swimCapType == value;
    return GestureDetector(
      onTap: () => setState(() => _swimCapType = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blackberry : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.blackberry : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: AppRadius.inputRadius,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.cream : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
