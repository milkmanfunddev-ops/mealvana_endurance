import 'package:meta/meta.dart';

import 'wire_record.dart';

/// The one photograph a Meal shows, or nothing (ADR 0003).
///
/// A Dish photo is an address plus an optional credit. The address points at
/// our storage or straight at the web; where it came from doesn't change how
/// it's shown, so there are no kinds of photo. A Meal with none shows no
/// picture at all — no Mosaic, no ingredient Tile, no placeholder box, no
/// icon — so the absence is modelled as a null [MealPhoto], never as an empty
/// one.
///
/// Both `MealRef` (cards) and `MealDetail` (the recipe screen) carry one;
/// this file is their common ground, as `meal_image.dart` was before the
/// ladder was retired.
class MealPhoto extends WireRecord {
  const MealPhoto({required this.url, this.credit, this.creditUrl});

  /// `meal_library.photo_url` — an https address.
  final String url;

  /// One line naming whoever is owed a credit, already worded
  /// (`meal_library.photo_credit`). Null for a photo that needs none, such as
  /// one a Tester took: the recipe screen then shows no line at all.
  final String? credit;

  /// The page [credit] opens when tapped — the photograph's own page, not the
  /// photographer's profile. Null when there is nowhere to go.
  final String? creditUrl;

  /// Null when the row has no address, which is how "this Meal shows nothing"
  /// arrives from every producer.
  static MealPhoto? fromJsonOrNull(Map<String, dynamic>? json) {
    if (json == null) return null;
    final url = readString(json, 'url')?.trim();
    if (url == null || url.isEmpty) return null;
    return MealPhoto(
      url: url,
      credit: _clean(readString(json, 'credit')),
      creditUrl: _clean(readString(json, 'creditUrl')),
    );
  }

  /// The same, from the snake_case columns `search_meals` returns.
  static MealPhoto? fromRow(Map<String, dynamic> row) {
    final url = readString(row, 'photo_url')?.trim();
    if (url == null || url.isEmpty) return null;
    return MealPhoto(
      url: url,
      credit: _clean(readString(row, 'photo_credit')),
      creditUrl: _clean(readString(row, 'photo_credit_url')),
    );
  }

  static String? _clean(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// What makes two photographs the same one, so a list never shows one twice.
  ///
  /// A mirrored photograph is stored once per Meal — two Meals wearing one
  /// Wikimedia file have different storage addresses — so the page it came
  /// from is what says they are the same picture. A stock CDN's resize
  /// parameters are not part of the picture, so the query string is dropped.
  /// Keyed the same way as `pictureIdentity` in the frozen pipeline's
  /// `scripts/_archived/meal-images/lib/ladder.mjs`.
  Set<String> get identity => {
    url.split('?').first,
    if (creditUrl case final page? when page.isNotEmpty) page,
  };

  @override
  Map<String, dynamic> toJson() => {
    'url': url,
    'credit': credit,
    'creditUrl': creditUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is MealPhoto &&
      other.url == url &&
      other.credit == credit &&
      other.creditUrl == creditUrl;

  @override
  int get hashCode => Object.hash(url, credit, creditUrl);
}

/// What a list hands one card where its picture goes.
///
/// Omitting the slot lets a card draw the Meal's own photo. Passing one wins:
/// `photosForList` gives a card [empty] when the photograph above it is the
/// same one, and an empty slot draws nothing, exactly as a Meal with no photo
/// does (ADR 0003).
@immutable
class MealPhotoSlot {
  const MealPhotoSlot(this.photo);

  static const empty = MealPhotoSlot(null);

  final MealPhoto? photo;
}
