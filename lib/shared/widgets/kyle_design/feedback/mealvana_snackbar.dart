import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';

/// Snackbar type enum for different visual states
enum SnackbarType { success, error, warning, info, loading }

/// Mealvana branded snackbar with consistent styling.
///
/// Provides static helper methods for showing different types of snackbars:
/// - [showSuccess] - Green electrolyte background with checkmark
/// - [showError] - Dragonfruit background with error icon
/// - [showWarning] - Orange background with warning icon
/// - [showInfo] - Blackberry background with info icon
/// - [showLoading] - Blackberry background with loading indicator
///
/// Example usage:
/// ```dart
/// MealvanaSnackbar.showSuccess(context, 'Settings saved!');
/// MealvanaSnackbar.showError(context, 'Failed to save settings');
/// ```
class MealvanaSnackbar {
  MealvanaSnackbar._();

  /// Default duration for snackbars
  static const Duration defaultDuration = Duration(seconds: 3);

  /// Short duration for simple messages
  static const Duration shortDuration = Duration(seconds: 2);

  /// Long duration for important messages
  static const Duration longDuration = Duration(seconds: 5);

  /// Shows a success snackbar with electrolyte green background.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    bool showIcon = true,
  }) {
    _show(
      context,
      message: message,
      type: SnackbarType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showIcon: showIcon,
    );
  }

  /// Shows an error snackbar with dragonfruit pink background.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool showIcon = true,
  }) {
    _show(
      context,
      message: message,
      type: SnackbarType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showIcon: showIcon,
    );
  }

  /// Shows a warning snackbar with orange background.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    bool showIcon = true,
  }) {
    _show(
      context,
      message: message,
      type: SnackbarType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showIcon: showIcon,
    );
  }

  /// Shows an info snackbar with blackberry background.
  /// Returns the [ScaffoldFeatureController] so callers can force-dismiss the
  /// snackbar themselves (e.g. as a backstop against Flutter's built-in
  /// auto-dismiss timer not arming when the entrance animation is interrupted
  /// by a rebuild storm).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    bool showIcon = true,
  }) {
    return _show(
      context,
      message: message,
      type: SnackbarType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showIcon: showIcon,
    );
  }

  /// Shows a loading snackbar with blackberry background and spinner.
  ///
  /// Returns the [ScaffoldFeatureController] so you can dismiss it manually:
  /// ```dart
  /// final controller = MealvanaSnackbar.showLoading(context, 'Saving...');
  /// // ... do work ...
  /// controller.close();
  /// ```
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message,
  ) {
    return _show(
      context,
      message: message,
      type: SnackbarType.loading,
      duration: const Duration(days: 1), // Stays until dismissed
      showIcon: true,
    );
  }

  /// Hides the currently showing snackbar
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Internal method to show the snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _show(
    BuildContext context, {
    required String message,
    required SnackbarType type,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showIcon = true,
  }) {
    // Clear any existing snackbars first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              config.icon,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: config.textColor,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: config.textColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: config.actionColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Get configuration for each snackbar type
  static _SnackbarConfig _getConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        // Electrolyte background - highly visible, dark text for contrast
        return _SnackbarConfig(
          backgroundColor: AppColors.electrolyte,
          textColor: AppColors.blackberry,
          actionColor: AppColors.blackberry,
          icon: const FaIcon(
            FontAwesomeIcons.circleCheck,
            color: AppColors.blackberry,
            size: 20,
          ),
        );
      case SnackbarType.error:
        // Dragonfruit background - attention-grabbing, white text
        return _SnackbarConfig(
          backgroundColor: AppColors.dragonfruit,
          textColor: Colors.white,
          actionColor: AppColors.cream,
          icon: const FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: Colors.white,
            size: 20,
          ),
        );
      case SnackbarType.warning:
        // Orange background - warning color, dark text for readability
        return _SnackbarConfig(
          backgroundColor: AppColors.orange,
          textColor: AppColors.blackberry,
          actionColor: AppColors.blackberry,
          icon: const FaIcon(
            FontAwesomeIcons.triangleExclamation,
            color: AppColors.blackberry,
            size: 20,
          ),
        );
      case SnackbarType.info:
        // Cream background - stands out on dark blackberry backgrounds
        return _SnackbarConfig(
          backgroundColor: AppColors.cream,
          textColor: AppColors.blackberry,
          actionColor: AppColors.electrolyteDark,
          icon: const FaIcon(
            FontAwesomeIcons.circleInfo,
            color: AppColors.blackberry,
            size: 20,
          ),
        );
      case SnackbarType.loading:
        // Cream background - visible on dark backgrounds, dark spinner
        return _SnackbarConfig(
          backgroundColor: AppColors.cream,
          textColor: AppColors.blackberry,
          actionColor: AppColors.electrolyteDark,
          icon: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blackberry),
            ),
          ),
        );
    }
  }
}

/// Internal configuration class for snackbar styling
class _SnackbarConfig {
  final Color backgroundColor;
  final Color textColor;
  final Color actionColor;
  final Widget icon;

  const _SnackbarConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.actionColor,
    required this.icon,
  });
}
