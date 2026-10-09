import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../ai_credits/application/credits_controller.dart';
import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/meal_analysis_result.dart';
import 'meal_photo_sanitizer.dart';

part 'meal_ai_service.g.dart';

// ---------------------------------------------------------------------------
// Typed exceptions
// ---------------------------------------------------------------------------

/// Category of failure returned by [MealAiService].
enum MealAiFailureKind {
  /// Device has no network connectivity.
  offline,

  /// The image was successfully transmitted but the model determined it is
  /// not a food photo.
  notFood,

  /// describe-meal refused the description as longer than its limit (400
  /// with `too_long: true`, ticket 79). The screen shows its own content line
  /// for this kind; [MealAiException.userMessage] is empty.
  tooLong,

  /// The picked photo could not be decoded and re-encoded without its
  /// metadata (ticket 75), so nothing was uploaded. The screen shows its own
  /// content line for this kind; [MealAiException.userMessage] is empty.
  photoUnreadable,

  /// The edge function or AI Gateway returned an unexpected error.
  serverError,
}

/// Thrown by [MealAiService] when an AI call cannot be completed.
///
/// [kind] drives the UI message; [debugMessage] is for logs only.
class MealAiException implements Exception {
  const MealAiException({
    required this.kind,
    required this.userMessage,
    this.debugMessage,
  });

  final MealAiFailureKind kind;

  /// Human-presentable reason, suitable for display directly in the UI.
  final String userMessage;

  /// Internal detail for logging — never shown to the user.
  final String? debugMessage;

  @override
  String toString() => 'MealAiException(${kind.name}): $userMessage';
}

// ---------------------------------------------------------------------------
// Result type for analyzePhoto
// ---------------------------------------------------------------------------

/// Combines the analysis result with the uploaded storage path so the caller
/// can reference the photo in the meal log record.
class MealPhotoAnalysis {
  const MealPhotoAnalysis({required this.result, required this.storagePath});

  final MealAnalysisResult result;

  /// Path inside the `meal-photos` bucket, e.g. `{userId}/{uuid}.jpg`.
  final String storagePath;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

@riverpod
MealAiService mealAiService(Ref ref) {
  // The notifier is read here, not inside the callback: screens `ref.read`
  // this autoDispose provider, so its ref is gone by the time a call returns.
  // CreditsController is keepAlive, so the notifier outlives every call.
  final credits = ref.read(creditsControllerProvider.notifier);
  return MealAiService(
    supabase: ref.watch(supabaseClientProvider),
    report: ref.watch(reportProvider),
    onCreditsChanged: credits.refresh,
    // Held by the service so a not-food count survives a disposed screen.
    analytics: ref.read(appExternalDepsProvider).analytics,
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Application-layer service for Mealvana AI AI meal analysis.
///
/// All network failures are mapped to [MealAiException] with a user-presentable
/// [MealAiException.userMessage] and a discriminated [MealAiFailureKind] so
/// the presentation layer can branch on the error type without string-matching.
class MealAiService {
  MealAiService({
    required SupabaseClient supabase,
    Report? report,
    Future<void> Function()? onCreditsChanged,
    AnalyticsTracker? analytics,
  }) : _supabase = supabase,
       _report = report,
       _onCreditsChanged = onCreditsChanged,
       _analytics = analytics;

  final SupabaseClient _supabase;
  final Report? _report;

  /// Where a not-food answer's `expected_failure` count goes (ticket 55).
  /// Null (a test, or no tracker): the count is a Sentry counter instead.
  final AnalyticsTracker? _analytics;

  /// Re-reads the credit balance after the server may have changed it: a 200
  /// (the function debited before answering) or a 402 (the balance the pill
  /// shows was stale). Fire-and-forget; the analysis result never waits on it.
  final Future<void> Function()? _onCreditsChanged;
  Report get _r => _report ?? SentryReport.global;
  static const _uuid = Uuid();
  static const _area = 'meal_logging';

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Upload [imageFile] to the `meal-photos` storage bucket and call the
  /// `analyze-meal-photo` edge function.
  ///
  /// Returns a [MealPhotoAnalysis] containing both the structured result and
  /// the storage path (for use in the meal log record).
  ///
  /// Throws [MealAiException] on any failure.
  ///
  /// When [description] is provided, the typed text is analyzed together with
  /// the photo as a single meal (one metered call).
  Future<MealPhotoAnalysis> analyzePhoto(
    File imageFile, {
    String? description,
  }) async {
    final userId = _requireUserId();
    final bytes = await imageFile.readAsBytes();
    return _analyzeBytes(
      userId: userId,
      bytes: bytes,
      extension: _extensionFromPath(imageFile.path),
      description: description,
    );
  }

  /// Web / byte-array variant of [analyzePhoto].
  ///
  /// Useful on platforms where [dart:io] `File` is not available, or when the
  /// image bytes are already in memory (e.g. from an image picker on web).
  Future<MealPhotoAnalysis> analyzePhotoBytes(
    Uint8List bytes, {
    String extension = 'jpg',
    String? description,
  }) async {
    final userId = _requireUserId();
    return _analyzeBytes(
      userId: userId,
      bytes: bytes,
      extension: extension,
      description: description,
    );
  }

  /// Call the `describe-meal` edge function with a free-text [description].
  ///
  /// Returns a [MealAnalysisResult]. Throws [MealAiException] on any failure.
  Future<MealAnalysisResult> describeMeal(String description) async {
    _requireUserId();

    try {
      final response = await _supabase.functions.invoke(
        'describe-meal',
        body: {'description': description},
      );

      return _parseAnalysisResponse(response, functionName: 'describe-meal');
    } on MealAiException {
      rethrow;
    } on InsufficientCreditsException {
      rethrow;
    } on SocketException catch (e) {
      throw MealAiException(
        kind: MealAiFailureKind.offline,
        userMessage:
            'No internet connection. Please check your network and try again.',
        debugMessage: e.toString(),
      );
    } on FunctionException catch (e) {
      throw await _mapFunctionException(e, functionName: 'describe-meal');
    } catch (e, st) {
      _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'describe-meal unexpected error',
      );
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Something went wrong. Please try again.',
        debugMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<MealPhotoAnalysis> _analyzeBytes({
    required String userId,
    required Uint8List bytes,
    required String extension,
    String? description,
  }) async {
    // 1. Strip EXIF (GPS, device, time) before anything leaves the device.
    final clean = await _sanitizePhoto(bytes, extension: extension);

    // 2. Upload to storage. The sanitized bytes are always JPEG.
    final photoPath = '$userId/${_uuid.v4()}.jpg';

    try {
      await _supabase.storage
          .from('meal-photos')
          .uploadBinary(
            photoPath,
            clean,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } on SocketException catch (e) {
      throw MealAiException(
        kind: MealAiFailureKind.offline,
        userMessage:
            'No internet connection. Please check your network and try again.',
        debugMessage: e.toString(),
      );
    } on StorageException catch (e, st) {
      _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'meal photo upload failed',
        extra: {'extension': extension, 'bytes': clean.length},
      );
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Could not upload the photo. Please try again.',
        debugMessage: 'StorageException: ${e.message}',
      );
    }

    // 3. Analyze via edge function
    try {
      final trimmedDescription = description?.trim();
      final response = await _supabase.functions.invoke(
        'analyze-meal-photo',
        body: {
          'photo_path': photoPath,
          if (trimmedDescription != null && trimmedDescription.isNotEmpty)
            'description': trimmedDescription,
        },
      );

      final result = _parseAnalysisResponse(
        response,
        functionName: 'analyze-meal-photo',
      );

      return MealPhotoAnalysis(result: result, storagePath: photoPath);
    } on MealAiException {
      rethrow;
    } on InsufficientCreditsException {
      rethrow;
    } on SocketException catch (e) {
      throw MealAiException(
        kind: MealAiFailureKind.offline,
        userMessage:
            'No internet connection. Please check your network and try again.',
        debugMessage: e.toString(),
      );
    } on FunctionException catch (e) {
      throw await _mapFunctionException(e, functionName: 'analyze-meal-photo');
    } catch (e, st) {
      _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: 'analyze-meal-photo unexpected error',
      );
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Something went wrong. Please try again.',
        debugMessage: e.toString(),
      );
    }
  }

  /// Parse a successful [FunctionResponse] into a [MealAnalysisResult].
  ///
  /// The edge function returns 422 when the image is not food. Any non-200
  /// status that is not 422 is treated as a server error.
  MealAnalysisResult _parseAnalysisResponse(
    FunctionResponse response, {
    required String functionName,
  }) {
    if (response.status == 422) {
      final message =
          _extractErrorMessage(response.data) ??
          "The photo doesn't appear to contain food. Please try a different image.";
      throw MealAiException(
        kind: MealAiFailureKind.notFood,
        userMessage: message,
        debugMessage: '422 from $functionName',
      );
    }

    // 402 → out of AI credits. Throw the typed exception so the presentation
    // layer can route the user to the buy-credits paywall.
    if (response.status == 402) {
      _creditsChanged(functionName);
      throw _insufficientCreditsFrom(response.data);
    }

    if (response.status != 200) {
      final message = _extractErrorMessage(response.data);
      _r.degraded(
        LoggedFault('$functionName returned status ${response.status}'),
        area: _area,
        extra: {'status': response.status, 'body': '${response.data}'},
      );
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage:
            message ?? 'The AI service returned an error. Please try again.',
        debugMessage: '$functionName returned status ${response.status}',
      );
    }

    // 200: the function debited before answering, so the balance is final.
    _creditsChanged(functionName);

    try {
      final data = response.data as Map<String, dynamic>;
      return MealAnalysisResult.fromJson(data);
    } catch (e, st) {
      _r.fault(
        e,
        stackTrace: st,
        area: _area,
        message: '$functionName response did not parse',
      );
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Received an unexpected response. Please try again.',
        debugMessage: 'Parse error from $functionName: $e',
      );
    }
  }

  /// Map a [FunctionException] from the Supabase client to a [MealAiException].
  Future<MealAiException> _mapFunctionException(
    FunctionException e, {
    required String functionName,
  }) async {
    // A not-food answer is the athlete's turn, free and expected (ticket 45;
    // ticket 55, 49-005): a note and one count, never degraded. Keyed on the
    // server's flag, not the status alone, so a future 422 meaning something
    // else still reports.
    if (isNotFoodAnswer(e)) {
      await _r.noteExpected(
        '$functionName: not food',
        area: _area,
        reason: 'not_food',
        analytics: _analytics,
        data: {'status': 422},
      );
      return _notFood(functionName);
    }

    // A too-long description is the athlete's turn too (ticket 79, 68-002):
    // keyed on describe-meal's flag, so any other 400 still reports.
    if (isTooLongAnswer(e)) {
      final details = e.details as Map;
      await _r.noteExpected(
        '$functionName: description too long',
        area: _area,
        reason: 'description_too_long',
        analytics: _analytics,
        data: {'status': 400, 'max_length': details['max_length']},
      );
      return MealAiException(
        kind: MealAiFailureKind.tooLong,
        userMessage: '',
        debugMessage:
            'FunctionException 400 (too_long, max ${details['max_length']}) '
            'from $functionName',
      );
    }

    // 402 is a business outcome (out of credits), not a failure.
    if (e.status != 402) {
      _r.degraded(
        e,
        area: _area,
        message: 'FunctionException from $functionName',
        extra: {'status': e.status},
      );
    }

    // 402 → out of AI credits. Throw the typed exception (this method's callers
    // `throw` its result, so throwing here propagates identically).
    if (e.status == 402) {
      _creditsChanged(functionName);
      throw _insufficientCreditsFrom(e.details);
    }

    // FunctionException.status is non-nullable (int).
    // A 422 with no flag (an older deployment) was reported above.
    if (e.status == 422) return _notFood(functionName);

    return MealAiException(
      kind: MealAiFailureKind.serverError,
      userMessage: 'The AI service returned an error. Please try again.',
      debugMessage: 'FunctionException ${e.status} from $functionName: $e',
    );
  }

  /// Whether [e] is describe-meal's or analyze-meal-photo's not-food answer:
  /// 422 with `not_food: true` in the body (`errorResponse`'s additional
  /// data, `_shared/responses.ts`).
  @visibleForTesting
  static bool isNotFoodAnswer(FunctionException e) {
    final details = e.details;
    return e.status == 422 && details is Map && details['not_food'] == true;
  }

  /// Whether [e] is describe-meal's too-long answer: 400 with
  /// `too_long: true` in the body (ticket 79).
  @visibleForTesting
  static bool isTooLongAnswer(FunctionException e) {
    final details = e.details;
    return e.status == 400 && details is Map && details['too_long'] == true;
  }

  static MealAiException _notFood(String functionName) => MealAiException(
    kind: MealAiFailureKind.notFood,
    userMessage:
        "The photo doesn't appear to contain food. Please try a different image.",
    debugMessage: 'FunctionException 422 from $functionName',
  );

  /// Kick off the credits refresh without waiting on it.
  void _creditsChanged(String functionName) {
    final refresh = _onCreditsChanged;
    if (refresh == null) return;
    unawaited(_refreshCredits(refresh, functionName));
  }

  Future<void> _refreshCredits(
    Future<void> Function() refresh,
    String functionName,
  ) async {
    try {
      await refresh();
    } catch (e, st) {
      // The pill keeps its old number until the next refresh; record it.
      await _r.degraded(
        e,
        stackTrace: st,
        area: _area,
        message: 'credits refresh after $functionName failed',
      );
    }
  }

  /// Build an [InsufficientCreditsException] from a 402 response body.
  InsufficientCreditsException _insufficientCreditsFrom(dynamic body) {
    final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
    return InsufficientCreditsException.fromMap(map);
  }

  /// Extract the `error` field from an edge function error JSON body.
  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return null;
  }

  /// Re-encode [bytes] without metadata (ticket 75: no GPS leaves the
  /// device). Runs off the UI isolate. An unreadable photo is recorded and
  /// nothing is uploaded: there is no fallback to the original bytes.
  Future<Uint8List> _sanitizePhoto(
    Uint8List bytes, {
    required String extension,
  }) async {
    try {
      return await compute(stripPhotoMetadata, bytes);
    } catch (e, st) {
      _r.degraded(
        e,
        stackTrace: st,
        area: _area,
        message: 'meal photo could not be re-encoded; not uploaded',
        extra: {'extension': extension, 'bytes': bytes.length},
      );
      throw MealAiException(
        kind: MealAiFailureKind.photoUnreadable,
        userMessage: '',
        debugMessage: e.toString(),
      );
    }
  }

  /// Ensure there is a signed-in user and return their ID.
  String _requireUserId() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'You must be signed in to use this feature.',
      );
    }
    return user.id;
  }

  /// Extract file extension from a path, defaulting to `jpg`. Reported on a
  /// failed sanitize; the upload is always `.jpg`.
  String _extensionFromPath(String path) {
    final ext = path.split('.').lastOrNull?.toLowerCase();
    return (ext != null && ext.isNotEmpty) ? ext : 'jpg';
  }
}
