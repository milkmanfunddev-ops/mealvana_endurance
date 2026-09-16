import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_photo.dart';

/// A Meal's Dish photo at thumbnail size in a row, or nothing at all.
///
/// "Nothing" means nothing: no placeholder box, no icon, no reserved space and
/// no gap after it, so a row for a Meal without a photo starts at its name and
/// a list mixing the two still lines up its names and macros (ADR 0003). A
/// photograph that fails to load — a hotlink that has gone, or Wikimedia rate-
/// limiting us — collapses the same way, drawing no broken-image glyph.
///
/// The credit rides on semantics: the licences want the photographer named
/// wherever the photo appears, and a 36pt thumbnail has no room for a line.
/// The visible line lives on the recipe screen ([MealPhotoCreditLine]).
class MealPhotoThumb extends StatelessWidget {
  const MealPhotoThumb({
    super.key,
    required this.photo,
    required this.size,
    this.gap = 12,
    this.borderRadius,
  });

  final MealPhoto? photo;

  /// Edge of the square box the photo fills.
  final double size;

  /// Space between the photo and whatever follows it, drawn only when the
  /// photo is.
  final double gap;

  /// Corners; defaults to a quarter of [size], the picture's own radius on a
  /// card thumbnail.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return const SizedBox.shrink();
    return _CollapsingPhoto(
      photo: photo,
      borderRadius: borderRadius ?? BorderRadius.circular(size / 4),
      builder: (context, image) => Padding(
        padding: EdgeInsets.only(right: gap),
        child: SizedBox.square(dimension: size, child: image),
      ),
    );
  }
}

/// A Meal's Dish photo at size, above a recipe. Draws nothing — no box, no
/// space — when the Meal has none, so the screen starts at the meal's name.
class MealPhotoHero extends StatelessWidget {
  const MealPhotoHero({
    super.key,
    required this.photo,
    this.aspectRatio = 16 / 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final MealPhoto? photo;
  final double aspectRatio;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return const SizedBox.shrink();
    return _CollapsingPhoto(
      photo: photo,
      borderRadius: borderRadius,
      builder: (context, image) =>
          AspectRatio(aspectRatio: aspectRatio, child: image),
    );
  }
}

/// The photograph itself: fetched, clipped, and gone without trace when it
/// fails. A hotlink that has expired, or Wikimedia rate-limiting us, collapses
/// to exactly what a Meal with no photo shows — never a broken-image glyph.
///
/// The credit rides on semantics where there is one: the licences want the
/// photographer named wherever the photo appears, and a 36pt thumbnail has no
/// room for a line. An uncredited photo is left unlabelled rather than
/// announced as an empty one; the meal's name is beside it either way.
class _CollapsingPhoto extends StatefulWidget {
  const _CollapsingPhoto({
    required this.photo,
    required this.borderRadius,
    required this.builder,
  });

  final MealPhoto photo;
  final BorderRadius borderRadius;

  /// Wraps the image in whatever shape the host needs — a row's square box, or
  /// the recipe screen's aspect. Called only while there is something to draw.
  final Widget Function(BuildContext context, Widget image) builder;

  @override
  State<_CollapsingPhoto> createState() => _CollapsingPhotoState();
}

class _CollapsingPhotoState extends State<_CollapsingPhoto> {
  /// The url that failed to decode. Kept so the collapse survives a rebuild,
  /// while a new photo still gets its own chance.
  String? _failed;

  @override
  void didUpdateWidget(_CollapsingPhoto old) {
    super.didUpdateWidget(old);
    if (old.photo.url != widget.photo.url) _failed = null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    if (photo.url == _failed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holding = isDark ? AppColors.blackberryLight : AppColors.creamDark;

    Widget image = Image.network(
      photo.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // No motion while decoding: a plain surface holds the space.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : ColoredBox(color: holding),
      errorBuilder: (context, _, __) {
        // Collapse after this frame — setState is illegal during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _failed != photo.url) {
            setState(() => _failed = photo.url);
          }
        });
        return ColoredBox(color: holding);
      },
    );
    image = ClipRRect(borderRadius: widget.borderRadius, child: image);
    if (photo.credit case final credit?) {
      image = Semantics(label: credit, image: true, child: image);
    }
    return widget.builder(context, image);
  }
}

/// One credit line under a Dish photo, and nothing when the photo has no
/// credit — our own photographs show clean. Tapping opens the photograph's
/// page when it has one; a credit without a link is plain text.
///
/// The wording is stored with the photo, not built here: a licence's required
/// wording must not drift with the app.
class MealPhotoCreditLine extends StatelessWidget {
  const MealPhotoCreditLine({
    super.key,
    required this.photo,
    required this.onOpen,
  });

  final MealPhoto? photo;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final credit = photo?.credit;
    if (credit == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.65,
    );
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final link = _webUri(photo?.creditUrl);

    final text = Text(
      credit,
      style: AppTextStyles.bodySmall.copyWith(
        color: link == null ? ink : accent,
        fontWeight: link == null ? null : FontWeight.w600,
      ),
    );
    if (link == null) return text;
    return GestureDetector(
      key: const ValueKey('meal_planning.detail_photo_credit'),
      onTap: () => onOpen(link),
      child: text,
    );
  }

  static Uri? _webUri(String? v) {
    final uri = Uri.tryParse(v?.trim() ?? '');
    if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      return null;
    }
    return uri.host.isEmpty ? null : uri;
  }
}
