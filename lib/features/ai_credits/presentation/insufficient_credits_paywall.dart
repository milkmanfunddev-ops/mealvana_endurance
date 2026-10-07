import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/core/bootstrap/bootstrap.dart' show appNavigatorKey;
import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../domain/insufficient_credits_exception.dart';

/// Surfaces the AI-credits paywall when an AI call fails with a 402.
///
/// If [error] is an [InsufficientCreditsException], shows a dialog explaining
/// the balance shortfall and offering to open `/buy-credits`, then returns
/// `true` so the caller can stop its normal error handling. Returns `false`
/// for any other error.
///
/// Uses the global [appNavigatorKey] (the app router's navigator key) so it
/// works from controllers without a [BuildContext] as well as from widgets.
/// The dialog is scheduled on the next frame, making it safe to call from
/// `catch` blocks, `ref.listen` callbacks, and async gaps.
///
/// Every word comes from the content system (`ai_credits.out_*`), never from
/// the server's English `message` (round develop-2026-10, ticket 23).
bool maybeShowInsufficientCreditsPaywall(Object? error) {
  if (error is! InsufficientCreditsException) return false;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => const InsufficientCreditsDialog(),
    );
  });
  // A post-frame callback waits for a frame; make sure one comes even when
  // nothing on screen changed (a controller with no listening widget).
  WidgetsBinding.instance.ensureVisualUpdate();

  return true;
}

/// The Out of AI credits dialog. "Get credits" opens `/buy-credits`.
class InsufficientCreditsDialog extends ConsumerWidget {
  const InsufficientCreditsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentServiceProvider);
    return AlertDialog(
      title: Text(content.getValue(ContentKeys.aiCreditsOutTitle)),
      content: Text(content.getValue(ContentKeys.aiCreditsOutBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(content.getValue(ContentKeys.aiCreditsOutNotNow)),
        ),
        FilledButton(
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/buy-credits');
          },
          child: Text(content.getValue(ContentKeys.aiCreditsOutGetCredits)),
        ),
      ],
    );
  }
}
