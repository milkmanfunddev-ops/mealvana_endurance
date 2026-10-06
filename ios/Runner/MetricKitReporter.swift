import Flutter
import Foundation
import MetricKit

/// Forwards Apple MetricKit payloads to Dart over a method channel, where
/// `MetricKitRelay` (lib/shared/services/report/metrickit_relay.dart) routes
/// them through the app's `Report` service: metric payloads become Sentry
/// structured logs, diagnostic payloads become warning events tagged
/// `metrickit`. This file no longer talks to the Sentry SDK at all.
///
/// ## Why this exists (2026-07-17)
///
/// A beta tester reported their phone running hot. We confirmed and fixed the
/// cause (always-on Sentry session replay — see `sentry_replay_sampling.dart`),
/// but had no way to *measure* CPU/battery on a real tester's device: the
/// simulator can't, and Xcode Organizer's battery pane needs App Store scale.
/// MetricKit closes that gap for the next such report.
///
/// ## Why it doesn't cost battery
///
/// MetricKit is passive. iOS already collects this data for the system battery
/// screen whether or not we subscribe; we only *read* what already exists.
/// Metric payloads are delivered at most once per 24h; diagnostics (CPU
/// exceptions, hangs) immediately on iOS 15+. Real devices only — the
/// simulator never delivers payloads.
///
/// ## Why it buffers (ticket 11, 2026-10-06)
///
/// The daily metric payload can arrive during launch, before the Dart side has
/// installed its method-call handler. Payloads are queued here until Dart
/// calls `ready`, then flushed in order; later payloads go straight through.
/// Until 2026-10-06 metric payloads were captured natively as Sentry *info
/// events*: 296 of them in 30 days, a third of the prod error quota.
///
/// ## Privacy
///
/// Deliberately NOT consent-gated, matching the app's existing policy that crash
/// and performance reporting run on legitimate interest (see the `beforeSend`
/// commentary in the bootstrap). MetricKit diagnostics are stability/perf data
/// about our own code — CPU time, hang durations, stack traces of our frames —
/// not user analytics. `sendDefaultPii` stays false on the shared SDK.
@available(iOS 13.0, *)
@objc final class MetricKitReporter: NSObject, MXMetricManagerSubscriber {

  @objc static let shared = MetricKitReporter()

  /// Must match `MetricKitRelay.channelName` on the Dart side.
  private static let channelName = "com.milkman.mealvanaendurance/metrickit"

  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var pending: [(method: String, json: String)] = []

  /// Subscribe to MetricKit and open the channel. Safe to call before Dart has
  /// started: payloads are buffered until Dart says `ready`.
  @objc func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: MetricKitReporter.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "ready":
        self.dartReady = true
        self.flush()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    MXMetricManager.shared.add(self)
  }

  // Daily aggregate metrics: cpuMetrics.cumulativeCPUTime,
  // applicationTimeMetrics.cumulativeForegroundTime, etc. Their ratio is
  // average CPU-while-foregrounded — the real-device version of the simulator
  // A/B we ran on the replay fix.
  func didReceive(_ payloads: [MXMetricPayload]) {
    for payload in payloads {
      forward(method: "metric", json: payload.jsonRepresentation())
    }
  }

  // Diagnostics: CPU exceptions, hangs, disk-write exceptions, crashes.
  // Delivered immediately on iOS 15+. This is the high-value channel — a hot
  // phone shows up here as an MXCPUExceptionDiagnostic with a call stack.
  @available(iOS 14.0, *)
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    for payload in payloads {
      forward(method: "diagnostic", json: payload.jsonRepresentation())
    }
  }

  private func forward(method: String, json: Data) {
    let text = String(data: json, encoding: .utf8) ?? "{}"
    // MetricKit delivers on a background queue; the channel is main-thread only.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.dartReady, let channel = self.channel {
        channel.invokeMethod(method, arguments: text)
      } else {
        self.pending.append((method: method, json: text))
      }
    }
  }

  private func flush() {
    guard let channel = channel else { return }
    let queued = pending
    pending.removeAll()
    for item in queued {
      channel.invokeMethod(item.method, arguments: item.json)
    }
  }
}
