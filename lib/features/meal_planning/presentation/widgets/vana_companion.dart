/// Vana everywhere: the launcher on every ordinary screen, and the sheet it
/// opens into (vana-sheet spec; the widgets are
/// `lib/shared/widgets/kyle_design/navigation/vana_sheet.dart`).
///
/// [VanaCompanionHost] sits above the router's Navigator (composed in
/// `MaterialApp.builder`) so the launcher floats over every route. It decides
/// from the router alone whether the launcher renders
/// ([vanaLauncherShownOn]), hides it under any dialog or sheet via
/// [VanaCompanionObserver], and tells the Situation which route is on top.
/// [VanaCompanionSheet] is the conversation inside the sheet: today's ambient
/// general conversation, the same Vana as the chat route.
///
/// When Vana has something to say first (vana-moment spec), the launcher
/// rings, shows its pill and stays tinted ([VanaMomentController] holds the
/// moment), and a tap opens the sheet on the moment (VM-1).
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/widgets/kyle_design/navigation/vana_sheet.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../subscription/application/pro_gate.dart';
import '../../../subscription/presentation/pro_gate_redirect.dart';
import '../../application/vana_ambient_conversation_controller.dart';
import '../../application/vana_chat_controller.dart';
import '../../application/vana_moment_controller.dart';
import '../../application/vana_situation_controller.dart';
import '../../domain/vana_conversation_kind.dart';
import '../../domain/vana_exchange.dart';
import '../../domain/vana_launcher_rule.dart';
import '../../domain/vana_message.dart';
import '../../domain/vana_moment.dart';
import 'part_entrance.dart';
import 'streamed_text.dart';
import 'vana_part_renderer.dart';

/// Watches the root Navigator for a dialog or sheet on top of the page, so
/// the launcher never floats over one (its own sheet included). Add it to the
/// router's observers and hand the same instance to [VanaCompanionHost].
class VanaCompanionObserver extends NavigatorObserver {
  /// True while the top route is a popup (dialog, bottom sheet, the Vana
  /// sheet). Turns false the moment a popup starts to pop, so the launcher is
  /// back in time for the sheet to condense into it.
  final ValueNotifier<bool> popupOnTop = ValueNotifier(false);

  final List<Route<dynamic>> _routes = [];

  void _update() =>
      popupOnTop.value = _routes.isNotEmpty && _routes.last is PopupRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) {
      if (i >= 0) {
        _routes[i] = newRoute;
      } else {
        _routes.add(newRoute);
      }
    } else if (i >= 0) {
      _routes.removeAt(i);
    }
    _update();
  }
}

/// The app's one observer, added to the router in `app_router.dart`.
final vanaCompanionObserver = VanaCompanionObserver();

/// The route on top of [config]: its location path and its route pattern. A
/// pushed route carries its own match list.
({String path, String pattern}) _top(RouteMatchList config) {
  if (config.matches.isEmpty) return (path: '', pattern: '');
  final last = config.last;
  final list = last is ImperativeRouteMatch ? last.matches : config;
  return (path: list.uri.path, pattern: list.fullPath);
}

/// The launcher over [child] (the router's Navigator), bottom-right, on every
/// route [vanaLauncherShownOn] allows (VS-6: elsewhere there is no node).
class VanaCompanionHost extends ConsumerStatefulWidget {
  const VanaCompanionHost({
    super.key,
    required this.router,
    required this.observer,
    required this.child,
  });

  final GoRouter router;
  final VanaCompanionObserver observer;
  final Widget child;

  @override
  ConsumerState<VanaCompanionHost> createState() => _VanaCompanionHostState();
}

class _VanaCompanionHostState extends ConsumerState<VanaCompanionHost> {
  String _path = '';
  bool _popupOnTop = false;

  /// Watches a conversation the server has not named yet, so the day holds
  /// it even when the sheet closes, or hands over to the full-screen chat,
  /// before the first event arrives.
  ProviderSubscription<AsyncValue<VanaChatState>>? _naming;

  /// Set from the launcher tap until the sheet has closed. The launcher only
  /// leaves the tree on the frame after the push, so a second tap can still
  /// land on it; it must not open a second sheet.
  bool _opening = false;

  /// The moment a ring has been asked for, so a rebuild does not ask twice.
  String? _ringing;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    widget.observer.popupOnTop.addListener(_onPopup);
    _popupOnTop = widget.observer.popupOnTop.value;
    _onRoute();
  }

  @override
  void dispose() {
    _naming?.close();
    widget.router.routerDelegate.removeListener(_onRoute);
    widget.observer.popupOnTop.removeListener(_onPopup);
    super.dispose();
  }

  void _onRoute() {
    final top = _top(widget.router.routerDelegate.currentConfiguration);
    // The Vana routes speak for no screen: the one under them stays the
    // Situation, so the full-screen chat still knows what was underneath.
    if (top.pattern.isNotEmpty && !isVanaRoute(top.path)) {
      ref
          .read(vanaSituationControllerProvider.notifier)
          .routeOnTop(top.pattern);
    }
    _set(() => _path = top.path);
  }

  void _onPopup() => _set(() => _popupOnTop = widget.observer.popupOnTop.value);

  /// The router and the Navigator report during their own build; this widget
  /// is above them, so it rebuilds after that frame instead of inside it.
  void _set(VoidCallback change) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(change);
      });
    } else {
      setState(change);
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      await _summon();
    } finally {
      _opening = false;
    }
  }

  Future<void> _summon() async {
    if (!ref.read(proUnlockedProvider)) {
      // Gating follows the app's gate: the same paywall the chat route uses.
      widget.router.push(kProPaywallPath);
      return;
    }
    final navigator = widget.router.routerDelegate.navigatorKey.currentState;
    if (navigator == null) return;
    String? conversationId;
    try {
      // Read at open time, so a sheet opened after midnight starts anew.
      conversationId = await ref.refresh(
        vanaAmbientConversationProvider.future,
      );
    } catch (_) {
      conversationId = null;
    }
    if (!mounted) return;
    if (conversationId == null) _awaitNaming();
    final content = ref.read(contentServiceProvider);
    // VM-1: a live moment is what the sheet opens on.
    final moment = ref.read(vanaMomentControllerProvider).value;
    // Completes when the sheet closes.
    await navigator.push(
      VanaSheetRoute<void>(
        barrierLabel: content.getValue(ContentKeys.mpCompanionClose),
        builder: (_) => VanaCompanionSheet(
          conversationId: conversationId,
          moment: moment?.moment,
          momentStart: moment?.exchangeStart,
        ),
      ),
    );
  }

  /// The day's first sheet: start its conversation fresh, and hold whatever
  /// id the server gives it for the rest of the day (VS-5).
  void _awaitNaming() {
    final provider = vanaChatControllerProvider(
      kind: VanaConversationKind.general,
    );
    _naming?.close();
    // The unnamed conversation is shared with the chat route opened without
    // an id; a previous day's must not be what today's sheet opens to.
    ref.invalidate(provider);
    _naming = ref.listenManual(provider, (_, next) {
      final id = next.value?.conversationId;
      if (id == null || id.isEmpty) return;
      ref.read(vanaAmbientConversationProvider.notifier).adopt(id);
      _naming?.close();
      _naming = null;
    });
  }

  /// A raised moment rings on a launcher the athlete can see, never on one
  /// that is hidden (its one ring would be spent where nobody saw it).
  void _ringWhenShown(VanaMomentState? moment, bool shown) {
    final key = moment?.moment?.key;
    if (!shown || key == null || moment!.phase != VanaMomentPhase.waiting) {
      return;
    }
    if (_ringing == key) return;
    _ringing = key;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vanaMomentControllerProvider.notifier).ring();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = vanaLauncherShownOn(_path) && !_popupOnTop;
    final moment = ref.watch(vanaMomentControllerProvider).value;
    _ringWhenShown(moment, shown);
    final live = moment?.moment;
    final content = ref.read(contentServiceProvider);
    final pill = live == null ? null : vanaMomentPillLine(content, live);
    return Stack(
      children: [
        widget.child,
        if (shown)
          Positioned(
            right: VanaLauncher.rightInset,
            bottom: VanaLauncher.bottomInset,
            child: VanaLauncher(
              semanticLabel: pill == null
                  ? content.getValue(ContentKeys.mpCompanionLauncher)
                  : ContentKeys.format(
                      content.getValue(ContentKeys.mpCompanionLauncherMoment),
                      {'line': pill},
                    ),
              state: live == null
                  ? VanaLauncherState.quiet
                  : switch (moment!.phase) {
                      VanaMomentPhase.waiting => VanaLauncherState.quiet,
                      VanaMomentPhase.ring => VanaLauncherState.ring,
                      VanaMomentPhase.pill => VanaLauncherState.pill,
                      VanaMomentPhase.tinted => VanaLauncherState.tinted,
                    },
              // Both moments so far are to-dos.
              tone: VanaLauncherTone.toDo,
              pill: pill,
              onTap: _open,
            ),
          ),
      ],
    );
  }
}

/// The pill's one line for [moment]: "Fuel tonight's run?".
String vanaMomentPillLine(ContentService content, VanaMoment moment) {
  final hour = moment.startsAt.hour;
  final line = hour < 12
      ? ContentKeys.mpCompanionMomentPreWorkoutMorning
      : hour < 17
      ? ContentKeys.mpCompanionMomentPreWorkoutAfternoon
      : ContentKeys.mpCompanionMomentPreWorkoutEvening;
  final session = switch (moment.activityType) {
    ActivityType.running => ContentKeys.mpCompanionSessionRun,
    ActivityType.cycling => ContentKeys.mpCompanionSessionRide,
    ActivityType.swimming => ContentKeys.mpCompanionSessionSwim,
    _ => ContentKeys.mpCompanionSessionOther,
  };
  return ContentKeys.format(content.getValue(line), {
    'session': content.getValue(session),
  });
}

/// The conversation inside the sheet: today's ambient general conversation
/// (VS-5). [conversationId] is what the day held when the sheet opened — null
/// for the day's first sheet — and stays the sheet's key for its whole life;
/// the host adopts the id the server gives a new one.
///
/// The export's surface ([VanaExchange] decides what shows): the status chip,
/// Vana's turns with the sparkle avatar and no bubble, the athlete's in a
/// cream-tinted bubble, the opening's offers as at most two quick replies,
/// the typing indicator, and the composer. Planning actions a part offers
/// (picking a meal, accepting a rule, the pantry) open the full-screen chat on
/// the same conversation, where the plan bar lives.
///
/// Opened on a live [moment] (VM-1), the sheet writes the moment's opener
/// into the conversation, even one with a thread, and reads the exchange from
/// there: its two quick replies and the orange to-do chip. [momentStart] is
/// where an earlier sheet already wrote it; a dismiss (VM-2) leaves it there
/// for the next sheet, and anything the athlete sends answers it (VM-3).
class VanaCompanionSheet extends ConsumerStatefulWidget {
  const VanaCompanionSheet({
    super.key,
    this.conversationId,
    this.moment,
    this.momentStart,
  });

  final String? conversationId;
  final VanaMoment? moment;
  final int? momentStart;

  @override
  ConsumerState<VanaCompanionSheet> createState() => _VanaCompanionSheetState();
}

class _VanaCompanionSheetState extends ConsumerState<VanaCompanionSheet> {
  static const _kind = VanaConversationKind.general;

  final _text = TextEditingController();
  final _focus = FocusNode();

  /// What the retry button repeats: the opener, or the last message sent.
  Future<void> Function()? _lastAttempt;

  /// The screen underneath, as the Situation has it when the sheet opens. It
  /// names a to-do the transcript does not name itself.
  String? _situationRoute;

  /// Set by the athlete's first send, so the quick replies stay retired even
  /// if that turn fails and leaves the transcript (VS-8).
  bool _repliesRetired = false;

  /// Where the exchange on show starts: the moment's opening, or the
  /// conversation's first message.
  late int _exchangeStart = widget.momentStart ?? 0;

  /// Whether the sheet rests at `auto`: it opened on one message and a
  /// dismiss, and still is one. Decided by the first transcript the sheet
  /// sees (it rests at 75 % until then); once false it stays false, so the
  /// sheet grows when the thread starts and does not shrink after that.
  bool? _restsAtAuto;

  VanaChatControllerProvider get _provider => vanaChatControllerProvider(
    kind: _kind,
    conversationId: widget.conversationId,
  );

  VanaChatController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    _situationRoute = ref
        .read(vanaSituationControllerProvider.notifier)
        .current()
        ?.route;
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _openToOpener());
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// No loading state: the sheet opens to whatever the conversation holds,
  /// and an empty conversation opens to the opener.
  Future<void> _openToOpener() async {
    final state = await ref.read(_provider.future);
    if (!mounted || state.isStreaming || state.error != null) return;
    final moment = widget.moment;
    // A moment already written (and still there) is opened on, not repeated.
    if (moment != null &&
        (widget.momentStart ?? state.messages.length) >=
            state.messages.length) {
      final start = state.messages.length;
      setState(() => _exchangeStart = start);
      ref.read(vanaMomentControllerProvider.notifier).opened(start);
      _lastAttempt = () => _controller.loadOpener(moment: moment);
      await _controller.loadOpener(moment: moment);
      return;
    }
    if (state.messages.isNotEmpty) return;
    _lastAttempt = _controller.loadOpener;
    await _controller.loadOpener();
  }

  void _send([String? label]) {
    final text = (label ?? _text.text).trim();
    if (text.isEmpty) return;
    if (label == null) _text.clear();
    setState(() => _repliesRetired = true);
    // VM-3: anything sent in the moment's exchange answers it.
    if (widget.moment != null) {
      ref.read(vanaMomentControllerProvider.notifier).answer();
    }
    _lastAttempt = () => _controller.send(text);
    _controller.send(text);
  }

  void _retry() {
    _controller.clearError();
    _lastAttempt?.call();
  }

  void _close() => Navigator.of(context).pop();

  /// VS-3: the chat route, carrying the sheet's own conversation. The sheet's
  /// key is passed as is, so the chat route reads the very same notifier —
  /// including an unnamed conversation whose id the server has not yet given.
  void _fullScreen() {
    final router = GoRouter.of(context);
    final id = widget.conversationId;
    _close();
    router.push(id == null ? '/vana?mode=general' : '/vana?mode=general&c=$id');
  }

  void _leaveTo(String location, {bool replace = false}) {
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    _close();
    if (!replace) {
      router.push(location);
      return;
    }
    // Replacing the stack removes the page the sheet sits on, which would cut
    // the condense short (VS-9): go once the sheet has finished closing.
    if (route != null) {
      route.completed.then((_) => router.go(location));
    } else {
      router.go(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(_provider).value;
    final streaming = state?.isStreaming ?? false;
    final exchange = state == null
        ? null
        : VanaExchange.of(
            state.messages,
            isStreaming: state.isStreaming,
            start: _exchangeStart,
            situationRoute: _situationRoute,
            repliesRetired: _repliesRetired,
            raisedFor: switch (widget.moment?.kind) {
              VanaMomentKind.preWorkout => VanaExchangeTopic.fuelPlan,
              null => null,
            },
          );
    if (exchange != null) {
      _restsAtAuto = (_restsAtAuto ?? true) && exchange.oneMessage;
    }

    return VanaSheet(
      rest: _restsAtAuto ?? false
          ? VanaSheetHeight.auto
          : VanaSheetHeight.threeQuarters,
      closeLabel: content.getValue(ContentKeys.mpCompanionClose),
      fullScreenLabel: content.getValue(ContentKeys.mpCompanionFullScreen),
      onClose: _close,
      onFullScreen: _fullScreen,
      body: state == null || exchange == null
          ? const SizedBox.shrink()
          : _body(content, state, exchange),
      composer: VanaSheetComposer(
        fieldKey: const ValueKey('vana_sheet.composer'),
        sendKey: const ValueKey('vana_sheet.send'),
        controller: _text,
        focusNode: _focus,
        hint: content.getValue(ContentKeys.mpPickerPlaceholderGeneral),
        sendLabel: content.getValue(ContentKeys.mpCompanionSend),
        canSend: _text.text.trim().isNotEmpty && !streaming,
        onSend: _send,
      ),
    );
  }

  Widget _body(
    ContentService content,
    VanaChatState state,
    VanaExchange exchange,
  ) {
    final callbacks = VanaPartCallbacks(
      onTapMeal: (meal) => _leaveTo('/food/meals/${meal.id}'),
      onPickMeal: (_, _) => _fullScreen(),
      onChipPick: _send,
      onSomethingElse: _focus.requestFocus,
      onAcceptRule: (_) => _fullScreen(),
      onViewShopping: () =>
          _leaveTo('/main?tab=food&food=shopping', replace: true),
      onPlanWeekOpen: () => _leaveTo('/main?tab=food&food=plan', replace: true),
      onPantryUse: (_) => _fullScreen(),
      onSwapPicked: (_) => _fullScreen(),
    );
    final messages = state.messages;
    final rows = <Widget>[
      for (var i = 0; i < messages.length; i++)
        if (messages[i].isUser)
          VanaSheetAthleteTurn(
            key: ValueKey('vana_sheet.message_$i'),
            text: messages[i].content,
          )
        else if (_vanaTurn(messages[i], i, exchange, callbacks, state)
            case final turn?)
          turn,
      if (exchange.quickReplies.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: kVanaSheetProseInset, top: 4),
          child: VanaSheetQuickReplies(
            labels: exchange.quickReplies,
            onTap: _send,
          ),
        ),
    ];
    final status = exchange.status;

    // As tall as what it holds: under the sheet's `auto` height the column is
    // the sheet's height; at 75 % and 100 % the transcript sits under the chip.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kVanaSheetColumnInset + kVanaSheetProseInset,
              4,
              kVanaSheetColumnInset,
              AppSpacing.xs,
            ),
            child: VanaSheetStatusChip(
              key: const ValueKey('vana_sheet.status'),
              label: _statusLabel(content, exchange),
              tone: switch (status) {
                VanaExchangeStatus.toDo => VanaSheetStatusTone.toDo,
                VanaExchangeStatus.update => VanaSheetStatusTone.update,
              },
            ),
          ),
        Flexible(
          // A short conversation sits under the chip, as the export draws it;
          // a long one fills the sheet and sticks to its newest turn.
          child: ListView.separated(
            reverse: true,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              kVanaSheetColumnInset,
              AppSpacing.xs,
              kVanaSheetColumnInset,
              AppSpacing.md,
            ),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => rows[rows.length - 1 - i],
          ),
        ),
        if (state.error != null) _errorLine(state),
      ],
    );
  }

  /// One of Vana's turns, or null when it has nothing to show: an opening
  /// turn whose only part is the offers the quick replies carry.
  Widget? _vanaTurn(
    VanaMessage message,
    int index,
    VanaExchange exchange,
    VanaPartCallbacks callbacks,
    VanaChatState state,
  ) {
    final inFlight = state.isStreaming && index == state.messages.length - 1;
    if (inFlight && exchange.typing) {
      return const VanaSheetVanaTurn(
        key: ValueKey('vana_sheet.typing'),
        child: Align(
          alignment: Alignment.centerLeft,
          child: VanaSheetTypingDots(),
        ),
      );
    }
    final parts = exchange.inlineParts(index, message);
    final prose = exchange.prose(index, message);
    if (prose.isEmpty && parts.isEmpty) return null;

    return VanaSheetVanaTurn(
      key: ValueKey('vana_sheet.message_$index'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prose.isNotEmpty)
            StreamedText(
              text: prose,
              animate: inFlight,
              style: kVanaSheetProseStyle,
            ),
          if (parts.isNotEmpty) ...[
            if (prose.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            // Parts wait for the prose (or the end of the stream) before
            // they come in — see [PartEntrance].
            PartEntrance(
              show: message.content.isNotEmpty || !inFlight,
              children: [
                for (final part in parts)
                  VanaPartRenderer(part: part, callbacks: callbacks),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(ContentService content, VanaExchange exchange) {
    if (exchange.status == VanaExchangeStatus.update) {
      return content.getValue(ContentKeys.mpCompanionStatusUpdate);
    }
    final topic = switch (exchange.topic) {
      VanaExchangeTopic.fuelPlan => ContentKeys.mpCompanionTopicFuelPlan,
      VanaExchangeTopic.mealPlan => ContentKeys.mpCompanionTopicMealPlan,
      null => null,
    };
    if (topic == null) {
      return content.getValue(ContentKeys.mpCompanionStatusToDoBare);
    }
    return ContentKeys.format(
      content.getValue(ContentKeys.mpCompanionStatusToDo),
      {'topic': content.getValue(topic)},
    );
  }

  /// ERROR: one plain line and a retry. Never a dialog, never a snackbar over
  /// the sheet.
  Widget _errorLine(VanaChatState state) {
    final content = ref.read(contentServiceProvider);
    final line = switch (state.error!) {
      VanaChatErrorKind.offline => content.getValue(ContentKeys.mpVanaOffline),
      VanaChatErrorKind.rateLimited => ContentKeys.format(
        content.getValue(ContentKeys.mpRateLimited),
        {'n': state.retryAfterSeconds ?? 30},
      ),
      VanaChatErrorKind.proRequired => content.getValue(
        ContentKeys.mpProRequired,
      ),
      _ => content.getValue(ContentKeys.mpServerError),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kVanaSheetColumnInset,
        0,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line,
              key: const ValueKey('vana_sheet.error'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.cream),
            ),
          ),
          TextButton(
            key: const ValueKey('vana_sheet.retry'),
            onPressed: _retry,
            child: Text(
              content.getValue(ContentKeys.mpRetry),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
