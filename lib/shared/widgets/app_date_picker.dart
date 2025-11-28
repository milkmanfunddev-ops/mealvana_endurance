import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Global wrapper for showDatePicker to ensure consistent styling and fix accessibility issues
/// (specifically truncated year in header on smaller screens)
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
  CalendarDelegate<DateTime> calendarDelegate = const AppDatePickerDelegate(),
  TransitionBuilder? builder,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  
  // Define the header style with a much smaller font to ensure year visibility
  // Using 16px Apercu (standard font) instead of Sansita (display font)
  final headerStyle = AppTextStyles.datePickerHeader.copyWith(
    fontSize: 16, 
    fontFamily: AppTextStyles.apercu, 
    color: isDark ? AppColors.textDark : AppColors.textLight,
    letterSpacing: -0.5,
  );

  TransitionBuilder themedBuilder = (context, child) {
    final themedChild = Theme(
      data: theme.copyWith(
        useMaterial3: true,
        textTheme: theme.textTheme.copyWith(
          headlineLarge: headerStyle, // Used for the selected date in header
          headlineMedium: headerStyle,
          displayLarge: headerStyle,
        ),
        datePickerTheme: theme.datePickerTheme.copyWith(
          headerHeadlineStyle: headerStyle,
          headerHelpStyle: AppTextStyles.smallLabel.copyWith(
            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
          ),
          weekdayStyle: AppTextStyles.calendarDayLetter.copyWith(
            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
          ),
          dayStyle: AppTextStyles.calendarDay.copyWith(
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
          yearStyle: AppTextStyles.calendarDay.copyWith(
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
          backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
          surfaceTintColor: Colors.transparent,
          headerForegroundColor: isDark ? AppColors.textDark : AppColors.textLight,
          headerBackgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        ),
      ),
      child: child!,
    );

    return builder != null ? builder(context, themedChild) : themedChild;
  };

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialEntryMode: initialEntryMode,
    selectableDayPredicate: selectableDayPredicate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    locale: locale,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    textDirection: textDirection,
    builder: themedBuilder,
    initialDatePickerMode: initialDatePickerMode,
    errorFormatText: errorFormatText,
    errorInvalidText: errorInvalidText,
    fieldHintText: fieldHintText,
    fieldLabelText: fieldLabelText,
    keyboardType: keyboardType,
    anchorPoint: anchorPoint,
    onDatePickerModeChange: onDatePickerModeChange,
    switchToInputEntryModeIcon: switchToInputEntryModeIcon,
    switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
    calendarDelegate: calendarDelegate,
  );
}

/// Places the year first and shortens labels so the year is always visible, even with large fonts.
class AppDatePickerDelegate extends GregorianCalendarDelegate {
  const AppDatePickerDelegate();

  String _locale() {
    final locale = Intl.getCurrentLocale();
    return locale.isEmpty ? 'en' : locale;
  }

  @override
  String formatMediumDate(DateTime date, MaterialLocalizations localizations) {
    final year = localizations.formatYear(date);
    final monthDay = DateFormat.MMMd(_locale()).format(date);
    return '$year $monthDay';
  }

  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) {
    final year = localizations.formatYear(date);
    final month = DateFormat.MMM(_locale()).format(date);
    return '$year $month';
  }
}
