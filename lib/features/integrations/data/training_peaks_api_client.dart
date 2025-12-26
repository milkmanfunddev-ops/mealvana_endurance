import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/http_retry_client.dart';
import '../domain/integration_exceptions.dart';

/// API client for TrainingPeaks workout and event data
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// - Tokens expire in 1 hour (must implement refresh)
/// - Separate OAuth and API URLs
/// - Distance is ALWAYS in meters
/// - Time is in decimal hours
/// - Has event sync endpoint (unique!)
/// - Athlete profile is a separate API call (not in token response)
///
/// Handles:
/// - OAuth token exchange
/// - Token refresh (CRITICAL - tokens expire in 1 hour)
/// - Fetching upcoming workouts
/// - Fetching athlete profile
/// - Fetching events (unique to TrainingPeaks)
/// - Automatic retry with exponential backoff
/// - Rate limit handling
class TrainingPeaksApiClient {
  TrainingPeaksApiClient({
    required String clientId,
    required String clientSecret,
    bool useSandbox = true,
    http.Client? httpClient,
    RetryConfig? retryConfig,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _oauthBaseUrl = useSandbox
            ? 'https://oauth.sandbox.trainingpeaks.com'
            : 'https://oauth.trainingpeaks.com',
        _apiBaseUrl = useSandbox
            ? 'https://api.sandbox.trainingpeaks.com'
            : 'https://api.trainingpeaks.com',
        _httpClient = httpClient ?? http.Client(),
        _retryConfig = retryConfig ?? RetryConfig.defaultConfig;

  static const _provider = 'training_peaks';

  final String _clientId;
  final String _clientSecret;
  final String _oauthBaseUrl;
  final String _apiBaseUrl;
  final http.Client _httpClient;
  final RetryConfig _retryConfig;

  static const _userAgent = 'Mealvana Endurance v1.0';

  /// Exchange authorization code for access token
  ///
  /// Called after user completes OAuth flow in browser.
  /// Note: Unlike Final Surge, athlete info is NOT in the token response.
  /// You must call getAthleteProfile() separately.
  Future<TrainingPeaksTokenResponse> exchangeCodeForToken(
    String code,
    String redirectUri,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$_oauthBaseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    if (response.statusCode != 200) {
      throw TrainingPeaksApiException(
        'Token exchange failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TrainingPeaksTokenResponse.fromJson(json);
  }

  /// Refresh an expired access token
  ///
  /// CRITICAL: TrainingPeaks tokens expire in 1 hour!
  /// Call this before making API requests when token is expired or near expiry.
  Future<TrainingPeaksTokenResponse> refreshToken(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse('$_oauthBaseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw TrainingPeaksApiException(
        'Token refresh failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TrainingPeaksTokenResponse.fromJson(json);
  }

  /// Deauthorize the app (revoke tokens)
  Future<void> deauthorize(String accessToken) async {
    final response = await _httpClient.post(
      Uri.parse('$_oauthBaseUrl/oauth/deauthorize'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw TrainingPeaksApiException(
        'Deauthorization failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  /// Get athlete profile
  ///
  /// Unlike Final Surge, this is a separate API call (not in token response).
  /// Includes: Id, FirstName, LastName, Weight (kg), IsPremium, PreferredUnits
  Future<TrainingPeaksAthleteProfile> getAthleteProfile(
    String accessToken,
  ) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_apiBaseUrl/v1/athlete/profile'),
        headers: _authHeaders(accessToken),
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch athlete profile');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TrainingPeaksAthleteProfile.fromJson(json);
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch workouts for a date range
  ///
  /// CRITICAL: Distance is in METERS, Time is in DECIMAL HOURS
  /// Max date range is 45 days.
  ///
  /// Throws:
  /// - [TokenExpiredException] if access token is invalid (401)
  /// - [RateLimitException] if rate limited (429)
  /// - [NetworkException] for connection issues
  /// - [IntegrationApiException] for other API errors
  Future<List<Map<String, dynamic>>> getWorkouts(
    String accessToken, {
    required DateTime startDate,
    required DateTime endDate,
    bool includeDescription = false,
  }) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_apiBaseUrl/v2/workouts/${_formatDate(startDate)}/${_formatDate(endDate)}')
            .replace(queryParameters: {
          if (includeDescription) 'includeDescription': 'true',
        }),
        headers: _authHeaders(accessToken),
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch workouts');
        final json = jsonDecode(response.body) as List;
        return json.cast<Map<String, dynamic>>();
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch upcoming workouts (convenience method)
  ///
  /// Fetches workouts for the next [days] days.
  Future<List<Map<String, dynamic>>> getUpcomingWorkouts(
    String accessToken, {
    int days = 14,
    bool includeDescription = false,
  }) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    return getWorkouts(
      accessToken,
      startDate: now,
      endDate: endDate,
      includeDescription: includeDescription,
    );
  }

  /// Get the next upcoming event (UNIQUE TO TRAININGPEAKS!)
  ///
  /// This is a key differentiator from Final Surge - we can auto-import
  /// races and events for nutrition planning.
  Future<Map<String, dynamic>?> getNextEvent(String accessToken) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_apiBaseUrl/v2/events/next'),
        headers: _authHeaders(accessToken),
      ),
      onResponse: (response) {
        // 404 = No upcoming events (not an error)
        if (response.statusCode == 404) return null;

        _handleErrorResponse(response, 'Failed to fetch next event');

        final body = response.body;
        if (body.isEmpty) return null;

        final json = jsonDecode(body);
        if (json == null) return null;

        // API can return a single object or array
        if (json is List) {
          return json.isNotEmpty ? json.first as Map<String, dynamic> : null;
        }
        return json as Map<String, dynamic>;
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Get events for a specific date
  Future<List<Map<String, dynamic>>> getEventsByDate(
    String accessToken,
    DateTime date,
  ) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_apiBaseUrl/v2/events/${_formatDate(date)}'),
        headers: _authHeaders(accessToken),
      ),
      onResponse: (response) {
        // 404 = No events on this date (not an error)
        if (response.statusCode == 404) return <Map<String, dynamic>>[];

        _handleErrorResponse(response, 'Failed to fetch events');

        final json = jsonDecode(response.body) as List;
        return json.cast<Map<String, dynamic>>();
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Push nutrition data to TrainingPeaks (UNIQUE FEATURE!)
  ///
  /// This allows us to sync Mealvana nutrition plans TO TrainingPeaks,
  /// making them visible to coaches!
  Future<Map<String, dynamic>> createNutritionEntry(
    String accessToken, {
    required String athleteId,
    required DateTime date,
    double? calories,
    double? carbohydrates,
    double? fat,
    double? protein,
  }) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.post(
        Uri.parse('$_apiBaseUrl/v1/athletes/$athleteId/nutrition'),
        headers: {
          ..._authHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'NutritionDate': date.toIso8601String(),
          if (calories != null) 'Calories': calories,
          if (carbohydrates != null) 'Carbohydrates': carbohydrates,
          if (fat != null) 'Fat': fat,
          if (protein != null) 'Protein': protein,
        }),
      ),
      onResponse: (response) {
        // 201 = Created (success for POST)
        if (response.statusCode != 201) {
          _handleErrorResponse(response, 'Failed to create nutrition entry');
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': _userAgent,
      };

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  void dispose() {
    _httpClient.close();
  }
}

/// Response from TrainingPeaks OAuth token exchange/refresh
class TrainingPeaksTokenResponse {
  const TrainingPeaksTokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.tokenType,
    this.scope,
  });

  factory TrainingPeaksTokenResponse.fromJson(Map<String, dynamic> json) {
    return TrainingPeaksTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int? ?? 600,
      tokenType: json['token_type'] as String?,
      scope: json['scope'] as String?,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final int expiresIn; // Always present (usually 600 seconds = 10 min? or 3600 = 1 hour)
  final String? tokenType;
  final String? scope;

  /// Calculate when the token expires
  DateTime get expiresAt => DateTime.now().add(Duration(seconds: expiresIn));

  /// Check if token will expire within the given duration
  bool willExpireWithin(Duration duration) {
    return expiresAt.isBefore(DateTime.now().add(duration));
  }
}

/// TrainingPeaks athlete profile data
class TrainingPeaksAthleteProfile {
  const TrainingPeaksAthleteProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.timeZone,
    this.birthMonth,
    this.sex,
    this.coachedBy,
    this.weight,
    required this.isPremium,
    this.preferredUnits,
  });

  factory TrainingPeaksAthleteProfile.fromJson(Map<String, dynamic> json) {
    return TrainingPeaksAthleteProfile(
      id: json['Id']?.toString() ?? '',
      firstName: json['FirstName'] as String?,
      lastName: json['LastName'] as String?,
      email: json['Email'] as String?,
      timeZone: json['TimeZone'] as String?,
      birthMonth: json['BirthMonth'] as String?,
      sex: json['Sex'] as String?,
      coachedBy: json['CoachedBy']?.toString(),
      weight: (json['Weight'] as num?)?.toDouble(),
      isPremium: json['IsPremium'] as bool? ?? false,
      preferredUnits: json['PreferredUnits'] as String?,
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? timeZone;
  final String? birthMonth;
  final String? sex; // 'm' or 'f'
  final String? coachedBy;
  final double? weight; // Always in kilograms!
  final bool isPremium;
  final String? preferredUnits; // 'English' or 'Metric'

  String? get fullName {
    if (firstName == null && lastName == null) return null;
    return [firstName, lastName].where((s) => s != null).join(' ');
  }

  /// Weight in pounds (converted from kg)
  double? get weightLbs => weight != null ? weight! * 2.20462 : null;
}

/// Exception for TrainingPeaks API errors
///
/// Extends the shared [IntegrationApiException] for consistency across integrations.
/// Kept for backward compatibility with existing code.
class TrainingPeaksApiException extends IntegrationApiException {
  const TrainingPeaksApiException(
    super.message, {
    super.statusCode,
    super.body,
  }) : super(provider: 'training_peaks');

  @override
  String toString() {
    final buffer = StringBuffer('TrainingPeaksApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (body != null && kDebugMode) {
      buffer.write('\nBody: $body');
    }
    return buffer.toString();
  }
}

/// Exception specifically for expired tokens
///
/// Extends the shared [TokenExpiredException] for consistency.
/// This exception should trigger a token refresh flow.
class TrainingPeaksTokenExpiredException extends TokenExpiredException {
  const TrainingPeaksTokenExpiredException()
      : super('Token expired. Call refreshToken().', provider: 'training_peaks');

  @override
  String toString() =>
      'TrainingPeaksTokenExpiredException: Token expired. Call refreshToken().';
}

/// Exception for OAuth-specific errors
class TrainingPeaksOAuthException extends IntegrationApiException {
  const TrainingPeaksOAuthException(super.message) : super(provider: 'training_peaks');

  @override
  String toString() => 'TrainingPeaksOAuthException: $message';
}
