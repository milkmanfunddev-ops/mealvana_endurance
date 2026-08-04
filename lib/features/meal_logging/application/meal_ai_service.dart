import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/meal_analysis_result.dart';

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
  return MealAiService(supabase: ref.watch(supabaseClientProvider));
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
  MealAiService({required SupabaseClient supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;
  static const _uuid = Uuid();

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
  Future<MealPhotoAnalysis> analyzePhoto(File imageFile) async {
    final userId = _requireUserId();
    final bytes = await imageFile.readAsBytes();
    return _analyzeBytes(
      userId: userId,
      bytes: bytes,
      extension: _extensionFromPath(imageFile.path),
    );
  }

  /// Web / byte-array variant of [analyzePhoto].
  ///
  /// Useful on platforms where [dart:io] `File` is not available, or when the
  /// image bytes are already in memory (e.g. from an image picker on web).
  Future<MealPhotoAnalysis> analyzePhotoBytes(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final userId = _requireUserId();
    return _analyzeBytes(userId: userId, bytes: bytes, extension: extension);
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
      throw _mapFunctionException(e, functionName: 'describe-meal');
    } catch (e) {
      if (kDebugMode)
        debugPrint('[MealAiService] describe-meal unexpected error: $e');
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
  }) async {
    // 1. Upload to storage
    final photoPath = '$userId/${_uuid.v4()}.$extension';

    try {
      await _supabase.storage
          .from('meal-photos')
          .uploadBinary(
            photoPath,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeFromExtension(extension),
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
    } on StorageException catch (e) {
      if (kDebugMode) debugPrint('[MealAiService] Storage upload error: $e');
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Could not upload the photo. Please try again.',
        debugMessage: 'StorageException: ${e.message}',
      );
    }

    // 2. Analyze via edge function
    try {
      final response = await _supabase.functions.invoke(
        'analyze-meal-photo',
        body: {'photo_path': photoPath},
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
      throw _mapFunctionException(e, functionName: 'analyze-meal-photo');
    } catch (e) {
      if (kDebugMode)
        debugPrint('[MealAiService] analyze-meal-photo unexpected error: $e');
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
      throw _insufficientCreditsFrom(response.data);
    }

    if (response.status != 200) {
      final message = _extractErrorMessage(response.data);
      if (kDebugMode) {
        debugPrint(
          '[MealAiService] $functionName status ${response.status}: ${response.data}',
        );
      }
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage:
            message ?? 'The AI service returned an error. Please try again.',
        debugMessage: '$functionName returned status ${response.status}',
      );
    }

    try {
      final data = response.data as Map<String, dynamic>;
      return MealAnalysisResult.fromJson(data);
    } catch (e) {
      if (kDebugMode)
        debugPrint('[MealAiService] $functionName parse error: $e');
      throw MealAiException(
        kind: MealAiFailureKind.serverError,
        userMessage: 'Received an unexpected response. Please try again.',
        debugMessage: 'Parse error from $functionName: $e',
      );
    }
  }

  /// Map a [FunctionException] from the Supabase client to a [MealAiException].
  MealAiException _mapFunctionException(
    FunctionException e, {
    required String functionName,
  }) {
    if (kDebugMode)
      debugPrint('[MealAiService] FunctionException from $functionName: $e');

    // 402 → out of AI credits. Throw the typed exception (this method's callers
    // `throw` its result, so throwing here propagates identically).
    if (e.status == 402) {
      throw _insufficientCreditsFrom(e.details);
    }

    // FunctionException.status is non-nullable (int).
    if (e.status == 422) {
      return MealAiException(
        kind: MealAiFailureKind.notFood,
        userMessage:
            "The photo doesn't appear to contain food. Please try a different image.",
        debugMessage: 'FunctionException 422 from $functionName',
      );
    }

    return MealAiException(
      kind: MealAiFailureKind.serverError,
      userMessage: 'The AI service returned an error. Please try again.',
      debugMessage: 'FunctionException ${e.status} from $functionName: $e',
    );
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

  /// Extract file extension from a path, defaulting to `jpg`.
  String _extensionFromPath(String path) {
    final ext = path.split('.').lastOrNull?.toLowerCase();
    return (ext != null && ext.isNotEmpty) ? ext : 'jpg';
  }

  /// Map a file extension to a MIME type string.
  String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
