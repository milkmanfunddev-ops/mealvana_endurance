import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/onboarding_design_tokens.dart';

/// "Building your plan…" transition — pixel port of the prototype's BUILDING
/// state.
///
/// Spec: full-bleed radial-gradient (115% 55% at 50% 40%, #4a2143→#381633
/// 60%), a 120px spinner (r54 cream-10% track ring + #f78b14 arc with
/// dasharray 70/340, round caps, 1.4s linear spin) around the 58px logo
/// pulsing 1.6s (scale 1→1.06, opacity 1→.85); 'Building your plan…'
/// Sansita 700 24 cream 34px below; a teal fontLabel-16 status line cycling
/// the four build messages with a .3s fade/rise; and a 220×5 progress bar
/// (cream-12% track, radius 3, orange fill) 28px below.
class OnboardingBuildLoader extends StatefulWidget {
  const OnboardingBuildLoader({super.key});

  /// Spec BUILD_LINES, uppercase under the unicase label face.
  static const List<String> buildLines = [
    'READING YOUR LONG-RUN DEMANDS…',
    'MATCHING ACSM CARB TARGETS…',
    'SPLITTING WORKOUT VS REST DAYS…',
    'LOCKING IN YOUR PLAN…',
  ];

  @override
  State<OnboardingBuildLoader> createState() => _OnboardingBuildLoaderState();
}

class _OnboardingBuildLoaderState extends State<OnboardingBuildLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _lines = AnimationController(
    vsync: this,
    // One build line per ~700ms, matching the prototype's pacing.
    duration: Duration(
      milliseconds: 700 * OnboardingBuildLoader.buildLines.length,
    ),
  )..forward();

  int get _lineIndex => (_lines.value * OnboardingBuildLoader.buildLines.length)
      .floor()
      .clamp(0, OnboardingBuildLoader.buildLines.length - 1);

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _lines.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Spec: radial-gradient(115% 55% at 50% 40%, #4a2143 0%, #381633 60%)
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2), // 50% x, 40% y
          radius: 1.0,
          transform: _LoaderEllipse(),
          colors: [OnbTokens.cardRaised, OnbTokens.bg],
          stops: [0.0, 0.60],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(34, 52, 34, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _spin,
                  child: const CustomPaint(
                    size: Size(120, 120),
                    painter: _SpinnerRingPainter(),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Opacity(
                      opacity: 1.0 - 0.15 * t,
                      child: Transform.scale(
                        scale: 1.0 + 0.06 * t,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/images/onboarding_logo_cream.png',
                    width: 58,
                    height: 58,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          const Text(
            'Building your plan…',
            key: ValueKey('plan_reveal.loader'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: OnbTokens.fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: OnbTokens.cream,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _lines,
            builder: (context, _) {
              final line = OnboardingBuildLoader.buildLines[_lineIndex];
              return SizedBox(
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    line,
                    key: ValueKey(line),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: OnbTokens.fontLabel,
                      fontSize: 16,
                      color: OnbTokens.teal,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _lines,
            builder: (context, _) {
              return Container(
                width: 220,
                height: 5,
                decoration: BoxDecoration(
                  color: OnbTokens.creamA(0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.1 + 0.9 * _lines.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: OnbTokens.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Spec ring: r54 track at cream-10% (3px) plus an orange arc — dasharray
/// 70/340 of the r54 circumference (≈74°), round caps.
class _SpinnerRingPainter extends CustomPainter {
  const _SpinnerRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const r = 54.0;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = OnbTokens.creamA(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    const sweep = 70 / (2 * math.pi * r) * 2 * math.pi; // dash 70 of C≈339
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = OnbTokens.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SpinnerRingPainter oldDelegate) => false;
}

/// CSS ellipse geometry for the loader gradient (115% width / 55% height
/// radii anchored at 50%/40%).
class _LoaderEllipse extends GradientTransform {
  const _LoaderEllipse();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    final cy = bounds.top + bounds.height * 0.40;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(1.15, 0.55 * (bounds.height / bounds.width), 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}
