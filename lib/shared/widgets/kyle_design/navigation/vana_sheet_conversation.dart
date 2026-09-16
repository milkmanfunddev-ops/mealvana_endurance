/// Design SSOT component — **Vana Sheet**, the inside of the sheet.
///
/// Spec: `spec/design/components/vana-sheet.md` in the QA repo, **PROPOSED**
/// (2026-09-10 revision, QA `9ffd92e`), §Anatomy "Inside the sheet" and
/// VS-8. Not yet ratified or mirrored (tickets 04/05 of `.scratch/mealplanning`).
/// The chrome, launcher and route are in `vana_sheet.dart`; this file is the
/// same component's conversation surface, split out for length.
///
/// Geometry is the export's (`docs/New Homepage with updated navbar calendar
/// and chat.html`, the chat sheet): a 20 px column, a 26 px avatar 11 px from
/// Vana's prose, which has no bubble; the athlete's turn right-aligned at most
/// 82 % wide in a cream-tinted bubble; quick replies inset to the prose's left
/// edge; a 44 px pill composer with a 44 px send circle.
///
/// Two departures from the export, both Lee's (2026-09-16): the avatar is the
/// app's own [VanaAvatar] (dragonfruit disc, cream "V"), not the export's
/// orange sparkle, which read as a plus sign; and the export's status chip
/// ("UPDATE" / "Fuel plan · to do") above the conversation is not drawn.
///
/// Contracts held here:
/// * **Quick replies** — at most two; the first filled, the second outline.
///   When they show and when they retire is the caller's (VS-8).
/// * **Send** — inert grey until [VanaSheetComposer.canSend], `orange` once it
///   is.
///
/// Always on the sheet's dark glass (`VanaSheet` forces the dark theme), so
/// the ink is cream in both app modes.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../icons/vana_avatar.dart';

/// The conversation column's horizontal padding.
const double kVanaSheetColumnInset = 20;

/// The avatar and the gap after it: where Vana's prose and the quick replies
/// start.
const double kVanaSheetProseInset =
    VanaSheetVanaTurn.avatarSize + VanaSheetVanaTurn.avatarGap;

/// Vana's prose on the sheet: no bubble, cream, 14.5 / 1.5.
final TextStyle kVanaSheetProseStyle = AppTextStyles.bodyMedium.copyWith(
  fontSize: 14.5,
  height: 1.5,
  color: AppColors.cream,
);

/// One of Vana's turns: her avatar, then [child] flush left with no bubble.
/// [child] is the prose (in [kVanaSheetProseStyle]) and whatever
/// generative-UI parts the turn carries, which compose here unchanged.
/// [pulsing] is for the turn still in flight (the typing indicator).
class VanaSheetVanaTurn extends StatelessWidget {
  const VanaSheetVanaTurn({
    super.key,
    required this.child,
    this.pulsing = false,
  });

  final Widget child;
  final bool pulsing;

  static const double avatarSize = 26;
  static const double avatarGap = 11;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: VanaAvatar(size: avatarSize, isPulsing: pulsing),
        ),
        const SizedBox(width: avatarGap),
        Expanded(
          child: Padding(padding: const EdgeInsets.only(top: 3), child: child),
        ),
      ],
    );
  }
}

/// The typing indicator where Vana's answer will land: three pulsing dots.
/// Place it as a [VanaSheetVanaTurn]'s child.
class VanaSheetTypingDots extends StatefulWidget {
  const VanaSheetTypingDots({super.key});

  @override
  State<VanaSheetTypingDots> createState() => _VanaSheetTypingDotsState();
}

class _VanaSheetTypingDotsState extends State<VanaSheetTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) {
                // Each dot peaks 150 ms after the one before it.
                final t = (_controller.value - i * 0.125) % 1;
                final wave = (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
                final alpha = still ? 0.7 : 0.3 + 0.4 * wave;
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cream.withValues(alpha: alpha),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The athlete's own turn: right-aligned, at most 82 % of the column, in a
/// soft cream-tinted bubble whose bottom-right corner is the tight one.
class VanaSheetAthleteTurn extends StatelessWidget {
  const VanaSheetAthleteTurn({super.key, required this.text});

  final String text;

  static const double maxWidthFraction = 0.82;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * maxWidthFraction,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.cream.withValues(alpha: 0.18),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(text, style: kVanaSheetProseStyle),
          ),
        ),
      ),
    );
  }
}

/// At most two quick replies, full width, stacked: the first filled `orange`,
/// the second an outline. More than two are not drawn.
class VanaSheetQuickReplies extends StatelessWidget {
  const VanaSheetQuickReplies({
    super.key,
    required this.labels,
    required this.onTap,
  });

  final List<String> labels;
  final ValueChanged<String> onTap;

  static const int max = 2;

  @override
  Widget build(BuildContext context) {
    final shown = labels.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _QuickReply(
            key: ValueKey('vana_sheet.quick_reply_$i'),
            label: shown[i],
            filled: i == 0,
            onTap: () => onTap(shown[i]),
          ),
        ],
      ],
    );
  }
}

class _QuickReply extends StatelessWidget {
  const _QuickReply({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? AppTextStyles.buttonPrimary.copyWith(
            fontSize: 14,
            color: AppColors.blackberry,
          )
        : AppTextStyles.buttonTertiary.copyWith(color: AppColors.cream);
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.orange : null,
            borderRadius: BorderRadius.circular(100),
            border: filled
                ? null
                : Border.all(color: AppColors.cream.withValues(alpha: 0.3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}

/// The composer: a pill field and the send circle, under a hairline. Send is
/// inert grey until [canSend], `orange` once it is.
class VanaSheetComposer extends StatelessWidget {
  const VanaSheetComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sendLabel,
    required this.canSend,
    required this.onSend,
    this.fieldKey,
    this.sendKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// "Send" — the button has no visible label.
  final String sendLabel;
  final bool canSend;
  final VoidCallback onSend;
  final Key? fieldKey;
  final Key? sendKey;

  static const double height = 44;

  /// The send circle's colour: `orange` when it will send, grey when inert.
  static Color sendColor({required bool canSend}) =>
      canSend ? AppColors.orange : AppColors.cream.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final hairline = AppColors.cream.withValues(alpha: 0.08);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: height),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cream.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(
                    color: AppColors.cream.withValues(alpha: 0.18),
                  ),
                ),
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: AppColors.orange,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cream,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.cream.withValues(alpha: 0.5),
                    ),
                    // The pill is the field; it draws no box of its own.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              container: true,
              button: true,
              enabled: canSend,
              label: sendLabel,
              excludeSemantics: true,
              child: GestureDetector(
                key: sendKey,
                behavior: HitTestBehavior.opaque,
                onTap: canSend ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: height,
                  height: height,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sendColor(canSend: canSend),
                  ),
                  child: const Center(
                    child: CustomPaint(
                      size: Size.square(16),
                      painter: _ArrowUpPainter(color: AppColors.blackberry),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The export's send arrow: a stem and a chevron, stroked at 2.6 in a 24-unit
/// view box.
class _ArrowUpPainter extends CustomPainter {
  const _ArrowUpPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(12, 19)
        ..lineTo(12, 5)
        ..moveTo(5, 12)
        ..lineTo(12, 5)
        ..lineTo(19, 12),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowUpPainter oldDelegate) => oldDelegate.color != color;
}
