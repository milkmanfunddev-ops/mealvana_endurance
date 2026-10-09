// Ticket 75 (Findings 68-004 / 68-005): meal photos leave the device with no
// EXIF. The fixtures are written by PIL, not by the `image` package the code
// uses, in the shape image_picker hands over: Orientation 6, a GPS IFD at a
// neutral point, Make/Model/DateTime.
//
// Plain `test()` only: `compute` does not resolve under `pumpAndSettle`.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_photo_sanitizer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockBucket extends Mock implements StorageFileApi {}

const _jpegFixture = 'test/fixtures/meal_photos/gps_orientation6.jpg';
const _pngFixture = 'test/fixtures/meal_photos/gps_orientation6.png';

/// True when the JPEG holds an APP1 segment that starts `Exif\0\0`.
bool _hasExifApp1(Uint8List jpeg) {
  expect(jpeg[0], 0xFF);
  expect(jpeg[1], 0xD8, reason: 'not a JPEG (no SOI)');
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) return false;
    final marker = jpeg[i + 1];
    if (marker == 0xDA || marker == 0xD9) return false; // SOS / EOI
    final len = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (marker == 0xE1 &&
        i + 10 <= jpeg.length &&
        String.fromCharCodes(jpeg.sublist(i + 4, i + 8)) == 'Exif' &&
        jpeg[i + 8] == 0 &&
        jpeg[i + 9] == 0) {
      return true;
    }
    i += 2 + len;
  }
  return false;
}

bool _isRed(img.Pixel p) => p.r > 180 && p.g < 80 && p.b < 80;
bool _isGreen(img.Pixel p) => p.g > 120 && p.r < 90 && p.b < 90;

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  test('the PIL fixture really carries EXIF (guards the test itself)', () {
    final raw = File(_jpegFixture).readAsBytesSync();
    expect(_hasExifApp1(raw), isTrue);
    final decoded = img.decodeJpg(raw)!;
    expect(decoded.exif.gpsIfd.isEmpty, isFalse);
    // The JPEG decoder applies Orientation 6 itself (and drops the tag), so
    // the 64x48 stored pixels decode as 48x64.
    expect(decoded.width, 48);
    expect(decoded.height, 64);
  });

  group('MealAiService photo upload', () {
    late _MockSupabaseClient supabase;
    late _MockGoTrueClient auth;
    late _MockFunctions functions;
    late _MockBucket bucket;
    late RecordingReport report;
    late MealAiService service;

    Uint8List? uploaded;
    String? uploadedPath;
    FileOptions? uploadedOptions;

    setUp(() {
      supabase = _MockSupabaseClient();
      auth = _MockGoTrueClient();
      functions = _MockFunctions();
      final storage = _MockStorage();
      bucket = _MockBucket();
      uploaded = null;
      uploadedPath = null;
      uploadedOptions = null;

      when(() => supabase.auth).thenReturn(auth);
      when(() => supabase.functions).thenReturn(functions);
      when(() => supabase.storage).thenReturn(storage);
      when(() => storage.from('meal-photos')).thenReturn(bucket);
      when(() => auth.currentUser).thenReturn(
        User(
          id: 'user-abc',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      when(
        () => bucket.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((inv) async {
        uploadedPath = inv.positionalArguments[0] as String;
        uploaded = inv.positionalArguments[1] as Uint8List;
        uploadedOptions = inv.namedArguments[#fileOptions] as FileOptions;
        return uploadedPath!;
      });
      when(
        () => functions.invoke('analyze-meal-photo', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => FunctionResponse(
          status: 200,
          data: {
            'name': 'Toast',
            'suggested_slot': 'breakfast',
            'confidence': 'high',
            'items': [
              {
                'name': 'Toast',
                'portion': '1 slice',
                'calories': 80,
                'carb_g': 15.0,
                'protein_g': 3.0,
                'fat_g': 1.0,
                'sodium_mg': 150.0,
              },
            ],
            'totals': {
              'calories': 80,
              'carb_g': 15.0,
              'protein_g': 3.0,
              'fat_g': 1.0,
              'sodium_mg': 150.0,
            },
          },
        ),
      );

      report = RecordingReport();
      service = MealAiService(supabase: supabase, report: report);
    });

    void expectCleanUprightJpeg() {
      expect(uploaded, isNotNull, reason: 'nothing was uploaded');
      expect(_hasExifApp1(uploaded!), isFalse, reason: 'EXIF went up');
      expect(uploadedPath, endsWith('.jpg'));
      expect(uploadedOptions!.contentType, 'image/jpeg');

      final out = img.decodeJpg(uploaded!)!;
      expect(out.exif.isEmpty, isTrue);
      // 64x48 stored + Orientation 6 → 48x64 upright.
      expect(out.width, 48);
      expect(out.height, 64);
      // Red block stored top-left lands top-right after the 90° turn.
      expect(_isRed(out.getPixel(44, 4)), isTrue);
      expect(_isGreen(out.getPixel(4, 4)), isTrue);
      expect(_isGreen(out.getPixel(24, 50)), isTrue);
    }

    test(
      'analyzePhotoBytes uploads a JPEG with no EXIF, rotation applied',
      () async {
        final raw = File(_jpegFixture).readAsBytesSync();
        final analysis = await service.analyzePhotoBytes(raw);

        expectCleanUprightJpeg();
        expect(analysis.storagePath, uploadedPath);
        expect(analysis.result.name, 'Toast');
        expect(report.calls.where((c) => c.severity != 'info'), isEmpty);
      },
    );

    test('analyzePhoto(File) goes through the same sanitizer', () async {
      await service.analyzePhoto(File(_jpegFixture));
      expectCleanUprightJpeg();
    });

    test('a PNG with an eXIf chunk uploads as a metadata-free .jpg', () async {
      final raw = File(_pngFixture).readAsBytesSync();
      await service.analyzePhotoBytes(raw, extension: 'png');

      expect(uploaded, isNotNull);
      expect(_hasExifApp1(uploaded!), isFalse);
      expect(uploadedPath, endsWith('.jpg'));
      expect(uploadedOptions!.contentType, 'image/jpeg');
      final out = img.decodeJpg(uploaded!)!;
      expect(out.exif.isEmpty, isTrue);
      expect(out.width * out.height, 64 * 48);
    });

    test(
      'unreadable bytes: photoUnreadable, one degraded, nothing uploaded',
      () async {
        await expectLater(
          () => service.analyzePhotoBytes(Uint8List(0)),
          throwsA(
            isA<MealAiException>().having(
              (e) => e.kind,
              'kind',
              MealAiFailureKind.photoUnreadable,
            ),
          ),
        );
        expect(report.degradeds, hasLength(1));
        expect(report.degradeds.single.area, 'meal_logging');
        verifyNever(
          () => bucket.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        );
      },
    );
  });

  group('stripPhotoMetadata', () {
    test('garbage bytes throw MealPhotoUnreadable', () {
      expect(
        () => stripPhotoMetadata(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<MealPhotoUnreadable>()),
      );
    });
  });

  group('benchmark fixtures (68-005)', () {
    final dir = Directory('benchmarks/ai-model-benchmark-2026-07/images');
    final jpegs = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.jpg'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];

    test('all ten benchmark JPEGs are present', () {
      expect(jpegs, hasLength(10));
    });

    for (final f in jpegs) {
      test('${f.uri.pathSegments.last} carries no EXIF / GPS', () {
        expect(_hasExifApp1(f.readAsBytesSync()), isFalse);
      });
    }
  });
}
