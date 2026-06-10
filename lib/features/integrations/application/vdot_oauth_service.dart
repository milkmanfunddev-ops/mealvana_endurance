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

    // VDOT is a custom (.NET) OAuth server and its authorization codes can
    // contain a literal '+' in the redirect URL. `Uri.queryParameters` decodes
    // with x-www-form-urlencoded rules, which turns '+' into a space and
    // silently corrupts the code — VDOT then rejects the token exchange with
    // `invalid_code` (HTTP 400). Parse the raw query ourselves so the code
    // reaches the token endpoint byte-for-byte intact.
    final params = _parseCallbackParams(result);
    final returnedState = params['state'];
    final code = params['code'];

    if (kDebugMode) {
      print('📥 [vdot] Callback received');
      print('   Raw: $result');
      print('   Parsed params: $params');
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
      final error = params['error'];
      final description = params['error_description'];
      throw VdotOAuthException(
        description ?? error ?? 'No authorization code received',
      );
    }

    final tokenResponse = await _apiClient.exchangeCodeForToken(
      code,
      redirectUri: _redirectUri,
    );

    // VDOT's token response and API don't expose a human athlete name — the
    // access-token JWT only carries a numeric VDOT user id, and there's no
    // profile endpoint. So mirror the Garmin integration (which also lacks a
    // real name) and store a static 'V.O2' label rather than leaving the
    // connected-app card's subtitle blank/null. (Safe re: onboarding name
    // prefill — that only reads Training Peaks / Final Surge integrations.)
    // The user's app user_id stands in as the provider_athlete_id placeholder.
    final integration = IntegrationModel(
      userId: userId,
      provider: 'vdot',
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: userId,
      providerAthleteName: 'V.O2',
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

  /// Parse the OAuth callback's query parameters from the raw redirect URL.
  ///
  /// Unlike `Uri.queryParameters`, this does NOT apply the
  /// `application/x-www-form-urlencoded` rule that decodes '+' as a space.
  /// VDOT places literal '+' characters inside its (base64-style)
  /// authorization codes, and the standard getter would corrupt them. Each
  /// component is decoded with `Uri.decodeComponent`, which resolves %XX
  /// escapes but leaves '+' untouched. OAuth codes never contain real spaces,
  /// so preserving '+' is strictly safer.
  static Map<String, String> _parseCallbackParams(String redirectUrl) {
    final params = <String, String>{};
    final queryStart = redirectUrl.indexOf('?');
    if (queryStart == -1) return params;
    var query = redirectUrl.substring(queryStart + 1);
    final fragmentStart = query.indexOf('#');
    if (fragmentStart != -1) query = query.substring(0, fragmentStart);
    for (final pair in query.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final rawKey = eq == -1 ? pair : pair.substring(0, eq);
      final rawValue = eq == -1 ? '' : pair.substring(eq + 1);
      try {
        params[Uri.decodeComponent(rawKey)] = Uri.decodeComponent(rawValue);
      } catch (_) {
        // Malformed percent-encoding — keep the raw text rather than throwing.
        params[rawKey] = rawValue;
      }
    }
    return params;
  }
}

/// Exception for V.O2 OAuth errors.
class VdotOAuthException implements Exception {
  const VdotOAuthException(this.message);

  final String message;

  @override
  String toString() => 'VdotOAuthException: $message';
}
