/// How a pure domain decoder tells its caller that a stored value was
/// malformed and a fallback was used, without the domain layer depending on
/// `Report` (FOA: `domain <- data`). The data layer that read the column
/// supplies the callback, usually `report.decodeIssue('area')`.
typedef DecodeIssue =
    void Function(String message, {Object? error, StackTrace? stackTrace});

/// A decoder with no caller interested in issues swallows them; use this as
/// the default so decoders never need a null check.
void ignoreDecodeIssue(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {}
