import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../data/final_surge_api_client.dart';
import '../data/integrations_repository.dart';
import '../domain/integration.dart';

/// Service for Final Surge OAuth authentication flow
///
/// Uses flutter_web_auth_2 which opens a secure in-app browser
/// (ASWebAuthenticationSession on iOS, Custom Tabs on Android).
class FinalSurgeOAuthService {
  FinalSurgeOAuthService({
    required FinalSurgeApiClient apiClient,
    required IntegrationsRepository repository,
    required String clientId,
    String callbackUrlScheme = 'com.milkman.mealvanaendurance',
  })  : _apiClient = apiClient,
        _repository = repository,
        _clientId = clientId,
        _callbackUrlScheme = callbackUrlScheme;

  final FinalSurgeApiClient _apiClient;
  final IntegrationsRepository _repository;
  final String _clientId;
  final String _callbackUrlScheme;

  /// Authenticate with Final Surge via OAuth
  ///
  /// Opens a browser window for user to log in to Final Surge,
  /// then exchanges the authorization code for an access token.
  ///
  /// Returns the created Integration record.
  Future<IntegrationModel> authenticate(String userId) async {
    // 1. Generate state for CSRF protection
    final state = _generateState();

    // 2. Build OAuth authorization URL
    // Use scheme://callback format (matching Training Peaks pattern)
    final redirectUri = '$_callbackUrlScheme://callback';
    final authUrl = Uri.https('log.finalsurge.com', '/oauth/authorize', {
      'client-id': _clientId,
      'redirect-uri': redirectUri,
      'state': state,
    });

    if (kDebugMode) {
      print('🔐 Starting Final Surge OAuth flow...');
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

    if (kDebugMode) {
      print('📥 Callback received:');
      print('   Raw callback: $result');
      print('   Parsed URI: $callbackUri');
      print('   Code param: $code');
      print('   Code length: ${code?.length ?? 0}');
    }

    // Validate state to prevent CSRF
    if (returnedState != state) {
      throw FinalSurgeOAuthException('State mismatch - possible CSRF attack');
    }

    if (code == null || code.isEmpty) {
      final error = callbackUri.queryParameters['error'];
      final errorDescription = callbackUri.queryParameters['error_description'];
      throw FinalSurgeOAuthException(
        errorDescription ?? error ?? 'No authorization code received',
      );
    }

    if (kDebugMode) {
      print('✅ Received authorization code');
    }

    // 5. Exchange code for access token
    // Final Surge requires redirect-uri to match the authorization request
    final tokenResponse = await _apiClient.exchangeCodeForToken(
      code,
      redirectUri: redirectUri,
    );

    if (kDebugMode) {
      print('✅ Token exchange successful');
      print('   Athlete: ${tokenResponse.fullName}');
      print('   Athlete ID: ${tokenResponse.athleteId}');
      print('   Access Token: ${tokenResponse.accessToken.substring(0, 8)}...');
    }

    // 6. Create and store integration
    if (kDebugMode) {
      print('📝 Creating integration model for user: $userId');
    }

    final integration = IntegrationModel(
      userId: userId,
      provider: 'final_surge',
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: tokenResponse.athleteId,
      providerAthleteName: tokenResponse.fullName,
      providerAthleteEmail: tokenResponse.email,
      isActive: true,
      lastSyncStatus: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (kDebugMode) {
      print('   Integration model created: provider=${integration.provider}, isActive=${integration.isActive}');
    }

    // 7. Save to database (upsert - replaces existing if present)
    if (kDebugMode) {
      print('💾 Saving integration to database...');
    }

    final savedIntegration = await _repository.upsertIntegration(integration);

    if (kDebugMode) {
      print('✅ Integration saved to database');
      print('   Saved ID: ${savedIntegration.providerAthleteId}');
      print('   Saved Name: ${savedIntegration.providerAthleteName}');
    }

    return savedIntegration;
  }

  /// Disconnect Final Surge integration
  ///
  /// Marks the integration as inactive but keeps the record for history.
  Future<void> disconnect(String userId) async {
    await _repository.deactivateIntegration(userId, 'final_surge');

    if (kDebugMode) {
      print('✅ Final Surge integration disconnected');
    }
  }

  /// Check if user has an active Final Surge integration
  Future<bool> isConnected(String userId) async {
    final integration = await _repository.getIntegration(userId, 'final_surge');
    return integration?.isActive ?? false;
  }

  /// Get the current Final Surge integration for a user
  Future<IntegrationModel?> getIntegration(String userId) async {
    return _repository.getIntegration(userId, 'final_surge');
  }

  /// Generate a random state string for CSRF protection
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Exception for Final Surge OAuth errors
class FinalSurgeOAuthException implements Exception {
  const FinalSurgeOAuthException(this.message);

  final String message;

  @override
  String toString() => 'FinalSurgeOAuthException: $message';
}
