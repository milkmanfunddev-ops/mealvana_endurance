import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Elegant full-screen overlay shown during nutrition plan generation
/// Features rotating motivational messages with Kyle's design system
/// Supports both light and dark modes
class GeneratingPlanOverlay extends StatefulWidget {
  const GeneratingPlanOverlay({super.key});

  @override
  State<GeneratingPlanOverlay> createState() => _GeneratingPlanOverlayState();
}

class _GeneratingPlanOverlayState extends State<GeneratingPlanOverlay>
    with TickerProviderStateMixin {
  // Kyle's Design System Colors
  static const Color kyleBlackberry = Color(0xFF381633);
  static const Color kyleCream = Color(0xFFF8F6EB);
  static const Color kyleOrange = Color(0xFFF78B14);
  static const Color kyleOffCream = Color(0xFFC6C3B2);

  late AnimationController _fadeController;
  late AnimationController _spinController;
  late Animation<double> _fadeAnimation;

  int _currentMessageIndex = 0;
  late List<String> _motivationalMessages;

  @override
  void initState() {
    super.initState();

    _motivationalMessages = [
      "Crafting your perfect fuel strategy...",
      "Analyzing your nutrition needs...",
      "Building your personalized plan...",
      "Almost ready to fuel your performance...",
    ];

    // Fade animation for the overlay
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Spin animation for circular progress
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start animations
    _fadeController.forward();
    _spinController.repeat();

    // Rotate messages every 2.5 seconds
    _startMessageRotation();
  }

  void _startMessageRotation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _motivationalMessages.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    // Color scheme based on theme
    final backgroundColor = isDark ? kyleBlackberry : kyleCream;
    final textColor = isDark ? kyleCream : kyleBlackberry;
    final accentColor = kyleOrange;
    final secondaryTextColor = isDark ? kyleOffCream : AppTheme.baseGrey;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: backgroundColor,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular progress indicator with Kyle's styling
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating circle
                    RotationTransition(
                      turns: _spinController,
                      child: Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                    // Inner accent arc
                    RotationTransition(
                      turns: _spinController,
                      child: SizedBox(
                        width: 80.w,
                        height: 80.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    // Center icon
                    Icon(
                      Icons.restaurant_menu,
                      color: accentColor,
                      size: 32.sp,
                    ),
                  ],
                ),

                SizedBox(height: 40.h),

                // Motivational text with smooth transitions - Sansita Bold
                SizedBox(
                  height: 80.h,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _motivationalMessages[_currentMessageIndex],
                      key: ValueKey(_currentMessageIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: 0.2,
                      ).copyWith(color: textColor),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Subtle progress dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _motivationalMessages.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: index == _currentMessageIndex
                            ? accentColor
                            : secondaryTextColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 32.h),

                // Subtle subtext - Apercu
                Text(
                  "This usually takes just a few seconds",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ).copyWith(
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}