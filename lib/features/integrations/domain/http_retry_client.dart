import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'integration_exceptions.dart';

/// Configuration for HTTP retry behavior
class RetryConfig {
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.backoffMultiplier = 2.0,
  });

  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay before first retry (in milliseconds)
  final int initialDelayMs;

  /// Maximum delay between retries (in milliseconds)
  final int maxDelayMs;

  /// Multiplier for exponential backoff (e.g., 2.0 = double each time)
  final double backoffMultiplier;

  /// Default configuration suitable for most integrations
  static const defaultConfig = RetryConfig();
}

/// Shared HTTP utilities for integration API clients
///
/// Provides:
/// - Automatic retry with exponential backoff
/// - Network error handling (SocketException, TimeoutException)
/// - Rate limit handling (429) with Retry-After support
/// - Consistent error response mapping to typed exceptions
///
/// Usage:
/// ```dart
/// final result = await HttpRetryClient.executeWithRetry(
///   request: () => _httpClient.get(url, headers: headers),
///   onResponse: (response) => _handleResponse(response),
///   provider: 'final_surge',
/// );
/// ```
class HttpRetryClient {
  /// Execute an HTTP request with automatic retry on transient failures
  ///
  /// [request] - Function that performs the HTTP request
  /// [onResponse] - Function to process the response (throws on error)
  /// [provider] - Provider name for error messages ('final_surge', 'training_peaks')
  /// [config] - Retry configuration (defaults to RetryConfig.defaultConfig)
  static Future<T> executeWithRetry<T>({
    required Future<http.Response> Function() request,
    required T Function(http.Response) onResponse,
    required String provider,
    RetryConfig config = RetryConfig.defaultConfig,
  }) async {
    int attempt = 0;
    int delayMs = config.initialDelayMs;

    while (true) {
      try {
        final response = await request();
        return onResponse(response);
      } on SocketException catch (e) {
        attempt++;
        if (attempt >= config.maxRetries) {
          throw NetworkException(
            'No internet connection after $attempt attempts: ${e.message}',
            provider: provider,
          );
        }
        if (kDebugMode) {
          print('⚠️ [$provider] Network error, retrying in ${delayMs}ms (attempt $attempt/${config.maxRetries})');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = _nextDelay(delayMs, config);
      } on TimeoutException catch (_) {
        attempt++;
        if (attempt >= config.maxRetries) {
          throw NetworkException(
            'Connection timed out after $attempt attempts',
            provider: provider,
          );
        }
        if (kDebugMode) {
          print('⚠️ [$provider] Timeout, retrying in ${delayMs}ms (attempt $attempt/${config.maxRetries})');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = _nextDelay(delayMs, config);
      } on RateLimitException catch (e) {
        attempt++;
        if (attempt >= config.maxRetries) rethrow;

        // Use server's retry-after if provided, otherwise exponential backoff
        final waitMs = e.retryAfterSeconds != null
            ? e.retryAfterSeconds! * 1000
            : delayMs;

        if (kDebugMode) {
          print('⚠️ [$provider] Rate limited, retrying in ${waitMs}ms (attempt $attempt/${config.maxRetries})');
        }
        await Future.delayed(Duration(milliseconds: waitMs));
        delayMs = _nextDelay(delayMs, config);
      } on ServerException catch (e) {
        // Retry server errors (5xx)
        attempt++;
        if (attempt >= config.maxRetries) rethrow;

        if (kDebugMode) {
          print('⚠️ [$provider] Server error (${e.statusCode}), retrying in ${delayMs}ms (attempt $attempt/${config.maxRetries})');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = _nextDelay(delayMs, config);
      }
      // Non-retryable exceptions (TokenExpiredException, etc.) propagate immediately
    }
  }

  /// Calculate next delay with exponential backoff, capped at maxDelayMs
  static int _nextDelay(int currentDelay, RetryConfig config) {
    final nextDelay = (currentDelay * config.backoffMultiplier).round();
    return nextDelay.clamp(0, config.maxDelayMs);
  }

  /// Map HTTP response status to appropriate exception
  ///
  /// Call this in your response handler to convert error responses to exceptions.
  /// Returns null if status is 200 (success).
  ///
  /// Example:
  /// ```dart
  /// void _handleResponse(http.Response response, String context) {
  ///   final error = HttpRetryClient.mapStatusToException(response, 'final_surge');
  ///   if (error != null) throw error;
  ///   // Process successful response...
  /// }
  /// ```
  static IntegrationApiException? mapStatusToException(
    http.Response response, {
    required String provider,
    String? context,
  }) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return null;
    }

    final message = context ?? 'API request failed';

    switch (response.statusCode) {
      case 401:
        return TokenExpiredException(
          'Access token expired or invalid',
          provider: provider,
        );
      case 403:
        return ForbiddenException(
          'Access forbidden - check API permissions',
          body: response.body,
          provider: provider,
        );
      case 429:
        // Extract retry-after header if present
        final retryAfter = response.headers['retry-after'];
        final retrySeconds = retryAfter != null ? int.tryParse(retryAfter) : null;
        return RateLimitException(
          'Rate limit exceeded',
          retryAfterSeconds: retrySeconds,
          provider: provider,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          'Server error - please try again later',
          statusCode: response.statusCode,
          body: response.body,
          provider: provider,
        );
      default:
        return IntegrationApiException(
          message,
          statusCode: response.statusCode,
          body: response.body,
          provider: provider,
        );
    }
  }

  /// Handle token refresh response
  ///
  /// Use this when implementing token refresh. Checks status code and throws
  /// appropriate exceptions for failure cases.
  ///
  /// Returns the response if successful (200), otherwise throws.
  static http.Response handleRefreshResponse(
    http.Response response, {
    required String provider,
  }) {
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw TokenRefreshException(
        'Refresh token expired or invalid. Please reconnect your account.',
        statusCode: response.statusCode,
        provider: provider,
        requiresReauth: true,
      );
    }

    if (response.statusCode != 200) {
      throw TokenRefreshException(
        'Token refresh failed',
        statusCode: response.statusCode,
        provider: provider,
      );
    }

    return response;
  }

  /// Wrap a network call with proper exception handling
  ///
  /// Converts SocketException and TimeoutException to NetworkException.
  static Future<T> withNetworkHandling<T>(
    Future<T> Function() operation, {
    required String provider,
  }) async {
    try {
      return await operation();
    } on SocketException catch (e) {
      throw NetworkException(
        'No internet connection: ${e.message}',
        provider: provider,
      );
    } on TimeoutException catch (_) {
      throw NetworkException(
        'Connection timed out',
        provider: provider,
      );
    }
  }
}
