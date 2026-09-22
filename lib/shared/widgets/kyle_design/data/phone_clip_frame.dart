/// Design SSOT component — **Phone Clip Frame**.
///
/// Spec: `docs/ssot/spec/design/components/phone-clip-frame.md` **v1**
/// (PROPOSED Lee 2026-09-21, authored app-side, awaiting Xuan).
///
/// A short, silent recording of our own app playing inside a phone-shaped
/// glass frame (mp-493 §1, §6). First use: the paywall's opening page.
///
/// Contracts held here:
/// * **PCF-1** — the clip plays muted, once; the [poster] (the clip's first
///   frame) holds the screen until the first frame plays.
/// * **PCF-2** — [onEnded] fires exactly once: when the clip ends, when it
///   fails, or when it has not started within [loadTimeout]. A page that
///   waits on the clip never waits forever.
/// * **PCF-3** — [still]: the poster alone; no player is made. The Reduce
///   Motion form.
/// * **PCF-4** — the frame takes the width it is given and keeps the clip's
///   [aspectRatio]; the bezel and corner radius scale with the width.
///
/// The bezel is the `glass` material ([GlassSurface], tokens §Materials): a
/// floating piece of chrome, not a content card. No colour of its own.
///
/// The player is a seam ([PhoneClipPlayer]): [VideoPhoneClipPlayer] plays a
/// bundled asset through `video_player`; widget tests pass a fake.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../materials/glass.dart';

/// Where a clip is: loading, playing, finished, or broken.
enum PhoneClipPhase { loading, playing, ended, failed }

/// The seam between [PhoneClipFrame] and whatever decodes the video.
abstract class PhoneClipPlayer {
  /// The current phase; the frame listens to it.
  ValueListenable<PhoneClipPhase> get phase;

  /// Loads the clip and plays it once, muted.
  Future<void> start();

  /// The decoded video, sized to fill its parent.
  Widget buildView();

  void dispose();
}

/// Plays a bundled video asset once, muted, mixing with other audio so it
/// never interrupts the athlete's music.
class VideoPhoneClipPlayer implements PhoneClipPlayer {
  VideoPhoneClipPlayer({required String asset})
    : _controller = VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

  final VideoPlayerController _controller;
  final ValueNotifier<PhoneClipPhase> _phase = ValueNotifier(
    PhoneClipPhase.loading,
  );
  bool _disposed = false;

  @override
  ValueListenable<PhoneClipPhase> get phase => _phase;

  void _set(PhoneClipPhase next) {
    if (_disposed || _phase.value == next) return;
    // Ended and failed are final.
    if (_phase.value == PhoneClipPhase.ended ||
        _phase.value == PhoneClipPhase.failed) {
      return;
    }
    _phase.value = next;
  }

  void _onValue() {
    final v = _controller.value;
    if (v.hasError) {
      _set(PhoneClipPhase.failed);
    } else if (v.isCompleted) {
      _set(PhoneClipPhase.ended);
    } else if (v.isPlaying && v.position > Duration.zero) {
      _set(PhoneClipPhase.playing);
    }
  }

  @override
  Future<void> start() async {
    try {
      _controller.addListener(_onValue);
      await _controller.initialize();
      if (_disposed) return;
      await _controller.setVolume(0);
      await _controller.setLooping(false);
      await _controller.play();
    } catch (_) {
      _set(PhoneClipPhase.failed);
    }
  }

  @override
  Widget buildView() => FittedBox(
    fit: BoxFit.cover,
    clipBehavior: Clip.hardEdge,
    child: SizedBox(
      width: _controller.value.size.width,
      height: _controller.value.size.height,
      child: VideoPlayer(_controller),
    ),
  );

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_onValue);
    unawaited(_controller.dispose());
    _phase.dispose();
  }
}

class PhoneClipFrame extends StatefulWidget {
  const PhoneClipFrame({
    super.key,
    required this.player,
    required this.poster,
    required this.semanticLabel,
    this.still = false,
    this.aspectRatio = 402 / 874,
    this.loadTimeout = const Duration(seconds: 3),
    this.onEnded,
  });

  /// Makes the player; called once, and never when [still].
  final PhoneClipPlayer Function() player;

  /// The clip's first frame (PCF-1, PCF-3).
  final ImageProvider poster;

  /// What the clip shows, for screen readers.
  final String semanticLabel;

  /// PCF-3: show the poster only.
  final bool still;

  /// Width over height of the clip's screen.
  final double aspectRatio;

  /// PCF-2: how long a clip may take to start before it counts as ended.
  final Duration loadTimeout;

  /// PCF-2: fires once.
  final VoidCallback? onEnded;

  static const posterKey = ValueKey('phone_clip_frame.poster');

  @override
  State<PhoneClipFrame> createState() => _PhoneClipFrameState();
}

class _PhoneClipFrameState extends State<PhoneClipFrame> {
  PhoneClipPlayer? _player;
  Timer? _loadTimer;
  bool _reported = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.still) _startPlayer();
  }

  void _startPlayer() {
    final player = widget.player();
    _player = player;
    player.phase.addListener(_onPhase);
    _loadTimer = Timer(widget.loadTimeout, () {
      if (!_playing) _report();
    });
    unawaited(player.start());
    _onPhase();
  }

  void _onPhase() {
    final phase = _player?.phase.value;
    switch (phase) {
      case PhoneClipPhase.playing:
        _loadTimer?.cancel();
        if (!_playing && mounted) setState(() => _playing = true);
      case PhoneClipPhase.ended:
      case PhoneClipPhase.failed:
        if (phase == PhoneClipPhase.failed && _playing && mounted) {
          setState(() => _playing = false);
        }
        _report();
      case PhoneClipPhase.loading:
      case null:
        break;
    }
  }

  void _report() {
    _loadTimer?.cancel();
    if (_reported) return;
    _reported = true;
    // Never during a build: a player may report from inside initState.
    scheduleMicrotask(() {
      if (mounted) widget.onEnded?.call();
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    final player = _player;
    if (player != null) {
      player.phase.removeListener(_onPhase);
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // A phone's proportions: bezel ~3% of the width, outer corner
            // ~14%, the screen's corner the outer less the bezel.
            final bezel = width * 0.03;
            final outer = BorderRadius.circular(width * 0.14);
            final inner = BorderRadius.circular(width * 0.14 - bezel);
            final player = _player;
            return GlassSurface(
              borderRadius: outer,
              lift: true,
              child: Padding(
                padding: EdgeInsets.all(bezel),
                child: ClipRRect(
                  borderRadius: inner,
                  child: ColoredBox(
                    color: AppColors.blackberry,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (player != null && _playing)
                          ExcludeSemantics(child: player.buildView())
                        else
                          Image(
                            key: PhoneClipFrame.posterKey,
                            image: widget.poster,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            gaplessPlayback: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
