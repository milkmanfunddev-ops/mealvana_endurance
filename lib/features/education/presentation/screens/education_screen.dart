import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/education_content.dart';
import '../providers/education_controller.dart';
import '../widgets/coming_soon_section_widget.dart';
import '../screens/video_player_screen.dart';

/// Main education tab screen with free videos, pro videos, and courses
class EducationScreen extends ConsumerWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(educationControllerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: isDark ? AppColors.inactive : AppColors.disabled,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Failed to load content',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textDarkSecondary
                        : AppColors.textLightSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KylePrimaryButton(
                  text: 'Retry',
                  onPressed: () =>
                      ref.read(educationControllerProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          data: (groups) => RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () =>
                ref.read(educationControllerProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Learn',
                    style: AppTextStyles.h1.copyWith(
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Free Videos section
                  _SectionHeader(
                    icon: FontAwesomeIcons.circlePlay,
                    title: 'Mealvana 101',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Free nutrition lessons for endurance athletes',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textDarkSecondary
                          : AppColors.textLightSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (groups.freeVideos.isEmpty)
                    _EmptySection(message: 'No videos available yet')
                  else
                    _HorizontalVideoList(videos: groups.freeVideos),

                  const SizedBox(height: AppSpacing.xxl),

                  // Pro Videos section
                  _SectionHeader(
                    icon: FontAwesomeIcons.crown,
                    title: 'Pro Videos',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const ComingSoonSectionWidget(
                    icon: FontAwesomeIcons.crown,
                    iconColor: AppColors.orange,
                    title: 'Premium Video Library',
                    description:
                        'Expert-led deep dives on race nutrition, hydration strategies, and performance fueling.',
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Courses section
                  _SectionHeader(
                    icon: FontAwesomeIcons.bookOpen,
                    title: 'Courses',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const ComingSoonSectionWidget(
                    icon: FontAwesomeIcons.bookOpen,
                    iconColor: AppColors.electrolyte,
                    title: 'Structured Learning Paths',
                    description:
                        'Step-by-step courses from beginner to advanced endurance nutrition.',
                  ),

                  // Bottom padding for FAB bar clearance
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with icon and title
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        FaIcon(icon, size: 18, color: AppColors.orange),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTextStyles.h3.copyWith(
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

/// Placeholder for empty sections
class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textDarkSecondary
                : AppColors.textLightSecondary,
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrolling list of video cards
class _HorizontalVideoList extends StatelessWidget {
  const _HorizontalVideoList({required this.videos});

  final List<EducationContent> videos;

  static const double _cardWidth = 240.0;
  static const double _cardHeight = 210.0;

  @override
  Widget build(BuildContext context) {
    // Use a negative margin approach to let the list bleed to screen edges
    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final video = videos[index];
          return SizedBox(
            width: _cardWidth,
            child: _CompactVideoCard(
              content: video,
              lessonNumber: index + 1,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    title: video.displayTitle,
                    videoUrl: video.videoUrl ?? '',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact video card for horizontal scrolling
class _CompactVideoCard extends StatelessWidget {
  const _CompactVideoCard({
    required this.content,
    required this.lessonNumber,
    required this.onTap,
  });

  final EducationContent content;
  final int lessonNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppRadius.cardRadius,
          boxShadow: isDark
              ? AppShadows.darkCardShadow
              : AppShadows.lightCardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.blackberry,
                          AppColors.blackberryLight.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),

                  // Lesson number watermark
                  Positioned(
                    right: -8,
                    bottom: -12,
                    child: Text(
                      '1.$lessonNumber',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),

                  // Play button
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
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
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          content.formattedDuration,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Title area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.displayTitle,
                    style: AppTextStyles.h5.copyWith(
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (content.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      content.description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
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
