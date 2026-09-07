// Smoke test suite — coach mode + formula kit screens.
//
// Coverage:
//   Coach mode (8 screens): CoachPortalScreen, CoachRegistrationScreen,
//     CoachDirectoryScreen, MyCoachesScreen, AthleteFeedbackScreen,
//     CoachChatScreen, CoachDashboardScreen, AthleteDetailScreen
//   Formula Kit (3 screens): FormulaLibraryScreen, FormulaDetailScreen,
//     FormulaEditorScreen
//
// Screens that make async remote calls on build() are overridden with seeded
// AsyncNotifier states so the test is deterministic and does not need
// real Drift / Supabase. Each seeded controller subclasses the concrete
// notifier class (not the private _$ base) and returns a fixed value from
// build(), short-circuiting all I/O.

// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// Coach mode screens
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_portal_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_registration_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_directory_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/my_coaches_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/athlete_feedback_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_chat_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/coach_dashboard_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/screens/athlete_detail_screen.dart';

// Coach mode providers / domain
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_portal_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_registration_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_directory_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/my_coaches_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/athlete_feedback_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_chat_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/athlete_detail_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_chat_state.dart';

// Calendar provider (used inside AthleteDetailScreen → activities tab)
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_view_provider.dart';
import 'package:mealvana_endurance/features/calendar/presentation/widgets/calendar_view_toggle.dart';

// Formula kit screens
import 'package:mealvana_endurance/features/formula_kit/presentation/screens/formula_library_screen.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/screens/formula_detail_screen.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/screens/formula_editor_screen.dart';

// Formula kit providers / domain
import 'package:mealvana_endurance/features/formula_kit/application/formula_library_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/personal_formulas_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_editor_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/after_filter_options.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/during_filter_options.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';

import '../helpers/widget_test_harness.dart';
import 'package:mealvana_endurance/features/formula_kit/application/athlete_conflict_profile_provider.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_profile_conflict.dart';

// ─── Minimal seeded domain objects ────────────────────────────────────────────

final _now = DateTime(2026, 1, 1);

final _testRelationship = CoachAthleteRelationship(
  id: 'rel-test-001',
  coachUserId: 'coach-user-001',
  athleteUserId: 'athlete-user-001',
  status: RelationshipStatus.active,
  requestedBy: 'coach',
  requestedAt: _now,
  createdAt: _now,
  updatedAt: _now,
  coachDisplayName: 'Test Coach',
  athleteDisplayName: 'Test Athlete',
);

// ─── Seeded states ────────────────────────────────────────────────────────────

// CoachDashboard: empty (isCoach = false) → static "Become a Coach" view.
const _emptyDashboardState = CoachDashboardState();

// CoachDirectory: empty → static "No Coaches Available" view.
const _emptyDirectoryState = CoachDirectoryState();

// MyCoaches: empty → static empty view.
const _emptyMyCoachesState = MyCoachesState();

// AthleteFeedback: no messages → static "No Messages Yet" view.
const _emptyFeedbackState = AthleteFeedbackState();

// CoachChat: empty conversation → "Start the Conversation" + input field.
late final _emptyChatState = CoachChatState(
  relationship: _testRelationship,
  currentUserId: 'coach-user-001',
  messages: const [],
  pendingMessages: const [],
);

// AthleteDetail: minimal state (no profile / events / activities).
late final _emptyAthleteDetailState = AthleteDetailState(
  relationship: _testRelationship,
  athleteProfile: null,
  events: const [],
  carbLoadingPlans: const [],
  carbLoadingDays: const [],
  activities: const [],
  messages: const [],
);

// FormulaLibrary: all lists empty → empty-state views.
const _emptyLibraryState = FormulaLibraryState(
  filter: FormulaFilterState(),
  beforeFormulas: [],
  duringFormulas: [],
  afterFormulas: [],
  userDiets: [],
  userAllergies: [],
);

// FormulaPin: no pins.
const _emptyPinState = FormulaPinState(pinnedTemplateIds: {});

// FormulaEditor: empty create-new draft for During phase.
const _emptyDraft = FormulaDraft(
  name: '',
  phase: FormulaPhase.during,
  components: [],
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Coach mode + Formula Kit screen smoke tests', () {
    // ── Coach mode ────────────────────────────────────────────────────────────

    // CoachPortalScreen renders a sidebar (PortalSidebar) which itself watches
    // coachDashboardControllerProvider. Use settle:false because PortalSidebar
    // has sub-providers not fully overridden here, preventing full settle.
    testWidgets('CoachPortalScreen builds without crashing', (tester) async {
      await smokeScreen(
        tester,
        const CoachPortalScreen(),
        overrides: [
          coachPortalControllerProvider.overrideWith(CoachPortalController.new),
          coachDashboardControllerProvider.overrideWith(
            _EmptyDashboardController.new,
          ),
        ],
        settle: false,
      );
    });

    // CoachRegistrationScreen: pure form UI + coachRegistrationControllerProvider
    // (async void, idles on load). Seed with the no-op controller.
    testWidgets('CoachRegistrationScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const CoachRegistrationScreen(),
        overrides: [
          coachRegistrationControllerProvider.overrideWith(
            _NoOpRegistrationController.new,
          ),
        ],
      );
    });

    // CoachDirectoryScreen: empty list → static "No Coaches Available" view.
    testWidgets('CoachDirectoryScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const CoachDirectoryScreen(),
        overrides: [
          coachDirectoryControllerProvider.overrideWith(
            _EmptyDirectoryController.new,
          ),
        ],
      );
    });

    // MyCoachesScreen: empty → static empty "No coaches connected" view.
    testWidgets('MyCoachesScreen renders without overflow', (tester) async {
      await smokeScreen(
        tester,
        const MyCoachesScreen(),
        overrides: [
          myCoachesControllerProvider.overrideWith(
            _EmptyMyCoachesController.new,
          ),
        ],
      );
    });

    // AthleteFeedbackScreen: empty → static "No Messages Yet" view.
    testWidgets('AthleteFeedbackScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const AthleteFeedbackScreen(),
        overrides: [
          athleteFeedbackControllerProvider.overrideWith(
            _EmptyFeedbackController.new,
          ),
        ],
      );
    });

    // CoachChatScreen: requires a relationshipId. Seeded with empty messages →
    // "Start the Conversation" view + ChatInputField.
    testWidgets('CoachChatScreen renders without overflow', (tester) async {
      await smokeScreen(
        tester,
        const CoachChatScreen(relationshipId: 'rel-test-001'),
        overrides: [
          coachChatControllerProvider(
            'rel-test-001',
          ).overrideWith(_EmptyChatControllerFactory.new),
        ],
      );
    });

    // CoachDashboardScreen: seeded empty (isCoach = false) → "Become a Coach"
    // static view with a FilledButton.
    testWidgets('CoachDashboardScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const CoachDashboardScreen(),
        overrides: [
          coachDashboardControllerProvider.overrideWith(
            _EmptyDashboardController.new,
          ),
        ],
      );
    });

    // AthleteDetailScreen: family provider keyed on relationshipId. Seeds
    // minimal state (no activities, no profile). Also seeds calendarViewProvider
    // (sync) so the activities tab renders the week-view calendar header.
    // settle:false to avoid timeouts from DefaultTabController animation.
    testWidgets('AthleteDetailScreen builds without crashing', (tester) async {
      await smokeScreen(
        tester,
        const AthleteDetailScreen(relationshipId: 'rel-test-001'),
        overrides: [
          athleteDetailControllerProvider(
            'rel-test-001',
          ).overrideWith(_MinimalAthleteDetailControllerFactory.new),
          calendarViewProvider.overrideWith(CalendarViewNotifier.new),
        ],
        // FINDING: AthleteDetailScreen embeds DefaultTabController +
        // CalendarWeekViewKyle. The calendar widget has internal async setup;
        // settle:false prevents a timeout while still verifying the screen
        // builds without throwing.
        settle: false,
      );
    });

    // ── Formula Kit ───────────────────────────────────────────────────────────

    // FormulaLibraryScreen: complex multi-provider screen. Seeds empty library
    // + no pins + no personal formulas → shows "Your Formulas" section (empty)
    // and library empty-state for the Before phase.
    testWidgets('FormulaLibraryScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const FormulaLibraryScreen(),
        overrides: [
          formulaLibraryControllerProvider.overrideWith(
            _EmptyLibraryController.new,
          ),
          // FP: the cards watch the athlete conflict profile; stub it so the
          // smoke pump doesn't instantiate a real AppDatabase.
          athleteConflictProfileProvider.overrideWith(
            (ref) async => const AthleteConflictProfile(),
          ),
          formulaPinControllerProvider.overrideWith(_EmptyPinController.new),
          personalFormulasControllerProvider.overrideWith(
            _EmptyPersonalFormulasController.new,
          ),
        ],
      );
    });

    // FormulaDetailScreen: requires id + phase. With empty library state the
    // formula lookup returns null → renders _NotFoundView (graceful fallback).
    testWidgets(
      'FormulaDetailScreen renders not-found view gracefully without overflow',
      (tester) async {
        await smokeScreen(
          tester,
          const FormulaDetailScreen(
            id: 'test-formula-id',
            phase: FormulaPhase.during,
          ),
          overrides: [
            formulaLibraryControllerProvider.overrideWith(
              _EmptyLibraryController.new,
            ),
            formulaPinControllerProvider.overrideWith(_EmptyPinController.new),
          ],
        );
      },
    );

    // FormulaEditorScreen: null formulaId = create-new mode. Seeds empty draft.
    // "Save formula" button is disabled (canSave = false for empty draft).
    // CoachInsightPanel is hidden (components empty) so coachInsightProvider
    // is not triggered.
    testWidgets('FormulaEditorScreen (create new) renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const FormulaEditorScreen(formulaId: null, phase: FormulaPhase.during),
        overrides: [
          formulaEditorControllerProvider(
            null,
            FormulaPhase.during,
          ).overrideWith(_EmptyEditorControllerFactory.new),
        ],
      );
    });
  });
}

// ─── Seeded controller subclasses ─────────────────────────────────────────────
// Each subclasses the *concrete* notifier (not the private _$ base) and
// overrides build() to return a fixed value. No I/O is performed.

// ignore_for_file: must_be_immutable

/// Coach dashboard — returns empty (not-a-coach) state immediately.
class _EmptyDashboardController extends CoachDashboardController {
  @override
  FutureOr<CoachDashboardState> build() => _emptyDashboardState;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> archiveAthlete(String relationshipId) async {}
}

/// Coach registration — idles (AsyncValue<void> with no data needed).
class _NoOpRegistrationController extends CoachRegistrationController {
  @override
  FutureOr<void> build() {}

  @override
  Future<bool> submitApplication({
    required String firstName,
    required String lastName,
    required String email,
    String? bio,
  }) async => false;
}

/// Coach directory — returns empty list immediately.
class _EmptyDirectoryController extends CoachDirectoryController {
  @override
  FutureOr<CoachDirectoryState> build() => _emptyDirectoryState;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> requestCoach(String coachUserId) async => false;
}

/// My coaches — returns empty state immediately.
class _EmptyMyCoachesController extends MyCoachesController {
  @override
  FutureOr<MyCoachesState> build() => _emptyMyCoachesState;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> acceptRequest(String relationshipId) async {}

  @override
  Future<void> declineRequest(String relationshipId) async {}
}

/// Athlete feedback — returns empty state immediately.
class _EmptyFeedbackController extends AthleteFeedbackController {
  @override
  FutureOr<AthleteFeedbackState> build() => _emptyFeedbackState;

  @override
  Future<void> refresh() async {}
}

/// Coach chat (family) — returns empty chat state immediately.
class _EmptyChatControllerFactory extends CoachChatController {
  @override
  FutureOr<CoachChatState> build(String relationshipId) => _emptyChatState;

  @override
  Future<void> sendMessage(String text) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> retryFailedMessages() async {}

  @override
  void clearError() {}
}

/// Athlete detail (family) — returns minimal seeded state immediately.
class _MinimalAthleteDetailControllerFactory extends AthleteDetailController {
  @override
  FutureOr<AthleteDetailState> build(String relationshipId) =>
      _emptyAthleteDetailState;

  @override
  Future<void> refresh() async {}
}

/// Formula library — returns empty library state immediately.
class _EmptyLibraryController extends FormulaLibraryController {
  @override
  FutureOr<FormulaLibraryState> build() => _emptyLibraryState;

  @override
  Future<void> setPhase(FormulaPhase phase) async {}

  @override
  Future<void> toggleBeforeSubPhase(BeforeSubPhase value) async {}

  @override
  Future<void> toggleDuringActivity(DuringActivity value) async {}

  @override
  Future<void> toggleDuringDuration(DuringDuration value) async {}

  @override
  Future<void> toggleAfterTravelFriendliness(TravelFriendliness value) async {}

  @override
  Future<void> togglePinnedOnly({required int pinnedCount}) async {}

  @override
  void clearPhaseChipFilters() {}

  @override
  void clearMoreFilters() {}

  @override
  Future<void> trackLibraryOpened({required String source}) async {}

  @override
  Future<void> trackDetailViewed({
    required String templateId,
    required FormulaPhase phase,
    required bool isPersonal,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> componentsForFork(
    String sourceId,
    FormulaPhase phase,
  ) async => const [];
}

/// Formula pin — returns empty pin state immediately.
class _EmptyPinController extends FormulaPinController {
  @override
  FutureOr<FormulaPinState> build() => _emptyPinState;
}

/// Personal formulas — returns empty list immediately.
class _EmptyPersonalFormulasController extends PersonalFormulasController {
  @override
  FutureOr<List<PersonalFormula>> build() async => const [];

  @override
  Future<PersonalFormula?> createFormula(
    PersonalFormula draft, {
    int? quantityEditCount,
  }) async => null;

  @override
  Future<void> deleteFormula(String id) async {}
}

/// Formula editor (family) — returns empty draft immediately.
class _EmptyEditorControllerFactory extends FormulaEditorController {
  @override
  FutureOr<FormulaDraft> build(String? formulaId, FormulaPhase phase) =>
      _emptyDraft;

  @override
  void setName(String name) {}

  @override
  void setPhase(FormulaPhase phase) {}

  @override
  void setSubPhase(String? subPhase) {}

  @override
  void setActivities(List<String>? activities) {}

  @override
  void setDurations(List<String>? durations) {}

  @override
  void setTravelFriendliness(String? value) {}

  @override
  void setNotes(String? notes) {}

  @override
  void addComponent(Food food, double quantity, {required bool isUserFood}) {}

  @override
  void removeComponent(int index) {}

  @override
  void replaceComponent(
    int index,
    Food food,
    double quantity, {
    required bool isUserFood,
  }) {}

  @override
  void updateComponentQuantity(int index, double quantity) {}

  @override
  Future<PersonalFormula?> save() async => null;
}
