import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Vana's avatar — a dragonfruit disc with a cream "V" in Sansita, pulsing
/// while the model streams (the Vana analogue of `AiCoachAvatar`). Mirrors
/// `.v-avatar` in the prototype.
class VanaAvatar extends StatefulWidget {
  const VanaAvatar({
    super.key,
    this.size = 32,
    this.isPulsing = false,
    this.initial = 'V',
  });

  final double size;
  final bool isPulsing;

  /// The letter(s) in the disc — "V" for Vana, a publisher's initials on the
  /// meal-detail attribution card.
  final String initial;

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
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.dragonfruit.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.initial,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.cream,
            fontSize: widget.size * 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
