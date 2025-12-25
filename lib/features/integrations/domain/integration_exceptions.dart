import 'package:flutter/foundation.dart';

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
  String toString() => 'TokenExpiredException${provider != null ? '[$provider]' : ''}: $message';
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
    if (retryAfterSeconds != null) buffer.write(' (retry after ${retryAfterSeconds}s)');
    return buffer.toString();
  }
}

/// Exception for network connectivity issues
///
/// These are transient errors (no internet, timeout) that may be
/// resolved by retrying after the network is available.
class NetworkException extends IntegrationApiException {
  const NetworkException(
    super.message, {
    super.provider,
  }) : super(isRetryable: true);

  @override
  String toString() => 'NetworkException${provider != null ? '[$provider]' : ''}: $message';
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
