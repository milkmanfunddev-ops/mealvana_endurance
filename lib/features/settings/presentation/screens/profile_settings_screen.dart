import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/debug_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/settings_controller.dart';
import '../../../../shared/widgets/app_date_picker.dart';

/// Profile Settings Screen - Personal information
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _handleTitleTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    // Debug logging
    debugPrint('🐛 Profile title tap detected! Tap count: $_tapCount');

    if (_tapCount == 3) {
      _tapCount = 0; // Reset counter
      debugPrint('🎉 Triple tap detected! Opening debug screen...');

      // Navigate to debug screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DebugScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: GestureDetector(
          onTap: _handleTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: settingsState.when(
              data: (state) => Text(
                state.profileSectionTitle,
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 18.sp,
                ),
              ),
              loading: () => Text(
                'Profile',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 18.sp,
                ),
              ),
              error: (_, __) => Text(
                'Profile',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 18.sp,
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: settingsState.when(
        data: (state) => _buildContent(context, ref, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic state) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input fields
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Gender
          _buildGenderSelector(context, ref, state),
          SizedBox(height: 20.h),

          // Birthday
          _buildBirthdaySelector(context, ref, state),
          SizedBox(height: 20.h),

          // Height
          _buildHeightSelector(context, ref, state),
          SizedBox(height: 20.h),

          // Weight
          _buildWeightSelector(context, ref, state),
          SizedBox(height: 20.h),

          // Water bottle preference
          _buildWaterBottleToggle(ref, state),
          SizedBox(height: 32.h),

          // Save button
          PrimaryButton(
            text: state.saveButtonText,
            onPressed: state.isSaving
                ? null
                : () {
                    // Show save confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Profile saved!'),
                        backgroundColor: AppTheme.primary600,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            width: double.infinity,
          ),

          SizedBox(height: 40.h),
        ],
      ),
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context, WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.genderLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: Gender.values.map((gender) {
            final isSelected = state.gender == gender;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(settingsControllerProvider.notifier).updateGender(gender),
                child: Container(
                  margin: EdgeInsets.only(right: gender != Gender.values.last ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary600 : AppTheme.baseWhite,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    gender.displayName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTheme.textStyle.copyWith(
                      color: isSelected ? AppTheme.baseWhite : AppTheme.baseBlack,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBirthdaySelector(BuildContext context, WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.birthdayLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: () async {
            final selectedDate = await showAppDatePicker(
              context: context,
              initialDate: state.birthday ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
              lastDate: DateTime.now(),
            );
            if (selectedDate != null) {
              ref.read(settingsControllerProvider.notifier).updateBirthday(selectedDate);
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: AppTheme.baseWhite,
              border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              state.birthday != null
                  ? '${state.birthday!.month}/${state.birthday!.day}/${state.birthday!.year}'
                  : 'Select your birthday',
              style: AppTheme.textStyle.copyWith(
                color: state.birthday != null ? AppTheme.baseBlack : AppTheme.baseGrey,
                fontSize: 16.sp,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightSelector(BuildContext context, WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.heightLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            // Feet selector
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.baseWhite,
                  border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.heightFeet,
                    hint: const Text('Feet'),
                    items: List.generate(4, (index) => index + 4).map((feet) {
                      return DropdownMenuItem(
                        value: feet,
                        child: Text('$feet ft'),
                      );
                    }).toList(),
                    onChanged: (feet) {
                      if (feet != null) {
                        ref.read(settingsControllerProvider.notifier)
                            .updateHeight(feet, state.heightInches ?? 0);
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Inches selector
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.baseWhite,
                  border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.heightInches,
                    hint: const Text('Inches'),
                    items: List.generate(12, (index) => index).map((inches) {
                      return DropdownMenuItem(
                        value: inches,
                        child: Text('$inches in'),
                      );
                    }).toList(),
                    onChanged: (inches) {
                      if (inches != null) {
                        ref.read(settingsControllerProvider.notifier)
                            .updateHeight(state.heightFeet ?? 5, inches);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightSelector(BuildContext context, WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.weightLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          initialValue: state.weightPounds?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter weight in pounds',
            suffixText: 'lbs',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primary600),
            ),
            filled: true,
            fillColor: AppTheme.baseWhite,
          ),
          onChanged: (value) {
            final weight = double.tryParse(value);
            if (weight != null && weight > 0) {
              ref.read(settingsControllerProvider.notifier).updateWeight(weight);
            }
          },
        ),
      ],
    );
  }

  Widget _buildWaterBottleToggle(WidgetRef ref, dynamic state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            state.waterBottleLabel,
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: state.runsWithWaterBottle,
          onChanged: (value) {
            ref.read(settingsControllerProvider.notifier).updateWaterBottle(value);
          },
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            return AppTheme.baseWhite;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primary600;
            }
            return AppTheme.baseGrey.withValues(alpha: 0.3);
          }),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: AppTheme.highlight600,
          ),
          SizedBox(height: 16.h),
          Text(
            'Error loading profile',
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.highlight600,
              fontSize: 18.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: AppTheme.noteStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
