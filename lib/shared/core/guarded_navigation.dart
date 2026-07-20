import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/performance_telemetry.dart';

/// Duplicate-push protection for taps that arrive while the UI is stalled.
///
/// A `GestureDetector.onTap` runs on the main isolate. When something stalls
/// that isolate — a synchronous init, an allocation burst forcing a major GC,
/// a long await chain gating the first frame — pointer events do not get
/// dropped. They queue. Nothing paints, the user assumes the tap missed and
/// taps again, and when the isolate frees up every queued handler runs
/// back-to-back, each one pushing its own route. That is how a single stalled
/// dashboard turns into ten stacked Settings pages.
///
/// [GuardedNavigation.pushOnce] collapses such a burst: a repeat push of the
/// same location is ignored until the destination paints its first frame (with
/// a ten-second safety timeout if routing fails).
///
/// This is a guard, not a fix. It stops the symptom from compounding; it does
/// not make the destination arrive any sooner. Slow routes still need their own
/// loading state, and the stall still needs its own root cause fixed.
extension GuardedNavigation on BuildContext {
  /// Pushes [location] unless an identical push just happened.
  ///
  /// Prefer this over `context.push` for any destination reachable from a
  /// persistent chrome affordance (nav bar, header icon) — those are the ones
  /// a user can hammer while nothing is happening on screen.
  void pushOnce(String location) {
    if (_PushGuard.shouldSuppress(location)) {
      PerformanceTelemetry.record(
        'Duplicate navigation suppressed',
        category: 'navigation.guard',
        data: {'destination': location},
      );
      return;
    }
    _NavigationTiming.started(location);
    push(location);
  }

  /// Named-route equivalent of [pushOnce].
  void pushNamedOnce(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    final destination = 'name:$name';
    if (_PushGuard.shouldSuppress(destination)) {
      PerformanceTelemetry.record(
        'Duplicate navigation suppressed',
        category: 'navigation.guard',
        data: {'destination': destination},
      );
      return;
    }
    _NavigationTiming.started(destination);
    pushNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}

/// Call from a destination's first post-frame callback to measure how long the
/// accepted tap took to become visible.
void recordNavigationDestinationRendered(String destination) {
  _NavigationTiming.rendered(destination);
  _PushGuard.completed(destination);
}

abstract final class _NavigationTiming {
  static final Map<String, Stopwatch> _pending = {};

  static void started(String destination) {
    _pending[destination] = Stopwatch()..start();
    PerformanceTelemetry.record(
      'Navigation accepted',
      category: 'navigation.timing',
      data: {'destination': destination},
    );
  }

  static void rendered(String destination) {
    final stopwatch = _pending.remove(destination);
    if (stopwatch == null) return;
    stopwatch.stop();
    PerformanceTelemetry.recordDuration(
      'navigation.first_frame',
      stopwatch.elapsed,
      data: {'destination': destination},
      threshold: const Duration(milliseconds: 750),
    );
  }

  @visibleForTesting
  static void reset() => _pending.clear();
}

/// Process-wide, deliberately: the guard has to hold across the *widgets* that
/// own the taps, not within one. The dashboard header gear and the shared
/// TabsScreen overlay gear are different widgets pushing the same route, and a
/// rebuild between two taps must not reset the guard.
abstract final class _PushGuard {
  /// Safety valve if a destination never renders because routing failed. A
  /// successful route unlocks on its first frame, normally within milliseconds.
  static const Duration _fallbackWindow = Duration(seconds: 10);

  static final Map<String, DateTime> _activeDestinations = {};

  static bool shouldSuppress(String location) {
    final now = DateTime.now();
    final startedAt = _activeDestinations[location];
    if (startedAt != null && now.difference(startedAt) < _fallbackWindow) {
      return true;
    }

    _activeDestinations[location] = now;
    return false;
  }

  static void completed(String location) {
    _activeDestinations.remove(location);
  }

  /// Test-only: clears the guard so cases don't leak into each other.
  @visibleForTesting
  static void reset() {
    _activeDestinations.clear();
    _NavigationTiming.reset();
  }
}

/// Test-only handle on the guard's state.
@visibleForTesting
void resetPushGuardForTest() => _PushGuard.reset();

/// Test-only: exercises the suppression decision without needing a router.
@visibleForTesting
bool shouldSuppressPushForTest(String location) =>
    _PushGuard.shouldSuppress(location);

@visibleForTesting
void completePushForTest(String location) => _PushGuard.completed(location);
