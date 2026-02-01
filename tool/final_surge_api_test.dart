/// Final Surge API Test Script
///
/// This script tests the Final Surge Partner API endpoints.
/// Run with: dart run tool/final_surge_api_test.dart
///
/// Prerequisites:
/// 1. Final Surge account with scheduled workouts
/// 2. Valid client credentials (client-id and client-secret)
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// ============================================================================
// CONFIGURATION
// ============================================================================

const String baseUrl = 'https://log.finalsurge.com';

// Your Final Surge Partner API credentials
const String clientId = 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC';
const String clientSecret = r'65kj$#deujXLk3h?mpkm*V94X$dkb2$u78H35-Sc#$es#^C2e5^pMat3*2QAe7+$';

// Redirect URI for OAuth (localhost is whitelisted by Final Surge)
const String redirectUri = 'http://127.0.0.1:8888/callback';

// File to cache token data between runs
const String tokenCacheFile = 'tool/.final_surge_token.json';

// ============================================================================
// MAIN
// ============================================================================

Future<void> main(List<String> args) async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           Final Surge API Test Script                            ║');
  print('║           Mealvana Endurance Integration                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');

  // Parse command line arguments
  final command = args.isNotEmpty ? args[0] : 'help';

  switch (command) {
    case 'auth':
      await runOAuthFlow();
      break;
    case 'test':
      final token = args.length >= 2 ? args[1] : await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first or provide token.');
        print('   Usage: dart run tool/final_surge_api_test.dart test [access_token]');
        exit(1);
      }
      await testApiEndpoints(token);
      break;
    case 'workouts':
      final token = args.length >= 2 ? args[1] : await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first or provide token.');
        exit(1);
      }
      await fetchUpcomingWorkouts(token);
      break;
    case 'profile':
      final token = args.length >= 2 ? args[1] : await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first or provide token.');
        exit(1);
      }
      await fetchProfileInfo(token);
      break;
    case 'athlete':
      await showCachedAthleteInfo();
      break;
    case 'workout':
      final token = await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      if (args.length < 2) {
        print('❌ Error: Workout ID required.');
        print('   Usage: dart run tool/final_surge_api_test.dart workout <workout_key>');
        exit(1);
      }
      await fetchWorkoutById(token, args[1]);
      break;
    case 'daterange':
      final token = await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await fetchWorkoutsByDateRange(token);
      break;
    case 'compare':
      final token = await _loadCachedToken();
      if (token == null) {
        print('❌ Error: No access token. Run "auth" first.');
        exit(1);
      }
      await compareEndpoints(token);
      break;
    case 'help':
    default:
      printHelp();
  }
}

void printHelp() {
  print('Usage: dart run tool/final_surge_api_test.dart <command> [options]');
  print('');
  print('Commands:');
  print('  auth      Start OAuth flow to get access token (saves athlete info)');
  print('  test      Run all API tests (uses cached token or provide one)');
  print('  workouts  Fetch upcoming workouts (UpcomingWorkouts endpoint)');
  print('  workout   Fetch single workout by ID (Workout/{id} endpoint)');
  print('  daterange Fetch workouts by date range (Workouts endpoint)');
  print('  compare   Compare data from different endpoints for same workout');
  print('  profile   Fetch/save app profile info (NOT athlete profile)');
  print('  athlete   Show cached athlete info from last auth');
  print('  help      Show this help message');
  print('');
  print('Examples:');
  print('  dart run tool/final_surge_api_test.dart auth');
  print('  dart run tool/final_surge_api_test.dart test');
  print('  dart run tool/final_surge_api_test.dart workouts');
  print('  dart run tool/final_surge_api_test.dart workout <workout_key>');
  print('  dart run tool/final_surge_api_test.dart daterange');
  print('  dart run tool/final_surge_api_test.dart compare');
  print('  dart run tool/final_surge_api_test.dart athlete');
  print('');
  print('Notes:');
  print('  - After running "auth", the token is cached for subsequent commands');
  print('  - Athlete info (id, name) comes from the OAuth token exchange');
  print('  - ProfileInfo endpoint is for YOUR app data, not athlete profile');
  print('  - Use "compare" to see data differences between API endpoints');
}

// ============================================================================
// TOKEN CACHE
// ============================================================================

Future<void> _saveTokenData(Map<String, dynamic> data) async {
  final file = File(tokenCacheFile);
  await file.writeAsString(jsonEncode(data));
}

Future<String?> _loadCachedToken() async {
  try {
    final file = File(tokenCacheFile);
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['access_token'] as String?;
    }
  } catch (e) {
    // Ignore cache errors
  }
  return null;
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

Future<void> showCachedAthleteInfo() async {
  final data = await _loadCachedTokenData();

  if (data == null) {
    print('❌ No cached athlete info. Run "auth" first.');
    return;
  }

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║ ATHLETE INFO (from OAuth token exchange)                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('   Athlete ID:  ${data['id'] ?? 'N/A'}');
  print('   First Name:  ${data['firstname'] ?? 'N/A'}');
  print('   Last Name:   ${data['lastname'] ?? 'N/A'}');
  print('   Token:       ${_truncateToken(data['access_token'] as String?)}');
  print('   Cached At:   ${data['cached_at'] ?? 'N/A'}');
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

  // Step 1: Generate authorization URL
  final authUrl = Uri.parse('$baseUrl/oauth/authorize').replace(
    queryParameters: {
      'client-id': clientId,
      'redirect-uri': redirectUri,
      'state': 'mealvana_test_${DateTime.now().millisecondsSinceEpoch}',
    },
  );

  print('📋 Step 1: Open this URL in your browser:');
  print('');
  print('   $authUrl');
  print('');

  // Step 2: Start local server to catch the redirect
  print('📡 Step 2: Starting local server to catch redirect...');
  print('');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8888);
  print('   Listening on http://127.0.0.1:8888');
  print('   Waiting for authorization callback...');
  print('');

  String? authCode;
  String? state;
  String? error;

  await for (final request in server) {
    final uri = request.uri;

    if (uri.path == '/callback') {
      authCode = uri.queryParameters['code'];
      state = uri.queryParameters['state'];
      error = uri.queryParameters['error'];

      // Send response to browser
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
          <!DOCTYPE html>
          <html>
          <head><title>Mealvana - Final Surge Authorization</title></head>
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

  print('✅ Received authorization code: ${authCode.substring(0, 10)}...');
  print('   State: $state');
  print('');

  // Step 3: Exchange code for access token
  print('🔄 Step 3: Exchanging code for access token...');
  print('');

  try {
    final tokenResponse = await http.post(
      Uri.parse('$baseUrl/oauth/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client-id': clientId,
        'client-secret': clientSecret,
        'code': authCode,
      },
    );

    print('   Response Status: ${tokenResponse.statusCode}');
    print('');

    if (tokenResponse.statusCode == 200) {
      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;

      // Add timestamp and save to cache
      tokenData['cached_at'] = DateTime.now().toIso8601String();
      await _saveTokenData(tokenData);

      print('✅ Access Token Received & Cached!');
      print('');
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ TOKEN RESPONSE (includes athlete info)                           ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      printJson(tokenData);
      print('');

      // Show athlete summary
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ ATHLETE SUMMARY                                                   ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      print('');
      print('   Athlete ID:  ${tokenData['id'] ?? 'N/A'}');
      print('   First Name:  ${tokenData['firstname'] ?? 'N/A'}');
      print('   Last Name:   ${tokenData['lastname'] ?? 'N/A'}');
      print('');

      final accessToken = tokenData['access_token'] as String?;
      if (accessToken != null) {
        print('📋 Token cached! You can now run tests without providing the token:');
        print('');
        print('   dart run tool/final_surge_api_test.dart test');
        print('   dart run tool/final_surge_api_test.dart workouts');
        print('   dart run tool/final_surge_api_test.dart athlete');
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
    print('Athlete: ${cachedData['firstname']} ${cachedData['lastname']} (ID: ${cachedData['id']})');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
  }

  // Test 1: Profile Info (app storage, not athlete profile)
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 1: GET /API/v1/ProfileInfo');
  print('        (This is for YOUR app data storage, not athlete profile)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchProfileInfo(accessToken);
  print('');

  // Test 2: Upcoming Workouts
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 2: GET /API/v1/UpcomingWorkouts');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchUpcomingWorkouts(accessToken);
  print('');

  // Test 3: Upcoming Workouts with parameters
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 3: GET /API/v1/UpcomingWorkouts?NumDays=14&NumWorkouts=21');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  await fetchUpcomingWorkouts(accessToken, numDays: 14, numWorkouts: 21);
  print('');

  print('✅ All tests completed!');
}

Future<void> fetchProfileInfo(String accessToken) async {
  print('📥 Fetching ProfileInfo (app storage endpoint)...');
  print('');
  print('   ℹ️  Note: This endpoint stores YOUR app\'s data about the user,');
  print('       not the athlete\'s Final Surge profile. Athlete info comes');
  print('       from the OAuth token exchange (run "athlete" command).');
  print('');

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/API/v1/ProfileInfo'),
      headers: {
        'client-id': clientId,
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ PROFILE INFO RESPONSE (App Storage)                              ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      printJson(data);

      // Explain the fields
      print('');
      print('   📝 Fields explained:');
      print('      uniqueid: Your app\'s unique ID for this user (max 200 chars)');
      print('      profile:  Custom profile data your app stores (max 3000 chars)');
      print('      Both are null until you POST data to this endpoint.');
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> fetchUpcomingWorkouts(
  String accessToken, {
  int? numDays,
  int? numWorkouts,
}) async {
  print('📥 Fetching upcoming workouts...');
  print('');

  try {
    final queryParams = <String, String>{};
    if (numDays != null) queryParams['NumDays'] = numDays.toString();
    if (numWorkouts != null) queryParams['NumWorkouts'] = numWorkouts.toString();

    final uri = Uri.parse('$baseUrl/API/v1/UpcomingWorkouts').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'client-id': clientId,
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('   Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ UPCOMING WORKOUTS RESPONSE                                        ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      printJson(data);

      // Parse workout summary with correct field names
      final workouts = data['Workouts'] as List? ?? [];
      print('');
      print('╔══════════════════════════════════════════════════════════════════╗');
      print('║ WORKOUT SUMMARY                                                   ║');
      print('╚══════════════════════════════════════════════════════════════════╝');
      print('');
      print('   Total workouts: ${workouts.length}');
      print('');

      if (workouts.isEmpty) {
        print('   No upcoming workouts found.');
        print('   Add workouts in Final Surge to see them here.');
      } else {
        for (var i = 0; i < workouts.length; i++) {
          final w = workouts[i] as Map<String, dynamic>;
          final title = w['WorkoutTitle'] ?? 'Untitled';
          final type = w['WorkoutTypeName'] ?? 'Unknown';
          final subType = w['WorkoutSubTypeName'];
          final date = w['WorkoutDate']?.toString().split('T')[0] ?? 'No date';
          final completed = w['WorkoutCompleted'] == true ? '✅' : '⏳';
          final hasStructured = w['HasStructuredWorkout'] == true ? '📊' : '';

          // Build type string
          final typeStr = subType != null ? '$type ($subType)' : type;

          // Distance/time info
          final plannedDist = w['PlannedDistance'];
          final plannedDistType = w['PlannedDistanceType'];
          final plannedTime = w['PlannedTime'];

          String details = '';
          if (plannedDist != null && plannedDistType != null) {
            details = '$plannedDist $plannedDistType';
          } else if (plannedTime != null) {
            details = plannedTime;
          }

          print('   ${i + 1}. $completed [$typeStr] $title');
          print('      Date: $date ${hasStructured.isNotEmpty ? "| Structured: Yes" : ""}');
          if (details.isNotEmpty) {
            print('      Planned: $details');
          }
          if (w['WorkoutDescription'] != null && (w['WorkoutDescription'] as String).isNotEmpty) {
            final desc = (w['WorkoutDescription'] as String);
            final truncDesc = desc.length > 60 ? '${desc.substring(0, 60)}...' : desc;
            print('      Notes: $truncDesc');
          }
          print('');
        }
      }

      // Show what data is useful for Mealvana
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 DATA USEFUL FOR MEALVANA NUTRITION PLANNING:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('');
      print('   • WorkoutDate       → Activity date for nutrition timing');
      print('   • WorkoutTypeName   → Sport type (Run, Bike, Swim, etc.)');
      print('   • PlannedDistance   → Distance for macro calculations');
      print('   • PlannedTime       → Duration for calorie estimates');
      print('   • WorkoutSubTypeName→ Intensity hint (Long Run, Tempo, etc.)');
      print('   • HasStructuredWorkout → Detailed interval data available');
      print('');
    } else {
      print('❌ Request failed');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

// ============================================================================
// SINGLE WORKOUT BY ID
// ============================================================================

Future<Map<String, dynamic>?> fetchWorkoutById(String accessToken, String workoutKey, {bool silent = false}) async {
  if (!silent) {
    print('📥 Fetching single workout by ID: $workoutKey');
    print('');
  }

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/API/v1/Workout/$workoutKey'),
      headers: {
        'client-id': clientId,
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (!silent) {
      print('   Status: ${response.statusCode}');
      print('');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!silent) {
        print('╔══════════════════════════════════════════════════════════════════╗');
        print('║ SINGLE WORKOUT RESPONSE (Workout/{id} endpoint)                   ║');
        print('╚══════════════════════════════════════════════════════════════════╝');
        printJson(data);
        print('');

        // Show key fields for nutrition
        _printWorkoutNutritionFields(data);
      }

      return data;
    } else {
      if (!silent) {
        print('❌ Request failed');
        print('   Body: ${response.body}');
      }
      return null;
    }
  } catch (e) {
    if (!silent) print('❌ Error: $e');
    return null;
  }
}

// ============================================================================
// WORKOUTS BY DATE RANGE
// ============================================================================

Future<List<Map<String, dynamic>>> fetchWorkoutsByDateRange(String accessToken, {bool silent = false}) async {
  if (!silent) {
    print('📥 Fetching workouts by date range (today +/- 7 days)...');
    print('');
  }

  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 7));
  final endDate = now.add(const Duration(days: 7));

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/API/v1/Workouts').replace(
        queryParameters: {
          'StartDate': _formatDate(startDate),
          'EndDate': _formatDate(endDate),
        },
      ),
      headers: {
        'client-id': clientId,
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (!silent) {
      print('   Status: ${response.statusCode}');
      print('   Date Range: ${_formatDate(startDate)} to ${_formatDate(endDate)}');
      print('');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!silent) {
        print('╔══════════════════════════════════════════════════════════════════╗');
        print('║ DATE RANGE WORKOUTS RESPONSE (Workouts endpoint)                  ║');
        print('╚══════════════════════════════════════════════════════════════════╝');
        printJson(data);
        print('');
      }

      final workouts = (data['Workouts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!silent && workouts.isNotEmpty) {
        print('╔══════════════════════════════════════════════════════════════════╗');
        print('║ WORKOUT NUTRITION FIELDS ANALYSIS                                 ║');
        print('╚══════════════════════════════════════════════════════════════════╝');
        print('');

        for (var i = 0; i < workouts.length; i++) {
          final w = workouts[i];
          print('Workout ${i + 1}: ${w['WorkoutTitle'] ?? 'Untitled'} (${w['WorkoutTypeName']})');
          _printWorkoutNutritionFields(w);
          print('');
        }
      }

      return workouts;
    } else {
      if (!silent) {
        print('❌ Request failed');
        print('   Body: ${response.body}');
      }
      return [];
    }
  } catch (e) {
    if (!silent) print('❌ Error: $e');
    return [];
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ============================================================================
// COMPARE ENDPOINTS
// ============================================================================

Future<void> compareEndpoints(String accessToken) async {
  print('🔬 COMPARING DATA FROM DIFFERENT ENDPOINTS');
  print('═══════════════════════════════════════════════════════════════════');
  print('');
  print('This test fetches the same workout from different endpoints to see');
  print('which one returns the most complete data for nutrition planning.');
  print('');

  // First, get workouts from UpcomingWorkouts
  print('Step 1: Fetching from UpcomingWorkouts endpoint...');
  print('');

  final upcomingResponse = await http.get(
    Uri.parse('$baseUrl/API/v1/UpcomingWorkouts').replace(
      queryParameters: {'NumDays': '7', 'NumWorkouts': '21'},
    ),
    headers: {
      'client-id': clientId,
      'Authorization': 'Bearer $accessToken',
    },
  );

  if (upcomingResponse.statusCode != 200) {
    print('❌ Failed to fetch upcoming workouts');
    return;
  }

  final upcomingData = jsonDecode(upcomingResponse.body) as Map<String, dynamic>;
  final upcomingWorkouts = (upcomingData['Workouts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  if (upcomingWorkouts.isEmpty) {
    print('❌ No workouts found. Create some workouts in Final Surge first.');
    return;
  }

  print('   Found ${upcomingWorkouts.length} workouts from UpcomingWorkouts');
  print('');

  // Get first workout's key
  final firstWorkout = upcomingWorkouts.first;
  final workoutKey = firstWorkout['WorkoutKey'] as String?;

  if (workoutKey == null) {
    print('❌ First workout has no WorkoutKey');
    return;
  }

  print('Step 2: Fetching same workout from Workout/{id} endpoint...');
  print('   WorkoutKey: $workoutKey');
  print('');

  final singleWorkout = await fetchWorkoutById(accessToken, workoutKey, silent: true);

  print('Step 3: Fetching from Workouts (date range) endpoint...');
  print('');

  final dateRangeWorkouts = await fetchWorkoutsByDateRange(accessToken, silent: true);
  final matchingWorkout = dateRangeWorkouts.firstWhere(
    (w) => w['WorkoutKey'] == workoutKey,
    orElse: () => <String, dynamic>{},
  );

  // Now compare the three
  print('═══════════════════════════════════════════════════════════════════');
  print('COMPARISON: "${firstWorkout['WorkoutTitle'] ?? 'Untitled'}"');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  final fieldsToCompare = [
    'WorkoutKey',
    'WorkoutDate',
    'WorkoutTypeName',
    'WorkoutSubTypeName',
    'WorkoutCompleted',
    'PlannedTime',
    'PlannedDistance',
    'PlannedDistanceType',
    'PlannedPace',
    'PlannedPaceType',
    'ActualTime',
    'ActualDistanceMeters',
    'ActualPace',
    'WorkoutDescription',
    'HasStructuredWorkout',
  ];

  print('Field                    │ UpcomingWorkouts │ Workout/{id}     │ Workouts (range) ');
  print('─────────────────────────┼──────────────────┼──────────────────┼──────────────────');

  for (final field in fieldsToCompare) {
    final v1 = _formatValue(firstWorkout[field]);
    final v2 = _formatValue(singleWorkout?[field]);
    final v3 = _formatValue(matchingWorkout[field]);

    // Highlight differences
    final hasDiff = (v1 != v2) || (v2 != v3) || (v1 != v3);
    final prefix = hasDiff ? '⚠️' : '  ';

    print('$prefix ${field.padRight(21)} │ ${v1.padRight(16)} │ ${v2.padRight(16)} │ $v3');
  }

  print('');
  print('═══════════════════════════════════════════════════════════════════');
  print('ANALYSIS:');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Check which endpoint has the most data
  int countNonNull(Map<String, dynamic>? data) {
    if (data == null) return 0;
    return fieldsToCompare.where((f) => data[f] != null).length;
  }

  final c1 = countNonNull(firstWorkout);
  final c2 = countNonNull(singleWorkout);
  final c3 = countNonNull(matchingWorkout.isEmpty ? null : matchingWorkout);

  print('Non-null fields:');
  print('   UpcomingWorkouts: $c1/${fieldsToCompare.length}');
  print('   Workout/{id}:     $c2/${fieldsToCompare.length}');
  print('   Workouts (range): $c3/${fieldsToCompare.length}');
  print('');

  // Specific checks for nutrition planning
  print('Key fields for nutrition planning:');
  print('');

  _checkField('PlannedTime (duration)', firstWorkout['PlannedTime'], singleWorkout?['PlannedTime'], matchingWorkout['PlannedTime']);
  _checkField('PlannedDistance', firstWorkout['PlannedDistance'], singleWorkout?['PlannedDistance'], matchingWorkout['PlannedDistance']);
  _checkField('PlannedPace', firstWorkout['PlannedPace'], singleWorkout?['PlannedPace'], matchingWorkout['PlannedPace']);
  _checkField('ActualTime', firstWorkout['ActualTime'], singleWorkout?['ActualTime'], matchingWorkout['ActualTime']);
  _checkField('ActualDistanceMeters', firstWorkout['ActualDistanceMeters'], singleWorkout?['ActualDistanceMeters'], matchingWorkout['ActualDistanceMeters']);

  print('');
  print('═══════════════════════════════════════════════════════════════════');
  print('RAW DATA DUMPS:');
  print('═══════════════════════════════════════════════════════════════════');
  print('');
  print('--- UpcomingWorkouts endpoint ---');
  printJson(firstWorkout);
  print('');
  print('--- Workout/{id} endpoint ---');
  if (singleWorkout != null) {
    printJson(singleWorkout);
  } else {
    print('(no data)');
  }
  print('');
  print('--- Workouts (date range) endpoint ---');
  if (matchingWorkout.isNotEmpty) {
    printJson(matchingWorkout);
  } else {
    print('(no matching workout found)');
  }
}

String _formatValue(dynamic value) {
  if (value == null) return 'null';
  if (value is String && value.isEmpty) return '(empty)';
  if (value is String && value.length > 14) return '${value.substring(0, 12)}..';
  if (value is Map || value is List) return '{...}';
  return value.toString();
}

void _checkField(String name, dynamic v1, dynamic v2, dynamic v3) {
  final hasV1 = v1 != null;
  final hasV2 = v2 != null;
  final hasV3 = v3 != null;

  final status = hasV1 || hasV2 || hasV3 ? '✅' : '❌';
  final sources = <String>[];
  if (hasV1) sources.add('Upcoming');
  if (hasV2) sources.add('Single');
  if (hasV3) sources.add('Range');

  final sourceStr = sources.isEmpty ? 'NONE!' : sources.join(', ');
  print('   $status $name: $sourceStr');

  if (hasV1) print('      Upcoming: $v1');
  if (hasV2) print('      Single:   $v2');
  if (hasV3) print('      Range:    $v3');
}

void _printWorkoutNutritionFields(Map<String, dynamic> workout) {
  print('');
  print('   📊 KEY NUTRITION FIELDS:');
  print('   ─────────────────────────────────────────');
  print('   PlannedTime:          ${workout['PlannedTime'] ?? 'NULL'}');
  print('   PlannedDistance:      ${workout['PlannedDistance'] ?? 'NULL'} ${workout['PlannedDistanceType'] ?? ''}');
  print('   PlannedPace:          ${workout['PlannedPace'] ?? 'NULL'} ${workout['PlannedPaceType'] ?? ''}');
  print('   ActualTime:           ${workout['ActualTime'] ?? 'NULL'}');
  print('   ActualDistanceMeters: ${workout['ActualDistanceMeters'] ?? 'NULL'}');
  print('   ActualPace:           ${workout['ActualPace'] ?? 'NULL'}');
  print('   WorkoutCompleted:     ${workout['WorkoutCompleted']}');
  print('   ─────────────────────────────────────────');
}

// ============================================================================
// UTILITIES
// ============================================================================

void printJson(dynamic data) {
  final encoder = JsonEncoder.withIndent('  ');
  final prettyJson = encoder.convert(data);
  print(prettyJson);
}
