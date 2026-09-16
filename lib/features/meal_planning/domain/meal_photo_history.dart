import 'meal_photo.dart';
import 'wire_record.dart';

/// One photograph a Meal has shown, as the `meal-photo` function lists it.
///
/// History is the honest record behind "a mistake or vandalism is one tap to
/// undo" (ADR 0003): replacing a photo keeps the old row, and every row says
/// who added it and when. A Meal whose photograph came from the ticket-01
/// switchover has an empty History on purpose — a rejected pipeline picture
/// must never be restorable with a tap.
class MealPhotoHistoryEntry extends WireRecord {
  const MealPhotoHistoryEntry({
    required this.id,
    required this.photo,
    required this.isCurrent,
    this.storagePath,
    this.addedBy,
    this.addedAt,
  });

  /// `meal_photo_history.id` — what Restore and Delete name (ticket 06).
  final String id;

  /// The photograph itself, parsed by the same [MealPhoto] the recipe screen
  /// draws, so a History thumbnail can never differ from what it restores.
  final MealPhoto photo;

  /// Whether this is the photograph the Meal is wearing right now. Decided by
  /// the server from `meal_library.photo_history_id`, not by comparing
  /// addresses here — two rows can share an address.
  final bool isCurrent;

  /// Object path in our storage, or null for a web address shown where it
  /// lives. Ticket 05 fills it; ticket 06 deletes the file it names.
  final String? storagePath;

  /// The account that added it, or null once that account is gone.
  final String? addedBy;

  /// Server clock (`created_at`), or null when the row predates the column
  /// being sent.
  final DateTime? addedAt;

  static MealPhotoHistoryEntry? fromJsonOrNull(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = readString(json, 'id')?.trim();
    final photo = MealPhoto.fromJsonOrNull(json);
    if (id == null || id.isEmpty || photo == null) return null;
    return MealPhotoHistoryEntry(
      id: id,
      photo: photo,
      isCurrent: json['isCurrent'] == true,
      storagePath: readString(json, 'storagePath'),
      addedBy: readString(json, 'addedBy'),
      addedAt: DateTime.tryParse(readString(json, 'createdAt') ?? '')?.toLocal(),
    );
  }

  MealPhotoHistoryEntry copyWith({bool? isCurrent}) => MealPhotoHistoryEntry(
    id: id,
    photo: photo,
    isCurrent: isCurrent ?? this.isCurrent,
    storagePath: storagePath,
    addedBy: addedBy,
    addedAt: addedAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    ...photo.toJson(),
    'isCurrent': isCurrent,
    'storagePath': storagePath,
    'addedBy': addedBy,
    'createdAt': addedAt?.toUtc().toIso8601String(),
  };
}

/// What the Meal photos page shows: what athletes see now, and everything this
/// Meal has shown before.
class MealPhotos {
  const MealPhotos({this.photo, this.history = const []});

  /// The Meal's current Dish photo, or null when it shows no picture at all.
  final MealPhoto? photo;

  /// Newest first.
  final List<MealPhotoHistoryEntry> history;

  static MealPhotos fromJson(Map<String, dynamic> json) => MealPhotos(
    photo: MealPhoto.fromJsonOrNull(asJsonMap(json['photo'])),
    history: [
      for (final row in (json['history'] as List<dynamic>? ?? const []))
        if (MealPhotoHistoryEntry.fromJsonOrNull(asJsonMap(row))
            case final entry?)
          entry,
    ],
  );

  /// The state after a Tester's add is acknowledged: the new photograph is the
  /// current one, and whatever was there is still in History.
  ///
  /// Built from the acknowledgement rather than re-read, so a successful
  /// publish is never reported as a failure because a second request happened
  /// to fail after it (story 32).
  MealPhotos withAdded(MealPhotoHistoryEntry added) => MealPhotos(
    photo: added.photo,
    history: [
      added,
      for (final e in history)
        if (e.id != added.id) e.copyWith(isCurrent: false),
    ],
  );
}
