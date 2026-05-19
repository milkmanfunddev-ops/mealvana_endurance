import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import 'geometric_pattern_painter.dart';

/// Hero image with geometric pattern for single-sport activities
class SingleSportHeroImage extends StatelessWidget {
  const SingleSportHeroImage({super.key, required this.activityType});

  final ActivityType activityType;

  @override
  Widget build(BuildContext context) {
    String imagePath = 'assets/images/Runner.png';
    if (activityType == ActivityType.cycling) {
      imagePath = 'assets/images/Biker.png';
    } else if (activityType == ActivityType.swimming) {
      imagePath = 'assets/images/Swimmer.png';
    }

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blackberry.withValues(alpha: 0.3),
            AppColors.electrolyte.withValues(alpha: 0.2),
            AppColors.dragonfruit.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 280),
            painter: GeometricPatternPainter(),
          ),
          Image.asset(
            imagePath,
            height: 200,
            fit: BoxFit.contain,
            semanticLabel: switch (activityType) {
              ActivityType.running => 'Running illustration',
              ActivityType.cycling => 'Cycling illustration',
              ActivityType.swimming => 'Swimming illustration',
              _ => 'Sport illustration',
            },
            errorBuilder: (context, error, stackTrace) {
              return FaIcon(
                FontAwesomeIcons.personRunning,
                size: 120,
                color: AppColors.cream.withValues(alpha: 0.5),
              );
            },
          ),
        ],
      ),
    );
  }
}
