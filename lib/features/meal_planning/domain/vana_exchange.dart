import 'vana_message.dart';
import 'vana_part.dart';

/// The sheet's reading of one exchange (vana-sheet spec, "Inside the sheet"):
/// the quick replies, and where the typing indicator goes. The export's
/// status chip, which once read the exchange too, is not drawn (Lee,
/// 2026-09-16), so nothing here says whether a turn waits on the athlete.
///
/// An exchange starts at a message: the conversation's first, or a later one
/// when Vana raises something mid-thread (vana-moment spec VM-1). Its
/// **opening** is Vana's turns from there to the athlete's next. A `choices`
/// part in the opening is offered as quick replies — at most two — and never
/// drawn inline. The **thread** is the athlete's first turn in the exchange
/// and everything after; the moment it has anything in it the quick replies
/// retire, and they do not come back in that exchange (VS-8).
class VanaExchange {
  const VanaExchange._({
    required this.quickReplies,
    required List<(int, int)> openings,
    required this.typing,
  }) : _openings = openings;

  /// Derives the exchange from the transcript. [start] is the index of the
  /// exchange's first message. Pass [repliesRetired] once the thread has had
  /// anything in it, so a thread that is later emptied (a rewind) does not
  /// bring the replies back.
  factory VanaExchange.of(
    List<VanaMessage> messages, {
    required bool isStreaming,
    int start = 0,
    bool repliesRetired = false,
  }) {
    start = start.clamp(0, messages.length);
    int athleteFrom(int from) {
      for (var i = from; i < messages.length; i++) {
        if (messages[i].isUser) return i;
      }
      return messages.length;
    }

    // The conversation's own opening, and this exchange's when it starts
    // later: both are drawn as openings.
    final openings = <(int, int)>[
      (0, athleteFrom(0)),
      if (start > 0) (start, athleteFrom(start)),
    ];
    final threadStarted =
        athleteFrom(start) < messages.length || repliesRetired;

    final replies = <String>[];
    if (!threadStarted && !isStreaming) {
      for (final message in messages.skip(start).toList().reversed) {
        if (_offer(message) case final offer?) {
          replies.addAll(offer.options.take(maxQuickReplies));
          break;
        }
      }
    }

    return VanaExchange._(
      quickReplies: List.unmodifiable(replies),
      openings: openings,
      typing:
          isStreaming &&
          messages.isNotEmpty &&
          !messages.last.isUser &&
          messages.last.content.isEmpty,
    );
  }

  /// The spec's cap: one filled reply and one outline.
  static const int maxQuickReplies = 2;

  /// Zero to two labels. Empty once the thread has started, and while a turn
  /// is in flight — never alongside the typing indicator.
  final List<String> quickReplies;

  /// The openings' index ranges, start inclusive, end exclusive.
  final List<(int, int)> _openings;

  bool _inOpening(int index) =>
      _openings.any((o) => index >= o.$1 && index < o.$2);

  /// A turn is in flight and Vana has not said anything in it yet.
  final bool typing;

  /// The parts of the message at [index] drawn inline: all of them, except
  /// that the opening's offers are the quick replies and never drawn, so they
  /// cannot come back once the thread has started.
  List<VanaPart> inlineParts(int index, VanaMessage message) =>
      _inOpening(index)
      ? [
          for (final part in message.parts)
            if (part is! VanaChoicesPart) part,
        ]
      : message.parts;

  /// The prose of the message at [index]: its text, and in the opening the
  /// offers' question, which would otherwise go undrawn with them.
  String prose(int index, VanaMessage message) {
    final question = _inOpening(index) ? _offer(message)?.question : null;
    return [
      if (message.content.isNotEmpty) message.content,
      if (question != null && question.isNotEmpty) question,
    ].join('\n');
  }

  static VanaChoicesPart? _offer(VanaMessage message) => message.isUser
      ? null
      : message.parts.whereType<VanaChoicesPart>().firstOrNull;
}
