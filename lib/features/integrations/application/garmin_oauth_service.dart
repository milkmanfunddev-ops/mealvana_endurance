import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/report/report.dart';
import '../data/integrations_repository.dart';
import '../domain/integration.dart';
import '../domain/provider_error_summary.dart';

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
    Report? report,
  }) : _repository = repository,
       _supabaseClient = supabaseClient,
       _clientId = clientId,
       _clientSecret = clientSecret,
       _redirectUri = redirectUri,
       _callbackUrlScheme = callbackUrlScheme,
       _report = report;

  final IntegrationsRepository _repository;
  final SupabaseClient _supabaseClient;
  final String _clientId;
  final String _clientSecret;
  final String _redirectUri;
  final String _callbackUrlScheme;
  final Report? _report;

  Report get _r => _report ?? SentryReport.global;

  static const _area = 'garmin';

  static const _authorizeUrl = 'https://connect.garmin.com/oauth2Confirm';
  static const _tokenUrl =
      'https://diauth.garmin.com/di-oauth2-service/oauth/token';
  static const _userIdUrl = 'https://apis.garmin.com/wellness-api/rest/user/id';

  /// Authenticate with Garmin Connect via OAuth 2.0 PKCE
  ///
  /// Opens a browser window for user to log in to Garmin Connect,
  /// exchanges the authorization code for tokens, fetches the
  /// Garmin user ID, and saves the integration locally.
  ///
  /// If [skipRemoteMapping] is true, the `garmin_user_mappings` upsert
  /// to Supabase is skipped (e.g. during onboarding when the user profile
  /// doesn't exist in Supabase yet). Call [upsertUserMapping] after the
  /// profile is created.
  ///
  /// Returns the created Integration record.
  Future<IntegrationModel> authenticate(
    String userId, {
    bool skipRemoteMapping = false,
  }) async {
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

    _r.debug('Garmin Connect OAuth flow started', area: _area);

    // 4. Launch OAuth flow via flutter_web_auth_2
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackUrlScheme,
      options: const FlutterWebAuth2Options(preferEphemeral: true),
    );

    // 5. Extract authorization code from callback URL
    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    // The raw callback carries the authorization code; never log it.
    _r.debug(
      'Garmin OAuth callback received',
      area: _area,
      data: {'hasCode': code != null && code.isNotEmpty},
    );

    // Validate state to prevent CSRF
    if (returnedState != state) {
      throw GarminOAuthException('State mismatch - possible CSRF attack');
    }

    if (code == null || code.isEmpty) {
      final error = callbackUri.queryParameters['error'];
      final errorDescription = callbackUri.queryParameters['error_description'];
      throw GarminOAuthException(
        errorDescription ?? error ?? 'No authorization code received',
      );
    }

    // 6. Exchange code for access token
    final tokenResponse = await _exchangeCodeForToken(code, codeVerifier);
    _r.debug('Garmin token exchange succeeded', area: _area);

    // 7. Fetch Garmin user ID
    final garminUserId = await _fetchGarminUserId(tokenResponse.accessToken);
    _r.debug('Garmin user id fetched', area: _area);

    // 7b. Fetch latest body composition (best-effort, non-blocking)
    final bodyComp = await _fetchLatestBodyComposition(
      tokenResponse.accessToken,
    );
    _r.debug(
      'Garmin body composition read',
      area: _area,
      data: {
        'hasWeight': bodyComp?.weightKg != null,
        'hasBodyFat': bodyComp?.bodyFatPct != null,
      },
    );

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
      providerAthleteWeightKg: bodyComp?.weightKg,
      providerAthleteBodyFatPct: bodyComp?.bodyFatPct,
      isActive: true,
      lastSyncStatus: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    final savedIntegration = await _repository.upsertIntegration(integration);
    _r.debug('Garmin integration saved', area: _area);

    // 9. Upsert garmin_user_mappings so push handler can map
    //    incoming Garmin data to our user.
    //    Skipped during onboarding — called later via upsertUserMapping()
    //    after the user profile exists in Supabase.
    if (!skipRemoteMapping) {
      await _upsertGarminUserMapping(
        userId: userId,
        garminUserId: garminUserId,
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
      );
      _r.debug('Garmin user mapping saved to Supabase', area: _area);
    } else {
      // Deferred to upsertUserMapping() once the profile row exists.
      await _r.note(
        'Garmin user mapping upsert skipped (onboarding mode)',
        area: _area,
      );
    }

    return savedIntegration;
  }

  /// Disconnect Garmin Connect integration
  ///
  /// Marks the integration as inactive and deletes the garmin_user_mappings row.
  Future<void> disconnect(String userId) async {
    final integration = await _repository.getIntegration(userId, 'garmin');

    // Delete garmin_user_mappings row first.
    try {
      await _invokeGarminUserMapping(
        action: 'delete',
        userId: userId,
        garminUserId: integration?.providerAthleteId,
      );
      _r.debug('Garmin user mapping deleted', area: _area);
    } catch (e, st) {
      // The local row is deactivated regardless, but an orphaned server
      // mapping keeps routing this athlete's pushes: worth an event.
      await _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'Garmin user mapping delete failed; local disconnect continues',
      );
    }

    await _repository.deactivateIntegration(userId, 'garmin');
    _r.debug('Garmin Connect integration disconnected', area: _area);
  }

  /// Upsert the garmin_user_mappings row in Supabase for an existing integration.
  ///
  /// Called after onboarding completes and the user profile exists in Supabase.
  /// Reads the integration from the local DB to get the Garmin credentials.
  Future<void> upsertUserMapping(String userId) async {
    final integration = await _repository.getIntegration(userId, 'garmin');
    if (integration == null || !integration.isActive) {
      await _r.note(
        'no active Garmin integration; user mapping sync skipped',
        area: _area,
      );
      return;
    }

    await _upsertGarminUserMapping(
      userId: userId,
      garminUserId: integration.providerAthleteId,
      accessToken: integration.accessToken,
      refreshToken: integration.refreshToken,
    );
    _r.debug('Garmin user mapping upserted (post-onboarding)', area: _area);
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

  /// The exception a refused code exchange throws: status and error code
  /// only, never the body (ticket 84, Finding 69-012: Garmin's
  /// `error_description` carried the refresh token).
  @visibleForTesting
  static GarminOAuthException tokenExchangeFailure(http.Response response) {
    final s = providerErrorSummary(response.statusCode, response.body);
    final code = s.errorCode != null ? ' ${s.errorCode}' : '';
    return GarminOAuthException('Token exchange failed: ${s.status}$code');
  }

  /// Exchange authorization code for access and refresh tokens
  Future<_GarminTokenResponse> _exchangeCodeForToken(
    String code,
    String codeVerifier,
  ) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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
      throw tokenExchangeFailure(response);
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
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
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

  static const _bodyCompUrl =
      'https://apis.garmin.com/wellness-api/rest/bodyComposition';

  /// Fetch the most recent body composition data using the access token.
  ///
  /// Queries the last 30 days of body comp data and returns the most recent
  /// entry. Returns null if no data is available (user may not have a Garmin
  /// scale or may not have entered weight manually in Garmin Connect).
  Future<_GarminBodyCompData?> _fetchLatestBodyComposition(
    String accessToken,
  ) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final url = Uri.parse(_bodyCompUrl).replace(
        queryParameters: {
          'uploadStartTimeInSeconds':
              (thirtyDaysAgo.millisecondsSinceEpoch ~/ 1000).toString(),
          'uploadEndTimeInSeconds': (now.millisecondsSinceEpoch ~/ 1000)
              .toString(),
        },
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        await _r.note(
          'Garmin body comp fetch returned non-200; skipped',
          area: _area,
          data: {'statusCode': response.statusCode},
        );
        return null;
      }

      final List<dynamic> items = jsonDecode(response.body) as List<dynamic>;
      if (items.isEmpty) return null;

      // Take the most recent entry (last in the list)
      final latest = items.last as Map<String, dynamic>;

      final weightGrams = latest['weightInGrams'] as int?;
      final percentFat = (latest['percentFat'] as num?)?.toDouble();

      return _GarminBodyCompData(
        weightKg: weightGrams != null ? weightGrams / 1000.0 : null,
        bodyFatPct: percentFat,
      );
    } catch (e, st) {
      // Body comp is optional: the athlete keeps a profile without it.
      await _r.degraded(
        e,
        stackTrace: st,
        area: _area,
        message: 'Garmin body comp fetch failed; continuing without it',
      );
      return null;
    }
  }

  /// Re-fetch body composition data from Garmin and update the integration.
  ///
  /// Called from settings when user wants to refresh their profile data.
  /// Returns the updated integration, or null if not connected.
  Future<IntegrationModel?> refreshBodyComposition(String userId) async {
    final integration = await _repository.getIntegration(userId, 'garmin');
    if (integration == null || !integration.isActive) return null;

    final bodyComp = await _fetchLatestBodyComposition(integration.accessToken);
    if (bodyComp == null) return integration; // No new data

    final updated = integration.copyWith(
      providerAthleteWeightKg:
          bodyComp.weightKg ?? integration.providerAthleteWeightKg,
      providerAthleteBodyFatPct:
          bodyComp.bodyFatPct ?? integration.providerAthleteBodyFatPct,
      updatedAt: DateTime.now(),
    );

    return _repository.upsertIntegration(updated);
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
    await _invokeGarminUserMapping(
      action: 'upsert',
      userId: userId,
      garminUserId: garminUserId,
      garminAccessToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  Future<void> _invokeGarminUserMapping({
    required String action,
    required String userId,
    String? garminUserId,
    String? garminAccessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final supabaseAccessToken = session?.accessToken;
    if (supabaseAccessToken == null || supabaseAccessToken.isEmpty) {
      throw const GarminOAuthException(
        'No active Supabase session for Garmin mapping request',
      );
    }

    final response = await _supabaseClient.functions.invoke(
      'garmin-user-mapping',
      headers: {'Authorization': 'Bearer $supabaseAccessToken'},
      body: {
        'action': action,
        'user_id': userId,
        if (garminUserId != null) 'garmin_user_id': garminUserId,
        if (garminAccessToken != null) 'access_token': garminAccessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        if (tokenExpiresAt != null)
          'token_expires_at': tokenExpiresAt.toUtc().toIso8601String(),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw GarminOAuthException(
        'Garmin mapping $action failed: ${response.status} ${response.data}',
      );
    }

    final data = response.data;
    if (data is Map && data['success'] != true) {
      throw GarminOAuthException(
        'Garmin mapping $action failed: ${data['error'] ?? data}',
      );
    }

    if (action == 'delete' && data is Map && data['remaining'] != 0) {
      throw GarminOAuthException(
        'Garmin mapping delete incomplete: ${data['remaining']} row(s) remain',
      );
    }
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

/// Internal body composition data from Garmin API
class _GarminBodyCompData {
  const _GarminBodyCompData({this.weightKg, this.bodyFatPct});
  final double? weightKg;
  final double? bodyFatPct;
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
