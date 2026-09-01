import 'vana_part.dart';
import 'wire_record.dart';

/// Who authored a [VanaMessage].
enum VanaMessageRole {
  user('user'),
  assistant('assistant');

  const VanaMessageRole(this.wire);

  final String wire;

  static VanaMessageRole? fromWire(String? value) {
    if (value == null) return null;
    for (final v in VanaMessageRole.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static VanaMessageRole requireWire(String? value) =>
      fromWire(value) ??
      (throw FormatException('Unknown VanaMessageRole "$value"'));
}

/// One chat turn as the client holds it — text plus the rendered [VanaPart]s.
///
/// This is the client model (successor to `AiCoachMessage`), not a
/// `vana_messages` row: the history loader maps the row's `parts` (or
/// `content + metadata.ui_parts`) into it. `id` is the row id, or a
/// client-generated id while a turn is still streaming.
class VanaMessage extends WireRecord {
  const VanaMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.parts = const [],
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final VanaMessageRole role;

  /// The assistant text (text blocks joined by `\n`) or the user's message.
  final String content;
  final List<VanaPart> parts;
  final DateTime createdAt;

  bool get isUser => role == VanaMessageRole.user;

  factory VanaMessage.fromJson(Map<String, dynamic> json) => VanaMessage(
    id: requireString(json, 'id'),
    conversationId: readString(json, 'conversationId') ?? '',
    role: VanaMessageRole.requireWire(readString(json, 'role')),
    content: readString(json, 'content') ?? '',
    parts: VanaPart.listFromJson(json['parts']),
    createdAt:
        DateTime.tryParse(readString(json, 'createdAt') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'role': role.wire,
    'content': content,
    'parts': parts.map((p) => p.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  VanaMessage copyWith({
    String? id,
    String? conversationId,
    VanaMessageRole? role,
    String? content,
    List<VanaPart>? parts,
    DateTime? createdAt,
  }) => VanaMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    parts: parts ?? this.parts,
    createdAt: createdAt ?? this.createdAt,
  );

  /// Append a streamed text delta.
  VanaMessage appendText(String delta) => copyWith(content: content + delta);

  /// Append a streamed part.
  VanaMessage appendPart(VanaPart part) =>
      copyWith(parts: List.unmodifiable([...parts, part]));

  /// Replace the part at [index] (e.g. fold a newer `batch` over an older
  /// one). Out-of-range indices are ignored.
  VanaMessage replacePart(int index, VanaPart part) {
    if (index < 0 || index >= parts.length) return this;
    final next = [...parts];
    next[index] = part;
    return copyWith(parts: List.unmodifiable(next));
  }
}
