import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/settings_controller.dart';

/// Sport Preferences Hub Screen - 2nd tier navigation
///
/// Shows 3 navigation tiles:
/// 1. Running Preferences (e.g., "Water bottle: Yes")
/// 2. Cycling Preferences (e.g., "FTP: 250W")
/// 3. Swimming Preferences (e.g., "CSS: 1:30/100m")
class SportPreferencesHubScreen extends ConsumerWidget {
  const SportPreferencesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: settingsAsync.when(
        data: (state) => _buildContent(context, ref, state),
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Sport Preferences',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.electrolyte,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Error loading sport preferences',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic state) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Hub navigation tiles
          BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Running Preferences
                _buildHubTile(
                  context: context,
                  ref: ref,
                  icon: FontAwesomeIcons.personRunning,
                  title: 'Running Preferences',
                  subtitle: _getRunningSubtitle(state),
                  route: '/settings/running-details',
                  analyticsEvent: 'settings_running_preferences_tapped',
                ),

                const SizedBox(height: AppSpacing.sm),

                // Cycling Preferences
                _buildHubTile(
                  context: context,
                  ref: ref,
                  icon: FontAwesomeIcons.personBiking,
                  title: 'Cycling Preferences',
                  subtitle: _getCyclingSubtitle(state),
                  route: '/settings/cycling-details',
                  analyticsEvent: 'settings_cycling_preferences_tapped',
                ),

                const SizedBox(height: AppSpacing.sm),

                // Swimming Preferences
                _buildHubTile(
                  context: context,
                  ref: ref,
                  icon: FontAwesomeIcons.personSwimming,
                  title: 'Swimming Preferences',
                  subtitle: _getSwimmingSubtitle(state),
                  route: '/settings/swimming-details',
                  analyticsEvent: 'settings_swimming_preferences_tapped',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildHubTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required String analyticsEvent,
  }) {
    return InkWell(
      onTap: () {
        final analytics = ref.read(appExternalDepsProvider);
        analytics.analytics.track(analyticsEvent);
        context.push(route);
      },
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _getRunningSubtitle(dynamic state) {
    final waterBottle = state.runsWithWaterBottle ?? false;
    final giSensitivity = state.giSensitivity ?? false;

    if (waterBottle && giSensitivity) {
      return 'Water bottle: Yes, GI sensitive';
    } else if (waterBottle) {
      return 'Water bottle: Yes';
    } else if (giSensitivity) {
      return 'GI sensitive';
    }
    return 'Water bottle: No';
  }

  String _getCyclingSubtitle(dynamic state) {
    final ftp = state.ftpWatts;
    final bottles = state.typicalBikeBottles;

    if (ftp != null && bottles != null) {
      return 'FTP: ${ftp}W, $bottles ${bottles == 1 ? 'bottle' : 'bottles'}';
    } else if (ftp != null) {
      return 'FTP: ${ftp}W';
    } else if (bottles != null) {
      return '$bottles ${bottles == 1 ? 'bottle' : 'bottles'}';
    }
    return 'Not configured';
  }

  String _getSwimmingSubtitle(dynamic state) {
    final cssPace = state.cssPacePer100mSeconds;
    final wetsuit = state.typicalWetsuit;

    if (cssPace != null) {
      final minutes = cssPace ~/ 60;
      final seconds = cssPace % 60;
      final paceStr = '$minutes:${seconds.toString().padLeft(2, '0')}/100m';

      if (wetsuit != null) {
        return 'CSS: $paceStr, ${wetsuit ? 'Wetsuit' : 'No wetsuit'}';
      }
      return 'CSS: $paceStr';
    } else if (wetsuit != null) {
      return wetsuit ? 'Wetsuit' : 'No wetsuit';
    }
    return 'Not configured';
  }
}
