import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/report/report.dart';
import '../../application/coach_service.dart';

part 'invite_athlete_controller.g.dart';

@riverpod
class InviteAthleteController extends _$InviteAthleteController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Send an invitation to an athlete
  Future<bool> inviteAthlete({required String athleteUserId}) async {
    state = const AsyncLoading();
    final coachService = _coachService;
    final report = ref.read(reportProvider);

    try {
      final relationship = await coachService.inviteAthlete(
        athleteUserId: athleteUserId,
      );

      if (ref.mounted) state = const AsyncData(null);
      return relationship != null;
    } catch (e, stack) {
      report.fault(
        e,
        stackTrace: stack,
        area: 'coach_mode',
        message: 'Invite athlete failed',
        extra: {'athleteUserId': athleteUserId},
      );
      if (ref.mounted) state = AsyncError(e, stack);
      return false;
    }
  }
}
