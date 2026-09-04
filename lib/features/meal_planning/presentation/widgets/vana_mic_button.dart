import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import 'vana_round_button.dart';

/// The composer's dictation button (plan §5 Phase 6.5): platform
/// speech-to-text into the field. Renders nothing on web and whenever the
/// recognizer is unavailable (no permission, no engine), so the composer
/// never shows a mic that cannot listen. While listening the button fills
/// electrolyte; tapping again stops.
class VanaMicButton extends StatefulWidget {
  const VanaMicButton({
    super.key,
    required this.onText,
    required this.tooltip,
    required this.listeningTooltip,
    this.enabled = true,
    this.speech,
  });

  /// Called with the recognised words so far (replace, not append — the
  /// recogniser re-emits the whole phrase as it refines).
  final ValueChanged<String> onText;
  final String tooltip;
  final String listeningTooltip;
  final bool enabled;

  /// Injectable recogniser for tests.
  final SpeechToText? speech;

  @override
  State<VanaMicButton> createState() => _VanaMicButtonState();
}

class _VanaMicButtonState extends State<VanaMicButton> {
  late final SpeechToText _speech = widget.speech ?? SpeechToText();
  bool _available = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _init();
  }

  Future<void> _init() async {
    bool ok;
    try {
      ok = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          final listening = status == SpeechToText.listeningStatus;
          if (listening != _listening) setState(() => _listening = listening);
        },
        onError: (_) {
          if (mounted && _listening) setState(() => _listening = false);
        },
      );
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _available = ok);
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        widget.onText(result.recognizedWords);
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_available) return const SizedBox.shrink();

    final button = VanaRoundButton(
      key: const ValueKey('meal_planning.chat_mic'),
      icon: _listening
          ? FontAwesomeIcons.microphoneLines
          : FontAwesomeIcons.microphone,
      tooltip: _listening ? widget.listeningTooltip : widget.tooltip,
      onTap: widget.enabled ? _toggle : () {},
    );
    if (!_listening) return button;

    // Listening: an electrolyte ring so the state reads at a glance.
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.electrolyte, width: 2),
        ),
      ),
      child: button,
    );
  }
}
