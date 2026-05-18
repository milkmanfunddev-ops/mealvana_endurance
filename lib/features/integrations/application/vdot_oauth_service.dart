import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../data/integrations_repository.dart';
import '../data/vdot_api_client.dart';
import '../domain/integration.dart';

/// Service for V.O2 (VDOT) OAuth 2.0 authentication.
///
/// Uses flutter_web_auth_2 to open ASWebAuthenticationSession on iOS / Custom
/// Tabs on Android, redirects back to our custom URI scheme, and exchanges
/// the authorization code for an access + refresh token.
///
/// The VDOT authorize endpoint lives on `app.vdoto2.com` (or the sandbox
/// equivalent). The redirect URI MUST be pre-registered with VDOT before this
/// flow will succeed — coordinate with info@vdoto2.com.
class VdotOAuthService {
  VdotOAuthService({
    required VdotApiClient apiClient,
    required IntegrationsRepository repository,
    required String clientId,
    required String authBaseUrl,
    required String redirectUri,
    String callbackUrlScheme = 'com.milkman.mealvanaendurance',
    String scope = 'read:workouts',
  })  : _apiClient = apiClient,
        _repository = repository,
        _clientId = clientId,
        _authBaseUrl = authBaseUrl,
        _redirectUri = redirectUri,
        _callbackUrlScheme = callbackUrlScheme,
        _scope = scope;

  final VdotApiClient _apiClient;
  final IntegrationsRepository _repository;
  final String _clientId;
  final String _authBaseUrl;
  final String _redirectUri;
  final String _callbackUrlScheme;
  final String _scope;

  /// Run the full authorization-code flow and persist the resulting tokens.
  Future<IntegrationModel> authenticate(String userId) async {
    final state = _generateState();

    final authUrl = Uri.parse('$_authBaseUrl/oauth/authorize').replace(
      queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': _scope,
        'state': state,
      },
    );

    if (kDebugMode) {
      print('🔐 [vdot] Starting OAuth flow');
      print('   Auth URL: $authUrl');
      print('   Redirect URI: $_redirectUri');
    }

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      // preferEphemeral=false reuses the system browser's VDOT session, so a
      // disconnect → reconnect cycle doesn't force the user to log in again.
      options: const FlutterWebAuth2Options(preferEphemeral: false),
    );

    final callbackUri = Uri.parse(result);
    final returnedState = callbackUri.queryParameters['state'];
    final code = callbackUri.queryParameters['code'];

    if (kDebugMode) {
      print('📥 [vdot] Callback received');
      print('   Raw: $result');
      print('   Query params: ${callbackUri.queryParameters}');
      print('   Sent state:     $state');
      print('   Returned state: ${returnedState ?? "(omitted)"}');
    }

    // VDOT's OAuth docs don't mention `state` echo-back and their example
    // URL omits the param entirely (verified against their wiki). Only enforce
    // the CSRF check when VDOT actually returns a state value. If they ever
    // start echoing it, we'll validate it; if they don't, we proceed without.
    if (returnedState != null && returnedState != state) {
      throw VdotOAuthException('State mismatch - possible CSRF attack');
    }

    if (code == null || code.isEmpty) {
      final error = callbackUri.queryParameters['error'];
      final description = callbackUri.queryParameters['error_description'];
      throw VdotOAuthException(
        description ?? error ?? 'No authorization code received',
      );
    }

    final tokenResponse = await _apiClient.exchangeCodeForToken(
      code,
      redirectUri: _redirectUri,
    );

    // VDOT's token response doesn't include athlete identity. Use the
    // user's app user_id as the provider_athlete_id placeholder until the
    // API exposes a profile endpoint we can query.
    final integration = IntegrationModel(
      userId: userId,
      provider: 'vdot',
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: userId,
      isActive: true,
      lastSyncStatus: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return _repository.upsertIntegration(integration);
  }

  /// Soft-disconnect: marks the integration inactive and pushes the change
  /// to Supabase so it survives a Drift wipe.
  Future<void> disconnect(String userId) async {
    await _repository.deactivateIntegration(userId, 'vdot');
  }

  Future<bool> isConnected(String userId) async {
    final integration = await _repository.getIntegration(userId, 'vdot');
    return integration?.isActive ?? false;
  }

  Future<IntegrationModel?> getIntegration(String userId) {
    return _repository.getIntegration(userId, 'vdot');
  }

  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Exception for V.O2 OAuth errors.
class VdotOAuthException implements Exception {
  const VdotOAuthException(this.message);

  final String message;

  @override
  String toString() => 'VdotOAuthException: $message';
}
