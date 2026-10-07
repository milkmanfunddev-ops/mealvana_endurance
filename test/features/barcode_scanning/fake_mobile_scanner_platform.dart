import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A stand-in for mobile_scanner's native side, shaped like the iOS plugin
/// (`MobileScannerPlugin.swift` in mobile_scanner 7.2.0):
///
/// - `start` opens a capture session before it looks for a camera, and a
///   failed start (no camera) leaves that session open;
/// - a `start` while a session is open answers
///   MOBILE_SCANNER_ALREADY_STARTED_ERROR ("The scanner was already
///   started.");
/// - `stop` and `dispose` close the session.
///
/// Each `start` parks on a completer so a test can hold it "waiting on the
/// camera permission prompt" and finish it later with [finishStart] or
/// [failStartNoCamera].
class FakeMobileScannerPlatform extends MobileScannerPlatform {
  int startCalls = 0;
  bool sessionOpen = false;
  final List<Completer<MobileScannerViewAttributes>> _pending = [];

  static const alreadyStarted = MobileScannerException(
    errorCode: MobileScannerErrorCode.controllerAlreadyInitialized,
    errorDetails: MobileScannerErrorDetails(
      code: 'MOBILE_SCANNER_ALREADY_STARTED_ERROR',
      message: 'The scanner was already started.',
    ),
  );

  static const noCamera = MobileScannerException(
    errorCode: MobileScannerErrorCode.unsupported,
    errorDetails: MobileScannerErrorDetails(
      code: 'MOBILE_SCANNER_NO_CAMERA_ERROR',
      message: 'No cameras available.',
    ),
  );

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) {
    startCalls++;
    if (sessionOpen) {
      return Future.error(alreadyStarted);
    }
    sessionOpen = true;
    final completer = Completer<MobileScannerViewAttributes>();
    _pending.add(completer);
    return completer.future;
  }

  /// The pending start succeeds: the camera is running.
  void finishStart() {
    _pending
        .removeAt(0)
        .complete(
          const MobileScannerViewAttributes(
            cameraDirection: CameraFacing.back,
            currentTorchMode: TorchState.off,
            size: Size(100, 100),
            numberOfCameras: 1,
          ),
        );
  }

  /// The pending start fails the way the simulator does: no camera, and the
  /// native session stays open.
  void failStartNoCamera() => failStart(noCamera);

  /// The pending start fails with [error]; the native session stays open.
  void failStart(MobileScannerException error) {
    _pending.removeAt(0).completeError(error);
  }

  @override
  Future<void> stop() async {
    sessionOpen = false;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    sessionOpen = false;
  }

  @override
  Future<void> toggleTorch() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<Set<CameraLensType>> getSupportedLenses() async => {};

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.expand();
}
