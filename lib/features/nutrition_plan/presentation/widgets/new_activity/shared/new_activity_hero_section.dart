import 'package:flutter/material.dart';

/// Hero image section for the New Activity screen
///
/// Displays a sport-specific hero image (running, cycling, or swimming)
/// with optional pink star overlay (currently commented out until asset is available)
///
/// Features:
/// - Dynamic hero image based on selected sport
/// - Fixed height container (200px) with centered image
/// - Stack-based layout for future overlay support
class NewActivityHeroSection extends StatelessWidget {
  const NewActivityHeroSection({
    super.key,
    required this.heroImagePath,
  });

  /// Path to the hero image asset (from coordinator.getHeroImagePath())
  final String heroImagePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hero image
          Image.asset(
            heroImagePath,
            height: 180,
            fit: BoxFit.contain,
          ),

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
