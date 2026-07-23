import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/food_item_data.dart';
import 'editable_expandable_food_item.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

/// Swipeable food item with dismiss actions
/// Left-to-right swipe: Swap action (blue/primary button)
/// Right-to-left swipe: Delete action (red button)
class SwipeableFoodItem extends ConsumerStatefulWidget {
  const SwipeableFoodItem({
    super.key,
    required this.foodItem,
    required this.category,
    this.isFirstInBeforeRun = false,
    this.onQuantityChanged,
    this.onTap,
    this.onSwap,
    this.onDelete,
  });

  final FoodItemData foodItem;
  final String category;
  final bool isFirstInBeforeRun;
  final Function(double newQuantity)? onQuantityChanged;
  final VoidCallback? onTap;
  final VoidCallback? onSwap;
  final VoidCallback? onDelete;

  @override
  ConsumerState<SwipeableFoodItem> createState() => _SwipeableFoodItemState();
}

class _SwipeableFoodItemState extends ConsumerState<SwipeableFoodItem>
    with TickerProviderStateMixin {
  late AnimationController _hintController;
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _hintTimer;
  bool _hasInteracted = false;
  bool _showHintBackground = false;
  bool _isSwipingLeft = false; // Track current swipe direction

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Create fancy animations with curves
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticInOut),
    );

    // Start hint animation for first item in Before Run section (if not shown before)
    if (widget.isFirstInBeforeRun) {
      _checkAndStartHintAnimation();
    }
  }

  @override
  void dispose() {
    _hintController.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _checkAndStartHintAnimation() {
    try {
      // Use SharedPreferences for simple, reliable persistence
      final prefs = ref.read(sharedPreferencesProvider);
      final hasShown = prefs.getBool('swipe_hint_shown') ?? false;

      DebugLogger.info('🎯 SharedPreferences check: hasShown = $hasShown');

      if (!hasShown && mounted && !_hasInteracted) {
        DebugLogger.info('🚀 Starting animation');
        _startHintAnimation();
      } else {
        DebugLogger.debug(
          '⏭️ Skipping animation: hasShown=$hasShown, mounted=$mounted, hasInteracted=$_hasInteracted',
        );
      }
    } catch (e) {
      DebugLogger.error('❌ SharedPreferences error: $e');
      // If there's an error, don't show the animation to be safe
    }
  }

  void _startHintAnimation() {
    // Start after a longer delay for a more gentle introduction
    Timer(const Duration(milliseconds: 2000), () {
      if (!_hasInteracted && mounted) {
        _performContinuousHintAnimation();
      }
    });
  }

  Future<void> _performContinuousHintAnimation() async {
    if (!mounted || _hasInteracted) return;

    // Show background
    setState(() => _showHintBackground = true);
    _backgroundController.forward();

    // Start the 15-second timer
    final stopTime = DateTime.now().add(const Duration(seconds: 15));

    // Continuously cycle through animations with smooth, gentle effects
    while (!_hasInteracted && mounted && DateTime.now().isBefore(stopTime)) {
      // Swipe right to show swap (positive direction) with gentle ease
      setState(() => _isSwipingLeft = false);
      _pulseController.forward(); // Start pulse effect
      await _hintController.animateTo(
        0.7, // Reduced from 0.8 to 0.7 for less aggressive swipe
        duration: const Duration(
          milliseconds: 1200,
        ), // Increased from 900ms to 1200ms for smoother motion
        curve: Curves
            .easeOutCubic, // Changed from elasticOut to easeOutCubic for less jerky motion
      );
      if (!mounted || _hasInteracted) return;

      await _pauseIfStillAnimating(const Duration(milliseconds: 1200));
      if (!mounted || _hasInteracted) return;

      // Return to center with smooth ease
      await _hintController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 900), // Increased from 700ms
        curve: Curves.easeInOut,
      );
      if (!mounted || _hasInteracted) return;

      _pulseController.reverse(); // End pulse effect
      await _pauseIfStillAnimating(
        const Duration(milliseconds: 800),
      ); // Increased pause
      if (!mounted || _hasInteracted) return;

      // Swipe left to show delete (negative direction) with gentle ease
      setState(() => _isSwipingLeft = true);
      _pulseController.forward(); // Start pulse effect
      await _hintController.animateTo(
        0.7, // Reduced from 0.8 to 0.7 for less aggressive swipe
        duration: const Duration(
          milliseconds: 1200,
        ), // Increased from 900ms to 1200ms for smoother motion
        curve: Curves
            .easeOutCubic, // Changed from elasticOut to easeOutCubic for less jerky motion
      );
      if (!mounted || _hasInteracted) return;

      await _pauseIfStillAnimating(const Duration(milliseconds: 1200));
      if (!mounted || _hasInteracted) return;

      // Return to center with smooth ease
      await _hintController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 900), // Increased from 700ms
        curve: Curves.easeInOut,
      );
      if (!mounted || _hasInteracted) return;

      _pulseController.reverse(); // End pulse effect
      await _pauseIfStillAnimating(
        const Duration(milliseconds: 1000),
      ); // Increased pause
      if (!mounted || _hasInteracted) return;
    }

    // Hide background when done
    if (mounted) {
      _backgroundController.reverse();
      setState(() {
        _showHintBackground = false;
        _isSwipingLeft = false;
      });
    }
  }

  Future<void> _pauseIfStillAnimating(Duration duration) async {
    if (!mounted || _hasInteracted) return;
    await Future.delayed(duration);
  }

  void _onInteraction() {
    if (!_hasInteracted) {
      DebugLogger.debug('👆 User interaction detected - stopping animation');
      setState(() {
        _hasInteracted = true;
        _showHintBackground = false;
      });
      _hintTimer?.cancel();
      _hintController.stop();
      _backgroundController.reverse();

      // Mark hint as shown in SharedPreferences (fire and forget)
      if (widget.isFirstInBeforeRun) {
        DebugLogger.info('💾 Attempting to mark swipe hint as shown');
        try {
          final prefs = ref.read(sharedPreferencesProvider);
          prefs.setBool('swipe_hint_shown', true).then((success) {
            DebugLogger.info(
              '✅ Successfully marked swipe hint as shown: $success',
            );
            // Verify it was saved
            final hasShown = prefs.getBool('swipe_hint_shown') ?? false;
            DebugLogger.info('🔍 Verification: hasShown = $hasShown');
          });
        } catch (e) {
          DebugLogger.error('❌ Failed to mark swipe hint as shown: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _hintController,
        _backgroundController,
        _pulseController,
      ]),
      builder: (context, child) {
        // Apply hint animation offset based on direction - reduced for better UX
        final rawOffset =
            _hintController.value * 140.0; // Reduced from 200px to 140px
        final hintOffset = _isSwipingLeft ? -rawOffset : rawOffset;
        final backgroundOpacity = _backgroundController.value;
        final scale = _scaleAnimation.value;

        return Stack(
          children: [
            // Background that shows during hint animation
            if (_showHintBackground) ...[
              // Show appropriate background based on direction
              if (!_isSwipingLeft && _hintController.value > 0.1)
                Opacity(
                  opacity: backgroundOpacity,
                  child: _buildSwapBackground(),
                ),
              if (_isSwipingLeft && _hintController.value > 0.1)
                Opacity(
                  opacity: backgroundOpacity,
                  child: _buildDeleteBackground(),
                ),
            ],

            // Main dismissible content with scaling effect
            Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(hintOffset, 0),
                child: Dismissible(
                  key: Key('food_${widget.foodItem.id}'),
                  direction: DismissDirection.horizontal,
                  dismissThresholds: const {
                    DismissDirection.startToEnd: 0.4, // Left-to-right: Swap
                    DismissDirection.endToStart: 0.4, // Right-to-left: Delete
                  },
                  background: _buildSwapBackground(),
                  secondaryBackground: _buildDeleteBackground(),
                  confirmDismiss: (direction) async {
                    _onInteraction();

                    if (direction == DismissDirection.startToEnd) {
                      // Left-to-right swipe: Swap
                      widget.onSwap?.call();
                    } else if (direction == DismissDirection.endToStart) {
                      // Right-to-left swipe: Delete
                      widget.onDelete?.call();
                    }

                    // Always return false to prevent actual dismissal
                    // Actions are handled by callbacks
                    return false;
                  },
                  onUpdate: (details) {
                    // Track any swipe interaction
                    if (details.progress > 0) {
                      _onInteraction();
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      _onInteraction();
                      widget.onTap?.call();
                    },
                    child: EditableExpandableFoodItem(
                      foodItem: widget.foodItem,
                      category: widget.category,
                      onQuantityChanged: (newQuantity) {
                        _onInteraction();
                        widget.onQuantityChanged?.call(newQuantity);
                      },
                      onTap: () {
                        _onInteraction();
                        widget.onTap?.call();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwapBackground() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16.w),
      decoration: BoxDecoration(
        color: AppTheme.primary900,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: _showHintBackground
            ? [
                BoxShadow(
                  color: AppTheme.primary900.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Transform.scale(
        scale: _showHintBackground ? _pulseAnimation.value : 1.0,
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.swap_horiz,
            color: AppTheme.primary900,
            size: 20.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 16.w),
      decoration: BoxDecoration(
        color: AppTheme.highlight600,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: _showHintBackground
            ? [
                BoxShadow(
                  color: AppTheme.highlight600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Transform.scale(
        scale: _showHintBackground ? _pulseAnimation.value : 1.0,
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_outline,
            color: AppTheme.highlight600,
            size: 20.sp,
          ),
        ),
      ),
    );
  }
}
