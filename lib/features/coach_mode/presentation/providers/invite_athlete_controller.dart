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

    try {
      final relationship = await _coachService.inviteAthlete(
        athleteUserId: athleteUserId,
      );

      state = const AsyncData(null);
      return relationship != null;
    } catch (e, stack) {
      ref
          .read(reportProvider)
          .fault(
            e,
            stackTrace: stack,
            area: 'coach_mode',
            message: 'Invite athlete failed',
            extra: {'athleteUserId': athleteUserId},
          );
      state = AsyncError(e, stack);
      return false;
    }
  }
}
