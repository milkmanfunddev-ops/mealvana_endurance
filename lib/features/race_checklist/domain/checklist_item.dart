/// Domain model for a race day checklist item
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.category,
    required this.itemName,
    this.sortOrder = 0,
    this.isChecked = false,
    this.checkedAt,
    this.notes,
    this.isTemplateItem = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final String category; // 'gear', 'nutrition', 'logistics', etc.
  final String itemName;
  final int sortOrder;
  final bool isChecked;
  final DateTime? checkedAt;
  final String? notes;
  final bool isTemplateItem;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChecklistItem copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? category,
    String? itemName,
    int? sortOrder,
    bool? isChecked,
    DateTime? checkedAt,
    String? notes,
    bool? isTemplateItem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      itemName: itemName ?? this.itemName,
      sortOrder: sortOrder ?? this.sortOrder,
      isChecked: isChecked ?? this.isChecked,
      checkedAt: checkedAt ?? this.checkedAt,
      notes: notes ?? this.notes,
      isTemplateItem: isTemplateItem ?? this.isTemplateItem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChecklistItem &&
        other.id == id &&
        other.eventId == eventId &&
        other.userId == userId &&
        other.category == category &&
        other.itemName == itemName &&
        other.isChecked == isChecked;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        eventId.hashCode ^
        userId.hashCode ^
        category.hashCode ^
        itemName.hashCode ^
        isChecked.hashCode;
  }

  @override
  String toString() {
    return 'ChecklistItem(id: $id, eventId: $eventId, itemName: $itemName, isChecked: $isChecked)';
  }
}

/// Category constants for checklist items
class ChecklistCategory {
  static const String gear = 'gear';
  static const String nutrition = 'nutrition';
  static const String logistics = 'logistics';
  static const String preRace = 'pre_race';
  static const String raceMorning = 'race_morning';
}
