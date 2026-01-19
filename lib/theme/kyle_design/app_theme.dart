import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';


/// Kyle's Design System Theme Configuration
/// Implements dual theme system with exact Figma specifications
class AppTheme {
  AppTheme._();

  /// Light theme (Cream background)
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.orange,
      onPrimary: AppColors.textLight,
      secondary: AppColors.electrolyte,
      onSecondary: AppColors.textLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      error: AppColors.dragonfruit,
      onError: AppColors.textLight,
      outline: AppColors.borderLight,
      surfaceContainerHighest: AppColors.cream,
      onSurfaceVariant: AppColors.textLightSecondary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      
      // Typography
      textTheme: _buildTextTheme(AppColors.textLight, AppColors.textLightSecondary),
      
      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(
          color: AppColors.textLight,
          size: AppIconSizes.md,
        ),
        titleTextStyle: AppTextStyles.pageTitle.copyWith(
          color: AppColors.textLight,
        ),
      ),
      
      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary,
        ),
      ),
      
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.orange,
          side: const BorderSide(color: AppColors.orange, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary,
        ),
      ),
      
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.dragonfruit,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          textStyle: AppTextStyles.buttonTertiary,
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.dragonfruit),
        ),
        hintStyle: AppTextStyles.inputText.copyWith(
          color: AppColors.textLightSecondary,
        ),
        labelStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textLightSecondary,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.borderLightSecondary),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      
      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listItemPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.textLightSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.smallLabel,
        unselectedLabelStyle: AppTextStyles.smallLabel,
      ),
      
      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelStyle: AppTextStyles.tabSelector.copyWith(
          color: AppColors.textLight,
        ),
        unselectedLabelStyle: AppTextStyles.tabSelector.copyWith(
          color: AppColors.textLightSecondary,
        ),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
      ),
      
      // Segmented Buttons
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.orange;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textLight;
            }
            return AppColors.textLight;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.borderLight),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: AppRadius.segmentedControlRadius,
            ),
          ),
          textStyle: WidgetStateProperty.all(AppTextStyles.segmentedControl),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
      ),
      
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.electrolyte,
        inactiveTrackColor: AppColors.electrolyte.withOpacity(0.3),
        thumbColor: AppColors.electrolyte,
        overlayColor: AppColors.electrolyte.withOpacity(0.2),
        valueIndicatorColor: AppColors.electrolyte,
        valueIndicatorTextStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textLight,
        ),
      ),
      
      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electrolyte;
          }
          return AppColors.surfaceLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electrolyte.withOpacity(0.5);
          }
          return AppColors.borderLightSecondary;
        }),
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.textLight,
        size: AppIconSizes.md,
      ),
      
      // Dividers
      dividerTheme: DividerThemeData(
        color: AppColors.borderLightSecondary,
        thickness: 1,
        space: 1,
      ),
      
      // Date Picker
      datePickerTheme: DatePickerThemeData(
        headerHeadlineStyle: AppTextStyles.datePickerHeader.copyWith(
          fontSize: 18, // Smaller font to prevent year truncation (was 20, 24)
          letterSpacing: -0.5,
          color: AppColors.textLight,
        ),
        headerHelpStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textLightSecondary,
        ),
        weekdayStyle: AppTextStyles.calendarDayLetter.copyWith(
          color: AppColors.textLightSecondary,
        ),
        dayStyle: AppTextStyles.calendarDay.copyWith(
          color: AppColors.textLight,
        ),
        yearStyle: AppTextStyles.calendarDay.copyWith(
          color: AppColors.textLight,
        ),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// Dark theme (Blackberry background)
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.orange,
      onPrimary: AppColors.textDark,
      secondary: AppColors.electrolyte,
      onSecondary: AppColors.textDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      error: AppColors.dragonfruit,
      onError: AppColors.textDark,
      outline: AppColors.borderDark,
      surfaceContainerHighest: AppColors.blackberry,
      onSurfaceVariant: AppColors.textDarkSecondary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.blackberry,
      
      // Typography
      textTheme: _buildTextTheme(AppColors.textDark, AppColors.textDarkSecondary),
      
      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: AppColors.textDark,
          size: AppIconSizes.md,
        ),
        titleTextStyle: AppTextStyles.pageTitle.copyWith(
          color: AppColors.textDark,
        ),
      ),
      
      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary,
        ),
      ),
      
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.orange,
          side: const BorderSide(color: AppColors.orange, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary,
        ),
      ),
      
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.dragonfruit,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          textStyle: AppTextStyles.buttonTertiary,
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.dragonfruit),
        ),
        hintStyle: AppTextStyles.inputText.copyWith(
          color: AppColors.textDarkSecondary,
        ),
        labelStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textDarkSecondary,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.borderDarkSecondary),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      
      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listItemPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.blackberry,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.textDarkSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.smallLabel,
        unselectedLabelStyle: AppTextStyles.smallLabel,
      ),
      
      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelStyle: AppTextStyles.tabSelector.copyWith(
          color: AppColors.textDark,
        ),
        unselectedLabelStyle: AppTextStyles.tabSelector.copyWith(
          color: AppColors.textDarkSecondary,
        ),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
      ),
      
      // Segmented Buttons
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.orange;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textDark;
            }
            return AppColors.textDark;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.borderDark),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: AppRadius.segmentedControlRadius,
            ),
          ),
          textStyle: WidgetStateProperty.all(AppTextStyles.segmentedControl),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
      ),
      
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.electrolyte,
        inactiveTrackColor: AppColors.electrolyte.withOpacity(0.3),
        thumbColor: AppColors.electrolyte,
        overlayColor: AppColors.electrolyte.withOpacity(0.2),
        valueIndicatorColor: AppColors.electrolyte,
        valueIndicatorTextStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textDark,
        ),
      ),
      
      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electrolyte;
          }
          return AppColors.surfaceDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electrolyte.withOpacity(0.5);
          }
          return AppColors.borderDarkSecondary;
        }),
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.textDark,
        size: AppIconSizes.md,
      ),
      
      // Dividers
      dividerTheme: DividerThemeData(
        color: AppColors.borderDarkSecondary,
        thickness: 1,
        space: 1,
      ),
      
      // Date Picker
      datePickerTheme: DatePickerThemeData(
        headerHeadlineStyle: AppTextStyles.datePickerHeader.copyWith(
          fontSize: 18, // Smaller font to prevent year truncation (was 20, 24)
          letterSpacing: -0.5,
          color: AppColors.textDark,
        ),
        headerHelpStyle: AppTextStyles.smallLabel.copyWith(
          color: AppColors.textDarkSecondary,
        ),
        weekdayStyle: AppTextStyles.calendarDayLetter.copyWith(
          color: AppColors.textDarkSecondary,
        ),
        dayStyle: AppTextStyles.calendarDay.copyWith(
          color: AppColors.textDark,
        ),
        yearStyle: AppTextStyles.calendarDay.copyWith(
          color: AppColors.textDark,
        ),
        backgroundColor: AppColors.blackberry,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// Build text theme with appropriate colors
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: AppTextStyles.pageTitle.copyWith(color: primaryColor),
      displayMedium: AppTextStyles.pageTitle.copyWith(color: primaryColor),
      displaySmall: AppTextStyles.sectionTitle.copyWith(color: primaryColor),
      headlineLarge: AppTextStyles.pageTitle.copyWith(color: primaryColor),
      headlineMedium: AppTextStyles.sectionTitle.copyWith(color: primaryColor),
      headlineSmall: AppTextStyles.sectionTitle.copyWith(color: primaryColor),
      titleLarge: AppTextStyles.sectionTitle.copyWith(color: primaryColor),
      titleMedium: AppTextStyles.subtitle.copyWith(color: primaryColor),
      titleSmall: AppTextStyles.descriptor.copyWith(color: primaryColor),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: primaryColor),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: primaryColor),
      bodySmall: AppTextStyles.smallLabel.copyWith(color: secondaryColor),
      labelLarge: AppTextStyles.inputText.copyWith(color: primaryColor),
      labelMedium: AppTextStyles.smallLabel.copyWith(color: secondaryColor),
      labelSmall: AppTextStyles.smallLabel.copyWith(color: secondaryColor),
    );
  }
}