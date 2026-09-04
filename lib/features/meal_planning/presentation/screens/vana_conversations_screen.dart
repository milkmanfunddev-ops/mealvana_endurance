import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/navigation/kyle_tab_pill.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_conversations_controller.dart';
import '../../domain/vana_conversation.dart';
import '../../domain/vana_conversation_kind.dart';
import '../widgets/dashed_box.dart';
import '../widgets/vana_avatar.dart';
import '../widgets/vana_round_button.dart';

/// `/vana/conversations` (05 §4): the two histories — "Ask Vana" and "Meal
/// plans" — behind a pill segment, the new-conversation action, and the
/// recent list. The gear opens Vana's settings.
class VanaConversationsScreen extends ConsumerStatefulWidget {
  const VanaConversationsScreen({super.key, this.initialKind});

  final VanaConversationKind? initialKind;

  @override
  ConsumerState<VanaConversationsScreen> createState() =>
      _VanaConversationsScreenState();
}

class _VanaConversationsScreenState
    extends ConsumerState<VanaConversationsScreen> {
  late VanaConversationKind _kind =
      widget.initialKind ?? VanaConversationKind.general;
  bool _creating = false;

  static const _kinds = [
    VanaConversationKind.general,
    VanaConversationKind.mealPlanning,
  ];

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final conversationsAsync = ref.watch(
      vanaConversationsControllerProvider(_kind),
    );
    final isGeneral = _kind == VanaConversationKind.general;

    return Scaffold(
      key: const ValueKey('meal_planning.conversations_screen'),
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: back · Vana · title · settings.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  VanaRoundButton.back(
                    context: context,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  const VanaAvatar(size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      content.getValue(ContentKeys.mpConvTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: textColor,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  VanaRoundButton(
                    icon: FontAwesomeIcons.gear,
                    tooltip: content.getValue(
                      ContentKeys.mpSettingsVanaTitle,
                    ),
                    onTap: () => context.push('/settings/vana'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: KyleTabPill(
                labels: [
                  content.getValue(ContentKeys.mpConvAsk),
                  content.getValue(ContentKeys.mpConvPlans),
                ],
                selectedIndex: _kinds.indexOf(_kind),
                onChanged: (i) => setState(() => _kind = _kinds[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: KylePrimaryButton(
                key: const ValueKey('meal_planning.conversations_new'),
                text: content.getValue(
                  isGeneral
                      ? ContentKeys.mpConvNewGeneral
                      : ContentKeys.mpConvNewPlan,
                ),
                icon: Icons.add,
                height: 44,
                isLoading: _creating,
                onPressed: _createConversation,
              ),
            ),
            if (_creating) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  content.getValue(
                    isGeneral
                        ? ContentKeys.mpConvCreatingGeneral
                        : ContentKeys.mpConvCreatingPlan,
                  ),
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                content.getValue(ContentKeys.mpConvRecent).toUpperCase(),
                style: AppTextStyles.overline.copyWith(color: secondary),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electrolyte,
                  ),
                ),
                error: (e, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(
                      vanaConversationsControllerProvider(_kind),
                    ),
                    child: Text(content.getValue(ContentKeys.mpRetry)),
                  ),
                ),
                data: (conversations) => conversations.isEmpty
                    // In a ListView so the dashed box keeps its own height
                    // rather than stretching down the empty screen.
                    ? ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        children: [
                          DashedBox(
                            child: Text(
                              content.getValue(ContentKeys.mpConvEmpty),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: secondary,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.xxl,
                        ),
                        itemCount: conversations.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ConversationRow(
                            conversation: conversations[i],
                            onTap: () => context.push(
                              '/vana?c=${conversations[i].id}'
                              '&mode=${_kind.wire}',
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createConversation() async {
    // A general chat opens straight into an empty view; a planning chat has
    // the server mint the conversation first so the opener can stream.
    if (_kind == VanaConversationKind.general) {
      context.push('/vana?c=new&mode=${_kind.wire}');
      return;
    }
    setState(() => _creating = true);
    try {
      final id = await ref
          .read(vanaConversationsControllerProvider(_kind).notifier)
          .create();
      if (mounted) context.push('/vana?c=$id&mode=${_kind.wire}');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

/// One conversation: title over "Sep 2, 3:04 PM · summary", with a chevron.
class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final VanaConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    final lastAt = DateTime.tryParse(
      conversation.lastMessageAt ?? conversation.createdAt,
    );
    final when = lastAt == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(lastAt.toLocal());
    final summary = conversation.summary;

    return Material(
      color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: textColor.withValues(alpha: 0.14)),
      ),
      child: InkWell(
        key: ValueKey('meal_planning.conversation_${conversation.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title ??
                          content.getValue(ContentKeys.mpConvUntitled),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      summary != null && summary.isNotEmpty
                          ? '$when · $summary'
                          : when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: textColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
