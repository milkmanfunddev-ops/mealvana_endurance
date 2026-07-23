import 'package:flutter/material.dart';

/// Composite Hero Image for Brick Workouts
///
/// Dynamically displays sport images based on selected sports.
/// Shows 2 or 3 images in a row, each with their built-in spiky border.
/// Images are displayed at approximately the same visual size as
/// single sport images on other tabs.
class BrickCompositeHeroImage extends StatelessWidget {
  const BrickCompositeHeroImage({
    super.key,
    required this.selectedSports,
    this.height = 180,
  });

  /// Set of selected sport keys ('swimming', 'cycling', 'running')
  final Set<String> selectedSports;

  /// Height of each sport image (same as single sport tabs)
  final double height;

  @override
  Widget build(BuildContext context) {
    // Build list of images to show based on selection
    final imagesToShow = <String>[];

    // Add in a logical order: swim -> bike -> run
    if (selectedSports.contains('swimming')) {
      imagesToShow.add('assets/images/Swimmer.png');
    }
    if (selectedSports.contains('cycling')) {
      imagesToShow.add('assets/images/Biker.png');
    }
    if (selectedSports.contains('running')) {
      imagesToShow.add('assets/images/Runner.png');
    }

    if (imagesToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate image size based on number of sports
    // For 2 sports: each image is ~55% of the single sport size
    // For 3 sports: each image is ~40% of the single sport size
    final imageHeight = imagesToShow.length == 2 ? height * 0.6 : height * 0.45;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: imagesToShow.map((imagePath) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Image.asset(
              imagePath,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return SizedBox(
                  height: imageHeight,
                  width: imageHeight * 0.8,
                  child: const Icon(Icons.sports, size: 40),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
