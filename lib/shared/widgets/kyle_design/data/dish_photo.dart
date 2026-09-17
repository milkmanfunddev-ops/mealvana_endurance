/// Design SSOT component — **Dish Photo**.
///
/// Spec: `docs/ssot/spec/design/components/dish-photo.md` **v1**
/// (PROPOSED Lee 2026-09-17, awaiting Xuan).
///
/// The one photograph of a dish, or nothing (ADR 0003). Three forms share one
/// rule: [DishPhotoThumb] in a row, [DishPhotoHero] above a recipe, and
/// [DishPhotoCreditLine] under a hero.
///
/// Takes plain fields rather than a feature's model, so the library depends on
/// no feature; a feature unpacks its own photo type into them.
///
/// Contracts held here:
/// * **DP-1** — no address draws a zero-size box: no placeholder, no icon, no
///   gap.
/// * **DP-2** — a failed load collapses to DP-1 with no glyph; a new address
///   gets its own chance.
/// * **DP-3** — a plain surface holds the space while decoding, no motion.
/// * **DP-4 / DP-5** — thumb is a square (radius edge/4); hero is 16:10,
///   radius 14.
/// * **DP-6** — one credit line, only when there is a credit; tappable only
///   for an http(s) link with a host.
/// * **DP-7** — thumbs and heroes carry the credit as their semantics label;
///   an uncredited photo is left unlabelled.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// A Dish photo at thumbnail size in a row, or nothing at all (DP-1, DP-4).
class DishPhotoThumb extends StatelessWidget {
  const DishPhotoThumb({
    super.key,
    required this.url,
    this.credit,
    required this.size,
    this.gap = 12,
    this.borderRadius,
  });

  /// The photograph's address, or null when the dish has none.
  final String? url;

  /// Read out as the image's label (DP-7).
  final String? credit;

  /// Edge of the square box the photo fills.
  final double size;

  /// Space between the photo and whatever follows it, drawn only when the
  /// photo is.
  final double gap;

  /// Corners; defaults to a quarter of [size].
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return const SizedBox.shrink();
    return _CollapsingPhoto(
      url: url,
      credit: credit,
      borderRadius: borderRadius ?? BorderRadius.circular(size / 4),
      builder: (context, image) => Padding(
        padding: EdgeInsets.only(right: gap),
        child: SizedBox.square(dimension: size, child: image),
      ),
    );
  }
}

/// A Dish photo at size, above a recipe (DP-5). Draws nothing — no box, no
/// space — when there is none, so the screen starts at the meal's name.
class DishPhotoHero extends StatelessWidget {
  const DishPhotoHero({
    super.key,
    required this.url,
    this.credit,
    this.aspectRatio = 16 / 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final String? url;
  final String? credit;
  final double aspectRatio;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return const SizedBox.shrink();
    return _CollapsingPhoto(
      url: url,
      credit: credit,
      borderRadius: borderRadius,
      builder: (context, image) =>
          AspectRatio(aspectRatio: aspectRatio, child: image),
    );
  }
}

/// The photograph itself: fetched, clipped, and gone without trace when it
/// fails (DP-2, DP-3, DP-7).
class _CollapsingPhoto extends StatefulWidget {
  const _CollapsingPhoto({
    required this.url,
    required this.credit,
    required this.borderRadius,
    required this.builder,
  });

  final String url;
  final String? credit;
  final BorderRadius borderRadius;

  /// Wraps the image in whatever shape the host needs. Called only while
  /// there is something to draw.
  final Widget Function(BuildContext context, Widget image) builder;

  @override
  State<_CollapsingPhoto> createState() => _CollapsingPhotoState();
}

class _CollapsingPhotoState extends State<_CollapsingPhoto> {
  /// The address that failed to decode. Kept so the collapse survives a
  /// rebuild, while a new address still gets its own chance.
  String? _failed;

  @override
  void didUpdateWidget(_CollapsingPhoto old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _failed = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == _failed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holding = isDark ? AppColors.blackberryLight : AppColors.creamDark;

    Widget image = Image.network(
      widget.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // No motion while decoding: a plain surface holds the space.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : ColoredBox(color: holding),
      errorBuilder: (context, _, __) {
        // Collapse after this frame — setState is illegal during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _failed != widget.url) {
            setState(() => _failed = widget.url);
          }
        });
        return ColoredBox(color: holding);
      },
    );
    image = ClipRRect(borderRadius: widget.borderRadius, child: image);
    if (widget.credit case final credit?) {
      image = Semantics(label: credit, image: true, child: image);
    }
    return widget.builder(context, image);
  }
}

/// One credit line under a Dish photo, and nothing when there is no credit
/// (DP-6). Tapping opens [creditUrl] when it is a web page; otherwise the line
/// is plain text. The wording is shown as stored: a licence's required wording
/// must not drift with the app.
class DishPhotoCreditLine extends StatelessWidget {
  const DishPhotoCreditLine({
    super.key,
    required this.credit,
    this.creditUrl,
    required this.onOpen,
    this.linkKey,
  });

  final String? credit;
  final String? creditUrl;
  final ValueChanged<Uri> onOpen;

  /// Key for the tappable line, so a host's tests can find it.
  final Key? linkKey;

  @override
  Widget build(BuildContext context) {
    final credit = this.credit;
    if (credit == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.65,
    );
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final link = _webUri(creditUrl);

    final text = Text(
      credit,
      style: AppTextStyles.bodySmall.copyWith(
        color: link == null ? ink : accent,
        fontWeight: link == null ? null : FontWeight.w600,
      ),
    );
    if (link == null) return text;
    return GestureDetector(
      key: linkKey,
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
