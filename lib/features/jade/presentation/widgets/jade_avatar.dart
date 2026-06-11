import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Jade AI coach avatar — a circular Electrolyte-cyan disc with a bold "J".
///
/// Sizes are parameterized; pass [isPulsing] to enable the thinking animation
/// while Jade is streaming a response.
///
/// Design: Electrolyte (#5DE4D3) fill, Blackberry "J" in Sansita bold.
class JadeAvatar extends StatefulWidget {
  const JadeAvatar({
    super.key,
    this.size = 40,
    this.isPulsing = false,
  });

  final double size;
  final bool isPulsing;

  @override
  State<JadeAvatar> createState() => _JadeAvatarState();
}

class _JadeAvatarState extends State<JadeAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed && widget.isPulsing) {
          _controller.forward();
        }
      });

    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(JadeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !_controller.isAnimating) {
      _controller.forward();
    } else if (!widget.isPulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = (widget.size * 0.42).clamp(12.0, 40.0);

    final disc = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.electrolyte,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.electrolyte.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'J',
        style: AppTextStyles.buttonPrimary.copyWith(
          fontFamily: AppTextStyles.sansita,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.blackberry,
          height: 1.0,
        ),
      ),
    );

    if (!widget.isPulsing) return disc;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: disc,
    );
  }
}
