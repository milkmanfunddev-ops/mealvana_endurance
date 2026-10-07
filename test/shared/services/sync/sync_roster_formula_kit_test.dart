/// Ticket 102: `personal_formulas` and `personal_templates` write locally
/// with `needs_upload` and belong in the dirty-record upload roster, or a
/// formula or template written offline never retries.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

void main() {
  test('the Formula Kit repositories have a dirty-upload retry channel', () {
    expect(
      SyncCoordinator.syncableRepositoryKeysForTesting,
      containsAll(<String>['personal_formulas', 'personal_templates']),
    );
  });
}
