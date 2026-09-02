import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/cooking_session.dart';

/// Batch-cooking session chip (Cook Sunday · Top-up Wednesday · Fresh
/// Friday) in a soft yolk tone, distinct from the slot chip's slot colour.
class SessionChip extends ConsumerWidget {
  const SessionChip({super.key, required this.session});

  final CookingSession session;

  static String labelFor(ContentService content, CookingSession session) =>
      switch (session) {
        CookingSession.cookSun => content.getValue(ContentKeys.mpSessionCookSun),
        CookingSession.topupWed => content.getValue(
          ContentKeys.mpSessionTopupWed,
        ),
        CookingSession.freshFri => content.getValue(
          ContentKeys.mpSessionFreshFri,
        ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = labelFor(ref.read(contentServiceProvider), session);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.yolk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.orangeDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
