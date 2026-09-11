/// Design SSOT component — **Meal Image Mosaic**.
///
/// Spec: `docs/ssot/spec/design/components/meal-image-mosaic.md` **v1.1**
/// (PROPOSED Lee 2026-09-08, icon state 2026-09-11, awaiting Xuan).
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
///   `mosaic` → an even grid in the order given, `none` → the host's
///   [MealImageMosaic.fallback], or a zero-size box when it has none.
/// * **MIM-2** — `none` draws nothing of its own: no placeholder, no panel.
/// * **MIM-3** — tile count drives the grid: 2 → two columns, 3 → one full
///   column left plus two stacked right, 4 → 2×2. Never more than 4.
/// * **MIM-4** — every tile is square-cropped and centred; equal sizes; never
///   letterboxed, never distorted.
/// * **MIM-5** — a failed image collapses its cell and the rest re-flow to the
///   next legal grid; all failed → MIM-2, so the host's icon rather than a
///   blank slot.
/// * **MIM-7** — a 1px surface-coloured gap is the only separator; the outer
///   radius belongs to the host.
/// * **MIM-8** — no motion beyond the host's standard loading treatment.
/// * **MIM-9** — the icon state: the fallback is drawn in the picture's own
///   box and corners, so a list mixing pictures and icons stays aligned.
///
/// * **MIM-6** — attribution travels with the image: [KyleImageCredit] words
///   and links one photograph's credit the way its provider asks, and
///   [MealImageCredits] shows every distinct photograph behind a picture. Where
///   the credit appears is the host's call — a card thumbnail carries it in
///   semantics only, the detail hero shows it.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

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
    this.creditLine,
  });

  final String url;

  /// The ingredient this tile depicts, for semantics and attribution.
  final String? name;

  final String? license;
  final String? creator;

  /// The page the photograph came from — what its credit opens.
  final String? sourceUrl;

  /// `wikimedia` | `openverse` | `unsplash` | `pexels`, or null for a
  /// photograph taken from a recipe page.
  final String? provider;

  /// A credit already written out, for when the photograph arrives without
  /// the fields above (`search_meals` sends a dish photo's url and this only).
  final String? creditLine;

  /// This photograph's credit, worded and linked as its provider asks: the
  /// photographer links to the photograph's page, and Unsplash and Pexels are
  /// linked themselves because their terms want a link back. Null only when
  /// there is nobody and nowhere to name.
  KyleImageCredit? get credit {
    final who = _clean(creator);
    final source = _webUri(sourceUrl);
    final platform = _platform(source);
    final licence = _licenceLabel(license);
    if (who == null && platform == null && licence == null) {
      final line = _clean(creditLine);
      return line == null ? null : KyleImageCredit([KyleCreditSpan(line)]);
    }
    final page = source == null ? null : _referral(platform, source);
    final home = _stockHomes[platform];
    return KyleImageCredit([
      KyleCreditSpan(who == null ? 'Photo' : 'Photo by '),
      if (who != null) KyleCreditSpan(who, page),
      if (platform != null) ...[
        const KyleCreditSpan(' on '),
        KyleCreditSpan(platform, home ?? (who == null ? page : null)),
      ],
      if (licence != null) KyleCreditSpan(' ($licence)'),
    ]);
  }

  /// The platform named in the credit. Openverse is a search engine over other
  /// sites, so its photographs are credited to the site they live on.
  String? _platform(Uri? source) {
    switch (provider) {
      case 'unsplash':
        return 'Unsplash';
      case 'pexels':
        return 'Pexels';
      case 'wikimedia':
        return 'Wikimedia Commons';
    }
    final host = source?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host == null) return provider == 'openverse' ? 'Openverse' : null;
    return _knownHosts[host] ?? host;
  }

  static const _knownHosts = {
    'unsplash.com': 'Unsplash',
    'pexels.com': 'Pexels',
    'commons.wikimedia.org': 'Wikimedia Commons',
    'flickr.com': 'Flickr',
  };

  static final _stockHomes = {
    'Unsplash': _referral('Unsplash', Uri.https('unsplash.com', '/')),
    'Pexels': Uri.https('www.pexels.com', '/'),
  };

  /// Unsplash's API terms require every link back to carry the app's name and
  /// `utm_medium=referral`. It must match the application registered with
  /// Unsplash.
  static const _unsplashApp = 'mealvana';

  static Uri _referral(String? platform, Uri uri) => platform != 'Unsplash'
      ? uri
      : uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'utm_source': _unsplashApp,
            'utm_medium': 'referral',
          },
        );

  static String? _clean(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static Uri? _webUri(String? v) {
    final uri = Uri.tryParse(v?.trim() ?? '');
    if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      return null;
    }
    return uri.host.isEmpty ? null : uri;
  }

  /// One spelling per licence, whichever way the pipeline stored it
  /// (`cc-by-sa-4.0`, `CC BY-SA 4.0`, `cc0-or-pd`). The stock licences are
  /// already named by their platform, so they are not repeated.
  static String? _licenceLabel(String? raw) {
    final s = _clean(raw);
    if (s == null) return null;
    final l = s.toLowerCase();
    if (l == 'unsplash' || l == 'pexels') return null;
    if (RegExp(r'^(pd|pdm|public domain|cc0[\s-]or[\s-]pd)$').hasMatch(l)) {
      return 'public domain';
    }
    if (RegExp(r'^cc0([\s-]1\.0)?$').hasMatch(l)) return 'CC0';
    final by = RegExp(
      r'^cc[\s-]+by((?:[\s-]+(?:sa|nc|nd))*)(?:[\s-]+(\d+(?:\.\d+)?))?$',
    ).firstMatch(l);
    if (by == null) return s;
    final terms = [
      'CC BY',
      ...by
          .group(1)!
          .split(RegExp(r'[\s-]+'))
          .where((t) => t.isNotEmpty)
          .map((t) => t.toUpperCase()),
    ].join('-');
    return by.group(2) == null ? terms : '$terms ${by.group(2)}';
  }
}

/// A run of a credit's text, and where it goes when tapped.
@immutable
class KyleCreditSpan {
  const KyleCreditSpan(this.text, [this.link]);

  final String text;
  final Uri? link;
}

/// One photograph's credit, as the licence wants it worded and linked.
///
/// The wording is the providers' own ("Photo by … on Unsplash"), so it lives
/// here rather than in the content system, where an edit could break a
/// licence term.
@immutable
class KyleImageCredit {
  const KyleImageCredit(this.spans);

  final List<KyleCreditSpan> spans;

  String get text => spans.map((s) => s.text).join();

  /// Every distinct photograph the picture shows, credited once each, in the
  /// order shown. A photograph is the page it came from, so two photographs
  /// by one photographer are two credits and one photograph in two cells is one.
  static List<KyleImageCredit> forPicture(
    KyleMealImageMode mode,
    List<KyleMealImageTile> tiles,
  ) {
    final shown = switch (mode) {
      KyleMealImageMode.none => const <KyleMealImageTile>[],
      KyleMealImageMode.dish || KyleMealImageMode.tile => tiles.take(1),
      KyleMealImageMode.mosaic => tiles.take(4), // MIM-3
    };
    final seen = <String>{};
    return [
      for (final tile in shown)
        if (seen.add(tile.sourceUrl ?? tile.url)) ?tile.credit,
    ];
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
    this.fallback,
  });

  /// For [KyleMealImageMode.dish] and [KyleMealImageMode.tile] only the first is used.
  final List<KyleMealImageTile> tiles;
  final KyleMealImageMode mode;

  /// Null lets the widget fill its parent's constraints (card thumbnails);
  /// the detail hero passes 16/10.
  final double? aspectRatio;

  final BorderRadius borderRadius;

  /// MIM-9 — what stands in the picture's place when there is nothing to show:
  /// mode `none`, or every photograph failed to load. The host passes the
  /// Meal's icon; it gets the same box and corners a picture would. Null
  /// takes no space (MIM-2), as the detail hero wants.
  final Widget? fallback;

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
    final tiles = widget.mode == KyleMealImageMode.none
        ? const <KyleMealImageTile>[]
        : _live;

    final Widget picture;
    if (tiles.isEmpty) {
      // MIM-2/MIM-9 — nothing to show is shown as nothing, or as the host's
      // icon in the picture's place.
      final fallback = widget.fallback;
      if (fallback == null) return const SizedBox.shrink();
      picture = fallback;
    } else {
      final single =
          widget.mode == KyleMealImageMode.dish ||
          widget.mode == KyleMealImageMode.tile ||
          tiles.length == 1;
      picture = single ? _cell(tiles.first) : _grid(tiles);
    }

    final content = ClipRRect(
      borderRadius: widget.borderRadius,
      child: picture,
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
      return Row(
        children: [
          Expanded(child: _cell(t[0])),
          Container(width: gap, color: divider),
          Expanded(child: _cell(t[1])),
        ],
      );
    }
    if (t.length == 3) {
      return Row(
        children: [
          Expanded(child: _cell(t[0])),
          Container(width: gap, color: divider),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _cell(t[1])),
                Container(height: gap, color: divider),
                Expanded(child: _cell(t[2])),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(t[0])),
              Container(width: gap, color: divider),
              Expanded(child: _cell(t[1])),
            ],
          ),
        ),
        Container(height: gap, color: divider),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(t[2])),
              Container(width: gap, color: divider),
              Expanded(child: _cell(t[3])),
            ],
          ),
        ),
      ],
    );
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

/// MIM-6 — the credits for a picture shown at size: every distinct photograph,
/// its photographer and platform tappable. [onOpen] receives the link; the host
/// decides how to open it.
class MealImageCredits extends StatefulWidget {
  const MealImageCredits({
    super.key,
    required this.tiles,
    required this.onOpen,
    this.mode = KyleMealImageMode.mosaic,
  });

  /// The same tiles and mode the [MealImageMosaic] beside it was given.
  final List<KyleMealImageTile> tiles;
  final KyleMealImageMode mode;
  final ValueChanged<Uri> onOpen;

  @override
  State<MealImageCredits> createState() => _MealImageCreditsState();
}

class _MealImageCreditsState extends State<MealImageCredits> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credits = KyleImageCredit.forPicture(widget.mode, widget.tiles);
    _disposeRecognizers();
    if (credits.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.65,
    );
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    TextSpan span(KyleCreditSpan s) {
      final link = s.link;
      if (link == null) return TextSpan(text: s.text);
      final tap = TapGestureRecognizer()..onTap = () => widget.onOpen(link);
      _recognizers.add(tap);
      return TextSpan(
        text: s.text,
        style: TextStyle(color: accent, fontWeight: FontWeight.w600),
        recognizer: tap,
      );
    }

    return Text.rich(
      TextSpan(
        style: AppTextStyles.bodySmall.copyWith(color: ink),
        children: [
          for (final (i, credit) in credits.indexed) ...[
            if (i > 0) const TextSpan(text: ' · '),
            ...credit.spans.map(span),
          ],
        ],
      ),
    );
  }
}
