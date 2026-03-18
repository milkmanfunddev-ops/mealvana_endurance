import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/settings_controller.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Sport Settings Screen - Cycling, swimming, and sport-specific preferences
class SportSettingsScreen extends ConsumerWidget {
  const SportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: settingsState.when(
          data: (state) => Text(
            state.sportSettingsSectionTitle,
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
            ),
          ),
          loading: () => Text(
            'Sport Settings',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
            ),
          ),
          error: (_, __) => Text(
            'Sport Settings',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
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
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GI Sensitivity toggle
          _buildGISensitivityToggle(ref, state),
          SizedBox(height: 32.h),

          // Cycling Settings
          _buildSectionHeader(state.cyclingSectionTitle),
          SizedBox(height: 16.h),

          _buildCyclingFtpInput(ref, state),
          SizedBox(height: 20.h),

          _buildBikeBottlesSelector(ref, state),
          SizedBox(height: 20.h),

          _buildAeroBottleToggle(ref, state),
          SizedBox(height: 20.h),

          _buildBentoBoxToggle(ref, state),
          SizedBox(height: 32.h),

          // Swimming Settings
          _buildSectionHeader(state.swimmingSectionTitle),
          SizedBox(height: 16.h),

          _buildCssPaceInput(ref, state),
          SizedBox(height: 20.h),

          _buildWetsuitToggle(ref, state),
          SizedBox(height: 20.h),

          _buildSwimCapSelector(ref, state),
          SizedBox(height: 32.h),

          // Save button - actually triggers save to Supabase
          PrimaryButton(
            text: state.isSaving ? 'Saving...' : state.saveButtonText,
            onPressed: state.isSaving
                ? null
                : () async {
                    // Call controller to save all sport preferences to Supabase
                    final controller = ref.read(
                      settingsControllerProvider.notifier,
                    );
                    await controller.saveSportSettings();

                    if (context.mounted) {
                      // Show success confirmation
                      MealvanaSnackbar.showInfo(
                        context,
                        'Sport settings saved!',
                      );
                    }
                  },
            width: double.infinity,
          ),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.titleStyle.copyWith(
        color: AppTheme.baseBlack,
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildGISensitivityToggle(WidgetRef ref, dynamic state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.giSensitivityLabel,
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Do you have a sensitive stomach during exercise?',
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        KyleSwitch(
          value: state.giSensitivity ?? false,
          onChanged: (value) {
            ref
                .read(settingsControllerProvider.notifier)
                .updateGISensitivity(value);
          },
          activeTrackColor: AppTheme.primary600,
          inactiveTrackColor: AppTheme.baseGrey.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  // Cycling Settings Widgets

  Widget _buildCyclingFtpInput(WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FTP (Functional Threshold Power)',
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Maximum power you can sustain for ~1 hour (enter 0 if unknown)',
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.baseGrey,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          initialValue: state.ftpWatts?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g., 250',
            suffixText: 'watts',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppTheme.baseGrey.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppTheme.baseGrey.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primary600),
            ),
            filled: true,
            fillColor: AppTheme.baseWhite,
          ),
          onChanged: (value) {
            final ftp = int.tryParse(value);
            if (ftp != null && ftp >= 0) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .updateCyclingPreferences(ftpWatts: ftp);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBikeBottlesSelector(WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Water Bottles',
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [1, 2, 3].map((bottles) {
            final isSelected = state.typicalBikeBottles == bottles;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref
                    .read(settingsControllerProvider.notifier)
                    .updateCyclingPreferences(typicalBikeBottles: bottles),
                child: Container(
                  margin: EdgeInsets.only(right: bottles != 3 ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary600
                        : AppTheme.baseWhite,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary600
                          : AppTheme.baseGrey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    bottles == 3 ? '3+' : '$bottles',
                    textAlign: TextAlign.center,
                    style: AppTheme.textStyle.copyWith(
                      color: isSelected
                          ? AppTheme.baseWhite
                          : AppTheme.baseBlack,
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

  Widget _buildAeroBottleToggle(WidgetRef ref, dynamic state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aero Bottle',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Do you have an aero bottle?',
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        KyleSwitch(
          value: state.hasAeroBottle ?? false,
          onChanged: (value) {
            ref
                .read(settingsControllerProvider.notifier)
                .updateCyclingPreferences(hasAeroBottle: value);
          },
          activeTrackColor: AppTheme.primary600,
          inactiveTrackColor: AppTheme.baseGrey.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildBentoBoxToggle(WidgetRef ref, dynamic state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bento Box',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Do you have a bento box for food?',
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        KyleSwitch(
          value: state.hasBentoBox ?? false,
          onChanged: (value) {
            ref
                .read(settingsControllerProvider.notifier)
                .updateCyclingPreferences(hasBentoBox: value);
          },
          activeTrackColor: AppTheme.primary600,
          inactiveTrackColor: AppTheme.baseGrey.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  // Swimming Settings Widgets

  Widget _buildCssPaceInput(WidgetRef ref, dynamic state) {
    // Convert seconds to MM:SS format for display
    String initialValue = '';
    if (state.cssPacePer100mSeconds != null) {
      final minutes = state.cssPacePer100mSeconds ~/ 60;
      final seconds = state.cssPacePer100mSeconds % 60;
      initialValue = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CSS (Critical Swim Speed)',
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Fastest pace per 100m you can sustain for 30 min (MM:SS format)',
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.baseGrey,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          initialValue: initialValue,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: 'e.g., 2:00',
            suffixText: 'per 100m',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppTheme.baseGrey.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppTheme.baseGrey.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primary600),
            ),
            filled: true,
            fillColor: AppTheme.baseWhite,
          ),
          onChanged: (value) {
            // Parse MM:SS format to total seconds
            final parts = value.split(':');
            if (parts.length == 2) {
              final minutes = int.tryParse(parts[0]);
              final seconds = int.tryParse(parts[1]);
              if (minutes != null && seconds != null && seconds < 60) {
                final totalSeconds = minutes * 60 + seconds;
                ref
                    .read(settingsControllerProvider.notifier)
                    .updateSwimmingPreferences(
                      cssPacePer100mSeconds: totalSeconds,
                    );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildWetsuitToggle(WidgetRef ref, dynamic state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wetsuit',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Do you typically wear a wetsuit?',
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        KyleSwitch(
          value: state.typicalWetsuit ?? false,
          onChanged: (value) {
            ref
                .read(settingsControllerProvider.notifier)
                .updateSwimmingPreferences(typicalWetsuit: value);
          },
          activeTrackColor: AppTheme.primary600,
          inactiveTrackColor: AppTheme.baseGrey.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSwimCapSelector(WidgetRef ref, dynamic state) {
    final capTypes = ['none', 'latex', 'silicone', 'neoprene'];
    final capLabels = ['None', 'Latex', 'Silicone', 'Neoprene'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Swim Cap Type',
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Column(
          children: List.generate(capTypes.length, (index) {
            final capType = capTypes[index];
            final label = capLabels[index];
            final isSelected = state.typicalSwimCapType == capType;

            return Container(
              margin: EdgeInsets.only(
                bottom: index != capTypes.length - 1 ? 8.h : 0,
              ),
              child: GestureDetector(
                onTap: () => ref
                    .read(settingsControllerProvider.notifier)
                    .updateSwimmingPreferences(typicalSwimCapType: capType),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary600
                        : AppTheme.baseWhite,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary600
                          : AppTheme.baseGrey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTheme.textStyle.copyWith(
                      color: isSelected
                          ? AppTheme.baseWhite
                          : AppTheme.baseBlack,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
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
          Icon(Icons.error_outline, size: 64.sp, color: AppTheme.highlight600),
          SizedBox(height: 16.h),
          Text(
            'Error loading sport settings',
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
