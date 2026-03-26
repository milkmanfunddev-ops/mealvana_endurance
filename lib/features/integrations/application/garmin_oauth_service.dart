import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/integrations_repository.dart';
import '../domain/integration.dart';

/// Service for Garmin Connect OAuth 2.0 PKCE authentication flow
///
/// Garmin uses a push-only model — unlike TP/FS where we pull workouts,
/// Garmin pushes completed activity data to our edge functions when users
/// sync their devices. This service only handles OAuth connect/disconnect.
///
/// Uses flutter_web_auth_2 which opens a secure in-app browser
/// (ASWebAuthenticationSession on iOS, Custom Tabs on Android).
class GarminOAuthService {
  GarminOAuthService({
    required IntegrationsRepository repository,
    required SupabaseClient supabaseClient,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    String callbackUrlScheme = 'com.milkman.mealvanaendurance',
  })  : _repository = repository,
        _supabaseClient = supabaseClient,
        _clientId = clientId,
        _clientSecret = clientSecret,
        _redirectUri = redirectUri,
        _callbackUrlScheme = callbackUrlScheme;

  final IntegrationsRepository _repository;
  final SupabaseClient _supabaseClient;
  final String _clientId;
  final String _clientSecret;
  final String _redirectUri;
  final String _callbackUrlScheme;

  static const _authorizeUrl = 'https://connect.garmin.com/oauthConfirm';
  static const _tokenUrl =
      'https://connectapi.garmin.com/oauth-service/oauth/token';
  static const _userIdUrl =
      'https://apis.garmin.com/wellness-api/rest/user/id';

  /// Authenticate with Garmin Connect via OAuth 2.0 PKCE
  ///
  /// Opens a browser window for user to log in to Garmin Connect,
  /// exchanges the authorization code for tokens, fetches the
  /// Garmin user ID, and creates the garmin_user_mappings row.
  ///
  /// Returns the created Integration record.
  Future<IntegrationModel> authenticate(String userId) async {
    // 1. Generate PKCE code_verifier and code_challenge
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // 2. Generate state for CSRF protection
    final state = _generateState();

    // 3. Build OAuth authorization URL
    final authUrl = Uri.parse(_authorizeUrl).replace(
      queryParameters: {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': 'ACTIVITY_EXPORT HEALTH_EXPORT',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    if (kDebugMode) {
      print('🔐 Starting Garmin Connect OAuth flow...');
      print('   Auth URL: $authUrl');
      print('   Redirect URI: $_redirectUri');
    }

    // 4. Launch OAuth flow via flutter_web_auth_2
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,
      ),
    );

    // 5. Extract authorization code from callback URL
    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    if (kDebugMode) {
      print('📥 Garmin callback received:');
      print('   Raw callback: $result');
      print('   Code param: $code');
      print('   Code length: ${code?.length ?? 0}');
    }

    // Validate state to prevent CSRF
    if (returnedState != state) {
      throw GarminOAuthException('State mismatch - possible CSRF attack');
    }

    if (code == null || code.isEmpty) {
      final error = callbackUri.queryParameters['error'];
      final errorDescription =
          callbackUri.queryParameters['error_description'];
      throw GarminOAuthException(
        errorDescription ?? error ?? 'No authorization code received',
      );
    }

    if (kDebugMode) {
      print('✅ Received Garmin authorization code');
    }

    // 6. Exchange code for access token
    final tokenResponse = await _exchangeCodeForToken(code, codeVerifier);

    if (kDebugMode) {
      print('✅ Garmin token exchange successful');
    }

    // 7. Fetch Garmin user ID
    final garminUserId = await _fetchGarminUserId(tokenResponse.accessToken);

    if (kDebugMode) {
      print('✅ Garmin user ID fetched: $garminUserId');
    }

    // 8. Create and store integration
    final now = DateTime.now();
    final integration = IntegrationModel(
      userId: userId,
      provider: 'garmin',
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: garminUserId,
      providerAthleteName: 'Garmin Connect',
      isActive: true,
      lastSyncStatus: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    final savedIntegration = await _repository.upsertIntegration(integration);

    if (kDebugMode) {
      print('✅ Garmin integration saved to database');
    }

    // 9. CRITICAL: Upsert garmin_user_mappings so push handler can map
    //    incoming Garmin data to our user
    await _upsertGarminUserMapping(
      userId: userId,
      garminUserId: garminUserId,
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
    );

    if (kDebugMode) {
      print('✅ Garmin user mapping saved to Supabase');
    }

    return savedIntegration;
  }

  /// Disconnect Garmin Connect integration
  ///
  /// Marks the integration as inactive and deletes the garmin_user_mappings row.
  Future<void> disconnect(String userId) async {
    // Delete garmin_user_mappings row first
    try {
      await _supabaseClient
          .from('garmin_user_mappings')
          .delete()
          .eq('user_id', userId);

      if (kDebugMode) {
        print('✅ Garmin user mapping deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to delete Garmin user mapping: $e');
      }
    }

    await _repository.deactivateIntegration(userId, 'garmin');

    if (kDebugMode) {
      print('✅ Garmin Connect integration disconnected');
    }
  }

  /// Check if user has an active Garmin Connect integration
  Future<bool> isConnected(String userId) async {
    final integration = await _repository.getIntegration(userId, 'garmin');
    return integration?.isActive ?? false;
  }

  /// Get the current Garmin Connect integration for a user
  Future<IntegrationModel?> getIntegration(String userId) async {
    return _repository.getIntegration(userId, 'garmin');
  }

  /// Exchange authorization code for access and refresh tokens
  Future<_GarminTokenResponse> _exchangeCodeForToken(
    String code,
    String codeVerifier,
  ) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode != 200) {
      if (kDebugMode) {
        print('❌ Garmin token exchange failed: ${response.statusCode}');
        print('   Body: ${response.body}');
      }
      throw GarminOAuthException(
        'Token exchange failed: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String;
    final refreshToken = json['refresh_token'] as String?;
    final expiresIn = json['expires_in'] as int?;

    return _GarminTokenResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : null,
    );
  }

  /// Fetch the Garmin user ID using the access token
  Future<String> _fetchGarminUserId(String accessToken) async {
    final response = await http.get(
      Uri.parse(_userIdUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      if (kDebugMode) {
        print('❌ Garmin user ID fetch failed: ${response.statusCode}');
        print('   Body: ${response.body}');
      }
      throw GarminOAuthException(
        'Failed to fetch Garmin user ID: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final userId = json['userId'] as String?;

    if (userId == null || userId.isEmpty) {
      throw GarminOAuthException('Garmin user ID was empty in response');
    }

    return userId;
  }

  /// Upsert the garmin_user_mappings row in Supabase
  ///
  /// This is critical for the push handler to map incoming Garmin data
  /// to our internal user ID.
  Future<void> _upsertGarminUserMapping({
    required String userId,
    required String garminUserId,
    required String accessToken,
    String? refreshToken,
  }) async {
    await _supabaseClient.from('garmin_user_mappings').upsert(
      {
        'user_id': userId,
        'garmin_user_id': garminUserId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'garmin_user_id',
    );
  }

  /// Generate a PKCE code verifier (43-128 chars, URL-safe)
  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Generate a PKCE code challenge from the verifier (SHA-256, base64url)
  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Generate a random state string for CSRF protection
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Internal token response class
class _GarminTokenResponse {
  const _GarminTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
}

/// Exception for Garmin OAuth errors
class GarminOAuthException implements Exception {
  const GarminOAuthException(this.message);

  final String message;

  @override
  String toString() => 'GarminOAuthException: $message';
}
