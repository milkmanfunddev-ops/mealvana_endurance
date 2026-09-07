import 'package:flutter/material.dart';

/// Prose that arrives in chunks. Text already on screen stays put; the
/// chunk that just landed fades from transparent to the text colour over
/// ~140 ms, so a streamed bubble fills in instead of flickering word by
/// word. Faster than the stream's own cadence — it never lags a delta.
///
/// Once [animate] is false (the turn finished, or the platform asks for
/// reduced motion) every update renders at once. The whole string is one
/// [SelectableText.rich], so selection and `find.text` see the full text.
class StreamedText extends StatefulWidget {
  const StreamedText({
    super.key,
    required this.text,
    required this.style,
    this.animate = true,
  });

  final String text;
  final TextStyle style;

  /// Whether new tails should fade in. False commits [text] immediately.
  final bool animate;

  @override
  State<StreamedText> createState() => _StreamedTextState();
}

class _StreamedTextState extends State<StreamedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  /// Text shown at full opacity.
  late String _committed = widget.text;

  /// The latest chunk, fading in.
  String _tail = '';

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(StreamedText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final settled = _committed + _tail;
    if (!widget.animate || reduce || !widget.text.startsWith(settled)) {
      // A rewrite (rewind, edit) or a finished turn: no fade to run.
      _committed = widget.text;
      _tail = '';
      _fade.value = 1;
      return;
    }
    // Commit the previous tail (it has mostly landed) and fade the new one.
    _committed = settled;
    _tail = widget.text.substring(settled.length);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tail.isEmpty) return SelectableText(_committed, style: widget.style);
    final base = widget.style.color ?? Colors.black;
    return AnimatedBuilder(
      animation: _fade,
      builder: (_, __) => SelectableText.rich(
        TextSpan(
          style: widget.style,
          children: [
            TextSpan(text: _committed),
            TextSpan(
              text: _tail,
              style: TextStyle(
                color: base.withValues(
                  alpha: base.a * Curves.easeOut.transform(_fade.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
