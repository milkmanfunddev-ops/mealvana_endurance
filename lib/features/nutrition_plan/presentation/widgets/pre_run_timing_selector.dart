import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';

/// Widget for selecting pre-run timing (30min-4hrs in 15min increments)
class PreRunTimingSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final String? label;

  const PreRunTimingSelector({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
    this.label,
  });

  /// Generate list of timing options from 30min to 4hrs in 15min increments
  static List<int> get timingOptions {
    List<int> options = [];
    // 30min to 2hrs in 15min increments
    for (int i = 30; i <= 120; i += 15) {
      options.add(i);
    }
    // 2hrs to 4hrs in 30min increments
    for (int i = 150; i <= 240; i += 30) {
      options.add(i);
    }
    return options;
  }

  /// Format minutes to human-readable string
  static String formatTiming(int minutes) {
    if (minutes < 60) {
      return '${minutes}min';
    } else if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTheme.subtitleStyle.copyWith(
              fontSize: 16.sp,
              color: AppTheme.primary900,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.primary900, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedMinutes,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                color: AppTheme.primary900,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.primary900,
                size: 24.w,
              ),
              items: timingOptions.map<DropdownMenuItem<int>>((int value) {
                final description = value <= 60 ? 'Quick fuel' : value <= 120 ? 'Optimal' : 'Full meal';
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    '${formatTiming(value)} - $description',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        SizedBox(height: 8.h),
        Text(
          _getTimingDescription(selectedMinutes),
          style: AppTheme.textStyle.copyWith(
            fontSize: 12.sp,
            color: AppTheme.baseGrey,
          ),
        ),
      ],
    );
  }

  String _getTimingDescription(int minutes) {
    if (minutes < 60) {
      return 'Quick fuel: Easily digestible carbs only';
    } else if (minutes <= 120) {
      return 'Optimal timing: Balanced meal with carbs and protein';
    } else {
      return 'Full meal timing: Complete nutrition with time to digest';
    }
  }
}

/// Compact version for inline use
class CompactPreRunTimingSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;

  const CompactPreRunTimingSelector({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Color(0xFFD6E0FF),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.primary900, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            color: AppTheme.primary900,
            size: 16.w,
          ),
          SizedBox(width: 6.w),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedMinutes,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              style: AppTheme.textStyle.copyWith(
                fontSize: 14.sp,
                color: AppTheme.primary900,
                fontWeight: FontWeight.w500,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppTheme.primary900,
                size: 20.w,
              ),
              items: PreRunTimingSelector.timingOptions.map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    PreRunTimingSelector.formatTiming(value),
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}