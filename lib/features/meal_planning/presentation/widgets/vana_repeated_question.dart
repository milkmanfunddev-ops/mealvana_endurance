import '../../domain/vana_message.dart';
import '../../domain/vana_part.dart';

/// [message] as the transcript draws it: when Vana's prose ends on the same
/// question the turn's choice prompt asks right under it, the bubble drops
/// that trailing question so it shows once, as the prompt above the chips
/// (testing-wave 15-002). The rest of her words are untouched: this is
/// presentation, never a rewrite of what the model drafted (mp-007/008).
///
/// The match ignores case and runs of whitespace, and only takes a whole
/// trailing sentence (it starts the prose or follows whitespace).
VanaMessage withoutRepeatedQuestion(VanaMessage message) {
  if (message.isUser || message.content.isEmpty) return message;
  for (final part in message.parts) {
    if (part is! VanaChoicesPart) continue;
    final words = (part.question ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (words.isEmpty) continue;
    final match = RegExp(
      '(^|\\s)${words.join(r'\s+')}\\s*\$',
      caseSensitive: false,
    ).firstMatch(message.content);
    if (match == null) continue;
    return message.copyWith(
      content: message.content.substring(0, match.start).trimRight(),
    );
  }
  return message;
}
