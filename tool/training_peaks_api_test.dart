/// TrainingPeaks API Test Script
///
/// This script tests the TrainingPeaks Partner API endpoints.
/// Run with: dart run tool/training_peaks_api_test.dart
///
/// Prerequisites:
/// 1. TrainingPeaks account (sandbox or production)
/// 2. Valid client credentials (client_id and client_secret)
///
/// CRITICAL: TrainingPeaks tokens expire in 1 HOUR!
/// Token refresh is tested as part of this script.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// ============================================================================
// CONFIGURATION
// ============================================================================

// Environment toggle - set to false for production
const bool useSandbox = true;

// OAuth endpoints
const String sandboxOAuthUrl = 'https://oauth.sandbox.trainingpeaks.com';
const String productionOAuthUrl = 'https://oauth.trainingpeaks.com';

// API endpoints
const String sandboxApiUrl = 'https://api.sandbox.trainingpeaks.com';
const String productionApiUrl = 'https://api.trainingpeaks.com';

// Current environment URLs
String get oauthBaseUrl => useSandbox ? sandboxOAuthUrl : productionOAuthUrl;
String get apiBaseUrl => useSandbox ? sandboxApiUrl : productionApiUrl;

// Your TrainingPeaks Partner API credentials
// Loaded from environment variables (set in .env.dev.local)
const String clientId = String.fromEnvironment(
  'TRAININGPEAKS_CLIENT_ID',
  defaultValue: 'mealvana',
);
const String clientSecret = String.fromEnvironment(
  'TRAININGPEAKS_CLIENT_SECRET',
  defaultValue: '',
);

// Redirect URI for OAuth
const String redirectUri = 'http://127.0.0.1:8889/callback';

// File to cache token data between runs
const String tokenCacheFile = 'tool/.training_peaks_token.json';

// OAuth scopes we need
const List<String> requestedScopes = [
  'athlete:profile',
  'events:read',
  'workouts:read',
  'nutrition:write',
  'nutrition:read',
];

// ============================================================================
// MAIN
// ============================================================================

Future<void> main(List<String> args) async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           TrainingPeaks API Test Script                          ║');
  print('║           Mealvana Endurance Integration                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('   Environment: ${useSandbox ? "SANDBOX" : "PRODUCTION"}');
  print('   OAuth URL: $oauthBaseUrl');
  print('   API URL: $apiBaseUrl');
  print('');

  if (clientSecret.isEmpty) {
    print('⚠️  Warning: TRAINING_PEAKS_CLIENT_SECRET not set');
    print('   Run with: dart run --define=TRAINING_PEAKS_CLIENT_SECRET=your_secret tool/training_peaks_api_test.dart');
    print('');
  }

  // Parse command line arguments
  final command = args.isNotEmpty ? args[0] : 'help';

  switch (command) {
    case 'auth':
      await runOAuthFlow();
      break;
    case 'refresh':
      await testTokenRefresh();
      break;
    case 'test':
      final token = await _getValidAccessToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await testApiEndpoints(token);
      break;
    case 'profile':
      final token = await _getValidAccessToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await fetchAthleteProfile(token);
      break;
    case 'workouts':
      final token = await _getValidAccessToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await fetchWorkouts(token);
      break;
    case 'events':
      final token = await _getValidAccessToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await fetchNextEvent(token);
      break;
    case 'athlete':
      await showCachedAthleteInfo();
      break;
    case 'help':
    default:
      printHelp();
  }
}

void printHelp() {
  print('Usage: dart run tool/training_peaks_api_test.dart <command> [options]');
  print('');
  print('Commands:');
  print('  auth      Start OAuth flow to get access token');
  print('  refresh   Test token refresh flow (CRITICAL for TrainingPeaks!)');
  print('  test      Run all API tests (auto-refreshes token if needed)');
  print('  profile   Fetch athlete profile');
  print('  workouts  Fetch upcoming workouts (14 days)');
  print('  events    Fetch next event/race');
  print('  athlete   Show cached athlete info');
  print('  help      Show this help message');
  print('');
  print('Examples:');
  print('  dart run tool/training_peaks_api_test.dart auth');
  print('  dart run tool/training_peaks_api_test.dart test');
  print('  dart run tool/training_peaks_api_test.dart events');
  print('');
  print('Environment Variable:');
  print('  TRAINING_PEAKS_CLIENT_SECRET - Your TrainingPeaks client secret');
  print('');
  print('Notes:');
  print('  - TrainingPeaks tokens expire in 1 HOUR (vs Final Surge never expires)');
  print('  - Token refresh is automatically tested and performed');
  print('  - Sandbox database refreshes every Saturday 6PM MST');
}

// ============================================================================
// TOKEN CACHE & REFRESH
// ============================================================================

Future<void> _saveTokenData(Map<String, dynamic> data) async {
  final file = File(tokenCacheFile);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
}

Future<Map<String, dynamic>?> _loadCachedTokenData() async {
  try {
    final file = File(tokenCacheFile);
    if (await file.exists()) {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }
  } catch (e) {
    // Ignore cache errors
  }
  return null;
}

/// Get a valid access token, refreshing if needed
Future<String?> _getValidAccessToken() async {
  final data = await _loadCachedTokenData();
  if (data == null) return null;

  final accessToken = data['access_token'] as String?;
  final expiresAt = data['expires_at'] as int?;
  final refreshToken = data['refresh_token'] as String?;

  if (accessToken == null) return null;

  // Check if token is expired or will expire in next 5 minutes
  if (expiresAt != null) {
    final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    final now = DateTime.now();
    final fiveMinutesFromNow = now.add(const Duration(minutes: 5));

    if (expiresAtTime.isBefore(fiveMinutesFromNow)) {
      print('⚠️  Token expired or expiring soon. Refreshing...');
      print('   Expires at: $expiresAtTime');
      print('   Current time: $now');
      print('');

      if (refreshToken != null) {
        final newToken = await _refreshAccessToken(refreshToken);
        if (newToken != null) {
          return newToken;
        }
      }

      print('❌ Token refresh failed. Please re-authenticate.');
      return null;
    }

    // Show time remaining
    final remaining = expiresAtTime.difference(now);
    print('✓ Token valid for ${remaining.inMinutes} minutes');
  }

  return accessToken;
}

Future<String?> _refreshAccessToken(String refreshToken) async {
  print('🔄 Refreshing access token...');

  try {
    final response = await http.post(
      Uri.parse('$oauthBaseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    print('   Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;

      // Calculate expiration time
      final expiresIn = tokenData['expires_in'] as int? ?? 600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // Merge with existing data and update
      final existingData = await _loadCachedTokenData() ?? {};
      existingData['access_token'] = tokenData['access_token'];
      existingData['refresh_token'] = tokenData['refresh_token'] ?? refreshToken;
      existingData['expires_in'] = expiresIn;
      existingData['expires_at'] = expiresAt.millisecondsSinceEpoch;
      existingData['refreshed_at'] = DateTime.now().toIso8601String();

      await _saveTokenData(existingData);

      print('✅ Token refreshed successfully!');
      print('   New expiration: $expiresAt');
      print('');

      return tokenData['access_token'] as String?;
    } else {
      print('❌ Token refresh failed');
      print('   Body: ${response.body}');
      return null;
    }
  } catch (e) {
    print('❌ Error during token refresh: $e');
    return null;
  }
}

Future<void> testTokenRefresh() async {
  print('🧪 Testing Token Refresh Flow');
  print('');

  final data = await _loadCachedTokenData();
  if (data == null) {
    print('❌ No cached token. Run "auth" first.');
    return;
  }

  final refreshToken = data['refresh_token'] as String?;
  if (refreshToken == null) {
    print('❌ No refresh token found. Re-authenticate.');
    return;
  }

  print('Current token info:');
  print('   Access Token: ${_truncateToken(data['access_token'] as String?)}');
  print('   Refresh Token: ${_truncateToken(refreshToken)}');

  final expiresAt = data['expires_at'] as int?;
  if (expiresAt != null) {
    final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    print('   Expires At: $expiresAtTime');
  }
  print('');

  // Force refresh
  final newToken = await _refreshAccessToken(refreshToken);

  if (newToken != null) {
    print('✅ Token refresh test PASSED');

    // Verify the new token works
    print('');
    print('🔍 Verifying new token works...');
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/v1/athlete/profile'),
        headers: {
          'Authorization': 'Bearer $newToken',
          'User-Agent': 'Mealvana Endurance Test v1.0',
        },
      );

      if (response.statusCode == 200) {
        print('✅ New token verified - API call successful');
      } else {
        print('⚠️  API call returned ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️  Error verifying token: $e');
    }
  } else {
    print('❌ Token refresh test FAILED');
  }
}

Future<void> showCachedAthleteInfo() async {
  final data = await _loadCachedTokenData();

  if (data == null) {
    print('❌ No cached athlete info. Run "auth" first.');
    return;
  }

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║ ATHLETE INFO (from OAuth & profile fetch)                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('   Athlete ID:  ${data['athlete_id'] ?? 'N/A'}');
  print('   First Name:  ${data['first_name'] ?? 'N/A'}');
  print('   Last Name:   ${data['last_name'] ?? 'N/A'}');
  print('   Email:       ${data['email'] ?? 'N/A'}');
  print('   Premium:     ${data['is_premium'] ?? 'N/A'}');
  print('   Weight (kg): ${data['weight_kg'] ?? 'N/A'}');
  print('');
  print('   Token:       ${_truncateToken(data['access_token'] as String?)}');
  print('   Cached At:   ${data['cached_at'] ?? 'N/A'}');

  final expiresAt = data['expires_at'] as int?;
  if (expiresAt != null) {
    final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    final now = DateTime.now();
    final remaining = expiresAtTime.difference(now);

    if (remaining.isNegative) {
      print('   Status:      ❌ EXPIRED ${remaining.inMinutes.abs()} min ago');
    } else {
      print('   Status:      ✅ Valid for ${remaining.inMinutes} min');
    }
  }
  print('');
}

String _truncateToken(String? token) {
  if (token == null) return 'N/A';
  if (token.length <= 20) return token;
  return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
}

// ============================================================================
// OAUTH FLOW
// ============================================================================

Future<void> runOAuthFlow() async {
  print('🔐 Starting OAuth Authorization Flow...');
  print('');

  if (clientSecret.isEmpty) {
    print('❌ Error: TRAINING_PEAKS_CLIENT_SECRET not set');
    print('   Run with: dart run --define=TRAINING_PEAKS_CLIENT_SECRET=your_secret tool/training_peaks_api_test.dart auth');
    exit(1);
  }

  // Step 1: Generate authorization URL
  final scopeString = requestedScopes.join(' ');
  final authUrl = Uri.parse('$oauthBaseUrl/OAuth/Authorize').replace(
    queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'scope': scopeString,
      'redirect_uri': redirectUri,
    },
  );

  print('📋 Step 1: Open this URL in your browser:');
  print('');
  print('   $authUrl');
  print('');

  // Step 2: Start local server to catch the redirect
  print('📡 Step 2: Starting local server to catch redirect...');
  print('');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8889);
  print('   Listening on http://127.0.0.1:8889');
  print('   Waiting for authorization callback...');
  print('');

  String? authCode;
  String? error;

  await for (final request in server) {
    final uri = request.uri;

    if (uri.path == '/callback') {
      authCode = uri.queryParameters['code'];
      error = uri.queryParameters['error'];

      // Send response to browser
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
          <!DOCTYPE html>
          <html>
          <head><title>Mealvana - TrainingPeaks Authorization</title></head>
          <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; text-align: center; padding: 50px;">
            ${error != null ? '<h1>❌ Authorization Failed</h1><p>Error: $error</p>' : '<h1>✅ Authorization Successful!</h1><p>You can close this window and return to the terminal.</p>'}
          </body>
          </html>
        ''');
      await request.response.close();
      break;
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
    }
  }

  await server.close();

  if (error != null) {
    print('❌ Authorization failed: $error');
    exit(1);
  }

  if (authCode == null) {
    print('❌ No authorization code received');
    exit(1);
  }

  print('✅ Received authorization code: ${authCode.substring(0, 20)}...');
  print('');

  // Step 3: Exchange code for access token
  print('🔄 Step 3: Exchanging code for access token...');
  print('');

  try {
    final tokenResponse = await http.post(
      Uri.parse('$oauthBaseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': authCode,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    print('   Response Status: ${tokenResponse.statusCode}');
    print('');

    if (tokenResponse.statusCode == 200) {
      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;

      // Calculate expiration time
      final expiresIn = tokenData['expires_in'] as int? ?? 600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // Prepare cache data
      final cacheData = {
        'access_token': tokenData['access_token'],
        'refresh_token': tokenData['refresh_token'],
        'token_type': tokenData['token_type'],
        'expires_in': expiresIn,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'scope': tokenData['scope'],
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _saveTokenData(cacheData);

      print('✅ Access Token Received & Cached!');
      print('');
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ TOKEN RESPONSE                                                    ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      print('   Token Type:     ${tokenData['token_type']}');
      print('   Expires In:     $expiresIn seconds (${expiresIn ~/ 60} minutes)');
      print('   Expires At:     $expiresAt');
      print('   Scopes:         ${tokenData['scope']}');
      print('');

      // Immediately fetch athlete profile to get more info
      final accessToken = tokenData['access_token'] as String?;
      if (accessToken != null) {
        print('📥 Fetching athlete profile...');
        await _fetchAndCacheAthleteProfile(accessToken, cacheData);

        print('');
        print('📋 Token cached! You can now run tests:');
        print('');
        print('   dart run tool/training_peaks_api_test.dart test');
        print('   dart run tool/training_peaks_api_test.dart profile');
        print('   dart run tool/training_peaks_api_test.dart workouts');
        print('   dart run tool/training_peaks_api_test.dart events');
        print('   dart run tool/training_peaks_api_test.dart refresh');
        print('');
        print('⚠️  REMEMBER: Token expires in 1 hour! Use "refresh" command to test refresh flow.');
        print('');
      }
    } else {
      print('❌ Token exchange failed!');
      print('   Status: ${tokenResponse.statusCode}');
      print('   Body: ${tokenResponse.body}');
    }
  } catch (e) {
    print('❌ Error during token exchange: $e');
    exit(1);
  }
}

Future<void> _fetchAndCacheAthleteProfile(
  String accessToken,
  Map<String, dynamic> cacheData,
) async {
  try {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/v1/athlete/profile'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana Endurance Test v1.0',
      },
    );

    if (response.statusCode == 200) {
      final profile = jsonDecode(response.body) as Map<String, dynamic>;

      // Add profile data to cache
      cacheData['athlete_id'] = profile['Id'];
      cacheData['first_name'] = profile['FirstName'];
      cacheData['last_name'] = profile['LastName'];
      cacheData['email'] = profile['Email'];
      cacheData['is_premium'] = profile['IsPremium'];
      cacheData['weight_kg'] = profile['Weight'];
      cacheData['preferred_units'] = profile['PreferredUnits'];
      cacheData['timezone'] = profile['TimeZone'];

      await _saveTokenData(cacheData);

      print('✅ Athlete profile cached');
      print('   Name: ${profile['FirstName']} ${profile['LastName']}');
      print('   Premium: ${profile['IsPremium']}');
    }
  } catch (e) {
    print('⚠️  Could not fetch athlete profile: $e');
  }
}

// ============================================================================
// API TESTS
// ============================================================================

Future<void> testApiEndpoints(String accessToken) async {
  print('🧪 Running API Tests...');
  print('');

  // Show cached athlete info first
  final cachedData = await _loadCachedTokenData();
  if (cachedData != null) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Athlete: ${cachedData['first_name']} ${cachedData['last_name']} (ID: ${cachedData['athlete_id']})');
    print('Premium: ${cachedData['is_premium']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
  }

  // Test 1: Athlete Profile
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 1: GET /v1/athlete/profile');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchAthleteProfile(accessToken);
  print('');

  // Test 2: Athlete Zones
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 2: GET /v1/athlete/profile/zones');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchAthleteZones(accessToken);
  print('');

  // Test 3: Workouts
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 3: GET /v2/workouts/{startDate}/{endDate}');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchWorkouts(accessToken);
  print('');

  // Test 4: Next Event
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 4: GET /v2/events/next');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchNextEvent(accessToken);
  print('');

  print('✅ All tests completed!');
}

Future<void> fetchAthleteProfile(String accessToken) async {
  print('📥 Fetching athlete profile...');
  print('');

  try {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/v1/athlete/profile'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana Endurance Test v1.0',
      },
    );

    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ ATHLETE PROFILE                                                   ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      printJson(data);
      print('');

      // Highlight Mealvana-relevant data
      print('📊 DATA USEFUL FOR MEALVANA:');
      print('   Weight (kg): ${data['Weight']}');
      print('   Is Premium:  ${data['IsPremium']}');
      print('   Units:       ${data['PreferredUnits']}');
      print('   Timezone:    ${data['TimeZone']}');
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - Token may be expired');
      print('   Run: dart run tool/training_peaks_api_test.dart refresh');
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> fetchAthleteZones(String accessToken) async {
  print('📥 Fetching athlete zones...');
  print('');

  try {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/v1/athlete/profile/zones'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana Endurance Test v1.0',
      },
    );

    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ ATHLETE ZONES                                                     ║');
      print('╚══════════════════════════════════════════════════════════════════╝');

      // Summarize zones instead of printing full JSON
      if (data['HeartRateZones'] != null) {
        print('   Heart Rate Zones: Available');
      }
      if (data['SpeedZones'] != null) {
        print('   Speed Zones: Available');
      }
      if (data['PowerZones'] != null) {
        print('   Power Zones: Available');
      }
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> fetchWorkouts(String accessToken) async {
  print('📥 Fetching workouts (next 14 days)...');
  print('');

  try {
    final now = DateTime.now();
    final startDate = _formatDate(now);
    final endDate = _formatDate(now.add(const Duration(days: 14)));

    final response = await http.get(
      Uri.parse('$apiBaseUrl/v2/workouts/$startDate/$endDate'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana Endurance Test v1.0',
      },
    );

    print('   Date Range: $startDate to $endDate');
    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final workouts = jsonDecode(response.body) as List;

      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ WORKOUTS (${workouts.length} found)                                              ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      print('');

      if (workouts.isEmpty) {
        print('   No upcoming workouts found.');
        print('   Add workouts in TrainingPeaks to see them here.');
      } else {
        for (var i = 0; i < workouts.length && i < 10; i++) {
          final w = workouts[i] as Map<String, dynamic>;
          final workoutType = w['WorkoutType'] ?? 'Unknown';
          final title = w['Title'] ?? 'Untitled';
          final workoutDay = w['WorkoutDay']?.toString().split('T')[0] ?? 'No date';

          // Distance is in METERS (TrainingPeaks standard)
          final distanceMeters = w['Distance'] as num?;
          final distanceMiles = distanceMeters != null ? distanceMeters * 0.000621371 : null;

          // Time is in DECIMAL HOURS (TrainingPeaks standard)
          final totalTimeHours = w['TotalTime'] as num?;
          final totalTimeMinutes = totalTimeHours != null ? totalTimeHours * 60 : null;

          print('   ${i + 1}. [$workoutType] $title');
          print('      Date: $workoutDay');
          if (distanceMiles != null) {
            print('      Distance: ${distanceMiles.toStringAsFixed(2)} mi (${distanceMeters?.toStringAsFixed(0)} m)');
          }
          if (totalTimeMinutes != null) {
            print('      Duration: ${totalTimeMinutes.toStringAsFixed(0)} min');
          }
          print('');
        }

        if (workouts.length > 10) {
          print('   ... and ${workouts.length - 10} more workouts');
        }
      }

      // Show critical unit info
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 CRITICAL UNIT DIFFERENCES FROM FINAL SURGE:');
      print('   • Distance: ALWAYS in METERS (convert: m * 0.000621371 = miles)');
      print('   • Time:     ALWAYS in DECIMAL HOURS (convert: h * 60 = minutes)');
      print('   • Pace:     NOT provided - calculate from distance/time');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - Token may be expired');
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> fetchNextEvent(String accessToken) async {
  print('📥 Fetching next event/race...');
  print('');

  try {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/v2/events/next'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana Endurance Test v1.0',
      },
    );

    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ NEXT EVENT                                                        ║');
      print('╚══════════════════════════════════════════════════════════════════╝');

      if (data == null || (data is List && data.isEmpty)) {
        print('   No upcoming events found.');
        print('   Add events/races in TrainingPeaks to see them here.');
      } else {
        printJson(data);
        print('');

        // Parse event for Mealvana use
        if (data is Map<String, dynamic>) {
          final eventDate = data['EventDate'];
          final eventType = data['EventType'];
          final name = data['Name'];
          final goals = data['Goals'] as List?;

          print('📊 DATA USEFUL FOR MEALVANA:');
          print('   Event Name: $name');
          print('   Event Type: $eventType');
          print('   Event Date: ${eventDate?.toString().split('T')[0]}');

          if (goals != null && goals.isNotEmpty) {
            print('   Goals:');
            for (final goal in goals) {
              final g = goal as Map<String, dynamic>;
              print('      ${g['GoalType']}: ${g['Value']} ${g['Unit'] ?? ''}');
            }
          }

          print('');
          print('   ⭐ This is UNIQUE to TrainingPeaks!');
          print('      Final Surge does NOT have event sync.');
          print('      Use this for race-day nutrition planning!');
        }
      }
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - Token may be expired');
    } else if (response.statusCode == 404) {
      print('   No upcoming events found.');
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

// ============================================================================
// UTILITIES
// ============================================================================

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

void printJson(dynamic data) {
  final encoder = JsonEncoder.withIndent('  ');
  final prettyJson = encoder.convert(data);
  print(prettyJson);
}
