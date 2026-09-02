import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Vana's avatar — an electrolyte disc with a "V", pulsing while the model
/// streams (the Vana analogue of `AiCoachAvatar`).
class VanaAvatar extends StatefulWidget {
  const VanaAvatar({super.key, this.size = 32, this.isPulsing = false});

  final double size;
  final bool isPulsing;

  @override
  State<VanaAvatar> createState() => _VanaAvatarState();
}

class _VanaAvatarState extends State<VanaAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VanaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing == oldWidget.isPulsing) return;
    if (widget.isPulsing) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: AppColors.electrolyte,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          'V',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.blackberry,
            fontSize: widget.size * 0.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
