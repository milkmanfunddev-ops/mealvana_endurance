import 'vana_message.dart';
import 'vana_part.dart';
import 'vana_situation.dart';

/// Whether something in the exchange waits on the athlete.
enum VanaExchangeStatus {
  /// Vana's latest settled turn asks the athlete for something: a choice in
  /// the thread, a meal to pick, a rule to accept, staples or pantry to tick.
  /// It stays a to-do while the athlete's answer is in flight.
  toDo,

  /// Vana has spoken and nothing she said waits on the athlete. The opening's
  /// offers are a menu, not a to-do.
  update,
}

/// What a to-do in the exchange is about, when that can be named.
enum VanaExchangeTopic {
  /// A session's fuelling: the Fuel Timeline, a fuel log, a session's plan.
  fuelPlan,

  /// The week's meals: a planning part, or a food screen underneath.
  mealPlan,
}

/// The sheet's reading of one exchange (vana-sheet spec, "Inside the sheet"):
/// the status chip, the quick replies, and where the typing indicator goes.
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
    required this.status,
    required this.topic,
    required this.quickReplies,
    required List<(int, int)> openings,
    required this.typing,
    required this.oneMessage,
  }) : _openings = openings;

  /// Derives the exchange from the transcript. [start] is the index of the
  /// exchange's first message. [situationRoute] is the route of the screen
  /// underneath (a [VanaScreen] route, or any other route), used to name a
  /// to-do the transcript does not name itself. Pass [repliesRetired] once
  /// the thread has had anything in it, so a thread that is later emptied (a
  /// rewind) does not bring the replies back.
  ///
  /// [raisedFor] says Vana raised this exchange herself, about that topic (a
  /// moment): its opening's offers answer a question she asked, so they are
  /// a to-do rather than a menu.
  factory VanaExchange.of(
    List<VanaMessage> messages, {
    required bool isStreaming,
    int start = 0,
    String? situationRoute,
    bool repliesRetired = false,
    VanaExchangeTopic? raisedFor,
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
    bool raisedOpening(int i) =>
        raisedFor != null && i >= start && i < athleteFrom(start);

    // The in-flight turn is not settled until the stream ends; the athlete's
    // turns say nothing about what Vana is waiting for.
    final settled = isStreaming && messages.isNotEmpty
        ? messages.length - 1
        : messages.length;
    final lastVana = messages
        .take(settled)
        .toList()
        .lastIndexWhere((m) => !m.isUser);
    final opening = openings.any((o) => lastVana >= o.$1 && lastVana < o.$2);
    final ask = lastVana < 0
        ? null
        : _ask(
            messages[lastVana].parts,
            opening: opening && !raisedOpening(lastVana),
          );
    final status = lastVana < 0
        ? null
        : ask == null
        ? VanaExchangeStatus.update
        : VanaExchangeStatus.toDo;

    final replies = <String>[];
    if (!threadStarted && !isStreaming) {
      for (final message in messages.skip(start).toList().reversed) {
        if (_offer(message) case final offer?) {
          replies.addAll(offer.options.take(maxQuickReplies));
          break;
        }
      }
    }

    final vanaTurns = messages.where((m) => !m.isUser).toList();
    final oneMessage =
        !threadStarted &&
        !isStreaming &&
        start == 0 &&
        vanaTurns.length == 1 &&
        replies.length <= 1 &&
        vanaTurns.single.parts.every((p) => p is VanaChoicesPart);

    return VanaExchange._(
      status: status,
      topic: ask == null
          ? null
          : raisedOpening(lastVana)
          ? raisedFor
          : _topicOfPart(ask) ?? _topicOfRoute(situationRoute),
      quickReplies: List.unmodifiable(replies),
      openings: openings,
      typing:
          isStreaming &&
          messages.isNotEmpty &&
          !messages.last.isUser &&
          messages.last.content.isEmpty,
      oneMessage: oneMessage,
    );
  }

  /// The spec's cap: one filled reply and one outline.
  static const int maxQuickReplies = 2;

  /// Null before Vana has said anything (no chip).
  final VanaExchangeStatus? status;

  /// What the to-do is about; null for an update, or a to-do nothing names.
  final VanaExchangeTopic? topic;

  /// Zero to two labels. Empty once the thread has started, and while a turn
  /// is in flight — never alongside the typing indicator.
  final List<String> quickReplies;

  /// The openings' index ranges, start inclusive, end exclusive.
  final List<(int, int)> _openings;

  bool _inOpening(int index) =>
      _openings.any((o) => index >= o.$1 && index < o.$2);

  /// A turn is in flight and Vana has not said anything in it yet.
  final bool typing;

  /// The exchange is one settled message of Vana's and at most one reply (a
  /// dismiss): no card, no thread (the spec's "one message and a dismiss").
  final bool oneMessage;

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

  /// The part of a settled Vana turn that asks the athlete for something. An
  /// [opening] turn's `choices` are offers, not an ask.
  static VanaPart? _ask(List<VanaPart> parts, {required bool opening}) {
    for (final part in parts.reversed) {
      switch (part) {
        case VanaChoicesPart() when !opening:
          return part;
        case VanaMealPickerPart() ||
            VanaRulePart() ||
            VanaStaplesPart() ||
            VanaPantryPart():
          return part;
        default:
          continue;
      }
    }
    return null;
  }

  static VanaExchangeTopic? _topicOfPart(VanaPart part) => switch (part) {
    VanaMealPickerPart() ||
    VanaRulePart() ||
    VanaStaplesPart() ||
    VanaPantryPart() => VanaExchangeTopic.mealPlan,
    _ => null,
  };

  static final _fuelRoutes = {
    VanaScreen.main.route,
    VanaScreen.fuelLog.route,
    VanaScreen.activityPlan.route,
    VanaScreen.currentPlan.route,
  };

  static final _foodRoutes = {
    VanaScreen.planTab.route,
    VanaScreen.mealDetail.route,
    VanaScreen.cookingMode.route,
  };

  static VanaExchangeTopic? _topicOfRoute(String? route) {
    if (_fuelRoutes.contains(route)) return VanaExchangeTopic.fuelPlan;
    if (_foodRoutes.contains(route)) return VanaExchangeTopic.mealPlan;
    return null;
  }
}
