/// TrainingPeaks Comment API Discovery Script
///
/// Tests undocumented comment CRUD endpoints to determine
/// if we can edit/delete workout comments (not just create them).
///
/// Usage:
///   dart run tools/tp_comment_discovery.dart <refresh_token>
///
/// The script will:
/// 1. Refresh the token to get a valid access token
/// 2. Fetch upcoming workouts to find a test workout
/// 3. POST a test comment
/// 4. Try GET/PUT/DELETE on comments
/// 5. Log all results to docs/tp_write/api_discovery_results.md
///
/// IMPORTANT: Uses PRODUCTION API (not sandbox) to test real behavior.
/// The test comment will be cleaned up if DELETE works.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _clientId = 'mealvana';
const _clientSecret = 'CSBPmjgHFFTjGNUfBlPTqcx1bm9ilR6laqHO31Ms';
const _oauthUrl = 'https://oauth.trainingpeaks.com';
const _apiUrl = 'https://api.trainingpeaks.com';
const _userAgent = 'Mealvana/discovery';

final _results = StringBuffer();
final _client = http.Client();

void log(String msg) {
  print(msg);
  _results.writeln(msg);
}

void logSection(String title) {
  log('\n## $title\n');
}

void logResult(String endpoint, int statusCode, String body,
    {String method = 'GET'}) {
  log('**$method `$endpoint`**');
  log('- Status: `$statusCode`');
  final preview =
      body.length > 500 ? '${body.substring(0, 500)}...(truncated)' : body;
  log('- Response: ```json\n$preview\n```');
  log('');
}

Future<String> refreshToken(String token) async {
  final response = await _client.post(
    Uri.parse('$_oauthUrl/oauth/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': _userAgent,
    },
    body: {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': token,
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        'Token refresh failed: ${response.statusCode} ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return json['access_token'] as String;
}

Map<String, String> authHeaders(String accessToken) => {
      'Authorization': 'Bearer $accessToken',
      'User-Agent': _userAgent,
    };

Map<String, String> jsonAuthHeaders(String accessToken) => {
      ...authHeaders(accessToken),
      'Content-Type': 'application/json',
    };

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tools/tp_comment_discovery.dart <refresh_token>');
    print('');
    print('To get your refresh token, add this to training_peaks_oauth_service.dart');
    print('in refreshTokenIfNeeded(), after line 213:');
    print('  print("REFRESH_TOKEN: \$refreshToken");');
    print('Then trigger a TP sync in the app and copy the token from the console.');
    exit(1);
  }

  final refreshTokenValue = args[0];

  log('# TrainingPeaks Comment API Discovery Results');
  log('');
  log('Date: ${DateTime.now().toIso8601String()}');
  log('Environment: Production');

  try {
    // Step 1: Get access token
    logSection('1. Token Refresh');
    final accessToken = await refreshToken(refreshTokenValue);
    log('Access token obtained (${accessToken.length} chars)');

    // Step 2: Get athlete profile (need athleteId for comment endpoints)
    logSection('2. Athlete Profile');
    final profileResponse = await _client.get(
      Uri.parse('$_apiUrl/v1/athlete/profile'),
      headers: authHeaders(accessToken),
    );
    logResult('/v1/athlete/profile', profileResponse.statusCode,
        profileResponse.body);

    final profile =
        jsonDecode(profileResponse.body) as Map<String, dynamic>;
    final athleteId = profile['Id']?.toString();
    log('Athlete ID: `$athleteId`');

    if (athleteId == null) {
      log('ERROR: Could not get athlete ID. Aborting.');
      await _writeResults();
      exit(1);
    }

    // Step 3: Fetch upcoming workouts to find a test workout
    logSection('3. Find Test Workout');
    final now = DateTime.now();
    final startDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final endDate = now.add(const Duration(days: 14));
    final endDateStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final workoutsResponse = await _client.get(
      Uri.parse('$_apiUrl/v2/workouts/$startDate/$endDateStr'),
      headers: authHeaders(accessToken),
    );
    logResult('/v2/workouts/$startDate/$endDateStr',
        workoutsResponse.statusCode, workoutsResponse.body);

    if (workoutsResponse.statusCode != 200) {
      log('ERROR: Could not fetch workouts. Aborting.');
      await _writeResults();
      exit(1);
    }

    final workouts = jsonDecode(workoutsResponse.body) as List;
    if (workouts.isEmpty) {
      log('ERROR: No upcoming workouts found in next 14 days. Need at least one workout to test comments.');
      await _writeResults();
      exit(1);
    }

    final testWorkout = workouts.first as Map<String, dynamic>;
    final workoutId = testWorkout['Id']?.toString();
    final workoutTitle = testWorkout['Title'] ?? 'Unknown';
    final workoutDay = testWorkout['WorkoutDay'] ?? 'Unknown';
    log('Using workout: `$workoutTitle` on `$workoutDay` (ID: `$workoutId`)');

    // Step 4: POST a test comment
    logSection('4. POST Comment (Create)');
    final testComment =
        '[Mealvana Discovery Test] ${DateTime.now().toIso8601String()}';

    final postResponse = await _client.post(
      Uri.parse(
          '$_apiUrl/v2/workouts/$athleteId/id/$workoutId/comment'),
      headers: jsonAuthHeaders(accessToken),
      body: jsonEncode({'Value': testComment}),
    );
    logResult('/v2/workouts/$athleteId/id/$workoutId/comment',
        postResponse.statusCode, postResponse.body,
        method: 'POST');

    // Check if POST response includes a comment ID
    String? commentId;
    if (postResponse.body.isNotEmpty) {
      try {
        final postJson = jsonDecode(postResponse.body);
        if (postJson is Map) {
          commentId = postJson['Id']?.toString() ??
              postJson['id']?.toString() ??
              postJson['CommentId']?.toString();
          log('Comment ID from POST response: `$commentId`');
        }
      } catch (_) {
        log('POST response is not JSON (likely 204 No Content)');
      }
    } else {
      log('POST response body is empty (204 No Content pattern)');
    }

    // Step 5: Try GET comments (various URL patterns)
    logSection('5. GET Comments (Discovery)');

    final getEndpoints = [
      '/v2/workouts/$athleteId/id/$workoutId/comments',
      '/v1/workouts/$workoutId/comments',
      '/v2/workouts/$workoutId/comments',
      '/v3/workouts/$workoutId/comments',
      '/v2/workouts/id/$workoutId/comments',
      '/v1/workouts/$athleteId/$workoutId/comments',
    ];

    String? foundGetEndpoint;
    List<dynamic>? commentsList;

    for (final endpoint in getEndpoints) {
      final response = await _client.get(
        Uri.parse('$_apiUrl$endpoint'),
        headers: authHeaders(accessToken),
      );
      logResult(endpoint, response.statusCode, response.body);

      if (response.statusCode == 200) {
        foundGetEndpoint = endpoint;
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is List) {
            commentsList = parsed;
            log('Found ${parsed.length} comments via `$endpoint`');

            // Try to find our test comment and get its ID
            for (final c in parsed) {
              if (c is Map) {
                final value = c['Value']?.toString() ?? c['value']?.toString() ?? '';
                if (value.contains('Mealvana Discovery Test')) {
                  commentId ??= c['Id']?.toString() ??
                      c['id']?.toString() ??
                      c['CommentId']?.toString();
                  log('Found our test comment! ID: `$commentId`');
                }
              }
            }
          }
        } catch (_) {}
        break; // Stop after first success
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Step 6: Try PUT (update) if we have a comment ID
    logSection('6. PUT Comment (Update)');

    if (commentId != null) {
      final updatedComment =
          '[Mealvana Discovery Test UPDATED] ${DateTime.now().toIso8601String()}';

      final putEndpoints = [
        '/v2/workouts/$athleteId/id/$workoutId/comment/$commentId',
        '/v2/workouts/$athleteId/id/$workoutId/comments/$commentId',
        '/v1/workouts/$workoutId/comments/$commentId',
        '/v2/workouts/comment/$commentId',
      ];

      for (final endpoint in putEndpoints) {
        final response = await _client.put(
          Uri.parse('$_apiUrl$endpoint'),
          headers: jsonAuthHeaders(accessToken),
          body: jsonEncode({'Value': updatedComment}),
        );
        logResult(endpoint, response.statusCode, response.body,
            method: 'PUT');

        if (response.statusCode == 200 || response.statusCode == 204) {
          log('PUT SUCCEEDED on `$endpoint`');
          break;
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }
    } else {
      log('No comment ID available - cannot test PUT.');
      log('(POST returned 204 with no body, and GET endpoints not found)');
    }

    // Step 7: Try DELETE if we have a comment ID
    logSection('7. DELETE Comment (Cleanup)');

    if (commentId != null) {
      final deleteEndpoints = [
        '/v2/workouts/$athleteId/id/$workoutId/comment/$commentId',
        '/v2/workouts/$athleteId/id/$workoutId/comments/$commentId',
        '/v1/workouts/$workoutId/comments/$commentId',
        '/v2/workouts/comment/$commentId',
      ];

      for (final endpoint in deleteEndpoints) {
        final response = await _client.delete(
          Uri.parse('$_apiUrl$endpoint'),
          headers: authHeaders(accessToken),
        );
        logResult(endpoint, response.statusCode, response.body,
            method: 'DELETE');

        if (response.statusCode == 200 || response.statusCode == 204) {
          log('DELETE SUCCEEDED on `$endpoint`');
          break;
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }
    } else {
      log('No comment ID available - cannot test DELETE.');
    }

    // Step 8: Test workout description PUT (our fallback approach)
    logSection('8. Workout Description PUT (Fallback Test)');
    log('Testing if we can read and update the Description field...');

    // First, GET the full workout by ID
    final fullWorkoutResponse = await _client.get(
      Uri.parse('$_apiUrl/v1/workouts/$workoutId'),
      headers: authHeaders(accessToken),
    );
    logResult('/v1/workouts/$workoutId', fullWorkoutResponse.statusCode,
        fullWorkoutResponse.body);

    if (fullWorkoutResponse.statusCode == 200) {
      final fullWorkout =
          jsonDecode(fullWorkoutResponse.body) as Map<String, dynamic>;
      final originalDesc = fullWorkout['Description'] ?? '';
      log('Original Description: `${originalDesc.toString().length > 100 ? '${originalDesc.toString().substring(0, 100)}...' : originalDesc}`');

      // Try PUT to add our block
      final testBlock = '''

---
[Mealvana Fuel Plan]
Pre: 60g carb, 16oz water (2h before)
During: 45g/h carb, 20oz/h water
Post: 30g protein, 60g carb
[/Mealvana]''';

      final updatedDesc = '$originalDesc$testBlock';

      // Build the PUT body - send ALL original fields plus our description change
      final putBody = Map<String, dynamic>.from(fullWorkout);
      putBody['Description'] = updatedDesc;

      final putWorkoutResponse = await _client.put(
        Uri.parse('$_apiUrl/v2/workouts/plan/${workoutId}'),
        headers: jsonAuthHeaders(accessToken),
        body: jsonEncode(putBody),
      );
      logResult('/v2/workouts/plan/$workoutId',
          putWorkoutResponse.statusCode, putWorkoutResponse.body,
          method: 'PUT');

      if (putWorkoutResponse.statusCode == 200 ||
          putWorkoutResponse.statusCode == 204) {
        log('Description PUT SUCCEEDED - we can write to descriptions!');

        // Immediately revert by stripping our block
        putBody['Description'] = originalDesc;
        final revertResponse = await _client.put(
          Uri.parse('$_apiUrl/v2/workouts/plan/${workoutId}'),
          headers: jsonAuthHeaders(accessToken),
          body: jsonEncode(putBody),
        );
        log('Revert status: `${revertResponse.statusCode}` (${revertResponse.statusCode == 200 || revertResponse.statusCode == 204 ? "cleaned up" : "FAILED to revert!"})');
      } else {
        log('Description PUT FAILED - status ${putWorkoutResponse.statusCode}');
      }
    }

    // Summary
    logSection('9. Summary & Recommendation');

    final hasGetComments = foundGetEndpoint != null;
    final hasCommentId = commentId != null;

    log('| Capability | Result |');
    log('|---|---|');
    log('| POST comment | ${postResponse.statusCode == 200 || postResponse.statusCode == 204 ? "YES" : "NO (${postResponse.statusCode})"} |');
    log('| GET comments | ${hasGetComments ? "YES via `$foundGetEndpoint`" : "NO - all endpoints returned errors"} |');
    log('| Comment ID available | ${hasCommentId ? "YES (`$commentId`)" : "NO"} |');
    log('| PUT comment | Tested above |');
    log('| DELETE comment | Tested above |');
    log('');

    if (hasGetComments && hasCommentId) {
      log('**Recommendation**: Comments may have full CRUD. Review PUT/DELETE results above.');
    } else {
      log('**Recommendation**: Use **Description field approach** (delimited block). Comments lack edit/delete capability.');
    }
  } catch (e, stack) {
    log('\n## ERROR\n');
    log('```\n$e\n$stack\n```');
  } finally {
    _client.close();
    await _writeResults();
  }
}

Future<void> _writeResults() async {
  final file = File('docs/tp_write/api_discovery_results.md');
  await file.writeAsString(_results.toString());
  print('\n\nResults written to: ${file.path}');
}
