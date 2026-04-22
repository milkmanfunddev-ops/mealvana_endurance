import 'package:flutter/material.dart';

import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../education/presentation/screens/video_player_screen.dart';
import 'transparency_accordion.dart';

/// Accordion section that opens the video player for nutrient transparency.
///
/// Navigates to [VideoPlayerScreen] when tapped.
/// Shows "Coming soon" when no video URL is available or when [comingSoon]
/// is explicitly set to true.
///
/// The [comingSoon] flag is a declarative alias for the `videoUrl == null`
/// branch — useful when callers know at construction time that no video
/// exists yet, without having to pass a nullable URL.
class TransparencyVideoSection extends StatelessWidget {
  const TransparencyVideoSection({
    super.key,
    required this.title,
    this.videoUrl,
    this.comingSoon = false,
  });

  final String title;
  final String? videoUrl;

  /// When true, always renders the "Coming soon" placeholder regardless of
  /// whether [videoUrl] is provided.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return TransparencyAccordion(
      title: title,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimText =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    if (comingSoon || videoUrl == null || videoUrl!.isEmpty) {
      // Coming soon placeholder
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 40,
              color: AppColors.electrolyte.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dimText,
              ),
            ),
          ],
        ),
      );
    }

    // Tappable video card that navigates to VideoPlayerScreen
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VideoPlayerScreen(
              title: title.replaceFirst('Watch: ', ''),
              videoUrl: videoUrl!,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? const Color(0xFF1a0f2e)
                  : Colors.grey.shade100,
              isDark
                  ? const Color(0xFF0e0818)
                  : Colors.grey.shade200,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.play_circle_filled_rounded,
              size: 48,
              color: AppColors.electrolyte.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 8),
            Text(
              title.replaceFirst('Watch: ', ''),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '~2 min \u00b7 Mealvana Education',
              style: TextStyle(
                fontSize: 11,
                color: dimText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
