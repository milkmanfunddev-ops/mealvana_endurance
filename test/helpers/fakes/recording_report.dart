import 'package:mealvana_endurance/shared/services/report/report.dart';

/// One call recorded by [RecordingReport].
class RecordedReport {
  const RecordedReport({
    required this.severity,
    this.error,
    this.message,
    this.area,
    this.tags,
    this.extra,
    this.data,
  });

  /// `fault`, `degraded`, `note`, `info`, `debug` or `breadcrumb`.
  final String severity;
  final Object? error;
  final String? message;
  final String? area;
  final Map<String, String>? tags;
  final Map<String, dynamic>? extra;
  final Map<String, dynamic>? data;

  @override
  String toString() =>
      '$severity(area: $area, error: $error, message: $message)';
}

/// A `Report` that remembers every call and emits nothing. Tests inject it
/// (`reportProvider.overrideWithValue(report)` or a constructor parameter)
/// and assert on [faults], [degradeds] or [notes] instead of console output.
class RecordingReport extends NoopReport {
  final List<RecordedReport> calls = [];
  final List<String> userIds = [];
  int cleared = 0;

  List<RecordedReport> get faults => _of('fault');
  List<RecordedReport> get degradeds => _of('degraded');
  List<RecordedReport> get notes => _of('note');

  List<RecordedReport> _of(String severity) =>
      calls.where((c) => c.severity == severity).toList(growable: false);

  @override
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    calls.add(
      RecordedReport(
        severity: 'fault',
        error: error,
        message: message,
        area: area,
        tags: tags,
        extra: extra,
      ),
    );
  }

  @override
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    calls.add(
      RecordedReport(
        severity: 'degraded',
        error: error,
        message: message,
        area: area,
        tags: tags,
        extra: extra,
      ),
    );
  }

  @override
  Future<void> note(
    String message, {
    String? area,
    Map<String, dynamic>? data,
  }) async {
    calls.add(
      RecordedReport(severity: 'note', message: message, area: area, data: data),
    );
  }

  @override
  void info(String message, {String? area, Map<String, dynamic>? data}) {
    calls.add(
      RecordedReport(severity: 'info', message: message, area: area, data: data),
    );
  }

  @override
  void debug(String message, {String? area, Map<String, dynamic>? data}) {
    calls.add(
      RecordedReport(
        severity: 'debug',
        message: message,
        area: area,
        data: data,
      ),
    );
  }

  @override
  void breadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    calls.add(
      RecordedReport(
        severity: 'breadcrumb',
        message: message,
        area: category,
        data: data,
      ),
    );
  }

  @override
  Future<void> setUser(String id, {String? role, String? deviceId}) async {
    userIds.add(id);
  }

  @override
  Future<void> clearUser() async {
    cleared++;
  }
}
