import 'dart:convert';

/// What a provider's refusal may say in a Report, an exception message or a
/// console line: its HTTP status and its error code.
typedef ProviderErrorSummary = ({int? status, String? errorCode});

/// An error code is a short token-shaped word; anything else may be free text.
final RegExp _errorCodePattern = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');

/// Fields read for a code, in order. Free-text fields are never read.
const List<String> _errorCodeFields = ['error', 'errorCode', 'code'];

/// The one redaction rule for provider error answers on the device.
///
/// Ruling (Lee, 2026-10-09, testing-wave develop-2026-10 tickets 76 and 84):
/// report only the HTTP status and the error code, never the description or
/// the body, for every provider and every endpoint (token, data and
/// write-back alike). The server side is ticket 76's
/// `supabase/functions/_shared/provider_error.ts`; this mirrors it.
///
/// Why (Finding 69-012): Garmin's token endpoint answered a dead refresh with
/// `{"error":"invalid_grant","error_description":"Invalid refresh token: eyJ…"}`,
/// and the base64 in the description decodes to JSON holding the refresh
/// token. Any free-text field of a provider answer can carry a token, so none
/// is kept.
///
/// `errorCode` is the first of `error`, `errorCode` or `code` whose value is
/// a string matching `^[A-Za-z0-9_.-]{1,64}$`; otherwise `null` (a non-JSON
/// body, a code with spaces, or a body with only `error_description`,
/// `message` or `errorMessage`). Never returns any other part of the body.
ProviderErrorSummary providerErrorSummary(int? status, String? body) =>
    (status: status, errorCode: _errorCodeOf(body));

String? _errorCodeOf(String? body) {
  if (body == null || body.isEmpty) return null;
  final Object? parsed;
  try {
    parsed = jsonDecode(body);
  } on FormatException {
    // Not JSON (an HTML gateway page, plain text): no code to keep.
    return null;
  }
  if (parsed is! Map) return null;
  for (final field in _errorCodeFields) {
    final value = parsed[field];
    if (value is String && _errorCodePattern.hasMatch(value)) return value;
  }
  return null;
}

/// `(status: 400, error: invalid_grant)`, `(status: 400)`, or `''` when
/// neither is known. The form every exception's `toString()` uses.
String providerErrorSuffix(ProviderErrorSummary s) {
  final parts = [
    if (s.status != null) 'status: ${s.status}',
    if (s.errorCode != null) 'error: ${s.errorCode}',
  ];
  return parts.isEmpty ? '' : ' (${parts.join(', ')})';
}
