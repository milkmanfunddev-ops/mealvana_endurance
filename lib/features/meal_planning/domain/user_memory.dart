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

  DateTime? get lastConfirmedAtDateTime => DateTime.tryParse(lastConfirmedAt);

  factory UserMemory.fromJson(Map<String, dynamic> json) => UserMemory(
    id: requireString(json, 'id'),
    kind: MemoryKind.requireWire(readString(json, 'kind')),
    key: readString(json, 'key'),
    fact: readString(json, 'fact') ?? '',
    value: json['value'],
    confidence: readDouble(json, 'confidence') ?? 0,
    lastConfirmedAt: readString(json, 'lastConfirmedAt') ?? '',
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
  };

  UserMemory copyWith({
    String? id,
    MemoryKind? kind,
    String? key,
    String? fact,
    Object? value,
    double? confidence,
    String? lastConfirmedAt,
  }) => UserMemory(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    key: key ?? this.key,
    fact: fact ?? this.fact,
    value: value ?? this.value,
    confidence: confidence ?? this.confidence,
    lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
  );
}
