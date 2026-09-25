import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// The running build as `version+build` ("1.27.1+4"), the way Sentry's user
/// context reads it (`AppStartupService.setSentryUserContext`). Read once
/// per session; `null` when the platform cannot say, so a row that carries
/// it is never refused for it.
@Riverpod(keepAlive: true)
Future<String?> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (_) {
    return null;
  }
}
