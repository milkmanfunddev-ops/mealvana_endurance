import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

/// A two-option pill slider with an animated thumb.
///
/// Designed for binary mode switches where options should look like
/// one connected control rather than two separate buttons.
class TwoOptionPillSlider extends StatelessWidget {
  const TwoOptionPillSlider({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeftTap,
    required this.onRightTap,
    required this.textStyle,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.trackColor,
    required this.thumbColor,
    this.borderColor,
    this.borderWidth = 0,
    this.height = 46,
    this.thumbInset = 2,
    this.enabled = true,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final TextStyle textStyle;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Color trackColor;
  final Color thumbColor;
  final Color? borderColor;
  final double borderWidth;
  final double height;
  final double thumbInset;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      container: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: radius,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: borderWidth),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: isLeftSelected
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.all(thumbInset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumbColor,
                          borderRadius: BorderRadius.circular(
                            (height / 2) - thumbInset,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _SliderSegmentLabel(
                      label: leftLabel,
                      selected: isLeftSelected,
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      textStyle: textStyle,
                      onTap: enabled ? onLeftTap : null,
                    ),
                    _SliderSegmentLabel(
                      label: rightLabel,
                      selected: !isLeftSelected,
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      textStyle: textStyle,
                      onTap: enabled ? onRightTap : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderSegmentLabel extends StatelessWidget {
  const _SliderSegmentLabel({
    required this.label,
    required this.selected,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.textStyle,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final TextStyle textStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                label,
                style: textStyle.copyWith(
                  color: selected ? selectedTextColor : unselectedTextColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
