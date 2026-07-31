import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../brick/brick_composite_hero_image.dart';
import '../../../providers/brick_input_controller.dart';

/// Hero image section for the New Activity screen
///
/// Displays a sport-specific hero image (running, cycling, or swimming)
/// For brick workouts, displays a composite of selected sport images.
///
/// Features:
/// - Dynamic hero image based on selected sport
/// - Composite image for brick workouts (shows only selected sports)
/// - Fixed height container (200px) with centered image
/// - Stack-based layout for future overlay support
class NewActivityHeroSection extends ConsumerWidget {
  const NewActivityHeroSection({
    super.key,
    required this.heroImagePath,
    this.isBrick = false,
  });

  /// Path to the hero image asset (from coordinator.getHeroImagePath())
  final String heroImagePath;

  /// Whether this is a brick workout (shows composite image)
  final bool isBrick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For brick workouts, show composite hero with selected sport images
    // Uses same 200px height as single sport tabs for visual consistency
    if (isBrick) {
      final brickFormState = ref.watch(brickInputControllerProvider);
      return BrickCompositeHeroImage(
        selectedSports: brickFormState.selectedSports,
        height: 200,
      );
    }

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hero image
          Image.asset(heroImagePath, height: 180, fit: BoxFit.contain),

          // Pink star overlay
          // TODO: Uncomment when Vector.png is extracted from Figma
          // Positioned(
          //   top: 0,
          //   right: 60,
          //   child: Image.asset(
          //     'assets/images/Vector.png',
          //     width: 80,
          //     height: 80,
          //   ),
          // ),
        ],
      ),
    );
  }
}
