import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API client for Final Surge workout data
///
/// Handles:
/// - OAuth token exchange
/// - Fetching upcoming workouts
/// - Token refresh (when needed)
class FinalSurgeApiClient {
  FinalSurgeApiClient({
    required String clientId,
    http.Client? httpClient,
  })  : _clientId = clientId,
        _httpClient = httpClient ?? http.Client();

  static const _baseUrl = 'https://log.finalsurge.com';

  final String _clientId;
  final http.Client _httpClient;

  /// Exchange authorization code for access token
  ///
  /// Called after user completes OAuth flow in browser
  Future<FinalSurgeTokenResponse> exchangeCodeForToken(String code) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client-id': _clientId,
        'code': code,
      },
    );

    if (response.statusCode != 200) {
      throw FinalSurgeApiException(
        'Token exchange failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FinalSurgeTokenResponse.fromJson(json);
  }

  /// Fetch upcoming workouts from Final Surge
  ///
  /// [numDays] - Number of days ahead to fetch (default: 7)
  /// [numWorkouts] - Maximum number of workouts to return (default: 21)
  Future<FinalSurgeWorkoutsResponse> getUpcomingWorkouts(
    String accessToken, {
    int numDays = 7,
    int numWorkouts = 21,
  }) async {
    final response = await _httpClient.get(
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
    );

    if (response.statusCode != 200) {
      throw FinalSurgeApiException(
        'Failed to fetch workouts',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FinalSurgeWorkoutsResponse.fromJson(json);
  }

  /// Fetch workouts for a specific date range
  Future<FinalSurgeWorkoutsResponse> getWorkoutsByDateRange(
    String accessToken, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _httpClient.get(
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
    );

    if (response.statusCode != 200) {
      throw FinalSurgeApiException(
        'Failed to fetch workouts by date range',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FinalSurgeWorkoutsResponse.fromJson(json);
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
    return FinalSurgeTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      athleteId: json['id']?.toString() ?? json['athlete_id']?.toString() ?? '',
      firstName: json['firstname'] as String?,
      lastName: json['lastname'] as String?,
      email: json['email'] as String?,
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
class FinalSurgeApiException implements Exception {
  const FinalSurgeApiException(
    this.message, {
    this.statusCode,
    this.body,
  });

  final String message;
  final int? statusCode;
  final String? body;

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
