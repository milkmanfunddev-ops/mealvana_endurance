import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../providers/onboarding_controller.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Sport preferences selection screen
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
          const SnackBar(content: Text('Please select at least one sport')),
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
        SnackBar(content: Text(errorMessage)),
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
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          'Sport Preferences',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: 0.67, // 67% through onboarding (step 2 of 3)
                backgroundColor: AppTheme.baseGrey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary600),
              ),

              SizedBox(height: 32.h),

              Text(
                'Which sports do you do?',
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary900,
                ),
              ),

              SizedBox(height: 8.h),

              Text(
                'We\'ll customize your nutrition plans for each sport.',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  color: AppTheme.baseGrey,
                ),
              ),

              SizedBox(height: 32.h),

              // Sport selection
              _buildSportCheckbox('Running 🏃', _doesRunning, (value) {
                setState(() => _doesRunning = value!);
              }),

              SizedBox(height: 12.h),

              _buildSportCheckbox('Cycling 🚴', _doesCycling, (value) {
                setState(() => _doesCycling = value!);
              }),

              SizedBox(height: 12.h),

              _buildSportCheckbox('Swimming 🏊', _doesSwimming, (value) {
                setState(() => _doesSwimming = value!);
              }),

              SizedBox(height: 32.h),

              // GI Sensitivity (shared)
              _buildGISensitivitySection(),

              // Cycling details (conditional)
              if (_doesCycling) ...[
                SizedBox(height: 32.h),
                _buildCyclingDetailsSection(),
              ],

              // Swimming details (conditional)
              if (_doesSwimming) ...[
                SizedBox(height: 32.h),
                _buildSwimmingDetailsSection(),
              ],

              SizedBox(height: 40.h),

              // Continue button
              PrimaryButton(
                text: 'Continue',
                onPressed: asyncState.isLoading ? null : _submitPreferences,
                isLoading: asyncState.isLoading,
                width: double.infinity,
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        border: Border.all(color: AppTheme.baseGrey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: AppTheme.textStyle.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary900,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary600,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      ),
    );
  }

  Widget _buildGISensitivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gut Sensitivity',
          style: AppTheme.titleStyle.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 12.h),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            border: Border.all(color: AppTheme.baseGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: SwitchListTile(
            title: Text(
              'Sensitive stomach during exercise',
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary900,
              ),
            ),
            subtitle: Text(
              'Helps us recommend easier-to-digest foods',
              style: AppTheme.noteStyle.copyWith(
                fontSize: 14.sp,
                color: AppTheme.baseGrey,
              ),
            ),
            value: _giSensitivity,
            onChanged: (value) {
              setState(() => _giSensitivity = value);
            },
            activeColor: AppTheme.primary600,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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
          style: AppTheme.titleStyle.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 12.h),

        // FTP input
        Text(
          'FTP (Functional Threshold Power)',
          style: AppTheme.textStyle.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 4.h),

        Text(
          'Maximum power you can sustain for ~1 hour (enter 0 if unknown)',
          style: AppTheme.noteStyle.copyWith(
            fontSize: 14.sp,
            color: AppTheme.baseGrey,
          ),
        ),

        SizedBox(height: 8.h),

        TextFormField(
          controller: _ftpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g., 250',
            suffixText: 'watts',
            filled: true,
            fillColor: AppTheme.baseWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppTheme.baseGrey.withOpacity(0.3)),
            ),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Required';
            final ftp = int.tryParse(value!);
            if (ftp == null || ftp < 0) return 'Enter valid FTP (0 or higher)';
            return null;
          },
        ),

        SizedBox(height: 20.h),

        // Bike bottles
        Text(
          'Water Bottles',
          style: AppTheme.textStyle.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 8.h),

        Row(
          children: [1, 2, 3].map((bottles) {
            final isSelected = _bikeBottles == bottles;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _bikeBottles = bottles),
                child: Container(
                  margin: EdgeInsets.only(right: bottles != 3 ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary600 : AppTheme.baseWhite,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    bottles == 3 ? '3+' : '$bottles',
                    textAlign: TextAlign.center,
                    style: AppTheme.textStyle.copyWith(
                      color: isSelected ? AppTheme.baseWhite : AppTheme.baseBlack,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 20.h),

        // Aero bottle
        Container(
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            border: Border.all(color: AppTheme.baseGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: SwitchListTile(
            title: Text(
              'Aero Bottle',
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary900,
              ),
            ),
            subtitle: Text(
              'Do you have an aero bottle?',
              style: AppTheme.noteStyle.copyWith(
                fontSize: 14.sp,
                color: AppTheme.baseGrey,
              ),
            ),
            value: _hasAeroBottle,
            onChanged: (value) => setState(() => _hasAeroBottle = value),
            activeColor: AppTheme.primary600,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          ),
        ),

        SizedBox(height: 12.h),

        // Bento box
        Container(
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            border: Border.all(color: AppTheme.baseGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: SwitchListTile(
            title: Text(
              'Bento Box',
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary900,
              ),
            ),
            subtitle: Text(
              'Do you have a bento box for food?',
              style: AppTheme.noteStyle.copyWith(
                fontSize: 14.sp,
                color: AppTheme.baseGrey,
              ),
            ),
            value: _hasBentoBox,
            onChanged: (value) => setState(() => _hasBentoBox = value),
            activeColor: AppTheme.primary600,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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
          style: AppTheme.titleStyle.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 12.h),

        // CSS input
        Text(
          'CSS (Critical Swim Speed)',
          style: AppTheme.textStyle.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 4.h),

        Text(
          'Fastest pace per 100m you can sustain for 30 min (MM:SS format)',
          style: AppTheme.noteStyle.copyWith(
            fontSize: 14.sp,
            color: AppTheme.baseGrey,
          ),
        ),

        SizedBox(height: 8.h),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cssMinutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  filled: true,
                  fillColor: AppTheme.baseWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.baseGrey.withOpacity(0.3)),
                  ),
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
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                ':',
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 24.sp,
                  color: AppTheme.primary900,
                ),
              ),
            ),

            Expanded(
              child: TextFormField(
                controller: _cssSecondsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Seconds',
                  filled: true,
                  fillColor: AppTheme.baseWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.baseGrey.withOpacity(0.3)),
                  ),
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

        SizedBox(height: 20.h),

        // Wetsuit
        Container(
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            border: Border.all(color: AppTheme.baseGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: SwitchListTile(
            title: Text(
              'Wetsuit',
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary900,
              ),
            ),
            subtitle: Text(
              'Do you typically wear a wetsuit?',
              style: AppTheme.noteStyle.copyWith(
                fontSize: 14.sp,
                color: AppTheme.baseGrey,
              ),
            ),
            value: _typicalWetsuit,
            onChanged: (value) => setState(() => _typicalWetsuit = value),
            activeColor: AppTheme.primary600,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          ),
        ),

        SizedBox(height: 20.h),

        // Swim cap type
        Text(
          'Swim Cap Type',
          style: AppTheme.textStyle.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary900,
          ),
        ),

        SizedBox(height: 8.h),

        Column(
          children: [
            _buildSwimCapOption('none', 'None'),
            SizedBox(height: 8.h),
            _buildSwimCapOption('latex', 'Latex'),
            SizedBox(height: 8.h),
            _buildSwimCapOption('silicone', 'Silicone'),
            SizedBox(height: 8.h),
            _buildSwimCapOption('neoprene', 'Neoprene'),
          ],
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
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary600 : AppTheme.baseWhite,
          border: Border.all(
            color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.textStyle.copyWith(
            color: isSelected ? AppTheme.baseWhite : AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
