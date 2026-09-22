import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../../subscription/application/write_guard.dart';

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
    await requireWriteAccess(ref);
    state = const AsyncLoading();

    try {
      final relationship = await _coachService.inviteAthlete(
        athleteUserId: athleteUserId,
      );

      state = const AsyncData(null);
      return relationship != null;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }
}
