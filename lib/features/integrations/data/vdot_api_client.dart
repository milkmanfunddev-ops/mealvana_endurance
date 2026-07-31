import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/http_retry_client.dart';
import '../domain/integration_exceptions.dart';

/// API client for the V.O2 (VDOT) REST API.
///
/// Handles:
/// - OAuth 2.0 authorization-code token exchange via HTTP Basic auth
/// - Refresh-token rotation
/// - Workout fetch by event id and by date range
///
/// Docs: https://github.com/VDOT-O2/V.O2-API/wiki
class VdotApiClient {
  VdotApiClient({
    required String clientId,
    required String clientSecret,
    required String authBaseUrl,
    required String apiBaseUrl,
    http.Client? httpClient,
    RetryConfig? retryConfig,
  }) : _clientId = clientId,
       _clientSecret = clientSecret,
       _authBaseUrl = authBaseUrl,
       _apiBaseUrl = apiBaseUrl,
       _httpClient = httpClient ?? http.Client(),
       _retryConfig = retryConfig ?? RetryConfig.defaultConfig;

  static const _provider = 'vdot';

  final String _clientId;
  final String _clientSecret;
  final String _authBaseUrl;
  final String _apiBaseUrl;
  final http.Client _httpClient;
  final RetryConfig _retryConfig;

  String get _basicAuthHeader =>
      'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}';

  /// Pull a human-readable reason out of an error response body.
  ///
  /// VDOT's token endpoint is a custom (.NET) service that returns
  /// `{"status":"NOK","error":"invalid_code", ...}` rather than RFC 6749's
  /// `{"error":"...","error_description":"..."}`. We fold whichever field is
  /// present into the thrown exception's message so the real reason is visible
  /// in release builds too — `VdotApiException.toString()` only appends the raw
  /// body in debug mode.
  static String _extractErrorReason(String body) {
    if (body.isEmpty) return 'empty response body';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const [
          'error_description',
          'error',
          'message',
          'status',
        ]) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Non-JSON body (e.g. an HTML error page) — fall through to raw text.
    }
    final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length > 200
        ? '${collapsed.substring(0, 200)}…'
        : collapsed;
  }

  /// Exchange an authorization code for an access + refresh token.
  ///
  /// [redirectUri] must match the value used in the authorize request.
  Future<VdotTokenResponse> exchangeCodeForToken(
    String code, {
    required String redirectUri,
  }) async {
    // VDOT's token endpoint validates the request body before it even looks at
    // the code: a missing/empty client_id or client_secret comes back as
    // `invalid_payload` (HTTP 400), NOT `invalid_code`. The most common way to
    // hit that is a build where the .env secret never loaded — `client_id`
    // silently falls back to its literal default ('mealvana') while
    // `client_secret` falls back to '' (see AppConfig.fromEnv). Fail loudly
    // here with an actionable message instead of letting the server return an
    // opaque `invalid_payload`.
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      throw VdotApiException(
        'VDOT credentials are not loaded (client_id '
        '${_clientId.isEmpty ? "empty" : "present"}, client_secret '
        '${_clientSecret.isEmpty ? "EMPTY" : "present"}). The token exchange '
        'would fail with `invalid_payload`. Check that VDOT_CLIENT_ID / '
        'VDOT_CLIENT_SECRET are set in the active .env file and do a clean '
        'rebuild — .env values are bundled as assets at build time, so a hot '
        'reload will not pick up a newly-added secret.',
      );
    }

    if (kDebugMode) {
      // Lengths only — never log the secret value itself.
      print(
        '🔑 [vdot] Token exchange creds: client_id="$_clientId" '
        '(len ${_clientId.length}), client_secret len ${_clientSecret.length}',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('$_authBaseUrl/oauth/token'),
      headers: {
        'Authorization': _basicAuthHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        // VDOT also accepts client_id/secret in the body, but Basic auth is
        // the documented happy path. Sent here defensively for tolerant servers.
        'client_id': _clientId,
        'client_secret': _clientSecret,
      },
    );

    if (kDebugMode) {
      print('🔄 [vdot] Token exchange status: ${response.statusCode}');
    }

    if (response.statusCode != 200) {
      final reason = _extractErrorReason(response.body);
      // `invalid_payload` from VDOT means a required body field (grant_type /
      // client_id / client_secret) was missing or empty, OR the body was sent
      // as JSON instead of x-www-form-urlencoded — it is NOT about the code
      // itself (that surfaces as `invalid_code`). Annotate so the cause is
      // obvious in logs/Sentry without re-deriving it each time.
      final hint = reason.contains('invalid_payload')
          ? ' (missing/empty client_id or client_secret, or wrong body '
                'content-type — see VdotApiClient)'
          : '';
      throw VdotApiException(
        'Token exchange failed: $reason$hint',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VdotTokenResponse.fromJson(json);
  }

  /// Refresh an access token using the stored refresh token.
  ///
  /// VDOT's documented refresh request includes BOTH the expired bearer
  /// (`token`) and the refresh token (`refresh_token`). We pass the expired
  /// bearer when available; it's non-standard but matches their wiki example.
  Future<VdotTokenResponse> refreshAccessToken(
    String refreshToken, {
    String? expiredAccessToken,
  }) async {
    // Same guard as exchangeCodeForToken: VDOT validates the body before it
    // looks at the token. A missing/empty client_id or client_secret comes
    // back as `invalid_payload` (HTTP 400) — the usual cause is a build where
    // the .env secret never loaded. Fail loudly here instead of letting the
    // refresh silently fail and force a needless re-auth.
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      throw VdotApiException(
        'VDOT credentials are not loaded (client_id '
        '${_clientId.isEmpty ? "empty" : "present"}, client_secret '
        '${_clientSecret.isEmpty ? "EMPTY" : "present"}). The token refresh '
        'would fail with `invalid_payload`. Check that VDOT_CLIENT_ID / '
        'VDOT_CLIENT_SECRET are set in the active .env file and do a clean '
        'rebuild — .env values are bundled as assets at build time.',
      );
    }
    try {
      // VDOT's custom .NET token endpoint IGNORES the Basic auth header and
      // reads the credentials from the form body (proven against the live
      // endpoint: a refresh with creds only in Basic auth returns
      // `invalid_payload`, while creds in the body are accepted). Mirror
      // exchangeCodeForToken and send them in the body — the Basic header is
      // kept defensively for tolerant servers.
      final body = <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
        'client_secret': _clientSecret,
      };
      if (expiredAccessToken != null && expiredAccessToken.isNotEmpty) {
        body['token'] = expiredAccessToken;
      }
      final response = await _httpClient.post(
        Uri.parse('$_authBaseUrl/oauth/token'),
        headers: {
          'Authorization': _basicAuthHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: body,
      );

      HttpRetryClient.handleRefreshResponse(response, provider: _provider);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return VdotTokenResponse.fromJson(json);
    } on SocketException catch (e) {
      throw NetworkException(
        'No internet connection: ${e.message}',
        provider: _provider,
      );
    } on TimeoutException catch (_) {
      throw NetworkException('Connection timed out', provider: _provider);
    }
  }

  /// Fetch a single workout by its event id.
  Future<Map<String, dynamic>> getWorkoutByEventId(
    String accessToken,
    String eventId,
  ) async {
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(
        Uri.parse('$_apiBaseUrl/v1/vdot-workouts/$eventId'),
        headers: _authedHeaders(accessToken),
      ),
      onResponse: (response) {
        _handleErrorResponse(response, 'Failed to fetch VDOT workout');
        return jsonDecode(response.body) as Map<String, dynamic>;
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Fetch all workouts within a date range. Range cannot exceed 60 days
  /// per VDOT's documented limit.
  Future<List<Map<String, dynamic>>> getWorkoutsByDateRange(
    String accessToken, {
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final from = _formatDate(fromDate);
    final to = _formatDate(toDate);
    final uri = Uri.parse('$_apiBaseUrl/v1/vdot-workouts/$from/$to');
    return HttpRetryClient.executeWithRetry(
      request: () => _httpClient.get(uri, headers: _authedHeaders(accessToken)),
      onResponse: (response) {
        if (kDebugMode && response.statusCode != 200) {
          // VDOT's 401/4xx body sometimes contains useful detail. Surface it
          // so we don't keep blaming "token expired" for unrelated failures.
          print('🔎 [vdot] GET $uri -> ${response.statusCode}');
          print('       headers: ${response.headers}');
          final body = response.body;
          print(
            '       body: ${body.length > 500 ? '${body.substring(0, 500)}…' : body}',
          );
        }
        _handleErrorResponse(response, 'Failed to fetch VDOT workouts');
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw VdotApiException(
            'Expected JSON array, got ${decoded.runtimeType}',
            statusCode: response.statusCode,
            body: response.body,
          );
        }
        return decoded.cast<Map<String, dynamic>>();
      },
      provider: _provider,
      config: _retryConfig,
    );
  }

  /// Upload a GPS file (FIT/TCX/GPX) and let VDOT match it to an event itself.
  ///
  /// Requires the `write:upload-gps` scope.
  ///
  /// NOTE: Mealvana does not currently produce GPS files of its own — this
  /// surface is here for completeness so callers (future features, edge
  /// functions, or scripts) can use it. There is no automatic trigger wired.
  Future<VdotGpsUploadResponse> uploadGps(
    String accessToken, {
    required List<int> fileBytes,
    required String fileName,
    required String uploadId,
    String? sourceId,
    String? sourceName,
  }) async {
    return _uploadGpsInternal(
      accessToken: accessToken,
      uri: Uri.parse('$_apiBaseUrl/v1/vdot-workouts/upload-gps'),
      fileBytes: fileBytes,
      fileName: fileName,
      uploadId: uploadId,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  /// Upload a GPS file (FIT/TCX/GPX) and attach it to a specific event.
  ///
  /// Requires the `write:upload-gps` scope.
  Future<VdotGpsUploadResponse> uploadGpsForEvent(
    String accessToken, {
    required String eventId,
    required List<int> fileBytes,
    required String fileName,
    required String uploadId,
    String? sourceId,
    String? sourceName,
  }) async {
    return _uploadGpsInternal(
      accessToken: accessToken,
      uri: Uri.parse('$_apiBaseUrl/v1/vdot-workouts/upload-gps/$eventId'),
      fileBytes: fileBytes,
      fileName: fileName,
      uploadId: uploadId,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  Future<VdotGpsUploadResponse> _uploadGpsInternal({
    required String accessToken,
    required Uri uri,
    required List<int> fileBytes,
    required String fileName,
    required String uploadId,
    String? sourceId,
    String? sourceName,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Accept'] = 'application/json'
      ..fields['uploadId'] = uploadId
      ..files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    if (sourceId != null) request.fields['sourceId'] = sourceId;
    if (sourceName != null) request.fields['sourceName'] = sourceName;

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    _handleErrorResponse(response, 'Failed to upload VDOT GPS');
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw VdotApiException(
        'Unexpected upload response shape (${json.runtimeType})',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return VdotGpsUploadResponse.fromJson(json);
  }

  Map<String, String> _authedHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };

  void _handleErrorResponse(http.Response response, String context) {
    final error = HttpRetryClient.mapStatusToException(
      response,
      provider: _provider,
      context: context,
    );
    if (error != null) throw error;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Response from the VDOT OAuth token endpoint.
class VdotTokenResponse {
  const VdotTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.tokenType,
  });

  factory VdotTokenResponse.fromJson(Map<String, dynamic> json) {
    // VDOT's wiki documents snake_case (access_token / expires_in / etc.),
    // but the live API returns camelCase (accessToken / expiresIn / etc.).
    // Accept both so we're tolerant if VDOT ever fixes their docs.
    final accessToken =
        (json['accessToken'] ?? json['access_token']) as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw VdotApiException(
        'No access token in VDOT response. Keys: ${json.keys.toList()}',
        body: json.toString(),
      );
    }
    return VdotTokenResponse(
      accessToken: accessToken,
      refreshToken: (json['refreshToken'] ?? json['refresh_token']) as String?,
      expiresIn: ((json['expiresIn'] ?? json['expires_in']) as num?)?.toInt(),
      tokenType: (json['tokenType'] ?? json['token_type']) as String?,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? tokenType;

  DateTime? get expiresAt {
    if (expiresIn == null) return null;
    return DateTime.now().add(Duration(seconds: expiresIn!));
  }
}

/// Result of a POST to either of the `/upload-gps` endpoints.
class VdotGpsUploadResponse {
  const VdotGpsUploadResponse({required this.success, required this.message});

  factory VdotGpsUploadResponse.fromJson(Map<String, dynamic> json) {
    return VdotGpsUploadResponse(
      success: (json['Success'] ?? json['success']) as bool? ?? false,
      message: (json['Message'] ?? json['message']) as String? ?? '',
    );
  }

  final bool success;
  final String message;
}

/// Exception for V.O2 API errors. Inherits from the shared base so the
/// retry/refresh machinery can treat it uniformly with the other integrations.
class VdotApiException extends IntegrationApiException {
  const VdotApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.isRetryable,
  }) : super(provider: 'vdot');

  @override
  String toString() {
    final buffer = StringBuffer('VdotApiException: $message');
    if (statusCode != null) buffer.write(' (status: $statusCode)');
    if (body != null && kDebugMode) buffer.write('\nBody: $body');
    return buffer.toString();
  }
}
