import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../providers/education_controller.dart';
import '../widgets/video_card_widget.dart';
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
                    title: 'Free Videos',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (groups.freeVideos.isEmpty)
                    _EmptySection(message: 'No videos available yet')
                  else
                    ...groups.freeVideos.map(
                      (video) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: VideoCardWidget(
                          content: video,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                title: video.title,
                                videoUrl: video.videoUrl ?? '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

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
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        FaIcon(
          icon,
          size: 18,
          color: AppColors.orange,
        ),
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
