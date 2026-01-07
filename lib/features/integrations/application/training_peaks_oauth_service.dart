import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../data/integrations_repository.dart';
import '../data/training_peaks_api_client.dart';
import '../domain/integration.dart';

/// Service for TrainingPeaks OAuth authentication flow
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// - Tokens expire in 1 HOUR (must implement refresh)
/// - Separate OAuth URL from API URL
/// - Athlete profile is NOT in token response (must call API)
/// - Different scope format (space-delimited)
///
/// Uses flutter_web_auth_2 which opens a secure in-app browser
/// (ASWebAuthenticationSession on iOS, Custom Tabs on Android).
class TrainingPeaksOAuthService {
  TrainingPeaksOAuthService({
    required TrainingPeaksApiClient apiClient,
    required IntegrationsRepository repository,
    required String clientId,
    bool useSandbox = true,
    String callbackUrlScheme = 'com.milkman.mealvanaendurance',
    List<String>? scopes,
  })  : _apiClient = apiClient,
        _repository = repository,
        _clientId = clientId,
        _oauthBaseUrl = useSandbox
            ? 'https://oauth.sandbox.trainingpeaks.com'
            : 'https://oauth.trainingpeaks.com',
        _callbackUrlScheme = callbackUrlScheme,
        _scopes = scopes ?? defaultScopes;

  final TrainingPeaksApiClient _apiClient;
  final IntegrationsRepository _repository;
  final String _clientId;
  final String _oauthBaseUrl;
  final String _callbackUrlScheme;
  final List<String> _scopes;

  /// Default OAuth scopes for Mealvana
  static const defaultScopes = [
    'athlete:profile', // Read athlete data (weight, zones, premium status)
    'events:read', // Fetch upcoming races/events
    'workouts:read', // Access workout data
    'nutrition:write', // Push daily macros to TrainingPeaks
    'nutrition:read', // Read nutrition data
  ];

  /// Authenticate with TrainingPeaks via OAuth
  ///
  /// Opens a browser window for user to log in to TrainingPeaks,
  /// exchanges the authorization code for tokens, then fetches
  /// the athlete profile.
  ///
  /// Returns the created Integration record.
  Future<IntegrationModel> authenticate(String userId) async {
    // 1. Generate state for CSRF protection
    final state = _generateState();

    // 2. Build OAuth authorization URL
    final redirectUri = '$_callbackUrlScheme://callback';
    final authUrl = Uri.parse('$_oauthBaseUrl/OAuth/Authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'scope': _scopes.join(' '),
        'redirect_uri': redirectUri,
        'state': state,
      },
    );

    if (kDebugMode) {
      print('🔐 Starting TrainingPeaks OAuth flow...');
      print('   Auth URL: $authUrl');
    }

    // 3. Launch OAuth flow via flutter_web_auth_2
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true, // Don't persist cookies
      ),
    );

    // 4. Extract authorization code from callback URL
    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    // Validate state to prevent CSRF
    if (returnedState != state) {
      throw TrainingPeaksOAuthException('State mismatch - possible CSRF attack');
    }

    if (code == null || code.isEmpty) {
      final error = callbackUri.queryParameters['error'];
      final errorDescription = callbackUri.queryParameters['error_description'];
      throw TrainingPeaksOAuthException(
        errorDescription ?? error ?? 'No authorization code received',
      );
    }

    if (kDebugMode) {
      print('✅ Received authorization code');
    }

    // 5. Exchange code for access token
    final tokenResponse = await _apiClient.exchangeCodeForToken(code, redirectUri);

    if (kDebugMode) {
      print('✅ Token exchange successful');
      print('   Expires in: ${tokenResponse.expiresIn} seconds');
    }

    // 6. Fetch athlete profile (TrainingPeaks doesn't include this in token response!)
    final profile = await _apiClient.getAthleteProfile(tokenResponse.accessToken);

    if (kDebugMode) {
      print('✅ Athlete profile fetched');
      print('   Athlete: ${profile.fullName}');
      print('   Athlete ID: ${profile.id}');
      print('   Premium: ${profile.isPremium}');
    }

    // 7. Create and store integration
    final now = DateTime.now();
    final integration = IntegrationModel(
      userId: userId,
      provider: 'training_peaks',
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: profile.id,
      providerAthleteName: profile.fullName,
      providerAthleteEmail: profile.email,
      isActive: true,
      lastSyncStatus: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    // 8. Save to database (upsert - replaces existing if present)
    final savedIntegration = await _repository.upsertIntegration(integration);

    if (kDebugMode) {
      print('✅ Integration saved to database');
    }

    return savedIntegration;
  }

  /// Refresh the access token if it's expired or about to expire
  ///
  /// CRITICAL: TrainingPeaks tokens expire in 1 hour!
  /// Call this before making API requests.
  ///
  /// Returns the updated integration with fresh tokens, or null if refresh failed.
  Future<IntegrationModel?> refreshTokenIfNeeded(String userId) async {
    final integration = await _repository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return null;
    }

    // Check if token needs refresh (expires in next 5 minutes)
    final expiresAt = integration.tokenExpiresAt;
    if (expiresAt != null) {
      final now = DateTime.now();
      final fiveMinutesFromNow = now.add(const Duration(minutes: 5));

      if (expiresAt.isAfter(fiveMinutesFromNow)) {
        // Token is still valid
        return integration;
      }
    }

    // Token is expired or about to expire - refresh it
    final refreshToken = integration.refreshToken;
    if (refreshToken == null) {
      throw TrainingPeaksOAuthException(
        'No refresh token available. User must re-authenticate.',
      );
    }

    if (kDebugMode) {
      print('🔄 Refreshing TrainingPeaks token...');
    }

    try {
      final tokenResponse = await _apiClient.refreshToken(refreshToken);

      // Update integration with new tokens
      final updatedIntegration = integration.copyWith(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken ?? refreshToken,
        tokenExpiresAt: tokenResponse.expiresAt,
        updatedAt: DateTime.now(),
      );

      final savedIntegration = await _repository.upsertIntegration(updatedIntegration);

      if (kDebugMode) {
        print('✅ Token refreshed successfully');
        print('   New expiration: ${tokenResponse.expiresAt}');
      }

      return savedIntegration;
    } on TrainingPeaksApiException catch (e) {
      if (kDebugMode) {
        print('❌ Token refresh failed: ${e.message}');
      }
      // Mark integration as needing re-auth
      await _repository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'error',
        error: 'Token refresh failed. Please reconnect.',
      );
      return null;
    }
  }

  /// Get a valid access token, refreshing if needed
  ///
  /// Returns the access token if valid, or null if refresh failed.
  Future<String?> getValidAccessToken(String userId) async {
    final integration = await refreshTokenIfNeeded(userId);
    return integration?.accessToken;
  }

  /// Disconnect TrainingPeaks integration
  ///
  /// Optionally deauthorizes the app on TrainingPeaks side,
  /// then marks the integration as inactive.
  Future<void> disconnect(String userId, {bool revokeAccess = false}) async {
    if (revokeAccess) {
      final integration = await _repository.getIntegration(userId, 'training_peaks');
      if (integration != null && integration.accessToken.isNotEmpty) {
        try {
          await _apiClient.deauthorize(integration.accessToken);
          if (kDebugMode) {
            print('✅ TrainingPeaks access revoked');
          }
        } catch (e) {
          // Log but don't fail - we'll still deactivate locally
          if (kDebugMode) {
            print('⚠️ Failed to revoke TrainingPeaks access: $e');
          }
        }
      }
    }

    await _repository.deactivateIntegration(userId, 'training_peaks');

    if (kDebugMode) {
      print('✅ TrainingPeaks integration disconnected');
    }
  }

  /// Check if user has an active TrainingPeaks integration
  Future<bool> isConnected(String userId) async {
    final integration = await _repository.getIntegration(userId, 'training_peaks');
    return integration?.isActive ?? false;
  }

  /// Get the current TrainingPeaks integration for a user
  Future<IntegrationModel?> getIntegration(String userId) async {
    return _repository.getIntegration(userId, 'training_peaks');
  }

  /// Check if the current token is valid (not expired)
  Future<bool> hasValidToken(String userId) async {
    final integration = await _repository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return false;
    }

    final expiresAt = integration.tokenExpiresAt;
    if (expiresAt == null) {
      return true; // No expiration info, assume valid
    }

    return expiresAt.isAfter(DateTime.now());
  }

  /// Generate a random state string for CSRF protection
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Exception for TrainingPeaks OAuth errors
class TrainingPeaksOAuthException implements Exception {
  const TrainingPeaksOAuthException(this.message);

  final String message;

  @override
  String toString() => 'TrainingPeaksOAuthException: $message';
}
