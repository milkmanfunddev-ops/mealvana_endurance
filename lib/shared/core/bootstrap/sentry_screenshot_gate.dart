/// Gate for the screenshot Sentry attaches to an error event (ticket 21,
/// `.scratch/sentry/issues/21-native-crashes.md`).
///
/// ## Why the gate exists
///
/// Prod crash MEALVANA-ENDURANCE-CR (1.28.0+146, Flutter 3.47.5, Android,
/// Impeller on its OpenGLES backend) died in
/// `Picture::DoRasterizeToImage → DoMakeRasterSnapshot →
/// AndroidSurfaceGLImpeller::CreateSnapshotSurface → … →
/// BlitCopyBufferToTextureCommandGLES::Encode`. `Picture.toImage` has one
/// caller in this app: the Sentry screenshot recorder. The activity had been
/// stopped a second earlier, so there was no onscreen surface and the engine
/// built an offscreen GLES snapshot surface. That path crashes in Flutter
/// 3.47.x GLES (flutter/flutter#193899, open). Session replay already skips
/// captures while the app is not resumed (sentry_flutter 9.30.1,
/// getsentry/sentry-dart#3923); the error-screenshot processor has no such
/// check, so this callback adds it.
///
/// A screenshot taken in the background shows nothing useful anyway: iOS
/// hands back the snapshot of the last frame, Android has no surface.
library;

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Reads the app's current lifecycle state; `null` before the first
/// lifecycle message, i.e. during startup, when the app is in the foreground.
typedef LifecycleStateReader = AppLifecycleState? Function();

AppLifecycleState? _bindingLifecycleState() =>
    WidgetsBinding.instance.lifecycleState;

/// Builds the `options.beforeCaptureScreenshot` callback.
///
/// Captures only while the app is resumed (or before the first lifecycle
/// message) and keeps the SDK's own debounce: a callback that is set
/// overrules the SDK's debounce decision, so it is applied here.
BeforeCaptureCallback foregroundOnlyScreenshots({
  LifecycleStateReader lifecycleState = _bindingLifecycleState,
}) {
  return (SentryEvent event, Hint hint, bool shouldDebounce) {
    if (shouldDebounce) return false;
    final state = lifecycleState();
    return state == null || state == AppLifecycleState.resumed;
  };
}
