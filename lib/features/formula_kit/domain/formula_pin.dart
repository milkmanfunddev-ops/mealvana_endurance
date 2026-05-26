import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';

/// Polymorphic ref for [FormulaPin.templateKind].
///
/// Mirrors the `template_kind` CHECK constraint on the Supabase
/// `formula_pins` table. PR 4 will widen this with `personalTemplate`
/// when personal formulas become pinnable.
enum TemplateKind {
  preSystem('pre_system'),
  duringSystem('during_system');

  const TemplateKind(this.wireValue);

  /// String stored in Drift + Supabase.
  final String wireValue;

  static TemplateKind fromWireValue(String value) {
    return TemplateKind.values.firstWhere(
      (k) => k.wireValue == value,
      orElse: () => throw ArgumentError(
        'Unknown TemplateKind wire value: $value',
      ),
    );
  }
}

/// Domain model for a single Formula Kit pin.
///
/// A pin is a user-declared preference signal — when pins exist matching a
/// workout's scope, the plan-generation algorithm tries pinned templates
/// first and falls through to existing scoring if none fit. See PLAN.md PR 2.
///
/// Unpinning sets [isDeleted] to true rather than removing the row (matches
/// the `user_foods` convention). All read paths must filter `WHERE NOT
/// is_deleted`. Sync uses the same offline-first dirty tracking as
/// `personal_templates`.
class FormulaPin {
  const FormulaPin({
    required this.id,
    required this.userId,
    required this.templateId,
    required this.templateKind,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;
  final String templateId;
  final TemplateKind templateKind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Drift-only sync flag (not present in Supabase).
  final bool? needsUpload;

  /// Drift-only timestamp set when local row was last mutated.
  final DateTime? localUpdatedAt;

  factory FormulaPin.fromDriftEntry(FormulaPinEntry entry) {
    return FormulaPin(
      id: entry.id,
      userId: entry.userId,
      templateId: entry.templateId,
      templateKind: TemplateKind.fromWireValue(entry.templateKind),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.isDeleted,
      needsUpload: entry.needsUpload,
      localUpdatedAt: entry.localUpdatedAt,
    );
  }

  FormulaPinsTableCompanion toDriftCompanion() {
    return FormulaPinsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      templateId: Value(templateId),
      templateKind: Value(templateKind.wireValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      needsUpload: Value(needsUpload),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  /// JSON payload sent to Supabase `formula_pins`. Excludes the Drift-only
  /// sync columns (`needs_upload`, `local_updated_at`).
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'template_id': templateId,
      'template_kind': templateKind.wireValue,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  FormulaPin copyWith({
    String? id,
    String? userId,
    String? templateId,
    TemplateKind? templateKind,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return FormulaPin(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      templateId: templateId ?? this.templateId,
      templateKind: templateKind ?? this.templateKind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }
}
