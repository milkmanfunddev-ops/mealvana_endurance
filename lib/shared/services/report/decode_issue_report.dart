import '../../domain/decode_issue.dart';
import 'report.dart';

/// Bridges a domain decoder's [DecodeIssue] callback onto `Report`. The data
/// layer picks the rung when it binds the callback: a column we wrote
/// ourselves that fails to decode is a bug (`fault`); a tolerated fallback is
/// `degraded` (the default); a malformed row that is skipped and counted is a
/// `note`.
extension DecodeIssueReport on Report {
  DecodeIssue decodeIssue(
    String area, {
    ReportSeverity severity = ReportSeverity.degraded,
  }) =>
      (String message, {Object? error, StackTrace? stackTrace}) {
        switch (severity) {
          case ReportSeverity.fault:
            fault(
              error ?? LoggedFault(message, context: area),
              stackTrace: stackTrace,
              area: area,
              message: error == null ? null : message,
            );
          case ReportSeverity.degraded:
            degraded(
              error ?? LoggedFault(message, context: area),
              stackTrace: stackTrace,
              area: area,
              message: error == null ? null : message,
            );
          case ReportSeverity.note:
            note(
              message,
              area: area,
              data: {
                if (error != null) 'error': error.toString(),
              },
            );
        }
      };
}
