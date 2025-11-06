import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/activity_reminder.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Reminder Settings Bottom Sheet
/// Allows users to configure activity reminders (days before, time, recurring)
class ReminderSettingsBottomSheet extends StatefulWidget {
  const ReminderSettingsBottomSheet({
    super.key,
    this.currentReminder,
    required this.onSave,
  });

  final ActivityReminder? currentReminder;
  final Function(ActivityReminder? reminder) onSave;

  @override
  State<ReminderSettingsBottomSheet> createState() => _ReminderSettingsBottomSheetState();
}

class _ReminderSettingsBottomSheetState extends State<ReminderSettingsBottomSheet> {
  late bool _noReminderNeeded;
  late int _daysBefore;
  late String _timeOfDay;
  late bool _isRecurring;

  @override
  void initState() {
    super.initState();

    // Initialize with current reminder or defaults
    if (widget.currentReminder != null && widget.currentReminder!.enabled) {
      _noReminderNeeded = false;
      _daysBefore = widget.currentReminder!.daysBefore;
      _timeOfDay = widget.currentReminder!.timeOfDay;
      _isRecurring = widget.currentReminder!.recurring;
    } else {
      _noReminderNeeded = true;
      _daysBefore = 1;
      _timeOfDay = '17:00'; // Default: 5:00 PM
      _isRecurring = false;
    }
  }

  void _showTimePicker() async {
    // Parse current time
    final timeParts = _timeOfDay.split(':');
    final currentHour = int.parse(timeParts[0]);
    final currentMinute = int.parse(timeParts[1]);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary600,
              onPrimary: AppTheme.baseWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _timeOfDay = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String _formatTime(String time24) {
    final timeParts = time24.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminder Settings',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary900,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 24.w),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Reminder Options
          Text(
            'Notification Preference',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.baseBlack,
            ),
          ),
          SizedBox(height: 16.h),

          // Option 1: No reminder needed
          _buildReminderOption(
            isSelected: _noReminderNeeded,
            label: 'No reminder needed',
            onTap: () => setState(() => _noReminderNeeded = true),
          ),

          SizedBox(height: 12.h),

          // Option 2: Set a reminder
          _buildReminderOption(
            isSelected: !_noReminderNeeded,
            label: 'Set a reminder',
            onTap: () => setState(() => _noReminderNeeded = false),
          ),

          // Show reminder settings if reminder is enabled
          if (!_noReminderNeeded) ...[
            SizedBox(height: 24.h),

            // Days before picker
            Text(
              'Remind me:',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.baseBlack,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: AppTheme.baseWhite,
                border: Border.all(color: AppTheme.baseGrey),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButton<int>(
                value: _daysBefore,
                isExpanded: true,
                underline: const SizedBox(),
                items: List.generate(7, (index) {
                  final days = index + 1;
                  return DropdownMenuItem(
                    value: days,
                    child: Text(
                      '$days ${days == 1 ? "day" : "days"} before',
                      style: AppTheme.textStyle.copyWith(fontSize: 14.sp),
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _daysBefore = value);
                  }
                },
              ),
            ),

            SizedBox(height: 16.h),

            // Time of day picker
            Text(
              'At:',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.baseBlack,
              ),
            ),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppTheme.baseWhite,
                  border: Border.all(color: AppTheme.baseGrey),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 20.sp, color: AppTheme.baseGrey),
                    SizedBox(width: 12.w),
                    Text(
                      _formatTime(_timeOfDay),
                      style: AppTheme.textStyle.copyWith(fontSize: 14.sp),
                    ),
                    const Spacer(),
                    Icon(Icons.edit, size: 16.sp, color: AppTheme.baseGrey),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // Recurring toggle
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.baseWhite,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.baseGrey),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Repeat this reminder',
                      style: AppTheme.textStyle.copyWith(fontSize: 14.sp),
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (value) => setState(() => _isRecurring = value),
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
              ),
            ),
          ],

          SizedBox(height: 24.h),

          // Save Button
          PrimaryButton(
            text: 'Save Reminder',
            onPressed: () {
              if (_noReminderNeeded) {
                // Clear reminder
                widget.onSave(null);
              } else {
                // Create/update reminder
                final reminder = ActivityReminder(
                  enabled: true,
                  daysBefore: _daysBefore,
                  timeOfDay: _timeOfDay,
                  recurring: _isRecurring,
                );
                widget.onSave(reminder);
              }
              Navigator.of(context).pop();
            },
            width: double.infinity,
            height: 56.h,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderOption({
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary100 : AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary600 : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 12.sp,
                      color: AppTheme.baseWhite,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: AppTheme.textStyle.copyWith(
                  color: isSelected ? AppTheme.primary600 : AppTheme.baseBlack,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
