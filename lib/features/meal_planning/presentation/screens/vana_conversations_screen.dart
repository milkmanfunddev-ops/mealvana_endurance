import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_conversations_controller.dart';
import '../../domain/vana_conversation.dart';
import '../../domain/vana_conversation_kind.dart';

/// `/vana/conversations` (05 §4): segmented "Ask Vana" / "Meal plans",
/// rows of title · date · summary, a "New…" button and the gear → settings.
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

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final conversationsAsync = ref.watch(vanaConversationsControllerProvider(_kind));

    return Scaffold(
      key: const ValueKey('meal_planning.conversations_screen'),
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(
          content.getValue(ContentKeys.mpConvTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
        actions: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.gear,
              color: secondary,
              size: 18,
            ),
            onPressed: () => context.push('/settings/vana'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _Segment(
                      label: content.getValue(ContentKeys.mpConvAsk),
                      selected: _kind == VanaConversationKind.general,
                      onTap: () => setState(
                        () => _kind = VanaConversationKind.general,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Segment(
                      label: content.getValue(ContentKeys.mpConvPlans),
                      selected: _kind == VanaConversationKind.mealPlanning,
                      onTap: () => setState(
                        () => _kind = VanaConversationKind.mealPlanning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                    ? Center(
                        child: Text(
                          content.getValue(ContentKeys.mpConvEmpty),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: conversations.length,
                        itemBuilder: (context, i) {
                          final conversation = conversations[i];
                          return _ConversationRow(
                            conversation: conversation,
                            onTap: () => context.push(
                              '/vana?c=${conversation.id}&mode=${_kind.wire}',
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('meal_planning.conversations_new'),
        backgroundColor: AppColors.electrolyte,
        foregroundColor: AppColors.blackberry,
        onPressed: () async {
          final id = await ref
              .read(vanaConversationsControllerProvider(_kind).notifier)
              .create();
          if (context.mounted) {
            context.push('/vana?c=$id&mode=${_kind.wire}');
          }
        },
        icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
        label: Text(content.getValue(ContentKeys.mpConvNew)),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? AppColors.cream : AppColors.blackberry;
    final inactive = active.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.orange : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.tabSelector.copyWith(
            color: selected ? active : inactive,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final VanaConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    final lastAt = DateTime.tryParse(
      conversation.lastMessageAt ?? conversation.createdAt,
    );
    final dateLabel = lastAt == null
        ? ''
        : '${lastAt.month}/${lastAt.day}';

    return ListTile(
      key: ValueKey('meal_planning.conversation_${conversation.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      title: Text(
        conversation.title ?? conversation.summary ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
      ),
      subtitle: conversation.summary != null && conversation.title != null
          ? Text(
              conversation.summary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            )
          : null,
      trailing: Text(
        dateLabel,
        style: AppTextStyles.bodySmall.copyWith(color: secondary),
      ),
      onTap: onTap,
    );
  }
}
