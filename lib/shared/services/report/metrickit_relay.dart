import 'dart:convert';

import 'package:flutter/services.dart';

import 'report.dart';

/// Receives Apple MetricKit payloads from `ios/Runner/MetricKitReporter.swift`
/// and routes them through [Report] (spec: `.scratch/sentry/spec.md`
/// § Telemetry that is not an error; ticket 11).
///
/// - A **metric** payload (daily CPU, energy, launch and hang aggregates) is a
///   structured log, `Report.info`, with the payload flattened into
///   attributes. It used to be an info event: 296 of them in 30 days spent
///   prod error quota on data that is never actionable on its own.
/// - A **diagnostic** payload (CPU exception, hang, disk-write exception,
///   crash, with native call stacks) stays an event, `Report.degraded`,
///   tagged `metrickit` so the event filter's diagnostic exemption and the
///   issue-stream filter keep working.
///
/// Swift buffers payloads until Dart calls `ready`, because the daily metric
/// payload can arrive before the engine has a method-call handler.
class MetricKitRelay {
  MetricKitRelay({Report? report, MethodChannel? channel})
    : _report = report,
      _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.milkman.mealvanaendurance/metrickit';
  static const String area = 'metrickit';

  /// Flattened attribute cap for a metric log; the rest is counted, not sent.
  static const int maxLogAttributes = 120;

  final Report? _report;
  final MethodChannel _channel;

  Report get _r => _report ?? SentryReport.global;

  /// Installs the handler and tells Swift to flush anything it buffered.
  Future<void> start() async {
    _channel.setMethodCallHandler(handle);
    try {
      await _channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      // Not iOS, or a host without the reporter: nothing will ever arrive.
    }
  }

  /// Public so tests can drive it without a platform channel.
  Future<void> handle(MethodCall call) async {
    final raw = call.arguments;
    final json = raw is String ? raw : raw?.toString() ?? '';
    switch (call.method) {
      case 'metric':
        _metric(json);
      case 'diagnostic':
        await _diagnostic(json);
      default:
        throw MissingPluginException('MetricKitRelay: ${call.method}');
    }
  }

  void _metric(String json) {
    final decoded = _decode(json);
    final flat = <String, Object?>{};
    flatten(decoded, flat);
    final attributes = <String, dynamic>{
      'metrickit': 'metric',
      'payload_bytes': json.length,
      'attribute_count': flat.length,
    };
    var sent = 0;
    for (final entry in flat.entries) {
      if (sent++ >= maxLogAttributes) break;
      attributes[entry.key] = entry.value;
    }
    _r.info('MetricKit metric payload', area: area, data: attributes);
  }

  Future<void> _diagnostic(String json) {
    final decoded = _decode(json);
    final kinds = diagnosticKinds(decoded);
    return _r.degraded(
      MetricKitDiagnostic(kinds),
      area: area,
      message: 'MetricKit diagnostic payload',
      tags: {
        'metrickit': 'diagnostic',
        if (kinds.isNotEmpty) 'diagnostic_kind': kinds.join(','),
      },
      extra: {
        'diagnostic_kinds': kinds,
        'payload_bytes': json.length,
        'payload': decoded,
      },
      fingerprint: ['metrickit-diagnostic', ...kinds],
    );
  }

  static Map<String, Object?> _decode(String json) {
    try {
      final value = jsonDecode(json);
      if (value is Map) return value.cast<String, Object?>();
      return {'value': value};
    } on FormatException {
      return {'raw': json};
    }
  }

  /// The MetricKit diagnostic arrays present in [payload]
  /// (`cpuExceptionDiagnostics`, `hangDiagnostics`, ...), minus the
  /// `Diagnostics` suffix, sorted.
  static List<String> diagnosticKinds(Map<String, Object?> payload) {
    final kinds = <String>[];
    for (final entry in payload.entries) {
      if (!entry.key.endsWith('Diagnostics')) continue;
      final value = entry.value;
      if (value is List && value.isEmpty) continue;
      kinds.add(entry.key.substring(0, entry.key.length - 'Diagnostics'.length));
    }
    return kinds..sort();
  }

  /// Nested maps become dotted keys; lists become indexed keys. Scalars stay
  /// scalars so Sentry keeps their type.
  static void flatten(
    Object? value,
    Map<String, Object?> out, {
    String prefix = '',
  }) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        flatten(entry.value, out, prefix: key);
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        flatten(value[i], out, prefix: prefix.isEmpty ? '$i' : '$prefix.$i');
      }
    } else {
      out[prefix.isEmpty ? 'value' : prefix] = value;
    }
  }
}

/// A MetricKit diagnostic payload: a hang, CPU exception, disk-write
/// exception or crash report from a real device.
class MetricKitDiagnostic implements Exception {
  const MetricKitDiagnostic(this.kinds);

  final List<String> kinds;

  @override
  String toString() => kinds.isEmpty
      ? 'MetricKit diagnostic payload'
      : 'MetricKit diagnostic payload: ${kinds.join(', ')}';
}
