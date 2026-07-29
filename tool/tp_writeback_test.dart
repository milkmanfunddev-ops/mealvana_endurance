/// TrainingPeaks Write-Back Integration Test
///
/// Diagnoses why PUT /v2/workouts/plan/{id} fails with 401.
/// Tests: token validity, scopes, GET vs PUT behavior.
///
/// Usage:
///   dart run tools/tp_writeback_test.dart <refresh_token>
///
/// To get your refresh token, look for this line in the app logs during TP sync:
///   "Refresh token preview: xxxxx...xxxxx"
/// Or add: print("REFRESH_TOKEN: $refreshToken") in refreshTokenIfNeeded()

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// Toggle between sandbox and production
const _useSandbox = true;
const _clientId = 'mealvana';
const _clientSecret = 'CSBPmjgHFFTjGNUfBlPTqcx1bm9ilR6laqHO31Ms';

final _oauthUrl = _useSandbox
    ? 'https://oauth.sandbox.trainingpeaks.com'
    : 'https://oauth.trainingpeaks.com';
final _apiUrl = _useSandbox
    ? 'https://api.sandbox.trainingpeaks.com'
    : 'https://api.trainingpeaks.com';

final _client = http.Client();

void log(String msg) => print(msg);

Future<Map<String, dynamic>> refreshToken(String token) async {
  log('\n=== TOKEN REFRESH ===');
  log('OAuth URL: $_oauthUrl/oauth/token');
  log('Client ID: $_clientId');

  final response = await _client.post(
    Uri.parse('$_oauthUrl/oauth/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'Mealvana/writeback-test',
    },
    body: {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': token,
    },
  );

  log('Refresh status: ${response.statusCode}');

  if (response.statusCode != 200) {
    log('REFRESH FAILED: ${response.body}');
    throw Exception('Token refresh failed: ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final accessToken = json['access_token'] as String;
  final scope = json['scope'] ?? json['scopes'] ?? 'NOT IN RESPONSE';
  final expiresIn = json['expires_in'];
  final tokenType = json['token_type'];

  log('Token type: $tokenType');
  log('Expires in: ${expiresIn}s');
  log('Scopes returned: $scope');
  log('Access token length: ${accessToken.length}');

  // Try to decode JWT to see claims/scopes
  try {
    final parts = accessToken.split('.');
    if (parts.length == 3) {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      log('JWT claims: ${const JsonEncoder.withIndent('  ').convert(claims)}');
    } else {
      log('Token is not a JWT (${parts.length} parts)');
    }
  } catch (e) {
    log('Could not decode token as JWT: $e');
  }

  return json;
}

Future<void> testEndpoint(
  String method,
  String path,
  String accessToken, {
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse('$_apiUrl$path');
  final headers = <String, String>{
    'Authorization': 'Bearer $accessToken',
    'User-Agent': 'Mealvana/writeback-test',
    if (body != null) 'Content-Type': 'application/json',
  };

  log('\n--- $method $path ---');

  http.Response response;
  switch (method) {
    case 'GET':
      response = await _client.get(uri, headers: headers);
      break;
    case 'PUT':
      response = await _client.put(uri, headers: headers,
          body: body != null ? jsonEncode(body) : null);
      break;
    case 'POST':
      response = await _client.post(uri, headers: headers,
          body: body != null ? jsonEncode(body) : null);
      break;
    default:
      throw ArgumentError('Unknown method: $method');
  }

  log('Status: ${response.statusCode}');
  log('Headers: ${response.headers}');

  final bodyStr = response.body;
  if (bodyStr.length > 1000) {
    log('Body (truncated): ${bodyStr.substring(0, 1000)}...');
  } else {
    log('Body: $bodyStr');
  }
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tools/tp_writeback_test.dart <refresh_token>');
    print('');
    print('To get your refresh token:');
    print('  1. Run the app and trigger a TP sync');
    print('  2. Look for "Refresh token preview:" in logs');
    print('  3. Or add print("RT: \$refreshToken") in refreshTokenIfNeeded()');
    exit(1);
  }

  final refreshTokenValue = args[0];

  log('=== TP WRITE-BACK INTEGRATION TEST ===');
  log('Environment: ${_useSandbox ? "SANDBOX" : "PRODUCTION"}');
  log('API URL: $_apiUrl');
  log('OAuth URL: $_oauthUrl');
  log('Date: ${DateTime.now()}');

  try {
    // 1. Refresh token
    final tokenResponse = await refreshToken(refreshTokenValue);
    final accessToken = tokenResponse['access_token'] as String;
    final newRefreshToken = tokenResponse['refresh_token'] as String?;

    if (newRefreshToken != null && newRefreshToken != refreshTokenValue) {
      log('\n⚠️  REFRESH TOKEN ROTATED! New refresh token:');
      log('   $newRefreshToken');
      log('   Use this for future test runs.');
    }

    // 2. Test basic auth (athlete profile)
    log('\n=== TEST 1: Basic Auth (GET profile) ===');
    await testEndpoint('GET', '/v1/athlete/profile', accessToken);

    // 3. Test workouts read
    log('\n=== TEST 2: Workouts Read ===');
    final now = DateTime.now();
    final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final end = now.add(const Duration(days: 14));
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    await testEndpoint('GET', '/v2/workouts/$start/$endStr', accessToken);

    // 4. Find a specific workout to test with
    log('\n=== TEST 3: GET Single Workout (with description) ===');
    const testWorkoutId = '3585291920'; // From the logs

    await testEndpoint(
      'GET',
      '/v2/workouts/id/$testWorkoutId?includeDescription=true',
      accessToken,
    );

    // 5. Try PUT with a minimal change
    log('\n=== TEST 4: PUT Workout Description (the failing operation) ===');

    // First GET the full workout
    final getResponse = await _client.get(
      Uri.parse('$_apiUrl/v2/workouts/id/$testWorkoutId?includeDescription=true'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': 'Mealvana/writeback-test',
      },
    );

    if (getResponse.statusCode == 200) {
      final workout = jsonDecode(getResponse.body) as Map<String, dynamic>;
      final originalDesc = workout['Description'] as String? ?? '';
      log('Original description: "${originalDesc.length > 100 ? '${originalDesc.substring(0, 100)}...' : originalDesc}"');

      // Add our test block
      final testDesc = '$originalDesc\n---\n[Mealvana Test]\nTest block\n[/Mealvana]';
      workout['Description'] = testDesc;

      await testEndpoint(
        'PUT',
        '/v2/workouts/plan/$testWorkoutId',
        accessToken,
        body: workout,
      );

      // If PUT succeeded, revert
      workout['Description'] = originalDesc;
      log('\n--- Reverting description... ---');
      final revertResponse = await _client.put(
        Uri.parse('$_apiUrl/v2/workouts/plan/$testWorkoutId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'User-Agent': 'Mealvana/writeback-test',
        },
        body: jsonEncode(workout),
      );
      log('Revert status: ${revertResponse.statusCode}');
    } else {
      log('Cannot test PUT — GET failed with ${getResponse.statusCode}');
      log('GET body: ${getResponse.body}');
    }

    // 6. Diagnosis
    log('\n=== DIAGNOSIS ===');
    log('If GET succeeds but PUT returns 401:');
    log('  → Missing workouts:write or workouts:plan scope');
    log('  → Fix: Add scope to defaultScopes and reconnect TP');
    log('If PUT returns 403:');
    log('  → Non-Premium sandbox account');
    log('If PUT returns 200/204:');
    log('  → Write-back should work! Check app token storage.');

  } catch (e, stack) {
    log('\nERROR: $e');
    log('Stack: $stack');
  } finally {
    _client.close();
  }
}
