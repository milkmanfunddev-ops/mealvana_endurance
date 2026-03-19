import 'package:calendar_date_picker2/calendar_date_picker2.dart'
    hide SelectableDayPredicate;
import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

@visibleForTesting
Size appDatePickerDialogSizeForWidth(double screenWidth) {
  final dialogWidth = (screenWidth - 24).clamp(325.0, 420.0).toDouble();
  return Size(dialogWidth, 400);
}

/// Global wrapper for date picking to ensure consistent styling.
///
/// Uses `calendar_date_picker2` for better UX (easy year/month navigation).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  TextDirection? textDirection,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? errorFormatText,
  String? errorInvalidText,
  String? fieldHintText,
  String? fieldLabelText,
  TextInputType? keyboardType,
  Offset? anchorPoint,
  ValueChanged<DatePickerEntryMode>? onDatePickerModeChange,
  Icon? switchToInputEntryModeIcon,
  Icon? switchToCalendarEntryModeIcon,
  // Kept for API compat but unused with calendar_date_picker2
  dynamic calendarDelegate,
  TransitionBuilder? builder,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final bgColor = isDark ? AppColors.blackberry : AppColors.cream;
  final textColor = isDark ? AppColors.cream : AppColors.blackberry;
  final secondaryColor = isDark
      ? AppColors.textDarkSecondary
      : AppColors.textLightSecondary;

  final config = CalendarDatePicker2WithActionButtonsConfig(
    calendarType: CalendarDatePicker2Type.single,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate ?? DateTime.now(),
    selectedDayHighlightColor: AppColors.orange,
    selectedDayTextStyle: AppTextStyles.bodyMedium.copyWith(
      color: AppColors.cream,
      fontWeight: FontWeight.w600,
    ),
    todayTextStyle: AppTextStyles.bodyMedium.copyWith(
      color: AppColors.orange,
      fontWeight: FontWeight.w600,
    ),
    dayTextStyle: AppTextStyles.bodyMedium.copyWith(color: textColor),
    weekdayLabelTextStyle: AppTextStyles.smallLabel.copyWith(
      color: secondaryColor,
      fontWeight: FontWeight.w600,
    ),
    controlsTextStyle: AppTextStyles.datePickerHeader.copyWith(
      color: textColor,
    ),
    yearTextStyle: AppTextStyles.bodyMedium.copyWith(color: textColor),
    selectedYearTextStyle: AppTextStyles.bodyMedium.copyWith(
      color: AppColors.cream,
      fontWeight: FontWeight.w600,
    ),
    okButtonTextStyle: AppTextStyles.bodyMedium.copyWith(
      color: AppColors.orange,
      fontWeight: FontWeight.w600,
    ),
    cancelButtonTextStyle: AppTextStyles.bodyMedium.copyWith(
      color: secondaryColor,
    ),
    okButton: confirmText != null ? Text(confirmText) : null,
    cancelButton: cancelText != null ? Text(cancelText) : null,
  );

  final dialogSize = appDatePickerDialogSizeForWidth(
    MediaQuery.sizeOf(context).width,
  );

  final results = await showCalendarDatePicker2Dialog(
    context: context,
    config: config,
    dialogSize: dialogSize,
    value: [initialDate],
    borderRadius: BorderRadius.circular(15),
    dialogBackgroundColor: bgColor,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
  );

  if (results != null && results.isNotEmpty && results.first != null) {
    return results.first;
  }
  return null;
}

/// Global wrapper for time picking to ensure consistent styling.
///
/// Applies Mealvana theming (orange primary, cream/blackberry surfaces).
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: AppColors.electrolyte,
            onPrimary: isDark ? AppColors.blackberry : Colors.white,
          ),
        ),
        child: child!,
      );
    },
  );
}

/// Merges a [date] and [time] into a single [DateTime].
///
/// Preserves the year/month/day from [date] and the hour/minute from [time].
DateTime mergeDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Replaces the time component of [dateTime] with [time], preserving the date.
DateTime replaceDateTimeTime(DateTime dateTime, TimeOfDay time) {
  return DateTime(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    time.hour,
    time.minute,
  );
}

/// Replaces the date component of [dateTime] with [date], preserving the time.
DateTime replaceDateTimeDate(DateTime dateTime, DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    dateTime.hour,
    dateTime.minute,
  );
}
