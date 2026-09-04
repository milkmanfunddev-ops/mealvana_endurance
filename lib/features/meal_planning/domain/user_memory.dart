import 'memory_kind.dart';
import 'wire_record.dart';

/// A `user_memories` row — `Memory` in `contracts.ts`.
///
/// [value] is `unknown` on the wire: a bool for settings, otherwise whatever
/// the tool stored (kept as-is; the JSON scalar/collection is the type).
class UserMemory extends WireRecord {
  const UserMemory({
    required this.id,
    required this.kind,
    this.key,
    required this.fact,
    this.value,
    required this.confidence,
    required this.lastConfirmedAt,
    this.source,
  });

  final String id;
  final MemoryKind kind;

  /// Settings key for `kind = setting` (see `VanaSetting`); may be null.
  final String? key;
  final String fact;
  final Object? value;
  final double confidence;

  /// ISO timestamp as sent.
  final String lastConfirmedAt;

  /// Where the memory came from — `conversation` · `onboarding` ·
  /// `settings` · `debrief` (plan Phase 2.4 provenance). `null` on rows
  /// written before the column existed; rendered as the date alone.
  final String? source;

  DateTime? get lastConfirmedAtDateTime => DateTime.tryParse(lastConfirmedAt);

  factory UserMemory.fromJson(Map<String, dynamic> json) => UserMemory(
    id: requireString(json, 'id'),
    kind: MemoryKind.requireWire(readString(json, 'kind')),
    key: readString(json, 'key'),
    fact: readString(json, 'fact') ?? '',
    value: json['value'],
    confidence: readDouble(json, 'confidence') ?? 0,
    lastConfirmedAt: readString(json, 'lastConfirmedAt') ?? '',
    source: readString(json, 'source'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wire,
    'key': key,
    'fact': fact,
    'value': value,
    'confidence': confidence,
    'lastConfirmedAt': lastConfirmedAt,
    'source': source,
  };

  UserMemory copyWith({
    String? id,
    MemoryKind? kind,
    String? key,
    String? fact,
    Object? value,
    double? confidence,
    String? lastConfirmedAt,
    String? source,
  }) => UserMemory(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    key: key ?? this.key,
    fact: fact ?? this.fact,
    value: value ?? this.value,
    confidence: confidence ?? this.confidence,
    lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
    source: source ?? this.source,
  );
}
