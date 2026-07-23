import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../providers/settings_controller.dart';

/// Food Preferences Hub Screen - 2nd tier navigation
///
/// Shows 3 navigation tiles:
/// 1. Dietary Preference (e.g., "Vegetarian")
/// 2. Allergies (e.g., "2 allergies selected")
/// 3. Food Likes & Dislikes (navigate to detailed food list)
class FoodPreferencesHubScreen extends ConsumerWidget {
  const FoodPreferencesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      contentWidth: AdaptiveContentWidth.standard,
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
      leading: const CustomAppBarBackButton(
        key: ValueKey('food_prefs.back_button'),
      ),
      title: Text(
        key: const ValueKey('food_prefs.title'),
        'Diet, Allergies & Formulas',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.electrolyte),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Error loading food preferences',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic state) {
    return AdaptiveScrollableBody(
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
                // Dietary Preference
                _buildHubTile(
                  context: context,
                  ref: ref,
                  tileKey: const ValueKey('food_prefs.dietary_row'),
                  icon: FontAwesomeIcons.leaf.data,
                  title: 'Dietary Preference',
                  subtitle: _getDietaryPreferenceSubtitle(state),
                  route: '/settings/dietary-preference',
                  analyticsEvent: 'settings_dietary_preference_tapped',
                ),

                const SizedBox(height: AppSpacing.sm),

                // Allergies
                _buildHubTile(
                  context: context,
                  ref: ref,
                  tileKey: const ValueKey('food_prefs.allergies_row'),
                  icon: FontAwesomeIcons.triangleExclamation.data,
                  title: 'Allergies',
                  subtitle: _getAllergiesSubtitle(state),
                  route: '/settings/allergies',
                  analyticsEvent: 'settings_allergies_tapped',
                ),

                const SizedBox(height: AppSpacing.sm),

                // Food Likes & Dislikes — restored 2026-07-08. Preferences are
                // collected again (scoped to endurance/fuel foods) and now feed
                // the nutrition-plan default-formula tier + solver.
                _buildHubTile(
                  context: context,
                  ref: ref,
                  tileKey: const ValueKey('food_prefs.likes_dislikes_row'),
                  icon: FontAwesomeIcons.heart.data,
                  title: 'Food Likes & Dislikes',
                  subtitle: 'Manage your fuel preferences',
                  route: '/settings/food-preferences',
                  analyticsEvent: 'settings_food_likes_dislikes_tapped',
                ),

                const SizedBox(height: AppSpacing.sm),

                // Formula Library — browse Before/During/After nutrition formulas.
                _buildHubTile(
                  context: context,
                  ref: ref,
                  icon: FontAwesomeIcons.flask.data,
                  title: 'Formula Library',
                  subtitle: 'Browse Before & During & After formulas',
                  route: '/settings/food-preferences/formula-library',
                  analyticsEvent: 'settings_formula_library_tapped',
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
    Key? tileKey,
  }) {
    return InkWell(
      key: tileKey,
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

            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _getDietaryPreferenceSubtitle(dynamic state) {
    if (state.dietaryPreference == null) {
      return 'None selected';
    }
    return state.dietaryPreference.displayName;
  }

  String _getAllergiesSubtitle(dynamic state) {
    final allergiesCount = state.allergies?.length ?? 0;
    if (allergiesCount == 0) {
      return 'No allergies';
    }
    return '$allergiesCount ${allergiesCount == 1 ? 'allergy' : 'allergies'} selected';
  }
}
