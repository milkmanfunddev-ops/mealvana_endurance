/// The picture of a meal: which rung of the fallback ladder it reached, the
/// real dish photograph when there is one, and the ingredient tiles when there
/// is not. Pipeline and licensing: `docs/meal-images/README.md`.
///
/// These types live in their own file because both `MealRef` (cards) and
/// `MealDetail` (the detail screen) carry them; putting them in either would
/// make the two domain files import each other.
library;

import 'wire_record.dart';

/// Which rung of the image fallback ladder a meal reached
/// (`meal_library.image_mode`). Domain-side twin of the Meal Image Mosaic
/// component's own enum — presentation maps between them, so the shared widget
/// stays independent of this feature.
enum MealImageMode {
  dish,
  mosaic,
  tile,
  none;

  static MealImageMode fromWire(String? v) => switch (v) {
    'dish' => MealImageMode.dish,
    'mosaic' => MealImageMode.mosaic,
    'tile' => MealImageMode.tile,
    _ => MealImageMode.none,
  };
}

/// One ingredient photograph backing a meal's mosaic, with the attribution the
/// licence requires. See `docs/meal-images/README.md`.
class MealImageTile extends WireRecord {
  const MealImageTile({
    required this.url,
    this.name,
    this.license,
    this.creator,
    this.sourceUrl,
    this.provider,
  });

  final String url;
  final String? name;
  final String? license;
  final String? creator;
  final String? sourceUrl;

  /// `wikimedia` | `openverse` | `unsplash` | `pexels`.
  final String? provider;

  factory MealImageTile.fromJson(Map<String, dynamic> json) => MealImageTile(
    url: requireString(json, 'url'),
    name: readString(json, 'name'),
    license: readString(json, 'license'),
    creator: readString(json, 'creator'),
    sourceUrl: readString(json, 'sourceUrl'),
    provider: readString(json, 'provider'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'license': license,
    'creator': creator,
    'sourceUrl': sourceUrl,
    'provider': provider,
  };
}

/// `MealDetail.image` — hero image with licensing attribution.
class MealImage extends WireRecord {
  const MealImage({
    required this.url,
    this.license,
    this.creator,
    this.credit,
    this.sourceUrl,
  });

  final String url;
  final String? license;
  final String? creator;
  final String? credit;
  final String? sourceUrl;

  factory MealImage.fromJson(Map<String, dynamic> json) => MealImage(
    url: requireString(json, 'url'),
    license: readString(json, 'license'),
    creator: readString(json, 'creator'),
    credit: readString(json, 'credit'),
    sourceUrl: readString(json, 'sourceUrl'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'url': url,
    'license': license,
    'creator': creator,
    'credit': credit,
    'sourceUrl': sourceUrl,
  };

  MealImage copyWith({
    String? url,
    String? license,
    String? creator,
    String? credit,
    String? sourceUrl,
  }) => MealImage(
    url: url ?? this.url,
    license: license ?? this.license,
    creator: creator ?? this.creator,
    credit: credit ?? this.credit,
    sourceUrl: sourceUrl ?? this.sourceUrl,
  );
}
