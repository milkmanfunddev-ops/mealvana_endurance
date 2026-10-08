import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A short, plain message for `integrations.last_sync_error` (ticket 138,
/// Finding 118-002). The raw exception used to be stored as is, address,
/// port and URI included; the card and the server row only need the kind
/// of failure. [providerName] is the name the athlete sees.
///
/// TODO(content): these English lines are stored server-side in
/// `integrations.last_sync_error` and shown on the card as stored, so they
/// cannot go through the content system as is. Moving them needs a
/// key-based design (store a reason code, render the text from content).
String plainSyncErrorMessage(Object error, {required String providerName}) {
  final couldNotReach =
      'Could not reach $providerName. Check your connection and try again.';
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is NetworkException) {
    return couldNotReach;
  }
  if (error is RateLimitException) {
    return '$providerName is busy. Try again later.';
  }
  if (error is IntegrationApiException) {
    final status = error.statusCode;
    if (status != null) return '$providerName sync failed (status $status).';
    // An API client wraps a transport failure into its own exception with
    // the raw text as the message; that text is the one with the address.
    if (_looksLikeNetworkFailure(error.message)) return couldNotReach;
    return '$providerName sync failed: ${_cap(_strip(error.message))}';
  }
  final text = error.toString();
  if (_looksLikeNetworkFailure(text)) return couldNotReach;
  return '$providerName sync failed: ${_cap(_strip(text))}';
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

/// Drops URIs, addresses and ports from an exception text.
String _strip(String text) => text
    .replaceAll(RegExp(r'https?://\S+'), '')
    .replaceAll(RegExp(r'address\s*=\s*[^,)]+'), '')
    .replaceAll(RegExp(r'port\s*=\s*\d+'), '')
    .replaceAll(RegExp(r'\b\d{1,3}(\.\d{1,3}){3}(:\d+)?\b'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _cap(String text) =>
    text.length > 160 ? '${text.substring(0, 160)}…' : text;

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
