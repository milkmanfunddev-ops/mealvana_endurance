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
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/navigation/vana_sheet.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../subscription/application/pro_gate.dart';
import '../../../subscription/presentation/pro_gate_redirect.dart';
import '../../application/vana_ambient_conversation_controller.dart';
import '../../application/vana_chat_controller.dart';
import '../../application/vana_situation_controller.dart';
import '../../domain/vana_conversation_kind.dart';
import '../../domain/vana_launcher_rule.dart';
import '../../domain/vana_message.dart';
import 'vana_message_card.dart';
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

  /// Set from the launcher tap until the sheet has closed. The launcher only
  /// leaves the tree on the frame after the push, so a second tap can still
  /// land on it; it must not open a second sheet.
  bool _opening = false;

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
    widget.router.routerDelegate.removeListener(_onRoute);
    widget.observer.popupOnTop.removeListener(_onPopup);
    super.dispose();
  }

  void _onRoute() {
    final top = _top(widget.router.routerDelegate.currentConfiguration);
    // The Vana routes speak for no screen: the one under them stays the
    // Situation, so the full-screen chat still knows what was underneath.
    if (top.pattern.isNotEmpty && !isVanaRoute(top.path)) {
      ref.read(vanaSituationControllerProvider.notifier).routeOnTop(top.pattern);
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
    final content = ref.read(contentServiceProvider);
    // Completes when the sheet closes.
    await navigator.push(
      VanaSheetRoute<void>(
        barrierLabel: content.getValue(ContentKeys.mpCompanionClose),
        builder: (_) => VanaCompanionSheet(conversationId: conversationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = vanaLauncherShownOn(_path) && !_popupOnTop;
    return Stack(
      children: [
        widget.child,
        if (shown)
          Positioned(
            right: VanaLauncher.rightInset,
            bottom: VanaLauncher.bottomInset,
            child: VanaLauncher(
              semanticLabel: ref
                  .read(contentServiceProvider)
                  .getValue(ContentKeys.mpCompanionLauncher),
              onTap: _open,
            ),
          ),
      ],
    );
  }
}

/// The conversation inside the sheet: today's ambient general conversation
/// (VS-5). [conversationId] is what the day held when the sheet opened — null
/// for the day's first sheet — and stays the sheet's key for its whole life;
/// when the server names a new conversation it is adopted for the rest of the
/// day.
///
/// This is a working conversation column, not yet the export's surface (status
/// chip, quick replies, the new message treatments are ticket 07). Planning
/// actions a part offers (picking a meal, accepting a rule, the pantry) open
/// the full-screen chat on the same conversation, where the plan bar lives.
class VanaCompanionSheet extends ConsumerStatefulWidget {
  const VanaCompanionSheet({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<VanaCompanionSheet> createState() => _VanaCompanionSheetState();
}

class _VanaCompanionSheetState extends ConsumerState<VanaCompanionSheet> {
  static const _kind = VanaConversationKind.general;

  final _text = TextEditingController();
  final _focus = FocusNode();

  /// What the retry button repeats: the opener, or the last message sent.
  Future<void> Function()? _lastAttempt;

  VanaChatControllerProvider get _provider => vanaChatControllerProvider(
    kind: _kind,
    conversationId: widget.conversationId,
  );

  VanaChatController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
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
    if (!mounted || state.messages.isNotEmpty || state.isStreaming) return;
    if (state.error != null) return;
    _lastAttempt = _controller.loadOpener;
    await _controller.loadOpener();
  }

  void _send([String? label]) {
    final text = (label ?? _text.text).trim();
    if (text.isEmpty) return;
    if (label == null) _text.clear();
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
    router.push(
      id == null ? '/vana?mode=general' : '/vana?mode=general&c=$id',
    );
  }

  void _leaveTo(String location, {bool replace = false}) {
    final router = GoRouter.of(context);
    _close();
    replace ? router.go(location) : router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(_provider).value;

    ref.listen(_provider, (previous, next) {
      final id = next.value?.conversationId;
      if (widget.conversationId == null &&
          id != null &&
          id.isNotEmpty &&
          previous?.value?.conversationId != id) {
        ref.read(vanaAmbientConversationProvider.notifier).adopt(id);
      }
    });

    return VanaSheet(
      closeLabel: content.getValue(ContentKeys.mpCompanionClose),
      fullScreenLabel: content.getValue(ContentKeys.mpCompanionFullScreen),
      onClose: _close,
      onFullScreen: _fullScreen,
      body: _thread(state),
      composer: _composer(content, streaming: state?.isStreaming ?? false),
    );
  }

  Widget _thread(VanaChatState? state) {
    if (state == null) return const SizedBox.expand();
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
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            // Newest at the bottom, and the list sticks to it as turns land.
            reverse: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final index = messages.length - 1 - i;
              final VanaMessage message = messages[index];
              final isLast = index == messages.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: VanaMessageCard(
                  key: ValueKey('vana_sheet.message_$index'),
                  message: message,
                  index: index,
                  callbacks: callbacks,
                  isStreaming: state.isStreaming && isLast,
                ),
              );
            },
          ),
        ),
        if (state.error != null) _errorLine(state),
      ],
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
        AppSpacing.md,
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

  Widget _composer(ContentService content, {required bool streaming}) {
    final hasDraft = _text.text.trim().isNotEmpty;
    final canSend = hasDraft && !streaming;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('vana_sheet.composer'),
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cream),
              decoration: InputDecoration(
                hintText: content.getValue(
                  ContentKeys.mpPickerPlaceholderGeneral,
                ),
                // The sheet is the surface; the field draws no box of its own.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          Semantics(
            button: true,
            enabled: canSend,
            label: content.getValue(ContentKeys.mpCompanionSend),
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('vana_sheet.send'),
              behavior: HitTestBehavior.opaque,
              onTap: canSend ? _send : null,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Inert until there is a draft, orange once there is.
                      color: canSend ? AppColors.orange : AppColors.disabled,
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.arrowUp,
                        size: 14,
                        color: AppColors.blackberry,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
