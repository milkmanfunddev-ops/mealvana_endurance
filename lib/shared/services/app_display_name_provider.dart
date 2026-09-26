import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The name the installed app carries on the device: `CFBundleDisplayName`
/// on iOS, the launcher label on Android. The dev build is "Endurance Dev",
/// prod is "Mealvana", so a message that sends the athlete to the app's row
/// in iOS Settings reads this rather than a fixed name (testing-wave
/// 120-005). [kDefaultAppDisplayName] stands in until the platform answers.
final appDisplayNameProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final name = info.appName.trim();
  return name.isEmpty ? kDefaultAppDisplayName : name;
});

/// The shipped name, for the moment before the platform answers and for
/// tests that never ask it.
const String kDefaultAppDisplayName = 'Mealvana';
