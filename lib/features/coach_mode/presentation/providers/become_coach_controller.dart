import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';

part 'become_coach_controller.g.dart';

/// Result of attempting to redeem an invite code
class RedeemCodeResult {
  final bool success;
  final String? message;
  final String? error;

  const RedeemCodeResult({
    required this.success,
    this.message,
    this.error,
  });

  factory RedeemCodeResult.success([String? message]) {
    return RedeemCodeResult(
      success: true,
      message: message ?? 'Welcome! You are now a coach.',
    );
  }

  factory RedeemCodeResult.failure(String error) {
    return RedeemCodeResult(
      success: false,
      error: error,
    );
  }
}

@riverpod
class BecomeCoachController extends _$BecomeCoachController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Attempt to redeem an invite code and become a coach
  Future<RedeemCodeResult> redeemInviteCode(String code) async {
    state = const AsyncLoading();

    try {
      final result = await _coachService.redeemCoachInviteCode(code);

      state = const AsyncData(null);

      if (result['success'] == true) {
        return RedeemCodeResult.success(result['message'] as String?);
      } else {
        return RedeemCodeResult.failure(
          result['error'] as String? ?? 'Failed to redeem code',
        );
      }
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return RedeemCodeResult.failure(e.toString());
    }
  }
}
