import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../features/content/application/content_service.dart';
import '../../features/content/domain/content_keys.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../../theme/kyle_design/app_materials.dart';
import '../../theme/kyle_design/app_spacing.dart';
import '../../theme/kyle_design/app_text_styles.dart';
import 'kyle_design/buttons/primary_button.dart';
import 'kyle_design/materials/glass.dart';

/// Summon the "What's new" sheet — the glass-sheet recipe (tokens
/// §Materials, same scrim + surface as the calendar sheet), shown once per
/// announcement version on first launch after an install or update. Copy is
/// content-managed (`whats_new.*`) so the next announcement is a content
/// change, not a release. Gate: `shouldShowWhatsNew` in
/// `shared/services/whats_new_gate.dart`.
Future<void> showWhatsNewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: AppMaterials.sheetScrim,
    backgroundColor: Colors.transparent,
    builder: (_) => const WhatsNewSheet(),
  );
}

class WhatsNewSheet extends ConsumerWidget {
  const WhatsNewSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return GlassSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grabber, as the calendar sheet draws it.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: AppSpacing.xl),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: AppColors.cream.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cream.withValues(alpha: 0.14),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.mobileScreenButton,
                  size: 24,
                  color: AppColors.cream,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content.getValue(ContentKeys.whatsNewEyebrow),
              style: AppTextStyles.overline.copyWith(
                color: AppColors.cream.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              content.getValue(ContentKeys.whatsNewTitle),
              key: const ValueKey('whats_new.title'),
              style: AppTextStyles.pageTitle.copyWith(
                color: AppColors.cream,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              content.getValue(ContentKeys.whatsNewBody),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.cream.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KylePrimaryButton(
              key: const ValueKey('whats_new.cta'),
              text: content.getValue(ContentKeys.whatsNewCta),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
