import '../../domain/decode_issue.dart';
import 'report.dart';

/// Bridges a domain decoder's [DecodeIssue] callback onto `Report`: each
/// malformed-but-tolerated value is a Degraded in [area], with the decoder's
/// message as the event message.
extension DecodeIssueReport on Report {
  DecodeIssue decodeIssue(String area) =>
      (String message, {Object? error, StackTrace? stackTrace}) {
        degraded(
          error ?? LoggedFault(message, context: area),
          stackTrace: stackTrace,
          area: area,
          message: error == null ? null : message,
        );
      };
}
