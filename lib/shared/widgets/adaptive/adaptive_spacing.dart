import 'package:flutter/widgets.dart';
import '../../../theme/kyle_design/app_spacing.dart';
import '../../utils/responsive_breakpoints.dart';

/// Shared spacing helpers for compact-height adaptations.
class AdaptiveSpacing {
  AdaptiveSpacing._();

  static double byHeightClass(
    BuildContext context, {
    required double short,
    required double regular,
    double? tall,
  }) {
    switch (context.heightClass) {
      case ResponsiveHeightClass.short:
        return short;
      case ResponsiveHeightClass.tall:
        return tall ?? regular;
      case ResponsiveHeightClass.regular:
        return regular;
    }
  }

  static double heroHeight(
    BuildContext context, {
    double short = 150,
    double regular = 200,
    double tall = 220,
  }) {
    return byHeightClass(context, short: short, regular: regular, tall: tall);
  }

  static double sectionGap(BuildContext context) {
    return byHeightClass(
      context,
      short: AppSpacing.lg,
      regular: AppSpacing.xxxl,
      tall: AppSpacing.huge,
    );
  }
}
