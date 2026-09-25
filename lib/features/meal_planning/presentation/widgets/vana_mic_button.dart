import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import 'vana_round_button.dart';

/// The composer's dictation button (plan §5 Phase 6.5): platform
/// speech-to-text into the field. The recogniser is initialised on the first
/// tap, never on build: initialising is what raises iOS's Speech Recognition
/// prompt, and asking on the way into a chat the athlete may never dictate
/// into invites a "Don't Allow" iOS never asks again (ticket 79, Finding
/// 09-004). Renders nothing on web. When the ask fails the button asks the
/// plugin whether permission is what failed: refused (iOS never asks twice)
/// keeps the button, and every tap shows [permissionMessage] saying where to
/// turn access back on; a device with no speech engine at all hides it
/// (ticket 104, Finding 86-005). While listening the button fills
/// electrolyte; tapping again stops.
class VanaMicButton extends StatefulWidget {
  const VanaMicButton({
    super.key,
    required this.onText,
    required this.tooltip,
    required this.listeningTooltip,
    required this.permissionMessage,
    this.enabled = true,
    this.speech,
    this.size = 44,
    this.flat = false,
  });

  /// Called with the recognised words so far (replace, not append — the
  /// recogniser re-emits the whole phrase as it refines).
  final ValueChanged<String> onText;
  final String tooltip;
  final String listeningTooltip;

  /// Shown on a tap once the athlete has refused Speech Recognition or the
  /// microphone: where in Settings to allow it.
  final String permissionMessage;
  final bool enabled;

  /// Injectable recogniser for tests.
  final SpeechToText? speech;

  /// Button diameter, and whether it draws without its disc (inside the
  /// composer pill).
  final double size;
  final bool flat;

  @override
  State<VanaMicButton> createState() => _VanaMicButtonState();
}

class _VanaMicButtonState extends State<VanaMicButton> {
  late final SpeechToText _speech = widget.speech ?? SpeechToText();

  /// Null until the first tap asks; false hides the button (no engine).
  bool? _available;

  /// The ask failed because the athlete refused: the button stays.
  bool _refused = false;
  bool _listening = false;

  Future<bool> _init() async {
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
    // A failed ask is either a refusal or no engine; only permission tells
    // them apart (the plugin answers false for both).
    var refused = false;
    if (!ok) {
      try {
        refused = !await _speech.hasPermission;
      } catch (_) {
        refused = false;
      }
    }
    if (mounted) {
      setState(() {
        _refused = refused;
        _available = ok ? true : (refused ? null : false);
      });
    }
    return ok;
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (_available != true && !await _init()) {
      // Asked again each tap: access turned back on in Settings (Android
      // keeps the process alive across that) listens straight away.
      if (_refused && mounted) {
        MealvanaSnackbar.showInfo(
          context,
          widget.permissionMessage,
          duration: MealvanaSnackbar.longDuration,
        );
      }
      return;
    }
    if (!mounted) return;
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
    if (kIsWeb || _available == false) return const SizedBox.shrink();

    final button = VanaRoundButton(
      key: const ValueKey('meal_planning.chat_mic'),
      icon: _listening
          ? FontAwesomeIcons.microphoneLines
          : FontAwesomeIcons.microphone,
      tooltip: _listening ? widget.listeningTooltip : widget.tooltip,
      onTap: widget.enabled ? _toggle : () {},
      size: widget.size,
      iconSize: widget.size < 40 ? 16 : 18,
      flat: widget.flat,
      color: _listening ? AppColors.electrolyte : null,
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
