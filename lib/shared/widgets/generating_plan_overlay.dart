import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Elegant full-screen overlay shown during nutrition plan generation
/// Features rotating motivational messages and animated progress dots
class GeneratingPlanOverlay extends StatefulWidget {
  const GeneratingPlanOverlay({super.key});

  @override
  State<GeneratingPlanOverlay> createState() => _GeneratingPlanOverlayState();
}

class _GeneratingPlanOverlayState extends State<GeneratingPlanOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _dotsController;
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
      "Almost ready to fuel your run...",
    ];
    
    // Fade animation for the overlay
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Start animations
    _fadeController.forward();
    _dotsController.repeat();
    
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
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: AppTheme.baseCream.withValues(alpha: 0.95),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon area
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary600.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: AppTheme.primary600,
                  size: 48.sp,
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Motivational text with smooth transitions
              SizedBox(
                height: 60.h,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _motivationalMessages[_currentMessageIndex],
                    key: ValueKey(_currentMessageIndex),
                    textAlign: TextAlign.center,
                    style: AppTheme.titleStyle.copyWith(
                      color: AppTheme.primary600,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              // Animated progress dots
              AnimatedBuilder(
                animation: _dotsController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      // Calculate animation offset for wave effect
                      final animationValue = (_dotsController.value * 4 - index).clamp(0.0, 1.0);
                      final scale = 0.5 + (0.5 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
                      
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              color: AppTheme.primary600.withValues(
                                alpha: 0.3 + (0.7 * scale),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              
              SizedBox(height: 24.h),
              
              // Subtle "hold tight" text
              Text(
                "Hold tight while we work our magic ✨",
                style: AppTheme.noteStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 14.sp,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}