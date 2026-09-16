import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/meal_photo.dart';
import '../domain/meal_photo_history.dart';
import '../domain/wire_record.dart';
import 'vana_exceptions.dart';

part 'meal_photo_repository.g.dart';

@riverpod
MealPhotoRepository mealPhotoRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return MealPhotoRepository(
    supabase: deps.supabaseClient,
    logger: deps.logger,
  );
}

/// A Tester's photo changes, through the `meal-photo` edge function.
///
/// Remote-ack only, by design (ADR 0003): there is no local write, no Drift
/// mirror and no upload queue. A photograph every athlete will see must not
/// publish later, unwatched, from a queue — so with no signal this throws and
/// nothing is remembered.
///
/// The function re-checks `users.is_internal` on every call. The hidden entry
/// point in the app is convenience; this 403 is the gate.
class MealPhotoRepository {
  MealPhotoRepository({
    required SupabaseClient supabase,
    required AppLogger logger,
  }) : _supabase = supabase,
       _logger = logger;

  final SupabaseClient _supabase;
  final AppLogger _logger;

  static const _function = 'meal-photo';
  static const _context = 'MEAL_PHOTO';

  /// The Meal's current photo and its History, newest first.
  Future<MealPhotos> history(String mealId) async {
    final body = await _call({'action': 'history', 'meal_id': mealId});
    return MealPhotos.fromJson(body);
  }

  /// Publish a web address as this Meal's photo. The server checks that the
  /// address really answers with an image before anything is written.
  ///
  /// Answers the History row the server wrote — its id, its account and its
  /// clock — so the caller can show the new photograph without a second read
  /// and without inventing any of it.
  Future<MealPhotoHistoryEntry> addAddress({
    required String mealId,
    required String url,
    String? credit,
    String? creditUrl,
  }) async {
    final body = await _call({
      'action': 'add_address',
      'meal_id': mealId,
      'url': url.trim(),
      'credit': credit?.trim(),
      'credit_url': creditUrl?.trim(),
    });

    // Parsed by the same reader the `history` list uses, so a row that reaches
    // the page from an add is the row it would have read back.
    final entry = MealPhotoHistoryEntry.fromJsonOrNull(asJsonMap(body['entry']));
    if (entry == null) {
      _logger.error(
        'meal-photo add_address acked without a usable History row',
        context: _context,
      );
      throw const MealPhotoException('server_error');
    }
    return entry;
  }

  /// Publish prepared bytes as this Meal's photo.
  ///
  /// [bytes] are what `prepareDishPhoto` produced — already cropped, shrunk
  /// and stripped of EXIF. Nothing here re-encodes them, so the photograph
  /// athletes get is the one the Tester previewed, and the location data is
  /// gone before the phone opens a socket rather than after the server
  /// receives it.
  ///
  /// Sent as base64 inside the JSON body: the function takes one JSON shape
  /// for every action, and a prepared photo is a few hundred KB, well inside
  /// what an edge function accepts.
  Future<MealPhotoHistoryEntry> addUpload({
    required String mealId,
    required Uint8List bytes,
    String? credit,
    String? creditUrl,
  }) async {
    final body = await _call({
      'action': 'add_upload',
      'meal_id': mealId,
      'data': base64Encode(bytes),
      'credit': credit?.trim(),
      'credit_url': creditUrl?.trim(),
    });

    final entry = MealPhotoHistoryEntry.fromJsonOrNull(asJsonMap(body['entry']));
    if (entry == null) {
      _logger.error(
        'meal-photo add_upload acked without a usable History row',
        context: _context,
      );
      throw const MealPhotoException('server_error');
    }
    return entry;
  }

  /// Take the current photograph down. The Meal then shows nothing, and every
  /// photograph stays in History — including the one just removed.
  ///
  /// Answers null, always: the Meal's new current photo, in the same shape
  /// every other action answers it.
  Future<MealPhoto?> remove(String mealId) async {
    final body = await _call({'action': 'remove', 'meal_id': mealId});
    return MealPhoto.fromJsonOrNull(asJsonMap(body['photo']));
  }

  /// Put a History row back on as the Meal's photograph.
  ///
  /// Answers the photograph the server wrote, rather than the one the page had
  /// in hand: the credit and address shown are then the ones athletes get, even
  /// if this device's History was stale.
  Future<MealPhoto> restore({
    required String mealId,
    required String photoId,
  }) async {
    final body = await _call({
      'action': 'restore',
      'meal_id': mealId,
      'photo_id': photoId,
    });
    final photo = MealPhoto.fromJsonOrNull(asJsonMap(body['photo']));
    if (photo == null) {
      _logger.error(
        'meal-photo restore acked without a photo',
        context: _context,
      );
      throw const MealPhotoException('server_error');
    }
    return photo;
  }

  /// Delete a photograph for good — out of History, and out of our storage when
  /// the file was ours.
  ///
  /// Answers what the Meal shows afterwards: null when the deleted photograph
  /// was the one being worn.
  Future<MealPhoto?> deletePhoto({
    required String mealId,
    required String photoId,
  }) async {
    final body = await _call({
      'action': 'delete',
      'meal_id': mealId,
      'photo_id': photoId,
    });
    return MealPhoto.fromJsonOrNull(asJsonMap(body['photo']));
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final result = await _supabase.functions.invoke(_function, body: body);
      final data = Map<String, dynamic>.from(result.data as Map);
      // A 2xx body carrying `error` should not exist, but a function that
      // changes shape must not be read as a success.
      if (data['error'] case final String code) {
        throw MealPhotoException(code);
      }
      return data;
    } on FunctionException catch (e) {
      final code = e.details is Map
          ? (e.details as Map)['error'] as String? ?? 'server_error'
          : 'server_error';
      _logger.warning(
        'meal-photo ${body['action']} refused: $code',
        context: _context,
        data: {'status': e.status},
      );
      if (e.status == 401) throw VanaUnauthenticatedException(code);
      throw MealPhotoException(code);
    } on SocketException catch (e) {
      throw VanaOfflineException(e);
    } on http.ClientException catch (e) {
      throw VanaOfflineException(e);
    } on TimeoutException catch (e) {
      throw VanaOfflineException(e);
    }
  }
}
