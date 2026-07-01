import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../main.dart' show sentryNavigatorKey;
import '../domain/insufficient_credits_exception.dart';

/// Surfaces the AI-credits paywall when an AI call fails with a 402.
///
/// If [error] is an [InsufficientCreditsException], shows a dialog explaining
/// the balance shortfall and offering to open `/buy-credits`, then returns
/// `true` so the caller can stop its normal error handling. Returns `false`
/// for any other error.
///
/// Uses the global [sentryNavigatorKey] (the app router's navigator key) so it
/// works from controllers without a [BuildContext] as well as from widgets.
/// The dialog is scheduled on the next frame, making it safe to call from
/// `catch` blocks, `ref.listen` callbacks, and async gaps.
bool maybeShowInsufficientCreditsPaywall(Object? error) {
  if (error is! InsufficientCreditsException) return false;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = sentryNavigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Out of AI credits'),
        content: Text(
          error.message.trim().isNotEmpty
              ? error.message
              : "You've used all your AI credits. Get more to keep using AI "
                  'features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              GoRouter.of(dialogContext).push('/buy-credits');
            },
            child: const Text('Get credits'),
          ),
        ],
      ),
    );
  });

  return true;
}
