import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../providers/settings_controller.dart';

/// Preferences Screen - Units, gut training, food preferences
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

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
            state.preferenceSectionTitle,
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
            ),
          ),
          loading: () => Text(
            'Preferences',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
            ),
          ),
          error: (_, __) => Text(
            'Preferences',
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
          // Distance unit
          _buildDistanceUnitSelector(ref, state),
          SizedBox(height: 20.h),

          // Pace unit
          _buildPaceUnitSelector(ref, state),
          SizedBox(height: 20.h),

          // Gut training level
          _buildGutTrainingSelector(ref, state),
          SizedBox(height: 20.h),

          // Food preferences button
          _buildFoodPreferencesButton(context, state),
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
                        content: const Text('✅ Preferences saved!'),
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
    );
  }

  Widget _buildDistanceUnitSelector(WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.distanceUnitLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: DistanceUnit.values.map((unit) {
            final isSelected = state.preferredDistanceUnit == unit;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(settingsControllerProvider.notifier).updateDistanceUnit(unit),
                child: Container(
                  margin: EdgeInsets.only(right: unit != DistanceUnit.values.last ? 8.w : 0),
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
                    unit.displayName,
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

  Widget _buildPaceUnitSelector(WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.paceUnitLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: PaceUnit.values.map((unit) {
            final isSelected = state.preferredPaceUnit == unit;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(settingsControllerProvider.notifier).updatePaceUnit(unit),
                child: Container(
                  margin: EdgeInsets.only(right: unit != PaceUnit.values.last ? 8.w : 0),
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
                    unit.displayName,
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

  Widget _buildGutTrainingSelector(WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.gutTrainingLabel,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Column(
          children: GutTraining.values.map((level) {
            final isSelected = state.gutTrainingLevel == level;
            return Container(
              margin: EdgeInsets.only(bottom: level != GutTraining.values.last ? 8.h : 0),
              child: GestureDetector(
                onTap: () => ref.read(settingsControllerProvider.notifier).updateGutTraining(level),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary600 : AppTheme.baseWhite,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    level.name.toUpperCase(),
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

  Widget _buildFoodPreferencesButton(BuildContext context, dynamic state) {
    return GestureDetector(
      onTap: () {
        // Navigate to food preferences editing screen
        context.push('/settings/food-preferences');
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 24.sp,
              color: AppTheme.primary600,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Preferences',
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Edit food likes & dislikes',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: AppTheme.primary600,
            ),
          ],
        ),
      ),
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
            'Error loading preferences',
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
