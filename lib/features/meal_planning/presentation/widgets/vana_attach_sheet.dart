import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// What the athlete chose on the composer's `+` sheet.
sealed class VanaAttachChoice {
  const VanaAttachChoice();
}

/// "Snap my fridge" / "Choose a photo" — the picked image.
class VanaAttachPhoto extends VanaAttachChoice {
  const VanaAttachPhoto(this.file);

  final XFile file;

  /// `jpg` when the name carries no usable extension.
  String get extension {
    final parts = file.name.split('.');
    return (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
  }
}

/// "Use what I have" — send the prompt that starts the server's pantry
/// flow.
class VanaAttachUseWhatIHave extends VanaAttachChoice {
  const VanaAttachUseWhatIHave();
}

/// "Browse meals" — open the catalog and pick straight into the draft.
class VanaAttachBrowseMeals extends VanaAttachChoice {
  const VanaAttachBrowseMeals();
}

/// Opens the composer `+` sheet (plan §5 Phases 6.5, 7.3; "Browse meals"
/// added 2026-09-03) and resolves to the athlete's choice, or null when
/// dismissed. On web the camera row is
/// dropped (the library row stays — `image_picker` handles a file input
/// there); the photo itself is picked here so the caller only ever sees a
/// ready [XFile]. A picker failure surfaces as [VanaAttachPickFailed].
Future<VanaAttachChoice?> showVanaAttachSheet({
  required BuildContext context,
  ImagePicker? picker,
}) async {
  final choice = await showAdaptiveModal<_AttachRow>(
    context: context,
    builder: (_) => const _VanaAttachSheet(),
  );
  if (choice == null) return null;
  switch (choice) {
    case _AttachRow.useWhatIHave:
      return const VanaAttachUseWhatIHave();
    case _AttachRow.browseMeals:
      return const VanaAttachBrowseMeals();
    case _AttachRow.camera:
    case _AttachRow.library:
      final XFile? file;
      try {
        // 1000px keeps enough detail for ingredient recognition while
        // trimming the image's share of model input tokens (same as the
        // meal-logging capture).
        file = await (picker ?? ImagePicker()).pickImage(
          source: choice == _AttachRow.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1000,
        );
      } catch (e) {
        throw VanaAttachPickFailed(e);
      }
      return file == null ? null : VanaAttachPhoto(file);
  }
}

/// The platform picker refused (permissions, no camera).
class VanaAttachPickFailed implements Exception {
  const VanaAttachPickFailed(this.cause);

  final Object cause;

  @override
  String toString() => 'VanaAttachPickFailed($cause)';
}

enum _AttachRow { browseMeals, camera, library, useWhatIHave }

class _VanaAttachSheet extends ConsumerWidget {
  const _VanaAttachSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    Widget row(_AttachRow value, FaIconData icon, String key, String label) =>
        ListTile(
          key: ValueKey('meal_planning.attach_$key'),
          leading: FaIcon(icon, size: 18, color: AppColors.electrolyteDark),
          title: Text(
            content.getValue(label),
            style: AppTextStyles.bodyMedium.copyWith(color: textColor),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          onTap: () => Navigator.of(context).pop(value),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The catalog first — Lee (2026-09-03): there was no way to
            // just pick from our meals mid-conversation.
            row(
              _AttachRow.browseMeals,
              FontAwesomeIcons.utensils,
              'browse_meals',
              ContentKeys.mpAttachBrowseMeals,
            ),
            if (!kIsWeb)
              row(
                _AttachRow.camera,
                FontAwesomeIcons.camera,
                'snap_fridge',
                ContentKeys.mpAttachSnapFridge,
              ),
            row(
              _AttachRow.library,
              FontAwesomeIcons.image,
              'photo_library',
              ContentKeys.mpAttachPhotoLibrary,
            ),
            row(
              _AttachRow.useWhatIHave,
              FontAwesomeIcons.carrot,
              'use_what_i_have',
              ContentKeys.mpAttachUseWhatIHave,
            ),
          ],
        ),
      ),
    );
  }
}
