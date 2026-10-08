import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/meal_ai_service.dart';
import '../../domain/meal_analysis_result.dart';

part 'describe_analysis_controller.g.dart';

/// The paid answer to one Analyze on Log a Meal → Describe, kept with the
/// input that bought it.
class DescribeAnalysis {
  const DescribeAnalysis({
    required this.inputText,
    required this.result,
    this.photoPath,
    this.storagePath,
  });

  /// The typed text, trimmed, as it was sent.
  final String inputText;

  /// The local path of the attached photo, when one was sent.
  final String? photoPath;

  final MealAnalysisResult result;

  /// Where the photo was uploaded (`meal-photos` bucket), for the logged row.
  final String? storagePath;

  /// Whether this analysis answers [text] (trimmed) with [photoPath].
  bool isFor({required String text, String? photoPath}) =>
      inputText == text.trim() && this.photoPath == photoPath;
}

/// Holds the Describe tab's last analysis for as long as Log a Meal is open
/// (testing-wave develop-2026-10 ticket 45, Finding 31-004).
///
/// `LogMealScreen` watches it, so it survives tab switches and the Review &
/// Log route pushed on top, and auto-dispose drops it when Log a Meal closes.
/// Back from Review and "Review again" re-open the stored result without a
/// second call, so seeing it again costs nothing. A changed input is a new
/// call (and a new token).
@riverpod
class DescribeAnalysisController extends _$DescribeAnalysisController {
  /// The call in flight and the input it answers, so a second [analyze] for
  /// the same input joins it instead of paying twice.
  Future<DescribeAnalysis>? _inFlight;
  String? _inFlightKey;

  @override
  FutureOr<DescribeAnalysis?> build() {
    // Riverpod can reuse the notifier across a rebuild; start clean.
    _inFlight = null;
    _inFlightKey = null;
    return null;
  }

  /// The stored analysis when it answers this exact input, else null.
  DescribeAnalysis? storedFor({required String text, XFile? photo}) {
    final stored = state.value;
    if (stored == null) return null;
    return stored.isFor(text: text, photoPath: photo?.path) ? stored : null;
  }

  /// Analyze [text] (and [photo], when attached) through [MealAiService].
  ///
  /// Returns the stored analysis without a call when the input is unchanged.
  /// Otherwise one call runs inside [AsyncValue.guard]; its outcome is stored
  /// and returned, so the caller branches on [AsyncError.error]
  /// ([MealAiException], `InsufficientCreditsException`) without a second
  /// read. A concurrent call for the same input joins the one in flight; when
  /// a newer input has started since, the older answer is returned but not
  /// stored.
  Future<AsyncValue<DescribeAnalysis>> analyze({
    required String text,
    XFile? photo,
  }) async {
    final stored = storedFor(text: text, photo: photo);
    if (stored != null) return AsyncData(stored);

    final trimmed = text.trim();
    final key = '${photo?.path}\u0000$trimmed';
    final joining = _inFlight != null && _inFlightKey == key;
    final call = joining ? _inFlight! : _call(trimmed, photo);
    if (!joining) {
      _inFlight = call;
      _inFlightKey = key;
      state = const AsyncLoading<DescribeAnalysis?>();
    }

    final outcome = await AsyncValue.guard(() => call);
    // Log a Meal closed mid-call: nothing is left to keep the answer for.
    if (!ref.mounted) return outcome;
    if (_inFlightKey == key) {
      _inFlight = null;
      _inFlightKey = null;
      // A failed call stays out of notifier state: `MealAiService` has
      // already reported the cause and the Describe tab notes the outcome,
      // and `SentryProviderObserver` would otherwise fault the wrapper with
      // no area (31-003's "my bike ride" is an expected answer, not an
      // event). The caller gets the error from the returned outcome.
      state = outcome.hasError
          ? AsyncData<DescribeAnalysis?>(state.value)
          : outcome;
    }
    return outcome;
  }

  /// Forget the stored analysis (after the meal is logged).
  void clear() {
    _inFlight = null;
    _inFlightKey = null;
    state = const AsyncData(null);
  }

  Future<DescribeAnalysis> _call(String text, XFile? photo) async {
    final service = ref.read(mealAiServiceProvider);
    if (photo == null) {
      final result = await service.describeMeal(text);
      return DescribeAnalysis(inputText: text, result: result);
    }
    // Photo (with the typed text riding along, if any) — one analysis, one
    // token.
    final description = text.isEmpty ? null : text;
    final MealPhotoAnalysis analysis;
    if (kIsWeb) {
      final bytes = await photo.readAsBytes();
      final parts = photo.name.split('.');
      final ext = (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
      analysis = await service.analyzePhotoBytes(
        bytes,
        extension: ext,
        description: description,
      );
    } else {
      analysis = await service.analyzePhoto(
        File(photo.path),
        description: description,
      );
    }
    return DescribeAnalysis(
      inputText: text,
      photoPath: photo.path,
      result: analysis.result,
      storagePath: analysis.storagePath,
    );
  }
}
