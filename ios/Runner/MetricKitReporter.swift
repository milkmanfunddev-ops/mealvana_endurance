import Foundation
import MetricKit
import Sentry

/// Forwards Apple MetricKit payloads into the Sentry pipeline the app already
/// uses, so real-device CPU / energy / hang data lands on the dashboard we
/// already have — with no separate backend, table, or Dart code.
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
/// screen whether or not we subscribe; we only *read* what already exists. There
/// is no instrumentation, polling, or display link here — contrast the replay
/// recorder this whole investigation was about. Metric payloads are delivered at
/// most once per 24h; diagnostics (CPU exceptions, hangs) immediately on iOS 15+.
/// Real devices only — the simulator never delivers payloads.
///
/// ## Where the data shows up
///
/// In Sentry, as `info` events tagged `metrickit:metric` / `metrickit:diagnostic`,
/// each carrying the raw payload as a JSON attachment. The valuable one is
/// `MXCPUExceptionDiagnostic` — it arrives with a device call stack of whatever
/// burned the CPU. Filter the Sentry issue stream by the `metrickit` tag.
///
/// ## Privacy
///
/// Deliberately NOT consent-gated, matching the app's existing policy that crash
/// and performance reporting run on legitimate interest (see the `beforeSend`
/// commentary in the entrypoints). MetricKit diagnostics are stability/perf data
/// about our own code — CPU time, hang durations, stack traces of our frames —
/// not user analytics. `sendDefaultPii` stays false on the shared SDK.
@available(iOS 13.0, *)
@objc final class MetricKitReporter: NSObject, MXMetricManagerSubscriber {

  @objc static let shared = MetricKitReporter()

  /// Subscribe to MetricKit. Safe to call before Sentry has started: payloads
  /// arrive asynchronously much later, and `SentrySDK.capture` is a no-op while
  /// the SDK is disabled, so nothing crashes and at worst a payload is dropped.
  @objc func register() {
    MXMetricManager.shared.add(self)
  }

  // Daily aggregate metrics: cpuMetrics.cumulativeCPUTime,
  // applicationTimeMetrics.cumulativeForegroundTime, etc. Their ratio is
  // average CPU-while-foregrounded — the real-device version of the simulator
  // A/B we ran on the replay fix.
  func didReceive(_ payloads: [MXMetricPayload]) {
    for payload in payloads {
      forward(json: payload.jsonRepresentation(),
              kind: "metric",
              message: "MetricKit metric payload")
    }
  }

  // Diagnostics: CPU exceptions, hangs, disk-write exceptions, crashes.
  // Delivered immediately on iOS 15+. This is the high-value channel — a hot
  // phone shows up here as an MXCPUExceptionDiagnostic with a call stack.
  @available(iOS 14.0, *)
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    for payload in payloads {
      forward(json: payload.jsonRepresentation(),
              kind: "diagnostic",
              message: "MetricKit diagnostic payload")
    }
  }

  private func forward(json: Data, kind: String, message: String) {
    let attachment = Attachment(
      data: json,
      filename: "metrickit-\(kind).json",
      contentType: "application/json")

    SentrySDK.capture(message: message) { scope in
      scope.setTag(value: kind, key: "metrickit")
      scope.setLevel(.info)
      scope.addAttachment(attachment)
    }
  }
}
