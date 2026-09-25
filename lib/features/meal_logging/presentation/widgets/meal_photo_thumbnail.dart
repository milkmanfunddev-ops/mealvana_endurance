import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_spacing.dart';
import '../providers/meal_log_providers.dart';

/// The meal's photo, 160 tall and full width, from a 1-hour signed URL on
/// the `meal-photos` bucket ([mealPhotoSignedUrlProvider]). Edit Meal shows
/// it tappable, with a "Tap to re-scan" affordance ([onTap]); Review & Log
/// shows it plain, so the athlete sees which picture the numbers came from
/// before "Log this meal" (testing-wave 97, 24-007). Nothing is drawn when
/// there is no URL to show.
class MealPhotoThumbnail extends ConsumerWidget {
  const MealPhotoThumbnail({super.key, required this.photoPath, this.onTap});

  final String photoPath;

  /// When non-null, the thumbnail is tappable (used to trigger a photo
  /// re-scan) and shows a "Tap to re-scan" affordance.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(mealPhotoSignedUrlProvider(photoPath));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: urlAsync.when(
        data: (url) {
          if (url == null) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Image.network(
                    url,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  if (onTap != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to re-scan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
