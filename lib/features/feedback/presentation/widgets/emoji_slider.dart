import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/feedback_data.dart';

/// Emoji slider matching Alex's design
/// Shows large emoji at top, text, and horizontal slider below
class EmojiSlider extends StatefulWidget {
  const EmojiSlider({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
  });

  final SatisfactionLevel selectedLevel;
  final Function(SatisfactionLevel) onChanged;

  @override
  State<EmojiSlider> createState() => _EmojiSliderState();
}

class _EmojiSliderState extends State<EmojiSlider> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large emoji display
        Container(
          width: 80.w,
          height: 80.h,
          decoration: BoxDecoration(
            color: AppTheme.baseWhite.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              widget.selectedLevel.emoji,
              style: TextStyle(fontSize: 40.sp),
            ),
          ),
        ),

        SizedBox(height: 12.h),

        // Text description
        Text(
          widget.selectedLevel.label,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 16.h),

        // Custom slider
        _buildCustomSlider(),
      ],
    );
  }

  Widget _buildCustomSlider() {
    final currentIndex = SatisfactionLevel.values.indexOf(widget.selectedLevel);

    return SizedBox(
      height: 60.h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sliderWidth = constraints.maxWidth - 80.w;

          return GestureDetector(
            onTapDown: (details) {
              _handleTap(details.localPosition.dx, sliderWidth);
            },
            onHorizontalDragUpdate: (details) {
              _handleTap(details.localPosition.dx, sliderWidth);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Slider track
                Container(
                  height: 8.h,
                  margin: EdgeInsets.symmetric(horizontal: 40.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary600,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),

                // Filled portion
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: 40.w,
                  child: Container(
                    height: 8.h,
                    width: _getFilledWidth(currentIndex, sliderWidth),
                    decoration: BoxDecoration(
                      color: AppTheme.primary900,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),

                // Slider thumb/circle
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: _getThumbPosition(currentIndex, sliderWidth),
                  child: Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primary900,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.highlight290,
                        width: 3.0,
                      ),
                    ),
                  ),
                ),

                // Small emojis at positions
                ...SatisfactionLevel.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final level = entry.value;

                  return Positioned(
                    left: _getEmojiPosition(index, sliderWidth),
                    child: GestureDetector(
                      onTap: () => widget.onChanged(level),
                      child: Text(
                        level.emoji,
                        style: TextStyle(fontSize: 20.sp),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTap(double localX, double sliderWidth) {
    final sectionWidth = sliderWidth / 2;
    final adjustedX = localX - 40.w;

    int newIndex;
    if (adjustedX < sectionWidth / 2) {
      newIndex = 0;
    } else if (adjustedX < sectionWidth * 1.5) {
      newIndex = 1;
    } else {
      newIndex = 2;
    }

    newIndex = newIndex.clamp(0, SatisfactionLevel.values.length - 1);

    if (newIndex != SatisfactionLevel.values.indexOf(widget.selectedLevel)) {
      widget.onChanged(SatisfactionLevel.values[newIndex]);
    }
  }

  double _getFilledWidth(int currentIndex, double sliderWidth) {
    return (sliderWidth / 2) * currentIndex;
  }

  double _getThumbPosition(int currentIndex, double sliderWidth) {
    return 24.w + (sliderWidth / 2) * currentIndex;
  }

  double _getEmojiPosition(int index, double sliderWidth) {
    return 28.w + (sliderWidth / 2) * index;
  }
}
