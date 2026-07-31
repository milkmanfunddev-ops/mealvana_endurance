import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_text_styles.dart';

/// The one-line running commentary shown while a Jade AI call is in flight.
///
/// The line advances through [phases] every [phaseDuration] and then holds on
/// the last one until the call returns — cycling back to the first would read
/// as the work restarting. A message that changes is what makes a wait feel
/// short; it does more for perceived speed than any spinner.
///
/// The stages are *time-based*, not reported by the server: the analysis is one
/// round trip with no progress events. So the copy names real work in the real
/// order, but never claims a step has finished. Keep it that way — a stage that
/// asserts completion ("Found 4 items") would be a lie the server never told.
///
/// Honours the platform "reduce motion" setting by switching without a
/// cross-fade.
class JadeThinkingStatus extends StatefulWidget {
  const JadeThinkingStatus({
    super.key,
    required this.phases,
    this.style,
    this.textAlign = TextAlign.start,
    this.phaseDuration = const Duration(milliseconds: 2200),
  });

  final List<String> phases;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration phaseDuration;

  /// The stages for a text description analysis.
  static const describePhases = <String>[
    'Reading your description',
    'Identifying the foods',
    'Estimating the macros',
    'Almost there',
  ];

  /// The stages for a photo analysis.
  static const photoPhases = <String>[
    'Looking at your photo',
    'Identifying the foods',
    'Estimating the macros',
    'Almost there',
  ];

  @override
  State<JadeThinkingStatus> createState() => _JadeThinkingStatusState();
}

class _JadeThinkingStatusState extends State<JadeThinkingStatus> {
  Timer? _timer;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    if (widget.phases.length > 1) {
      _timer = Timer.periodic(widget.phaseDuration, (_) {
        if (_phase >= widget.phases.length - 1) return;
        setState(() => _phase++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // AnimatedSwitcher stacks its children centred, so inside a stretched
    // column the line would centre itself regardless of [textAlign]. The Align
    // pins it back.
    return Align(
      alignment: switch (widget.textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.end || TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion ? 0 : 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          // The ellipsis is part of the line so the copy reads as ongoing at
          // whatever stage it is held on.
          '${widget.phases[_phase]}…',
          key: ValueKey(_phase),
          textAlign: widget.textAlign,
          style: widget.style ?? AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
