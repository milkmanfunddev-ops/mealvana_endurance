import 'package:flutter/material.dart';

import '../../../main.dart' show sentryNavigatorKey;
import '../domain/insufficient_credits_exception.dart';
import 'sheets/token_top_up_sheet.dart';

/// The one client handler for a 402 (mp-282 §3).
///
/// Every debiting call — describe-meal, the photo analysis, the coach
/// insight, the coach chat, the Vana composer — maps the server's 402 to an
/// [InsufficientCreditsException] and hands it here. The answer is always the
/// top-up sheet (what the allowance is, when it renews, the two packs), never
/// a gate: the person stays in the app with everything that does not debit
/// (mp-282 §1). A new debiting feature calls this and gets the sheet for free.
///
/// Returns `true` when [error] was a 402 and the sheet was raised, so the
/// caller can stop its normal error handling; `false` for any other error.
///
/// [context] is the caller's when it has one (a screen); controllers without
/// one fall back to the app router's navigator ([sentryNavigatorKey]). The
/// sheet is scheduled on the next frame, making this safe to call from
/// `catch` blocks, `ref.listen` callbacks, and async gaps.
bool handleInsufficientCredits(Object? error, {BuildContext? context}) {
  if (error is! InsufficientCreditsException) return false;
  showInsufficientCreditsSheet(context: context);
  return true;
}

/// Whether the sheet is up. A second 402 while it is showing (two calls in
/// flight, a retry) must not stack a second sheet on the first.
bool _sheetShowing = false;

/// Forget a sheet a previous widget tree left up (tests tear the tree down
/// without popping the modal, so its future never completes).
@visibleForTesting
void debugResetInsufficientCreditsSheet() => _sheetShowing = false;

/// Raise the top-up sheet for an empty wallet, from a screen or a controller.
///
/// Split from [handleInsufficientCredits] for the callers that only know
/// *that* the wallet was empty (the Vana screen sees a
/// `VanaChatErrorKind`, not the exception).
void showInsufficientCreditsSheet({BuildContext? context}) {
  if (_sheetShowing) return;
  _sheetShowing = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final ctx = context ?? sentryNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _sheetShowing = false;
      return;
    }
    try {
      await showTokenTopUpSheet(ctx);
    } finally {
      _sheetShowing = false;
    }
  });
}
