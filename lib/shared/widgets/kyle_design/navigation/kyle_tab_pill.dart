import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Segmented "pill" tab bar — a filled track with the selected item drawn as
/// an inverted pill. Ratified in the meal-logging screen and re-used by the
/// Food screen's Plan · Meals · Shopping segments; the prototype mirrors it as
/// `.k-tab-pill` in `packages/web/src/styles/kyle.css`.
///
/// Distinct from [KyleSegmentedControl], which draws every segment as an
/// outlined box. Use this one where the segments are *sections of a screen*.
class KyleTabPill extends StatelessWidget {
  const KyleTabPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.itemKeys,
  });

  /// One label per segment, in display order.
  final List<String> labels;

  /// Index into [labels] of the active segment.
  final int selectedIndex;

  final ValueChanged<int> onChanged;

  /// Optional per-segment keys, parallel to [labels], for tests.
  final List<Key>? itemKeys;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                key: itemKeys != null && i < itemKeys!.length
                    ? itemKeys![i]
                    : null,
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? (isDark ? AppColors.cream : AppColors.blackberry)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == selectedIndex
                                ? (isDark
                                      ? AppColors.blackberry
                                      : AppColors.cream)
                                : (isDark
                                      ? AppColors.cream.withValues(alpha: 0.7)
                                      : AppColors.blackberry.withValues(
                                          alpha: 0.6,
                                        )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
