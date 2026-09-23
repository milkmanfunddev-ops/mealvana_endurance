/// A Code entry controller for screen tests: records each Code sent and
/// answers with [answer] (a [CodeRedemption], or a [CodeRedeemFailure] that
/// lands as the state's error), the way the real controller leaves its state.
/// The real one is covered through `redeem-code`'s own answers in
/// `application/code_entry_controller_test.dart`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/features/subscription/application/code_entry_controller.dart';
import 'package:mealvana_endurance/features/subscription/domain/code_redemption.dart';

class RecordingCodeEntry extends CodeEntryController {
  RecordingCodeEntry(this.answer);

  /// What the next redemption answers.
  Object answer;
  final sent = <String>[];

  @override
  FutureOr<CodeRedemption?> build() => null;

  @override
  Future<CodeRedemption?> redeem(String code) async {
    sent.add(code.trim());
    final a = answer;
    if (a is CodeRedeemFailure) {
      state = AsyncError(a, StackTrace.empty);
      return null;
    }
    state = AsyncData(a as CodeRedemption);
    return a;
  }
}
