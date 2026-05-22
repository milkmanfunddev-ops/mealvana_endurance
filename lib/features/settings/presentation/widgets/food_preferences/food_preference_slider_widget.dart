import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// A 5-point preference slider widget with avoid/like labels
///
/// Displays a horizontal slider track with 5 levels (0-4):
/// - 0: Avoid (red)
/// - 1-3: Neutral (gray)
/// - 4: Like (green)
class FoodPreferenceSliderWidget extends StatelessWidget {
  final int sliderLevel;
  final ValueChanged<int> onLevelChanged;

  const FoodPreferenceSliderWidget({
    super.key,
    required this.sliderLevel,
    required this.onLevelChanged,
  });

  Color _getIconColor(BuildContext context, int level, bool isAvoid) {
    if (isAvoid) {
      return level == 0 ? AppColors.dragonfruit : Colors.grey;
    } else {
      return level == 4 ? AppColors.electrolyte : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : theme.colorScheme.onSurface.withValues(alpha: 0.32);
    final activeDotColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final inactiveDotColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : theme.colorScheme.onSurface.withValues(alpha: 0.25);
    final handleColor = isDark ? Colors.white : theme.colorScheme.primary;

    return Column(
      children: [
        // Slider track
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth - 40;
            final dotSpacing = trackWidth / 4;

            return GestureDetector(
              onHorizontalDragStart: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(
                  0,
                  4,
                );
                onLevelChanged(newLevel);
              },
              onHorizontalDragUpdate: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(
                  0,
                  4,
                );

                if (newLevel != sliderLevel) {
                  onLevelChanged(newLevel);
                }
              },
              onTapDown: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(
                  0,
                  4,
                );
                onLevelChanged(newLevel);
              },
              child: Container(
                height: 40,
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Track line
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 19,
                      child: Container(height: 2, color: trackColor),
                    ),

                    // Track dots
                    ...List.generate(5, (index) {
                      final position = 20.0 + (index * dotSpacing);
                      return Positioned(
                        left: position - 4,
                        top: 15,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: index <= sliderLevel
                                ? activeDotColor
                                : inactiveDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),

                    // Active handle
                    Positioned(
                      left: 20.0 + (sliderLevel * dotSpacing) - 10,
                      top: 11,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: handleColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.2,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.sm),

        // Labels with dynamic color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Avoid label with X icon
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 15,
                  color: _getIconColor(context, sliderLevel, true),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Avoid',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: _getIconColor(context, sliderLevel, true),
                  ),
                ),
              ],
            ),

            // Like label with heart icon
            Row(
              children: [
                Text(
                  'Like',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: _getIconColor(context, sliderLevel, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FaIcon(
                  FontAwesomeIcons.solidHeart,
                  size: 15,
                  color: _getIconColor(context, sliderLevel, false),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
