import 'dart:convert';

import 'vana_part.dart';
import 'wire_record.dart';

/// One NDJSON line from `POST vana-chat` (contract 02 §5):
///
/// ```
/// {"type":"text","delta":"…"}          a "\n" delta separates text blocks
/// {"type":"ui","part":VanaPart}
/// {"type":"status","tool":"suggestMeals"}
/// {"type":"done","usage":{"input_tokens":N,"output_tokens":N}}
/// {"type":"error","message":"…"}
/// ```
sealed class VanaStreamEvent extends WireRecord {
  const VanaStreamEvent();

  String get type;

  /// Parse one raw NDJSON line. Returns `null` for blank lines, non-JSON,
  /// unknown `type`s, and a `ui` line whose part kind is unknown (the caller
  /// drops it — same rule as [VanaPart.fromJson]).
  static VanaStreamEvent? fromJsonLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
    final json = asJsonMap(decoded);
    if (json == null) return null;
    return fromJson(json);
  }

  static VanaStreamEvent? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return VanaTextEvent(readString(json, 'delta') ?? '');
      case 'ui':
        final partJson = asJsonMap(json['part']);
        if (partJson == null) return null;
        final part = VanaPart.fromJson(partJson);
        return part == null ? null : VanaUiEvent(part);
      case 'status':
        return VanaStatusEvent(readString(json, 'tool') ?? '');
      case 'done':
        final usage = asJsonMap(json['usage']) ?? const <String, dynamic>{};
        return VanaDoneEvent(
          inputTokens: readInt(usage, 'input_tokens'),
          outputTokens: readInt(usage, 'output_tokens'),
        );
      case 'error':
        return VanaErrorEvent(readString(json, 'message') ?? '');
      default:
        return null;
    }
  }
}

/// A slice of assistant text. A `"\n"` delta separates text blocks.
class VanaTextEvent extends VanaStreamEvent {
  const VanaTextEvent(this.delta);

  final String delta;

  bool get isBlockSeparator => delta == '\n';

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'delta': delta};
}

/// A tool result rendered as a widget.
class VanaUiEvent extends VanaStreamEvent {
  const VanaUiEvent(this.part);

  final VanaPart part;

  @override
  String get type => 'ui';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'part': part.toJson()};
}

/// Emitted on tool-input-start — drives the "Finding options…" line.
class VanaStatusEvent extends VanaStreamEvent {
  const VanaStatusEvent(this.tool);

  final String tool;

  @override
  String get type => 'status';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'tool': tool};
}

/// Stream finished. Token counts may be null when the model did not report
/// usage.
class VanaDoneEvent extends VanaStreamEvent {
  const VanaDoneEvent({this.inputTokens, this.outputTokens});

  final int? inputTokens;
  final int? outputTokens;

  @override
  String get type => 'done';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'usage': {'input_tokens': inputTokens, 'output_tokens': outputTokens},
  };
}

/// A mid-stream error (pre-stream errors arrive as HTTP status codes).
class VanaErrorEvent extends VanaStreamEvent {
  const VanaErrorEvent(this.message);

  final String message;

  @override
  String get type => 'error';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'message': message};
}
