import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Shows a modal that adapts to screen size:
/// - **Mobile** (< 600 px): bottom sheet
/// - **Wide** (>= 600 px): centered dialog with max-width constraint
///
/// Usage:
/// ```dart
/// final result = await showAdaptiveModal<bool>(
///   context: context,
///   builder: (context) => MyModalContent(),
/// );
/// ```
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxDialogWidth = 480,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  if (context.screenWidth >= Breakpoints.compact) {
    // Wide screen — show as a centered dialog
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth),
          child: builder(context),
        ),
      ),
    );
  }

  // Mobile — show as a bottom sheet
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}
