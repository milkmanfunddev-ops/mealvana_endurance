/// The 7-tap "Mark this device as internal" switch, fixed for a test.
///
/// Every widget test that renders a Tester-gated surface needs this: a debug
/// test build is *forced* internal ([InternalDeviceFlagNotifier.isForced]), so
/// an unoverridden test renders the Tester's screen and silently calls it the
/// athlete's.
library;

import 'package:mealvana_endurance/shared/services/analytics/internal_user_service.dart';

class StubInternalDeviceFlag extends InternalDeviceFlagNotifier {
  StubInternalDeviceFlag(this._isInternal);

  final bool _isInternal;

  @override
  bool build() => _isInternal;
}
