import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/cooking_step_timers.dart';
import '../domain/meal_detail.dart';
import 'meal_detail_controller.dart';

part 'cooking_session_controller.g.dart';

/// Cooking-mode phases (05 §4): cooking → done. The screen enters straight
/// at step 1 — the overview interstitial was removed (2026-09-03).
enum CookingPhase { cooking, done }

/// One timer chip parsed from a step.
class StepTimerState {
  const StepTimerState({
    required this.timer,
    required this.remainingSeconds,
    this.running = false,
    this.rang = false,
  });

  final StepTimer timer;
  final int remainingSeconds;
  final bool running;

  /// Reached zero and has not been acknowledged — the UI fires the local
  /// notification + vibration once, then calls
  /// [CookingSessionController.acknowledgeTimer].
  final bool rang;

  bool get finished => remainingSeconds <= 0;

  StepTimerState copyWith({int? remainingSeconds, bool? running, bool? rang}) =>
      StepTimerState(
        timer: timer,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        running: running ?? this.running,
        rang: rang ?? this.rang,
      );
}

/// Immutable cooking-mode state for one meal.
class CookingSessionState {
  const CookingSessionState({
    required this.detail,
    this.phase = CookingPhase.cooking,
    this.stepIndex = 0,
    this.timers = const {},
    this.checkedIngredients = const {},
  });

  final MealDetail detail;
  final CookingPhase phase;
  final int stepIndex;

  /// Step index → its timers (parsed once from the step text).
  final Map<int, List<StepTimerState>> timers;

  /// Ingredient indices struck through in the drawer.
  final Set<int> checkedIngredients;

  List<String> get steps => detail.methodSteps;
  int get stepCount => steps.length;
  bool get hasSteps => steps.isNotEmpty;
  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex >= stepCount - 1;
  String get currentStep => hasSteps ? steps[stepIndex] : '';
  List<StepTimerState> get currentTimers => timers[stepIndex] ?? const [];

  /// The screen holds the wake lock only while cooking (05 §4). The platform
  /// call lives in the presentation layer; this is the intent.
  bool get wakeLockWanted => phase == CookingPhase.cooking;

  /// Any timer anywhere is counting down.
  bool get anyRunning =>
      timers.values.any((list) => list.any((t) => t.running));

  /// Timers that rang and await acknowledgement (any step).
  List<StepTimerState> get ringing => [
    for (final list in timers.values)
      for (final t in list)
        if (t.rang) t,
  ];

  CookingSessionState copyWith({
    MealDetail? detail,
    CookingPhase? phase,
    int? stepIndex,
    Map<int, List<StepTimerState>>? timers,
    Set<int>? checkedIngredients,
  }) => CookingSessionState(
    detail: detail ?? this.detail,
    phase: phase ?? this.phase,
    stepIndex: stepIndex ?? this.stepIndex,
    timers: timers ?? this.timers,
    checkedIngredients: checkedIngredients ?? this.checkedIngredients,
  );
}

/// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
/// per-step timers parsed by [CookingStepTimers], the ingredients drawer
/// and the wake-lock intent. No platform calls here — the screen owns
/// `wakelock_plus`, notifications and vibration.
///
/// Timers tick once a second while any is running (one `Timer.periodic`,
/// cancelled on dispose). Countdown is per-tick so it is deterministic under
/// `fakeAsync`; a backgrounded app resumes from where it paused.
@riverpod
class CookingSessionController extends _$CookingSessionController {
  Timer? _ticker;

  @override
  FutureOr<CookingSessionState> build(String mealId) async {
    ref.onDispose(_stopTicker);
    final detail = await ref.watch(mealDetailControllerProvider(mealId).future);
    return CookingSessionState(
      detail: detail,
      timers: parseTimers(detail.methodSteps),
    );
  }

  /// Parse every step's durations up front.
  static Map<int, List<StepTimerState>> parseTimers(List<String> steps) => {
    for (var i = 0; i < steps.length; i++)
      i: [
        for (final t in CookingStepTimers.findDurations(steps[i]))
          StepTimerState(timer: t, remainingSeconds: t.seconds),
      ],
  };

  // ── Phases ─────────────────────────────────────────────────────────────────

  /// Next step, or → done on the last one.
  void next() {
    final s = state.value;
    if (s == null || s.phase != CookingPhase.cooking) return;
    if (s.isLastStep) {
      finish();
      return;
    }
    state = AsyncData(s.copyWith(stepIndex: s.stepIndex + 1));
  }

  void back() {
    final s = state.value;
    if (s == null || s.phase != CookingPhase.cooking || s.isFirstStep) return;
    state = AsyncData(s.copyWith(stepIndex: s.stepIndex - 1));
  }

  void goToStep(int index) {
    final s = state.value;
    if (s == null || index < 0 || index >= s.stepCount) return;
    state = AsyncData(
      s.copyWith(phase: CookingPhase.cooking, stepIndex: index),
    );
  }

  /// Cooking → done. Timers stop.
  void finish() {
    final s = state.value;
    if (s == null) return;
    _stopTicker();
    state = AsyncData(
      s.copyWith(phase: CookingPhase.done, timers: _stopAll(s.timers)),
    );
  }

  /// Back to step 1 with everything reset.
  void startOver() {
    final s = state.value;
    if (s == null) return;
    _stopTicker();
    state = AsyncData(
      CookingSessionState(
        detail: s.detail,
        timers: parseTimers(s.detail.methodSteps),
      ),
    );
  }

  // ── Ingredients drawer ─────────────────────────────────────────────────────

  void toggleIngredient(int index) {
    final s = state.value;
    if (s == null) return;
    final next = {...s.checkedIngredients};
    if (!next.remove(index)) next.add(index);
    state = AsyncData(s.copyWith(checkedIngredients: next));
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void startTimer(int stepIndex, int timerIndex) {
    _updateTimer(stepIndex, timerIndex, (t) {
      if (t.finished) return t; // reset first
      return t.copyWith(running: true, rang: false);
    });
    _ensureTicker();
  }

  void pauseTimer(int stepIndex, int timerIndex) {
    _updateTimer(stepIndex, timerIndex, (t) => t.copyWith(running: false));
    _maybeStopTicker();
  }

  /// Cancel = back to the full duration, stopped.
  void resetTimer(int stepIndex, int timerIndex) {
    _updateTimer(
      stepIndex,
      timerIndex,
      (t) => StepTimerState(timer: t.timer, remainingSeconds: t.timer.seconds),
    );
    _maybeStopTicker();
  }

  /// The UI has rung the alarm for this timer.
  void acknowledgeTimer(int stepIndex, int timerIndex) {
    _updateTimer(stepIndex, timerIndex, (t) => t.copyWith(rang: false));
  }

  void _updateTimer(
    int stepIndex,
    int timerIndex,
    StepTimerState Function(StepTimerState) change,
  ) {
    final s = state.value;
    if (s == null) return;
    final list = s.timers[stepIndex];
    if (list == null || timerIndex < 0 || timerIndex >= list.length) return;
    final nextList = [...list];
    nextList[timerIndex] = change(list[timerIndex]);
    state = AsyncData(s.copyWith(timers: {...s.timers, stepIndex: nextList}));
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state.value;
    if (s == null) {
      _stopTicker();
      return;
    }
    var anyRunning = false;
    final next = <int, List<StepTimerState>>{};
    for (final entry in s.timers.entries) {
      next[entry.key] = [
        for (final t in entry.value)
          if (!t.running)
            t
          else if (t.remainingSeconds <= 1)
            t.copyWith(remainingSeconds: 0, running: false, rang: true)
          else
            () {
              anyRunning = true;
              return t.copyWith(remainingSeconds: t.remainingSeconds - 1);
            }(),
      ];
    }
    state = AsyncData(s.copyWith(timers: next));
    if (!anyRunning) _stopTicker();
  }

  void _maybeStopTicker() {
    final s = state.value;
    if (s == null || !s.anyRunning) _stopTicker();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  static Map<int, List<StepTimerState>> _stopAll(
    Map<int, List<StepTimerState>> timers,
  ) => {
    for (final entry in timers.entries)
      entry.key: [
        for (final t in entry.value) t.copyWith(running: false, rang: false),
      ],
  };
}
