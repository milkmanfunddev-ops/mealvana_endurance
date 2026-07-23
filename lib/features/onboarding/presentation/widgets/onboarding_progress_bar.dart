import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Progress bar for the onboarding flow showing completion across segments
///
/// Displays 3 segments representing:
/// 1. Profile (user info)
/// 2. Sports + Details (sport selection and sport-specific preferences)
/// 3. Diet + Allergies (dietary preference and allergen selection)
///
/// Matches Figma design specification with 8px height and spacing.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentSegment,
    this.totalSegments = 3,
    this.height = 8.0,
    this.spacing = 8.0,
  });

  /// Current active segment (1-indexed)
  final int currentSegment;

  /// Total number of segments (default: 3)
  final int totalSegments;

  /// Height of each segment bar
  final double height;

  /// Spacing between segments
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSegments, (index) {
        final segmentNumber = index + 1;
        final isCompleted = segmentNumber < currentSegment;
        final isActive = segmentNumber == currentSegment;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < totalSegments - 1 ? spacing : 0,
            ),
            child: _ProgressSegment(
              isCompleted: isCompleted,
              isActive: isActive,
              height: height,
            ),
          ),
        );
      }),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.isCompleted,
    required this.isActive,
    required this.height,
  });

  final bool isCompleted;
  final bool isActive;
  final double height;

  @override
  Widget build(BuildContext context) {
    Color segmentColor;

    if (isCompleted) {
      // Completed segments are solid orange
      segmentColor = AppColors.orange;
    } else if (isActive) {
      // Active segment is orange
      segmentColor = AppColors.orange;
    } else {
      // Inactive segments are cream with 8% opacity
      segmentColor = AppColors.textDark.withValues(alpha: 0.08);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: height,
      decoration: BoxDecoration(
        color: segmentColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Enum representing onboarding flow segments
enum OnboardingSegment {
  profile(1),
  sportsDetails(2),
  dietAllergies(3);

  const OnboardingSegment(this.value);
  final int value;
}
