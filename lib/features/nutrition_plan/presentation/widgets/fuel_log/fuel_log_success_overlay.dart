import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../shared/utils/celebration_haptics.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Full-screen success overlay shown after fuel log is saved.
/// Features animated checkmark and confetti particles.
class FuelLogSuccessOverlay extends StatefulWidget {
  const FuelLogSuccessOverlay({
    super.key,
    required this.onDismiss,
    this.onViewDashboard,
  });

  final VoidCallback onDismiss;
  final VoidCallback? onViewDashboard;

  /// Show the overlay as a general dialog.
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDismiss,
    VoidCallback? onViewDashboard,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => FuelLogSuccessOverlay(
        onDismiss: onDismiss,
        onViewDashboard: onViewDashboard,
      ),
    );
  }

  @override
  State<FuelLogSuccessOverlay> createState() => _FuelLogSuccessOverlayState();
}

class _FuelLogSuccessOverlayState extends State<FuelLogSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _confettiController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _checkScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _checkController.forward();
    _confettiController.forward();

    // Fire the celebration haptic on the same frame the confetti launches.
    unawaited(CelebrationHaptics.play());

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Confetti particles
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(progress: _confettiController.value),
              );
            },
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated checkmark
                ScaleTransition(
                  scale: _checkScale,
                  child: FadeTransition(
                    opacity: _checkFade,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.electrolyte,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.electrolyte.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Title
                FadeTransition(
                  opacity: _checkFade,
                  child: Text(
                    'Fuel Logged',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Subtitle
                FadeTransition(
                  opacity: _checkFade,
                  child: Text(
                    'Your workout nutrition has been saved',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Back to Activity button
                FadeTransition(
                  opacity: _checkFade,
                  child: SizedBox(
                    width: 220,
                    child: KylePrimaryButton(
                      text: 'Back to Activity',
                      onPressed: widget.onDismiss,
                    ),
                  ),
                ),

                if (widget.onViewDashboard != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FadeTransition(
                    opacity: _checkFade,
                    child: TextButton(
                      onPressed: widget.onViewDashboard,
                      child: Text(
                        'View Dashboard',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple confetti particle painter.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;
  static final Random _random = Random(42);
  static final List<_Particle> _particles = List.generate(
    40,
    (_) => _Particle.random(_random),
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final x = p.startX * size.width + p.driftX * progress * size.width * 0.3;
      final y =
          p.startY * size.height * -0.2 +
          progress * size.height * (1.2 + p.speed * 0.5);
      final opacity = (1.0 - progress * 1.5).clamp(0.0, 1.0) * p.opacity;

      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.rotationSpeed * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  final double startX;
  final double startY;
  final double driftX;
  final double speed;
  final double size;
  final double opacity;
  final double rotationSpeed;
  final Color color;

  const _Particle({
    required this.startX,
    required this.startY,
    required this.driftX,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.rotationSpeed,
    required this.color,
  });

  static final _colors = [
    AppColors.orange,
    AppColors.electrolyte,
    AppColors.dragonfruit,
    const Color(0xFFFFD700),
    const Color(0xFF7B68EE),
  ];

  factory _Particle.random(Random random) {
    return _Particle(
      startX: random.nextDouble(),
      startY: random.nextDouble(),
      driftX: (random.nextDouble() - 0.5) * 2,
      speed: 0.5 + random.nextDouble() * 0.5,
      size: 6 + random.nextDouble() * 8,
      opacity: 0.6 + random.nextDouble() * 0.4,
      rotationSpeed: (random.nextDouble() - 0.5) * 2,
      color: _colors[random.nextInt(_colors.length)],
    );
  }
}
