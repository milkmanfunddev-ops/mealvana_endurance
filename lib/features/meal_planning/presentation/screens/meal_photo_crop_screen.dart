/// Cropping a photograph to the shape a Meal shows it in (ADR 0003, ticket 05).
///
/// The Tester sees the whole photo and drags a fixed 16:10 window over it, so
/// what they frame is what a card and the recipe screen will draw — no
/// surprise trimming later (story 22). Backing out returns null and changes
/// nothing (story 25).
///
/// The crop here is a convenience, not the guarantee: `prepareDishPhoto` crops
/// to the same aspect again on the way out, so a photograph that reaches the
/// controller some other way is still published at the right shape.
library;

import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/dish_photo_preparation.dart';

class MealPhotoCropScreen extends ConsumerStatefulWidget {
  const MealPhotoCropScreen({super.key, required this.bytes});

  /// The picked photograph, as it came off the camera or out of the gallery.
  final Uint8List bytes;

  static const routeName = '/food/meals/photo-crop';

  static Route<Uint8List> route(Uint8List bytes) => MaterialPageRoute<Uint8List>(
    builder: (_) => MealPhotoCropScreen(bytes: bytes),
    settings: const RouteSettings(name: routeName),
    fullscreenDialog: true,
  );

  @override
  ConsumerState<MealPhotoCropScreen> createState() =>
      _MealPhotoCropScreenState();
}

class _MealPhotoCropScreenState extends ConsumerState<MealPhotoCropScreen> {
  final _controller = CropController();

  /// True from the moment Use this crop is tapped until the cropper answers —
  /// cropping a large photograph takes a moment, and a second tap would run it
  /// twice.
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        MealvanaSnackbar.showError(
          context,
          ref.read(contentServiceProvider).getValue(ContentKeys.mpPhotosUnreadable),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    // Always dark: a crop editor is a lightbox, and a cream ground around a
    // photograph makes it impossible to judge the edges.
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      appBar: AppBar(
        backgroundColor: AppColors.blackberry,
        foregroundColor: AppColors.cream,
        elevation: 0,
        title: Text(
          content.getValue(ContentKeys.mpPhotosCropTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.cream),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                key: const ValueKey('meal_planning.photos_cropper'),
                image: widget.bytes,
                controller: _controller,
                // The one shape a Dish photo is ever shown in.
                aspectRatio: kDishPhotoAspectRatio,
                onCropped: _onCropped,
                baseColor: AppColors.blackberry,
                maskColor: AppColors.blackberry.withValues(alpha: 0.6),
                radius: 14,
                interactive: true,
                progressIndicator: const CircularProgressIndicator(
                  color: AppColors.electrolyte,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: KylePrimaryButton(
                key: const ValueKey('meal_planning.photos_crop_confirm'),
                text: content.getValue(ContentKeys.mpPhotosCropConfirm),
                isLoading: _cropping,
                onPressed: _cropping
                    ? null
                    : () {
                        setState(() => _cropping = true);
                        _controller.crop();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
