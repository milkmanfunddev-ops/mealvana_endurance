import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';

void main() {
  group('Allergy.toJsonList', () {
    test('returns empty list for empty input', () {
      expect(Allergy.toJsonList(const []), <String>[]);
    });

    test('emits dbValue strings (not the PG-literal "{a,b}" form)', () {
      // Regression: Supabase column `users.allergies` is `allergy_enum[]`.
      // PostgREST silently drops the PG-literal string form, so uploads must
      // send a real JSON array of dbValue strings.
      final result = Allergy.toJsonList(const [Allergy.dairy, Allergy.gluten]);
      expect(result, ['dairy', 'gluten']);
      // Specifically, must NOT be a single string like "{dairy,gluten}".
      expect(result, isA<List<String>>());
      expect(result.length, 2);
    });

    test(
      'round-trips through fromDbArray when stored locally as PG-literal',
      () {
        // Local Drift uses toDbArray ("{dairy,gluten}"); the sync handler parses
        // that back via fromDbArray and re-emits via toJsonList for upload.
        final stored = Allergy.toDbArray(const [Allergy.dairy, Allergy.gluten]);
        final parsed = Allergy.fromDbArray(stored);
        final forUpload = Allergy.toJsonList(parsed);
        expect(forUpload, ['dairy', 'gluten']);
      },
    );
  });
}
