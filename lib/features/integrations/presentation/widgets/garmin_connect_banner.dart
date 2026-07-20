import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/preferences_service.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../providers/integrations_providers.dart';

/// A dismissible banner prompting users to connect Garmin.
///
/// Self-hides when:
/// - The user has already dismissed it (persisted via [PreferencesService]).
/// - Garmin is already connected for the current user.
/// - There is no authenticated user.
///
/// Once dismissed, the banner never re-appears until app data is cleared.
class GarminConnectBanner extends ConsumerStatefulWidget {
  const GarminConnectBanner({super.key});

  @override
  ConsumerState<GarminConnectBanner> createState() =>
      _GarminConnectBannerState();
}

class _GarminConnectBannerState extends ConsumerState<GarminConnectBanner> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesServiceProvider);

    // Already dismissed — never show again.
    if (prefs.garminBannerDismissed) return const SizedBox.shrink();

    // Require an authenticated user.
    final profileAsync = ref.watch(currentUserProvider);
    final userId = profileAsync.asData?.value?.id;
    if (userId == null) return const SizedBox.shrink();

    // Hide when Garmin is already connected.
    final isConnected = ref
        .watch(isGarminConnectedProvider(userId))
        .maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
    if (isConnected) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return BaseCard(
      // The banner owns the gap to whatever follows it, so the spacing
      // disappears along with the banner on the three self-hiding paths
      // above (dismissed / signed out / already connected). A SizedBox in
      // the parent Column instead would leave a doubled dead band whenever
      // the banner is hidden, which is the common case.
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      backgroundColor: isDark
          ? AppColors.electrolyte.withValues(alpha: 0.12)
          : AppColors.electrolyte.withValues(alpha: 0.08),
      border: Border.all(
        color: AppColors.electrolyte.withValues(alpha: 0.3),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Garmin',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sync body composition and activity data to refine your nutrition targets.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => context.push('/settings/connected-apps'),
                  child: Text(
                    'Set up in Connected Apps →',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.electrolyte,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dismiss button
          GestureDetector(
            key: const ValueKey('garmin_banner.dismiss'),
            onTap: () async {
              await ref.read(preferencesServiceProvider).dismissGarminBanner();
              if (mounted) setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(
                Icons.close,
                size: 18,
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
