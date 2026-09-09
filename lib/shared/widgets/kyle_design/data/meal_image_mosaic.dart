/// Design SSOT component — **Meal Image Mosaic**.
///
/// Spec: `docs/ssot/spec/design/components/meal-image-mosaic.md` **v1**
/// (PROPOSED Lee 2026-09-08, awaiting Xuan).
///
/// The picture of a meal, at any size. Renders whichever rung of the image
/// fallback ladder that meal reached: one real photograph, a mosaic of 2–4
/// photographs of its principal ingredients, or nothing at all.
///
/// Most of `meal_library` is *assemblies* — "Barley, chard & pinto bean bowl" —
/// of which no photograph exists anywhere, so a meal is depicted by its own
/// ingredients rather than by a shared generic stock photo. Pipeline and
/// licensing: `docs/meal-images/README.md`.
///
/// Contracts held here:
/// * **MIM-1** — the mode decides the form: `dish`/`tile` → one photograph,
///   `mosaic` → an even grid in the order given, `none` → a zero-size box.
/// * **MIM-2** — `none` shows nothing: no icon, no placeholder, no panel.
/// * **MIM-3** — tile count drives the grid: 2 → two columns, 3 → one full
///   column left plus two stacked right, 4 → 2×2. Never more than 4.
/// * **MIM-4** — every tile is square-cropped and centred; equal sizes; never
///   letterboxed, never distorted.
/// * **MIM-5** — a failed image collapses its cell and the rest re-flow to the
///   next legal grid; all failed → MIM-2.
/// * **MIM-7** — a 1px surface-coloured gap is the only separator; the outer
///   radius belongs to the host.
/// * **MIM-8** — no motion beyond the host's standard loading treatment.
///
/// Attribution (**MIM-6**) is the host surface's job, not this widget's — it
/// must credit *every* distinct tile shown. See [KyleMealImageTile.attribution].
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// One photograph in a meal's picture — a whole dish, or one ingredient.
@immutable
class KyleMealImageTile {
  const KyleMealImageTile({
    required this.url,
    this.name,
    this.license,
    this.creator,
    this.sourceUrl,
    this.provider,
  });

  final String url;

  /// The ingredient this tile depicts, for semantics and attribution.
  final String? name;

  final String? license;
  final String? creator;
  final String? sourceUrl;

  /// `wikimedia` | `openverse` | `unsplash` | `pexels`.
  final String? provider;

  /// Human-readable credit line for this one photograph.
  ///
  /// Unsplash and Pexels both require the photographer and the source to be
  /// named; Creative Commons requires creator plus licence. Returns null only
  /// when we hold neither a creator nor a licence.
  String? get attribution {
    final who = (creator ?? '').trim();
    switch (provider) {
      case 'unsplash':
        return who.isEmpty ? 'Photo on Unsplash' : 'Photo by $who on Unsplash';
      case 'pexels':
        return who.isEmpty ? 'Photo on Pexels' : 'Photo by $who on Pexels';
      default:
        final lic = (license ?? '').trim();
        if (who.isEmpty && lic.isEmpty) return null;
        if (who.isEmpty) return lic;
        return lic.isEmpty ? who : '$who · $lic';
    }
  }
}

/// Which rung of the fallback ladder a meal reached (`meal_library.image_mode`).
enum KyleMealImageMode {
  dish,
  mosaic,
  tile,
  none;

  static KyleMealImageMode fromWire(String? v) => switch (v) {
    'dish' => KyleMealImageMode.dish,
    'mosaic' => KyleMealImageMode.mosaic,
    'tile' => KyleMealImageMode.tile,
    _ => KyleMealImageMode.none,
  };
}

class MealImageMosaic extends StatefulWidget {
  const MealImageMosaic({
    super.key,
    required this.tiles,
    this.mode = KyleMealImageMode.mosaic,
    this.aspectRatio,
    this.borderRadius = BorderRadius.zero,
  });

  /// For [KyleMealImageMode.dish] and [KyleMealImageMode.tile] only the first is used.
  final List<KyleMealImageTile> tiles;
  final KyleMealImageMode mode;

  /// Null lets the widget fill its parent's constraints (card thumbnails);
  /// the detail hero passes 16/10.
  final double? aspectRatio;

  final BorderRadius borderRadius;

  @override
  State<MealImageMosaic> createState() => _MealImageMosaicState();
}

class _MealImageMosaicState extends State<MealImageMosaic> {
  /// MIM-5 — urls that failed to decode, so their cell can collapse and the
  /// survivors re-flow to the next legal grid.
  final Set<String> _failed = <String>{};

  @override
  void didUpdateWidget(MealImageMosaic old) {
    super.didUpdateWidget(old);
    if (old.tiles != widget.tiles) _failed.clear();
  }

  List<KyleMealImageTile> get _live {
    final live = widget.tiles.where((t) => !_failed.contains(t.url)).toList();
    // MIM-3 — never more than four.
    return live.length > 4 ? live.sublist(0, 4) : live;
  }

  @override
  Widget build(BuildContext context) {
    // MIM-1/MIM-2 — nothing to show is shown as nothing.
    if (widget.mode == KyleMealImageMode.none) return const SizedBox.shrink();
    final tiles = _live;
    if (tiles.isEmpty) return const SizedBox.shrink();

    final single = widget.mode == KyleMealImageMode.dish ||
        widget.mode == KyleMealImageMode.tile ||
        tiles.length == 1;

    final content = ClipRRect(
      borderRadius: widget.borderRadius,
      child: single ? _cell(tiles.first) : _grid(tiles),
    );

    return widget.aspectRatio == null
        ? content
        : AspectRatio(aspectRatio: widget.aspectRatio!, child: content);
  }

  /// MIM-3 — the legal grid for each tile count.
  Widget _grid(List<KyleMealImageTile> t) {
    const gap = 1.0; // MIM-7
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? AppColors.blackberry : AppColors.cream;

    if (t.length == 2) {
      return Row(children: [
        Expanded(child: _cell(t[0])),
        Container(width: gap, color: divider),
        Expanded(child: _cell(t[1])),
      ]);
    }
    if (t.length == 3) {
      return Row(children: [
        Expanded(child: _cell(t[0])),
        Container(width: gap, color: divider),
        Expanded(
          child: Column(children: [
            Expanded(child: _cell(t[1])),
            Container(height: gap, color: divider),
            Expanded(child: _cell(t[2])),
          ]),
        ),
      ]);
    }
    return Column(children: [
      Expanded(
        child: Row(children: [
          Expanded(child: _cell(t[0])),
          Container(width: gap, color: divider),
          Expanded(child: _cell(t[1])),
        ]),
      ),
      Container(height: gap, color: divider),
      Expanded(
        child: Row(children: [
          Expanded(child: _cell(t[2])),
          Container(width: gap, color: divider),
          Expanded(child: _cell(t[3])),
        ]),
      ),
    ]);
  }

  /// MIM-4 — square-cropped, centred, never distorted.
  Widget _cell(KyleMealImageTile tile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holding = isDark ? AppColors.blackberryLight : AppColors.creamDark;
    return Semantics(
      label: tile.name,
      image: true,
      child: Image.network(
        tile.url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // MIM-8 — no motion; a plain surface holds the space while decoding.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : ColoredBox(color: holding),
        errorBuilder: (context, _, __) {
          // MIM-5 — collapse this cell and re-flow, after this frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _failed.add(tile.url)) setState(() {});
          });
          return ColoredBox(color: holding);
        },
      ),
    );
  }
}
