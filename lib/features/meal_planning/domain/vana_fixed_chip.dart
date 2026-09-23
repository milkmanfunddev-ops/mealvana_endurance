import '../../content/domain/content_keys.dart';
import 'ui_action.dart';
import 'vana_setting.dart';

/// A chip whose next step is already fixed (mp-464 clause 1, ai-cost
/// ticket 11). Tapping one runs that step on the no-model endpoint
/// (`vana-action`) with the label on the payload: no model runs, nothing is
/// drawn from the budget, Vana writes no line, and the server stores the tap
/// and what it produced in the conversation so she sees it on her next turn.
///
/// Two kinds of label reach here. The app draws some itself ("Draft my whole
/// week" under the first picker, "Use what I have" in the attach sheet), and
/// those come from the content system. The rest Vana names in an `askChoice`
/// and the persona pins them to the literals in [VanaFixedChipLabels]; a
/// label that drifts is a chip that costs a full turn again. Chips Vana
/// names on her own, "Different protein", "Adjust", every opener and every
/// typed message still go to her (clause 6). The picker's own replies
/// ("Other options", "I like these", `Next: <type>`, the two filters) are
/// ticket 12's.
enum VanaFixedChip {
  /// The first picker's door: `draft_week`, the `draftWeek` tool's body.
  draftWeek(statusTool: 'draftWeek'),

  /// The opener's build-on-last-time answer: `same_as_last_time`.
  sameAsLastTime(statusTool: 'sameAsLastTime'),

  /// The batch-cooking fork's two answers: `set_setting batch_cooking`.
  batchOn(statusTool: 'setSetting'),
  batchOff(statusTool: 'setSetting'),

  /// The coverage fork's three answers: `set_setting coverage_scope`.
  coverageDinners(statusTool: 'setSetting'),
  coverageDinnersLunches(statusTool: 'setSetting'),
  coverageAll(statusTool: 'setSetting'),

  /// After a confirm: the app opens the Shopping segment itself and records
  /// the tap (`open_shopping_list` does nothing else server-side).
  openShoppingList(
    statusTool: 'openShoppingList',
    navigatesTo: '/main?tab=food&food=shopping',
  ),

  /// After a confirm: `plan_week`, the `planWeek` tool's body; the `week`
  /// widget lands in the transcript.
  layAcrossWeek(statusTool: 'planWeek'),

  /// The attach sheet's "Use what I have": `ask_pantry`, the `askPantry`
  /// tool's body; the pantry grid lands in the transcript.
  useWhatIHave(statusTool: 'askPantry');

  const VanaFixedChip({required this.statusTool, this.navigatesTo});

  /// The tool name the status line shows while the action runs
  /// (`VanaStatusCopy`), the same name the server stores the tap under.
  final String statusTool;

  /// The route the app opens on this tap, when the chip navigates.
  final String? navigatesTo;

  /// The action this chip runs. [label] is what the athlete tapped, sent as
  /// `chip` so the server stores it as their turn.
  UiAction action({required String conversationId, required String label}) =>
      switch (this) {
        VanaFixedChip.draftWeek => DraftWeekAction(
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.sameAsLastTime => SameAsLastTimeAction(
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.batchOn => SetSettingAction(
          key: VanaSetting.batchCooking,
          value: true,
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.batchOff => SetSettingAction(
          key: VanaSetting.batchCooking,
          value: false,
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.coverageDinners => SetSettingAction(
          key: VanaSetting.coverageScope,
          value: 'dinners',
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.coverageDinnersLunches => SetSettingAction(
          key: VanaSetting.coverageScope,
          value: 'dinners_lunches',
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.coverageAll => SetSettingAction(
          key: VanaSetting.coverageScope,
          value: 'all',
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.openShoppingList => OpenShoppingListAction(
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.layAcrossWeek => PlanWeekAction(
          conversationId: conversationId,
          chip: label,
        ),
        VanaFixedChip.useWhatIHave => AskPantryAction(
          conversationId: conversationId,
          chip: label,
        ),
      };
}

/// The labels Vana names herself that the app acts on at once. The persona
/// (`supabase/functions/_shared/vana/persona.ts`) is pinned to the same
/// strings through `chip-labels.ts`; change both, and the tests on each side.
abstract final class VanaFixedChipLabels {
  static const String sameAsLastTime = 'Same as last time';
  static const String batchOn = 'Batch cook';
  static const String batchOff = 'Cook most nights';
  static const String coverageDinners = 'Dinners only';
  static const String coverageDinnersLunches = 'Dinners and lunches';
  static const String coverageAll = 'Every meal';
  static const String openShoppingList = 'Open shopping list';
  static const String layAcrossWeek = 'Lay it across the week';

  /// Vana-named label → chip. Keys are the pinned literals as written; the
  /// resolver compares case-insensitively.
  static const Map<String, VanaFixedChip> byLabel = {
    sameAsLastTime: VanaFixedChip.sameAsLastTime,
    batchOn: VanaFixedChip.batchOn,
    batchOff: VanaFixedChip.batchOff,
    coverageDinners: VanaFixedChip.coverageDinners,
    coverageDinnersLunches: VanaFixedChip.coverageDinnersLunches,
    coverageAll: VanaFixedChip.coverageAll,
    openShoppingList: VanaFixedChip.openShoppingList,
    layAcrossWeek: VanaFixedChip.layAcrossWeek,
  };
}

/// Resolves a tapped label to its [VanaFixedChip], or null when the tap is
/// Vana's (a chip she named, "Adjust", "Different protein"). App-drawn
/// labels are read through [content] (the content key's current value);
/// Vana-named ones are the pinned literals. Whitespace and case are ignored:
/// the label is a match key, not a display string.
class VanaFixedChipResolver {
  const VanaFixedChipResolver(this.content);

  /// `ContentService.getValue` or a test stand-in.
  final String Function(String key) content;

  VanaFixedChip? match(String label) {
    final key = _fold(label);
    if (key.isEmpty) return null;
    if (key == _fold(content(ContentKeys.mpChipDraftWeek))) {
      return VanaFixedChip.draftWeek;
    }
    if (key == _fold(content(ContentKeys.mpAttachUseWhatIHave))) {
      return VanaFixedChip.useWhatIHave;
    }
    for (final entry in VanaFixedChipLabels.byLabel.entries) {
      if (_fold(entry.key) == key) return entry.value;
    }
    return null;
  }

  static String _fold(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
