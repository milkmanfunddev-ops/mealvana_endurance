/// `public.users.created_at` is the real instant (testing-wave 120-003,
/// 121-004). The column is `timestamp without time zone`: the app used to send
/// a local `DateTime`'s ISO string, which carries no offset, so PostgREST
/// stored a Chicago wall-clock as UTC (five hours early), and read the
/// zoneless answer back as local time (another shift).
///
/// Seam: the JSON the repository upserts, and a `users` row as PostgREST
/// returns it (no offset), never the model's own round trip.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';

UserProfile _profile({required DateTime createdAt}) => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.female,
  birthday: DateTime(1990, 6, 15),
  heightFeet: 5,
  heightInches: 6,
  weightPounds: 140,
  runsWithWaterBottle: false,
  createdAt: createdAt,
  updatedAt: createdAt,
  appVersion: '1.0.0',
);

void main() {
  test('toJson sends created_at and updated_at as UTC with an offset', () {
    // A local wall-clock time, as DateTime.now() hands it to the signup.
    final local = DateTime(2026, 9, 26, 12, 4, 11);
    final json = _profile(createdAt: local).toJson();

    expect(json['created_at'], local.toUtc().toIso8601String());
    expect(json['updated_at'], local.toUtc().toIso8601String());
    expect(json['created_at'], endsWith('Z'), reason: 'the offset is on the wire');
    expect(
      DateTime.parse(json['created_at'] as String).isAtSameMomentAs(local),
      isTrue,
      reason: 'the same instant, whatever zone reads it',
    );
  });

  group('parseServerTimestamp (seam: PostgREST wire strings)', () {
    test('a zoneless timestamp (users.created_at) is read as UTC', () {
      final parsed = parseServerTimestamp('2026-09-26T17:04:11.123');
      expect(parsed, DateTime.utc(2026, 9, 26, 17, 4, 11, 123));
      expect(parsed!.isUtc, isTrue);
    });

    test('a timestamptz string keeps its own zone', () {
      expect(
        parseServerTimestamp('2026-09-26T12:04:11-05:00'),
        DateTime.utc(2026, 9, 26, 17, 4, 11),
      );
      expect(
        parseServerTimestamp('2026-09-26T17:04:11Z'),
        DateTime.utc(2026, 9, 26, 17, 4, 11),
      );
      expect(
        parseServerTimestamp('2026-09-26T17:04:11+0000'),
        DateTime.utc(2026, 9, 26, 17, 4, 11),
      );
    });

    test('null, empty and garbage answer null', () {
      expect(parseServerTimestamp(null), isNull);
      expect(parseServerTimestamp(''), isNull);
      expect(parseServerTimestamp('yesterday'), isNull);
    });

    test('fromSupabaseRow reads the zoneless row as the instant it is', () {
      final row = <String, dynamic>{
        'id': 'u1',
        'device_id': 'd1',
        'gender': 'female',
        'birthday': '1990-06-15',
        'created_at': '2026-09-26T17:04:11.123456',
        'updated_at': '2026-09-26T17:04:11.123456',
        'gut_training_level': 'moderate',
      };
      final profile = UserProfile.fromSupabaseRow(row, fallbackId: 'u1');
      expect(profile.createdAt, DateTime.utc(2026, 9, 26, 17, 4, 11, 123, 456));
    });
  });
}
