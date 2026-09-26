import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../application/conversation_kind_provider.dart';
import '../../domain/vana_conversation_kind.dart';
import 'vana_chat_screen.dart';

/// `/vana` — the chat, with its kind taken from the link's `mode` when the
/// link names one, else from the conversation itself. Before this every
/// `/vana?c=<id>` without a mode opened as meal planning, so a general
/// conversation opened by link read "New meal plan" (testing-wave 134,
/// Finding 118-004). A conversation the server cannot name (not ours,
/// gone, offline) opens as meal planning, as before.
class VanaChatRoute extends ConsumerWidget {
  const VanaChatRoute({
    super.key,
    required this.kind,
    required this.conversationId,
    this.startOpener = false,
    this.newPlan = false,
  });

  /// The link's `mode`, or null when the conversation decides.
  final VanaConversationKind? kind;
  final String? conversationId;
  final bool startOpener;
  final bool newPlan;

  static const fallbackKind = VanaConversationKind.mealPlanning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = conversationId;
    final known = kind;
    if (known != null || id == null) {
      return VanaChatScreen(
        kind: known ?? fallbackKind,
        conversationId: id,
        startOpener: startOpener,
        newPlan: newPlan,
      );
    }
    final resolved = ref.watch(conversationKindProvider(id));
    if (resolved.isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        key: const ValueKey('meal_planning.vana_chat_route.resolving'),
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
      );
    }
    return VanaChatScreen(
      kind: resolved.value ?? fallbackKind,
      conversationId: id,
      startOpener: startOpener,
      newPlan: newPlan,
    );
  }
}
