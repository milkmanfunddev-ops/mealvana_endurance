import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/http_retry_client.dart';
import '../domain/integration_exceptions.dart';

/// API client for Final Surge workout data
///
/// Handles:
/// - OAuth token exchange
/// - Fetching upcoming workouts
/// - Token refresh with automatic retry
/// - Error handling with typed exceptions
class FinalSurgeApiClient {
  FinalSurgeApiClient({
    required String clientId,
    required String clientSecret,
    http.Client? httpClient,
    RetryConfig? retryConfig,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _httpClient = httpClient ?? http.Client(),
        _retryConfig = retryConfig ?? RetryConfig.defaultConfig;

  static const _baseUrl = 'https://log.finalsurge.com';
  static const _provider = 'final_surge';

  final String _clientId;
  final String _clientSecret;
  final http.Client _httpClient;
  final RetryConfig _retryConfig;

  /// Exchange authorization code for access token
  ///
  /// Called after user completes OAuth flow in browser.
  /// [redirectUri] must match the redirect-uri used in the authorization request.
  Future<FinalSurgeTokenResponse> exchangeCodeForToken(
    String code, {
    String? redirectUri,
  }) async {
    if (kDebugMode) {
      print('🔄 Exchanging authorization code for token...');
      print('   Code: ${code.substring(0, code.length > 8 ? 8 : code.length)}...');
      print('   Client ID: $_clientId');
      print('   Secret length: ${_clientSecret.length} (expected: 64)');
      if (_clientSecret.length >= 10) {
        print('   Secret first 5 chars: ${_clientSecret.substring(0, 5)}');
        print('   Secret last 5 chars: ${_clientSecret.substring(_clientSecret.length - 5)}');
      } else {
        print('   ❌ SECRET TOO SHORT! Got: "$_clientSecret"');
        print('   ⚠️  The \$ characters in .env must be escaped as \\\$');
      }
    }

    // Build form-encoded body
    // NOTE: Final Surge uses hyphens (client-id) not underscores (client_id)
    final bodyParams = {
      'client-id': _clientId,
      'client-secret': _clientSecret,
      'code': code,
    };

    if (kDebugMode) {
      print('   Request body keys: ${bodyParams.keys.toList()}');
    }

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: bodyParams,
    );

    if (kDebugMode) {
      print('   Token exchange response status: ${response.statusCode}');
      print('   Response body: ${response.body}');
    }

    if (response.statusCode != 200) {
      if (kDebugMode) {
        print('❌ Token exchange failed: ${response.body}');
      }
      throw FinalSurgeApiException(
        'Token exchange failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (kDebugMode) {
      print('   JSON keys: ${json.keys.toList()}');
    }

    // Final Surge returns 200 even on error - check the error field
    final errorMessage = json['error'] as String?;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      if (kDebugMode) {
        print('❌ Token exchange error: $errorMessage');
      }
      throw FinalSurgeApiException(
        'Token exchange failed: $errorMessage',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    if (kDebugMode) {
      print('✅ Token exchange successful');
    }

    return FinalSurgeTokenResponse.fromJson(json);
  }

  /// Refresh an expired access token using the refresh token
  ///
  /// Returns a new [FinalSurgeTokenResponse] with fresh tokens.
  /// Throws [TokenRefreshException] if refresh fails.
  Future<FinalSurgeTokenResponse> refreshAccessToken(String refreshToken) async {
    if (kDebugMode) {
      print('🔄 Refreshing Final Surge access token...');
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client-id': _clientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 401 || response.statusCode == 400) {
        // Refresh token is invalid or expired - user must re-authenticate
        throw TokenRefreshException(
          'Refresh token expired or invalid. Please reconnect your Final Surge account.',
          requiresReauth: true,
        );
      }

      if (response.statusCode != 200) {
        throw TokenRefreshException(
          'Token refresh failed',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (kDebugMode) {
        print('✅ Token refresh successful');
      }

      return FinalSurgeTokenResponse.fromJson(json);
    } on SocketException catch (e) {
      throw NetworkException('No internet connection: ${e.message}');
    } on TimeoutException catch (_) {
      throw NetworkException('Connection timed out');
    }
  }

  /// Fetch upcoming workouts from Final Surge
  ///
  /// [numDays] - Number of days ahead to fetch (default: 7)
  /// [numWorkouts] - Maximum number of workouts to return (default: 21)
  ///
  /// Throws:
  /// - [TokenExpiredException] if access token is invalid (401)
  /// - [RateLimitException] if rate limited (429)
  /// - [NetworkException] for connection issues
  /// - [FinalSurgeApiException] for other API errors
  Future<FinalSurgeWorkoutsResponse> getUpcomingWorkouts(
    String accessToken, {
    int numDays = 7,
    int numWorkouts = 21,
  }) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_baseUrl/API/v1/UpcomingWorkouts').replace(
          queryParameters: {
            'NumDays': numDays.toString(),
            'NumWorkouts': numWorkouts.toString(),
          },
        ),
        headers: {
          'client-id': _clientId,
          'Authorization': 'Bearer $accessToken',
        },
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch workouts');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return FinalSurgeWorkoutsResponse.fromJson(json);
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch workouts for a specific date range
  ///
  /// Throws:
  /// - [TokenExpiredException] if access token is invalid (401)
  /// - [RateLimitException] if rate limited (429)
  /// - [NetworkException] for connection issues
  /// - [FinalSurgeApiException] for other API errors
  Future<FinalSurgeWorkoutsResponse> getWorkoutsByDateRange(
    String accessToken, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_baseUrl/API/v1/Workouts').replace(
          queryParameters: {
            'StartDate': _formatDate(startDate),
            'EndDate': _formatDate(endDate),
          },
        ),
        headers: {
          'client-id': _clientId,
          'Authorization': 'Bearer $accessToken',
        },
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch workouts by date range');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return FinalSurgeWorkoutsResponse.fromJson(json);
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch a single workout by its WorkoutKey
  ///
  /// Used for single-activity refresh button feature.
  /// [workoutKey] - The unique WorkoutKey identifier from Final Surge
  ///
  /// Throws:
  /// - [TokenExpiredException] if access token is invalid (401)
  /// - [RateLimitException] if rate limited (429)
  /// - [NetworkException] for connection issues
  /// - [FinalSurgeApiException] for other API errors (including 404 if workout not found)
  Future<Map<String, dynamic>> getWorkoutById(
    String accessToken,
    String workoutKey,
  ) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_baseUrl/API/v1/Workout/$workoutKey'),
        headers: {
          'client-id': _clientId,
          'Authorization': 'Bearer $accessToken',
        },
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch workout by ID');
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // Final Surge may return an error in the response body even with 200 status
        final errorMessage = json['ErrorMessage'] as String?;
        if (errorMessage != null && errorMessage.isNotEmpty) {
          throw FinalSurgeApiException(
            'Failed to fetch workout: $errorMessage',
            statusCode: response.statusCode,
            body: response.body,
          );
        }

        return json;
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch structured workout data for a workout
  ///
  /// The URL comes from `workout['StructuredWorkoutURLs']['json_fs_v1']`.
  /// Returns the structured workout steps in Final Surge JSON format.
  ///
  /// Throws:
  /// - [TokenExpiredException] if access token is invalid (401)
  /// - [NetworkException] for connection issues
  /// - [FinalSurgeApiException] for other API errors
  Future<Map<String, dynamic>> getStructuredWorkout(
    String accessToken,
    String jsonFsV1Url,
  ) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse(jsonFsV1Url),
        headers: {
          'client-id': _clientId,
          'Authorization': 'Bearer $accessToken',
        },
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch structured workout');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json;
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Handle error responses and throw appropriate exceptions
  void _handleErrorResponse(http.Response response, String context) {
    final error = HttpRetryClient.mapStatusToException(
      response,
      provider: _provider,
      context: context,
    );
    if (error != null) throw error;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Response from Final Surge OAuth token exchange
class FinalSurgeTokenResponse {
  const FinalSurgeTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    required this.athleteId,
    this.firstName,
    this.lastName,
    this.email,
  });

  factory FinalSurgeTokenResponse.fromJson(Map<String, dynamic> json) {
    // Final Surge token response format (based on working test script):
    // {
    //   "access_token": "...",
    //   "id": "athlete-uuid",
    //   "firstname": "John",
    //   "lastname": "Doe",
    //   "error": null
    // }
    // Note: Athlete fields are at ROOT level, not nested under 'athlete'
    // The 'athlete' key exists but may be null

    // Get access token
    final accessToken = json['access_token'] as String? ??
                        json['accessToken'] as String? ??
                        json['token'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      throw FinalSurgeApiException(
        'No access token in response. Keys: ${json.keys.toList()}',
        body: json.toString(),
      );
    }

    // Athlete data is at root level (based on working test script)
    // Fall back to nested 'athlete' object if present (per some docs)
    final athlete = json['athlete'] as Map<String, dynamic>?;

    return FinalSurgeTokenResponse(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String? ?? json['refreshToken'] as String?,
      expiresIn: json['expires_in'] as int? ?? json['expiresIn'] as int?,
      // Root level first (test script shows this), then nested as fallback
      athleteId: json['id']?.toString() ??
                 athlete?['id']?.toString() ??
                 json['athlete_id']?.toString() ?? '',
      firstName: json['firstname'] as String? ?? athlete?['firstname'] as String?,
      lastName: json['lastname'] as String? ?? athlete?['lastname'] as String?,
      email: json['email'] as String? ?? athlete?['email'] as String?,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String athleteId;
  final String? firstName;
  final String? lastName;
  final String? email;

  String? get fullName {
    if (firstName == null && lastName == null) return null;
    return [firstName, lastName].where((s) => s != null).join(' ');
  }

  DateTime? get expiresAt {
    if (expiresIn == null) return null;
    return DateTime.now().add(Duration(seconds: expiresIn!));
  }
}

/// Response from Final Surge workouts API
class FinalSurgeWorkoutsResponse {
  const FinalSurgeWorkoutsResponse({
    required this.success,
    this.errorNumber,
    this.errorMessage,
    required this.workouts,
  });

  factory FinalSurgeWorkoutsResponse.fromJson(Map<String, dynamic> json) {
    final workoutsList = json['Workouts'] as List?;
    return FinalSurgeWorkoutsResponse(
      success: json['Success'] as bool? ?? false,
      errorNumber: json['ErrorNumber'] as int?,
      errorMessage: json['ErrorMessage'] as String?,
      workouts: workoutsList?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  final bool success;
  final int? errorNumber;
  final String? errorMessage;
  final List<Map<String, dynamic>> workouts;

  bool get hasError => !success || errorMessage != null;
}

/// Exception for Final Surge API errors
///
/// Extends the shared [IntegrationApiException] for consistency across integrations.
/// Kept for backward compatibility with existing code.
class FinalSurgeApiException extends IntegrationApiException {
  const FinalSurgeApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.isRetryable,
  }) : super(provider: 'final_surge');

  @override
  String toString() {
    final buffer = StringBuffer('FinalSurgeApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (body != null && kDebugMode) {
      buffer.write('\nBody: $body');
    }
    return buffer.toString();
  }
}

/// Exception for OAuth-specific errors
class FinalSurgeOAuthException extends IntegrationApiException {
  const FinalSurgeOAuthException(super.message) : super(provider: 'final_surge');

  @override
  String toString() => 'FinalSurgeOAuthException: $message';
}

// Re-export shared exceptions for backward compatibility
// These are now defined in integration_exceptions.dart
// The imports at the top make them available in this file
