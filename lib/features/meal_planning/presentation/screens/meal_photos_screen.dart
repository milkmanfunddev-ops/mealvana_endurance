import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/inputs/text_field.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/dish_photo_capture.dart';
import '../providers/dish_photo_cropper.dart';
import '../../application/meal_photos_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/dish_photo_preparation.dart';
import '../../domain/meal_photo_history.dart';
import '../../domain/meal_photo_messages.dart';
import '../widgets/meal_photo_view.dart';

/// Every photo action for one library Meal, in one place — Testers only
/// (ADR 0003). Reached from the recipe screen's camera icon, or from the
/// "Add photo" line where the picture would be.
///
/// Pushed with [route], which names it: a `MaterialPageRoute` is invisible to
/// the router otherwise, so an unnamed push would leave analytics and Vana's
/// screen situation looking at the recipe screen underneath.
///
/// This ticket builds the current photo, adding by web address or by camera
/// and gallery, and History as a read-only record. Remove/Restore/Delete
/// (ticket 06) land in the same sections.
///
/// Only one add is ever in flight: a pending upload and a pending address
/// replace each other, so Confirm is never ambiguous about what it publishes.
class MealPhotosScreen extends ConsumerStatefulWidget {
  const MealPhotosScreen({
    super.key,
    required this.mealId,
    required this.mealName,
  });

  /// `meal_library.id` — a saved meal has no library row and no photos page.
  final String mealId;
  final String mealName;

  static String routeNameFor(String mealId) => '/food/meals/$mealId/photos';

  static Route<void> route({required String mealId, required String mealName}) =>
      MaterialPageRoute<void>(
        builder: (_) => MealPhotosScreen(mealId: mealId, mealName: mealName),
        settings: RouteSettings(name: routeNameFor(mealId)),
      );

  @override
  ConsumerState<MealPhotosScreen> createState() => _MealPhotosScreenState();
}

class _MealPhotosScreenState extends ConsumerState<MealPhotosScreen> {
  final _address = TextEditingController();
  final _credit = TextEditingController();
  final _creditUrl = TextEditingController();

  /// The address currently being previewed, or null while the Tester is still
  /// typing one. Confirm exists only once there is something to look at.
  String? _previewing;

  /// Whether [_previewing] actually drew. Null while it is still loading:
  /// Confirm waits rather than publishing an address that may be a 404 page.
  bool? _previewLoaded;

  /// The cropped photograph waiting for Confirm, or null when there is none.
  /// Held in memory only: nothing is stored anywhere until the Tester confirms.
  Uint8List? _pendingUpload;

  bool _sending = false;

  @override
  void dispose() {
    _address.dispose();
    _credit.dispose();
    _creditUrl.dispose();
    super.dispose();
  }

  void _preview() {
    final url = _address.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _previewing = url;
      _previewLoaded = null;
    });
  }

  /// Cancel changes nothing: the Meal keeps whatever it was showing, and the
  /// page goes back to an empty address field.
  void _cancel() {
    setState(() {
      _previewing = null;
      _previewLoaded = null;
      _pendingUpload = null;
      _address.clear();
      _credit.clear();
      _creditUrl.clear();
    });
  }

  /// Take a photo, or choose one, then crop it — and stop at any point the
  /// Tester backs out. Nothing is prepared, sent or stored here: the bytes sit
  /// in memory until Confirm (story 24).
  Future<void> _pick(ImageSource source) async {
    final content = ref.read(contentServiceProvider);
    final pick = ref.read(dishPhotoPickerProvider);
    final crop = ref.read(dishPhotoCropperProvider);

    Uint8List? picked;
    try {
      picked = await pick(source);
    } catch (_) {
      // A refused camera permission, or no gallery on this device.
      if (!mounted) return;
      MealvanaSnackbar.showError(
        context,
        content.getValue(ContentKeys.mpPhotosPickFailed),
      );
      return;
    }
    // Backed out of the picker: changes nothing.
    if (picked == null || !mounted) return;

    final cropped = await crop(context, picked);
    // Cancelled at the crop step: also changes nothing (story 25).
    if (cropped == null || !mounted) return;

    setState(() {
      _pendingUpload = cropped;
      // One add at a time — a half-typed address is dropped rather than left
      // to make Confirm ambiguous. The credit goes with it: a credit typed for
      // an address the Tester walked away from must not be attached to this
      // photograph behind their back.
      _previewing = null;
      _previewLoaded = null;
      _address.clear();
      _credit.clear();
      _creditUrl.clear();
    });
  }

  /// Publish the cropped photograph.
  ///
  /// The controller prepares it first — shrink and strip the EXIF — so a
  /// [DishPhotoUnreadable] here means nothing was sent at all.
  Future<void> _confirmUpload() async {
    final bytes = _pendingUpload;
    if (bytes == null) return;
    await _publish(
      () => ref
          .read(mealPhotosControllerProvider(widget.mealId).notifier)
          .addUpload(
            bytes: bytes,
            credit: _credit.text,
            creditUrl: _creditUrl.text,
          ),
    );
  }

  /// Send one add and say what happened — the same for a pasted address and a
  /// photograph, so the two can never drift into reporting differently.
  ///
  /// Success is only said once [send] returns, because that is when the server
  /// has it and therefore when every athlete has it (story 32). An offline
  /// failure says so plainly and queues nothing: a photograph every athlete
  /// sees must not publish later, unwatched (story 33).
  Future<void> _publish(Future<void> Function() send) async {
    if (_sending) return;
    final content = ref.read(contentServiceProvider);
    setState(() => _sending = true);
    try {
      await send();
      if (!mounted) return;
      _cancel();
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpPhotosAdded),
        duration: MealvanaSnackbar.shortDuration,
      );
    } on VanaOfflineException {
      if (!mounted) return;
      MealvanaSnackbar.showWarning(
        context,
        content.getValue(ContentKeys.mpNeedsConnection),
      );
    } catch (e) {
      if (!mounted) return;
      MealvanaSnackbar.showError(context, content.getValue(_failureKey(e)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    final url = _previewing;
    // Nothing publishes until the address has actually drawn.
    if (url == null || _previewLoaded != true) return;
    await _publish(
      () => ref
          .read(mealPhotosControllerProvider(widget.mealId).notifier)
          .addAddress(
            url: url,
            credit: _credit.text,
            creditUrl: _creditUrl.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final photosAsync = ref.watch(mealPhotosControllerProvider(widget.mealId));

    return Scaffold(
      key: ValueKey('meal_planning.photos_${widget.mealId}'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(
          content.getValue(ContentKeys.mpPhotosTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: SafeArea(
        child: photosAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.electrolyte),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                content.getValue(_failureKey(e)),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
          ),
          data: (photos) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                widget.mealName,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _CurrentPhoto(photos: photos),
              const SizedBox(height: AppSpacing.lg),
              if (_pendingUpload case final bytes?)
                _buildUploadPreview(content, bytes)
              else ...[
                // Hidden while an address is being previewed: one add at a
                // time, so Confirm always means one obvious thing.
                if (_previewing == null) ...[
                  _buildTakeOrChoose(content),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _buildAddByAddress(content, textColor, isDark),
              ],
              const SizedBox(height: AppSpacing.lg),
              _History(entries: photos.history),
            ],
          ),
        ),
      ),
    );
  }

  /// Take photo and Choose photo. On a simulator the camera is not there at
  /// all, which the picker reports as a failure — the gallery is the way in.
  Widget _buildTakeOrChoose(ContentService content) {
    return Row(
      children: [
        Expanded(
          child: KylePrimaryButton(
            key: const ValueKey('meal_planning.photos_take'),
            text: content.getValue(ContentKeys.mpPhotosTake),
            height: 40,
            onPressed: _sending ? null : () => _pick(ImageSource.camera),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: KylePrimaryButton(
            key: const ValueKey('meal_planning.photos_choose'),
            text: content.getValue(ContentKeys.mpPhotosChoose),
            height: 40,
            onPressed: _sending ? null : () => _pick(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  /// The cropped photograph, drawn at the shape the recipe screen draws it —
  /// exactly what athletes will see (story 23) — with the credit fields and
  /// Confirm.
  ///
  /// Straight from memory, so there is no loading state and nothing to fail:
  /// the bytes are already in hand, unlike a pasted address.
  Widget _buildUploadPreview(ContentService content, Uint8List bytes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(content.getValue(ContentKeys.mpPhotosPreviewLabel)),
        const SizedBox(height: AppSpacing.xs),
        AspectRatio(
          aspectRatio: kDishPhotoAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              bytes,
              key: const ValueKey('meal_planning.photos_upload_preview_image'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        KyleTextField(
          key: const ValueKey('meal_planning.photos_upload_credit_field'),
          controller: _credit,
          hint: content.getValue(ContentKeys.mpPhotosCreditHint),
        ),
        const SizedBox(height: AppSpacing.xs),
        KyleTextField(
          key: const ValueKey('meal_planning.photos_upload_credit_url_field'),
          controller: _creditUrl,
          hint: content.getValue(ContentKeys.mpPhotosCreditUrlHint),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.sm),
        KylePrimaryButton(
          key: const ValueKey('meal_planning.photos_upload_confirm'),
          text: content.getValue(ContentKeys.mpPhotosConfirm),
          height: 40,
          isLoading: _sending,
          onPressed: _confirmUpload,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          key: const ValueKey('meal_planning.photos_upload_cancel'),
          onPressed: _sending ? null : _cancel,
          child: Text(content.getValue(ContentKeys.mpPhotosCancel)),
        ),
      ],
    );
  }

  Widget _buildAddByAddress(
    ContentService content,
    Color textColor,
    bool isDark,
  ) {
    final previewing = _previewing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(content.getValue(ContentKeys.mpPhotosAddressTitle)),
        const SizedBox(height: AppSpacing.xs),
        KyleTextField(
          key: const ValueKey('meal_planning.photos_address_field'),
          controller: _address,
          hint: content.getValue(ContentKeys.mpPhotosAddressHint),
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (previewing == null)
          KylePrimaryButton(
            key: const ValueKey('meal_planning.photos_preview'),
            text: content.getValue(ContentKeys.mpPhotosPreview),
            height: 40,
            onPressed: _address.text.trim().isEmpty ? null : _preview,
          )
        else ...[
          _Label(content.getValue(ContentKeys.mpPhotosPreviewLabel)),
          const SizedBox(height: AppSpacing.xs),
          // Exactly the widget the recipe screen draws, at the recipe screen's
          // shape, so what the Tester checks is what athletes get (story 23).
          _AddressPreview(
            key: ValueKey('meal_planning.photos_preview_image_$previewing'),
            url: previewing,
            onResult: (loaded) {
              if (mounted && _previewLoaded != loaded) {
                setState(() => _previewLoaded = loaded);
              }
            },
          ),
          if (_previewLoaded == false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpPhotosNotAnImage),
              key: const ValueKey('meal_planning.photos_preview_failed'),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          KyleTextField(
            key: const ValueKey('meal_planning.photos_credit_field'),
            controller: _credit,
            hint: content.getValue(ContentKeys.mpPhotosCreditHint),
          ),
          const SizedBox(height: AppSpacing.xs),
          KyleTextField(
            key: const ValueKey('meal_planning.photos_credit_url_field'),
            controller: _creditUrl,
            hint: content.getValue(ContentKeys.mpPhotosCreditUrlHint),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          KylePrimaryButton(
            key: const ValueKey('meal_planning.photos_confirm'),
            text: content.getValue(ContentKeys.mpPhotosConfirm),
            height: 40,
            isLoading: _sending,
            // Nothing publishes until the address has drawn.
            onPressed: _previewLoaded == true ? _confirm : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const ValueKey('meal_planning.photos_cancel'),
            onPressed: _sending ? null : _cancel,
            child: Text(content.getValue(ContentKeys.mpPhotosCancel)),
          ),
        ],
      ],
    );
  }
}

/// What athletes see right now — the Meal's photo at the recipe screen's
/// shape, with its credit line, or a plain line saying there is none.
class _CurrentPhoto extends ConsumerWidget {
  const _CurrentPhoto({required this.photos});

  final MealPhotos photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final photo = photos.photo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(content.getValue(ContentKeys.mpPhotosCurrent)),
        const SizedBox(height: AppSpacing.xs),
        if (photo == null)
          Text(
            content.getValue(ContentKeys.mpPhotosNone),
            key: const ValueKey('meal_planning.photos_none'),
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor.withValues(alpha: 0.65),
            ),
          )
        else ...[
          MealPhotoHero(photo: photo),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MealPhotoCreditLine(
              photo: photo,
              onOpen: (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every photograph this Meal has shown, newest first. Read-only here:
/// Restore and Delete arrive with ticket 06.
class _History extends ConsumerWidget {
  const _History({required this.entries});

  final List<MealPhotoHistoryEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(content.getValue(ContentKeys.mpPhotosHistory)),
        const SizedBox(height: AppSpacing.xs),
        if (entries.isEmpty)
          Text(
            content.getValue(ContentKeys.mpPhotosHistoryEmpty),
            key: const ValueKey('meal_planning.photos_history_empty'),
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor.withValues(alpha: 0.65),
            ),
          )
        else
          for (final entry in entries)
            Padding(
              key: ValueKey('meal_planning.photos_history_${entry.id}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MealPhotoThumb(photo: entry.photo, size: 48),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.photo.credit ?? entry.photo.url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: textColor,
                          ),
                        ),
                        if (entry.addedAt case final at?)
                          Text(
                            _whenLabel(at),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: textColor.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (entry.isCurrent)
                    Text(
                      content.getValue(ContentKeys.mpPhotosShowingNow),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.electrolyte
                            : AppColors.electrolyteDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  /// `2026-09-16 14:05` in the device's own zone — a Tester reading the record
  /// wants the clock they were holding, not a relative "2 days ago".
  static String _whenLabel(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

/// The pasted address, drawn at the recipe screen's shape, reporting whether it
/// actually became a picture.
///
/// Deliberately **not** [MealPhotoHero]: the hero collapses to nothing when an
/// address fails, which is right for an athlete and useless for a Tester who
/// needs to be told the link is wrong (story 30).
class _AddressPreview extends StatelessWidget {
  const _AddressPreview({super.key, required this.url, required this.onResult});

  final String url;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holding = isDark ? AppColors.blackberryLight : AppColors.creamDark;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSync) {
            if (frame != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onResult(true),
              );
              return child;
            }
            return ColoredBox(color: holding);
          },
          errorBuilder: (context, _, __) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onResult(false),
            );
            return ColoredBox(color: holding);
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.bodySmall.copyWith(
        color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
          alpha: 0.55,
        ),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// What the page says when a photo change fails, in one place: the load at the
/// top of the page and a refused Confirm answer the same way.
String _failureKey(Object error) => switch (error) {
  VanaOfflineException() => ContentKeys.mpNeedsConnection,
  // The picked file never decoded, so nothing was sent — a different photo is
  // the fix, not a retry.
  DishPhotoUnreadable() => ContentKeys.mpPhotosUnreadable,
  MealPhotoException(:final code) =>
    mealPhotoMessageKey(code) ?? ContentKeys.mpServerError,
  _ => ContentKeys.mpServerError,
};
