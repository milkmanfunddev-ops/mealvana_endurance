import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../providers/reconnect_notice_controller.dart';

/// One dismissible line on the Timeline naming the connected app that needs
/// signing in again, with Reconnect to Connected Apps (ticket 138, Finding
/// 118-007). Renders nothing while [ReconnectNoticeController] holds no
/// provider. Words come from the content system.
class ReconnectNotice extends ConsumerWidget {
  const ReconnectNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(reconnectNoticeControllerProvider);
    if (provider == null) return const SizedBox.shrink();

    final content = ref.watch(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final message = ContentKeys.format(
      content.getValue(ContentKeys.connectionsReconnectNotice),
      {'provider': reconnectProviderDisplayName(provider)},
    );

    return Padding(
      key: ValueKey('reconnect_notice.$provider'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.electrolyte.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.electrolyte.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(color: textColor),
              ),
            ),
            TextButton(
              key: const ValueKey('reconnect_notice.reconnect'),
              onPressed: () {
                ref.read(reconnectNoticeControllerProvider.notifier).dismiss();
                context.push('/settings/connected-apps');
              },
              child: Text(
                content.getValue(ContentKeys.connectionsReconnectNoticeAction),
              ),
            ),
            IconButton(
              key: const ValueKey('reconnect_notice.dismiss'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close, size: 18, color: textColor),
              onPressed: () =>
                  ref.read(reconnectNoticeControllerProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}
