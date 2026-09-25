import 'package:flutter/widgets.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../data/vana_exceptions.dart';

/// The one line a failed remote-ack write shows: "Needs a connection" when
/// it never reached the server ([isConnectionFailure]), else the server
/// error. The screen stays as it was either way (testing-wave 129).
void showWriteFailure(
  BuildContext context,
  ContentService content,
  Object error,
) {
  if (isConnectionFailure(error)) {
    MealvanaSnackbar.showWarning(
      context,
      content.getValue(ContentKeys.mpNeedsConnection),
    );
  } else {
    MealvanaSnackbar.showError(
      context,
      content.getValue(ContentKeys.mpServerError),
    );
  }
}
