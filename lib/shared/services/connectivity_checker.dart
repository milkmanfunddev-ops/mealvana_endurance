import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_checker.g.dart';

/// Answers "is the device online right now?" for controllers that must
/// refuse a remote-ack write while offline (write-consistency policy).
///
/// Wraps `connectivity_plus` behind a provider so tests can override it with
/// a stub instead of the platform channel. Same check `SyncCoordinator`
/// makes inline.
class ConnectivityChecker {
  const ConnectivityChecker();

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}

@Riverpod(keepAlive: true)
ConnectivityChecker connectivityChecker(Ref ref) => const ConnectivityChecker();
