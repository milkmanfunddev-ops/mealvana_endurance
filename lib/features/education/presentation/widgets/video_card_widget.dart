import 'package:flutter/material.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/education_content.dart';

/// Card displaying a video thumbnail, title, description, and duration badge
class VideoCardWidget extends StatelessWidget {
  const VideoCardWidget({
    super.key,
    required this.content,
    required this.onTap,
  });

  final EducationContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: BaseCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail with play button overlay
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail or gradient placeholder
                    if (content.thumbnailUrl != null)
                      Image.network(
                        content.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _GradientPlaceholder(),
                      )
                    else
                      _GradientPlaceholder(),

                    // Play button overlay
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                    // Duration badge
                    if (content.durationSeconds != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            content.formattedDuration,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Title + description
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.displayTitle,
                    style: AppTextStyles.h5.copyWith(
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  if (content.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      content.description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient placeholder when no thumbnail is available
class _GradientPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange, AppColors.dragonfruit],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white54, size: 48),
      ),
    );
  }
}
