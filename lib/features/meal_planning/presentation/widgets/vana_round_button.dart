import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// A 44pt circular icon button on the raised surface — the prototype's
/// `.v-backbtn`. Used for back / new-conversation / conversations across the
/// meal-planning screens, which draw their headers in the body rather than in
/// an [AppBar].
class VanaRoundButton extends StatelessWidget {
  const VanaRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.iconSize = 18,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  /// The standard back button for a meal-planning detail screen.
  factory VanaRoundButton.back({
    Key? key,
    required BuildContext context,
    required VoidCallback onTap,
  }) => VanaRoundButton(
    key: key,
    icon: FontAwesomeIcons.arrowLeft,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: FaIcon(
                icon,
                size: iconSize,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
