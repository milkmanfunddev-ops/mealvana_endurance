import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Why a sync failed, as stored in `integrations.last_sync_error`
/// (testing-wave develop-2026-10 ticket 37). The row holds a short wire
/// code, never English: the card and snackbars map the code to content
/// keys at display time (`syncErrorText` in `integration_sync_helpers.dart`),
/// so the text can change without a release. Same text column, no
/// migration; a row written before ticket 37 holds English and reads as
/// [unknown]. The server writes the same codes
/// (`supabase/functions/_shared/garmin/token.ts`).
enum SyncErrorCode {
  network('network'),
  rateLimited('rate_limited'),

  /// Wire form `http_<status>`, e.g. `http_502`.
  httpStatus('http_'),
  reauthRequired('reauth_required'),
  unknown('unknown');

  const SyncErrorCode(this.wire);

  /// The stored string; for [httpStatus] the prefix before the status.
  final String wire;
}

/// The wire code for "the provider refused the token; sign in again".
/// TrainingPeaks, Final Surge, V.O2 and Garmin all store this one code; the
/// provider name comes from the row, not the text.
const reauthRequiredCode = 'reauth_required';

/// A parsed `last_sync_error` value: the [code], and the HTTP [status] for
/// [SyncErrorCode.httpStatus].
@immutable
class SyncError {
  const SyncError(this.code, {this.status});

  final SyncErrorCode code;
  final int? status;

  /// The string written to `integrations.last_sync_error`.
  String get wire => code == SyncErrorCode.httpStatus
      ? '${SyncErrorCode.httpStatus.wire}$status'
      : code.wire;

  static final _http = RegExp(r'^http_(\d{3})$');

  /// A wire code, or null when [text] is not one (English from a row
  /// written before ticket 37, or any other message).
  static SyncError? tryParse(String? text) {
    if (text == null) return null;
    final t = text.trim();
    for (final c in SyncErrorCode.values) {
      if (c != SyncErrorCode.httpStatus && c.wire == t) return SyncError(c);
    }
    final m = _http.firstMatch(t);
    if (m != null) {
      return SyncError(SyncErrorCode.httpStatus, status: int.parse(m[1]!));
    }
    return null;
  }

  /// Like [tryParse], but anything that is not a wire code (legacy English
  /// included) reads as [SyncErrorCode.unknown].
  static SyncError parse(String? text) =>
      tryParse(text) ?? const SyncError(SyncErrorCode.unknown);

  @override
  bool operator ==(Object other) =>
      other is SyncError && other.code == code && other.status == status;

  @override
  int get hashCode => Object.hash(code, status);

  @override
  String toString() => 'SyncError($wire)';
}

/// The wire code for [error], stored in `integrations.last_sync_error`
/// (replaces ticket 138's English `plainSyncErrorMessage`). The raw
/// exception is never stored: its text carries addresses, ports and URIs
/// (Finding 118-002), and the card only needs the kind of failure.
String syncErrorCode(Object error) {
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is NetworkException) {
    return SyncErrorCode.network.wire;
  }
  if (error is RateLimitException) return SyncErrorCode.rateLimited.wire;
  if (error is TokenRefreshException && error.requiresReauth) {
    return reauthRequiredCode;
  }
  if (error is IntegrationApiException) {
    final status = error.statusCode;
    if (status == 429) return SyncErrorCode.rateLimited.wire;
    if (status != null) {
      return SyncError(SyncErrorCode.httpStatus, status: status).wire;
    }
    // An API client wraps a transport failure into its own exception with
    // the raw text as the message.
    if (_looksLikeNetworkFailure(error.message)) {
      return SyncErrorCode.network.wire;
    }
    return SyncErrorCode.unknown.wire;
  }
  if (_looksLikeNetworkFailure(error.toString())) {
    return SyncErrorCode.network.wire;
  }
  return SyncErrorCode.unknown.wire;
}

/// The code for a failed sync result: a refused token or a network failure
/// flagged on the result wins; otherwise [error] when it is already a wire
/// code, else `unknown`.
String syncFailureCode({
  String? error,
  bool needsReauth = false,
  bool isNetworkError = false,
}) {
  if (needsReauth) return reauthRequiredCode;
  if (isNetworkError) return SyncErrorCode.network.wire;
  return SyncError.parse(error).wire;
}

bool _looksLikeNetworkFailure(String text) {
  final t = text.toLowerCase();
  return t.contains('socketexception') ||
      t.contains('clientexception') ||
      t.contains('timeoutexception') ||
      t.contains('handshakeexception') ||
      t.contains('network is unreachable') ||
      t.contains('connection refused') ||
      t.contains('connection reset') ||
      t.contains('failed host lookup') ||
      t.contains('no answer');
}

/// Base exception for all workout integration API errors
///
/// This is the common base for Final Surge, TrainingPeaks, and future integrations.
/// Use specific subclasses to handle different error scenarios appropriately.
class IntegrationApiException implements Exception {
  const IntegrationApiException(
    this.message, {
    this.statusCode,
    this.body,
    this.isRetryable = false,
    this.provider,
  });

  final String message;
  final int? statusCode;
  final String? body;
  final bool isRetryable;
  final String? provider; // 'final_surge', 'training_peaks', etc.

  /// The most of a response body that goes into a Report's `extra`.
  static const maxReportedBodyChars = 1000;

  /// Status and clipped response body for a Report's `extra`. `toString()`
  /// drops the body outside debug builds, so without this a prod 4xx reaches
  /// Sentry with no clue what the provider objected to.
  Map<String, dynamic> get reportExtra {
    final b = body;
    return {
      'statusCode': statusCode,
      if (b != null)
        'responseBody': b.length > maxReportedBodyChars
            ? b.substring(0, maxReportedBodyChars)
            : b,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('IntegrationApiException');
    if (provider != null) buffer.write('[$provider]');
    buffer.write(': $message');
    if (statusCode != null) buffer.write(' (status: $statusCode)');
    if (body != null && kDebugMode) buffer.write('\nBody: $body');
    return buffer.toString();
  }
}

/// Exception thrown when access token has expired (401)
///
/// The caller should attempt to refresh the token and retry the request.
/// This is thrown by API clients when they receive a 401 response.
class TokenExpiredException extends IntegrationApiException {
  const TokenExpiredException(
    super.message, {
    super.statusCode = 401,
    super.provider,
  });

  @override
  String toString() =>
      'TokenExpiredException${provider != null ? '[$provider]' : ''}: $message';
}

/// Exception thrown when token refresh fails
///
/// If [requiresReauth] is true, the refresh token itself has expired
/// and the user must go through the full OAuth flow again.
class TokenRefreshException extends IntegrationApiException {
  const TokenRefreshException(
    super.message, {
    super.statusCode,
    super.provider,
    this.requiresReauth = false,
  });

  /// If true, the user must reconnect their account (refresh token expired)
  final bool requiresReauth;

  @override
  String toString() =>
      'TokenRefreshException${provider != null ? '[$provider]' : ''}: $message (requiresReauth: $requiresReauth)';
}

/// Exception thrown when rate limited (429)
///
/// [retryAfterSeconds] indicates how long to wait before retrying,
/// as specified by the server's Retry-After header.
class RateLimitException extends IntegrationApiException {
  const RateLimitException(
    super.message, {
    this.retryAfterSeconds,
    super.provider,
  }) : super(isRetryable: true);

  final int? retryAfterSeconds;

  @override
  String toString() {
    final buffer = StringBuffer('RateLimitException');
    if (provider != null) buffer.write('[$provider]');
    buffer.write(': $message');
    if (retryAfterSeconds != null)
      buffer.write(' (retry after ${retryAfterSeconds}s)');
    return buffer.toString();
  }
}

/// Exception for network connectivity issues
///
/// These are transient errors (no internet, timeout) that may be
/// resolved by retrying after the network is available.
class NetworkException extends IntegrationApiException {
  const NetworkException(super.message, {super.provider})
    : super(isRetryable: true);

  @override
  String toString() =>
      'NetworkException${provider != null ? '[$provider]' : ''}: $message';
}

/// Exception for server-side errors (5xx)
///
/// These are typically transient and can be retried.
class ServerException extends IntegrationApiException {
  const ServerException(
    super.message, {
    super.statusCode,
    super.body,
    super.provider,
  }) : super(isRetryable: true);

  @override
  String toString() {
    final buffer = StringBuffer('ServerException');
    if (provider != null) buffer.write('[$provider]');
    buffer.write(': $message');
    if (statusCode != null) buffer.write(' (status: $statusCode)');
    return buffer.toString();
  }
}

/// Exception for forbidden access (403)
///
/// This typically means the user doesn't have permission (e.g., premium feature
/// on a basic account, or missing OAuth scope).
class ForbiddenException extends IntegrationApiException {
  const ForbiddenException(
    super.message, {
    super.statusCode = 403,
    super.body,
    super.provider,
    this.isPremiumRequired = false,
  });

  /// If true, this feature requires a premium account with the provider
  final bool isPremiumRequired;

  @override
  String toString() {
    final buffer = StringBuffer('ForbiddenException');
    if (provider != null) buffer.write('[$provider]');
    buffer.write(': $message');
    if (isPremiumRequired) buffer.write(' (premium required)');
    return buffer.toString();
  }
}
