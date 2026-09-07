import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../application/shopping_list_controller.dart';

/// Shares the confirmed plan's shopping list as plain text. Lives in the
/// Food screen's header beside the settings gear (2026-09-03 — moved from
/// the bottom of the list), so it renders its own share origin.
class ShoppingShareButton extends ConsumerWidget {
  const ShoppingShareButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final shareTitle = content.getValue(ContentKeys.mpShoppingShareTitle);
    final shareAction = content.getValue(ContentKeys.mpShoppingShareAction);

    return IconButton(
      key: const ValueKey('meal_planning.shopping_share'),
      onPressed: () {
        final state = ref.read(shoppingListControllerProvider).value;
        if (state == null || state.isEmpty) return;
        final summary = ContentKeys.format(
          content.getValue(
            state.itemCount == 1
                ? ContentKeys.mpShoppingShareSummaryOne
                : ContentKeys.mpShoppingShareSummaryMany,
          ),
          {'items': state.itemCount},
        );
        final body = ref
            .read(shoppingListControllerProvider.notifier)
            .shareText(title: shareTitle, summary: summary);
        if (body.isEmpty) return;

        final box = context.findRenderObject();
        final origin = box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        SharePlus.instance.share(
          ShareParams(
            text: body,
            title: shareTitle,
            subject: shareTitle,
            sharePositionOrigin: origin,
          ),
        );
      },
      tooltip: shareAction,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        switch (Theme.of(context).platform) {
          TargetPlatform.iOS || TargetPlatform.macOS => Icons.ios_share_outlined,
          _ => Icons.share_outlined,
        },
        size: 22,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cream
            : AppColors.blackberry,
      ),
    );
  }
}
