import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../nutrition_plan/presentation/providers/swap_food_controller.dart';
import '../../domain/log_date_time.dart';
import '../../domain/meal_analysis_result.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import '../../domain/meal_swap.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/meal_component_editor.dart';
import '../widgets/slot_chip_selector.dart' show OptionalSlotChipSelector;

/// Review & confirm screen shown after AI analysis (photo or describe flows).
///
/// Log a Meal → Describe pushes it on top of itself with the constructor
/// params, so Back returns to the typed text and the stored analysis
/// (testing-wave develop-2026-10 ticket 45, 31-004); a logged meal pops `true`.
///
/// Route: `/meal-log/review` reads the same values from the GoRouter extras
/// when [result] is null:
/// `{ 'result': MealAnalysisResult, 'source': String, 'logDate': String, 'photoPath': String? }`
///
/// Back with a changed name or items asks "Discard changes?"; a swiped-away
/// item offers a 3 s Undo (testing-wave develop-2026-10 ticket 66, 49-003).
/// Changing only the meal type does not ask (Lee, 2026-10-08).
class MealReviewScreen extends ConsumerStatefulWidget {
  const MealReviewScreen({
    super.key,
    this.result,
    this.source,
    this.logDate,
    this.photoPath,
  });

  final MealAnalysisResult? result;
  final String? source;
  final String? logDate;

  /// The uploaded photo's storage path, when the analysis was a photo.
  final String? photoPath;

  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen> {
  final _nameCtrl = TextEditingController();

  MealAnalysisResult? _result;
  String? _source;
  String? _logDate;
  String? _photoPath;
  MealSlot? _slot;
  List<MealComponent> _components = [];

  bool _initialized = false;

  /// True once the athlete has edited the name; only then does an empty name
  /// show its error (31-002).
  bool _nameEdited = false;

  bool get _nameIsEmpty => _nameCtrl.text.trim().isEmpty;

  /// Taken while mounted so [dispose] can hide an Undo bar that would
  /// otherwise act on a gone screen.
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    if (!_initialized) {
      if (widget.result != null) {
        _result = widget.result;
        _source = widget.source;
        _logDate = widget.logDate;
        _photoPath = widget.photoPath;
      } else {
        final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
        _result = extra?['result'] as MealAnalysisResult?;
        _source = extra?['source'] as String?;
        _logDate = extra?['logDate'] as String?;
        _photoPath = extra?['photoPath'] as String?;
      }

      if (_result != null) {
        _nameCtrl.text = _result!.name;
        // AI's best-guess slot pre-fills the (optional) selector — the user
        // can clear it back to "Any time" if it's wrong or not relevant.
        _slot = _result!.suggestedSlot;
        _components = _result!.items.map(_itemToComponent).toList();
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _messenger?.hideCurrentSnackBar();
    _nameCtrl.dispose();
    super.dispose();
  }

  MealComponent _itemToComponent(MealAnalysisItem item) {
    return MealComponent(
      name: item.name,
      portion: item.portion,
      calories: item.calories,
      carbG: item.carbG,
      proteinG: item.proteinG,
      fatG: item.fatG,
      sodiumMg: item.sodiumMg,
    );
  }

  static String _encodeComponents(List<MealComponent> components) =>
      jsonEncode(components.map((c) => c.toJson()).toList());

  /// A rename, swap, removal or Edit Item change since the analysis. The meal
  /// type alone does not count (Lee, 2026-10-08). An undone removal compares
  /// equal again.
  bool _hasEdits() {
    final result = _result;
    if (result == null) return false;
    if (_nameCtrl.text.trim() != result.name.trim()) return true;
    return _encodeComponents(_components) !=
        _encodeComponents(result.items.map(_itemToComponent).toList());
  }

  /// Handles a blocked back-navigation attempt (see [PopScope]): no edits
  /// leaves at once; edits ask Keep editing / Discard. Discard pops with no
  /// result, so Describe keeps its text (ticket 45).
  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;
    if (!_hasEdits()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final content = ref.read(contentServiceProvider);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(content.getValue(ContentKeys.mealLogReviewDiscardTitle)),
        content: Text(content.getValue(ContentKeys.mealLogReviewDiscardBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(content.getValue(ContentKeys.mealLogReviewKeepEditing)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(content.getValue(ContentKeys.mealLogReviewDiscard)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Opens the shared food-swap picker (returnSelection mode) and maps the
  /// chosen food + quantity into a replacement [MealComponent] through
  /// [swappedComponent], the same mapping Edit Meal uses, so both flows share
  /// the same swap UX (unifies with the build-a-meal draft editor — item 13).
  Future<MealComponent?> _swapComponentFood(MealComponent current) async {
    final selection = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {
        'returnSelection': true,
        'category': 'before_run',
        'foodToSwapName': current.name,
      },
    );
    if (selection == null) return null;

    return swappedComponent(selection.food, selection.quantity);
  }

  Future<void> _logMeal() async {
    final name = _nameCtrl.text.trim();
    // Backstop: the button is disabled for an empty name (31-002).
    if (name.isEmpty || _logDate == null) return;

    final source = MealLogSource.fromWireValue(_source) ?? MealLogSource.photo;
    // The note shown above the button is what the estimate assumed; it is
    // kept with the meal so Edit Meal shows it later (testing-wave 23-002).
    final note = _result?.notes?.trim();

    await ref
        .read(mealLogControllerProvider.notifier)
        .logFromComponents(
          name: name,
          slot: _slot,
          logDate: _logDate!,
          source: source,
          components: _components,
          photoPath: _photoPath,
          notes: (note == null || note.isEmpty) ? null : note,
          eatenAt: eatenAtForLogDate(_logDate!),
        );

    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      // Pushed by Log a Meal → Describe: hand back `true` so it closes too.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(true);
      } else {
        context.go('/main');
      }
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(
        context,
        'Failed to log meal. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;
    final nameError = _nameEdited && _nameIsEmpty
        ? ref
              .watch(contentServiceProvider)
              .getValue(ContentKeys.mealLogReviewNameRequired)
        : null;

    if (_result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Meal')),
        body: const Center(child: Text('Missing analysis result.')),
      );
    }

    final content = ref.watch(contentServiceProvider);

    return PopScope(
      // A logged meal pops `true` through the navigator directly, which this
      // guard does not block; every other Back runs [_onPopInvoked].
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        appBar: AppBar(
          // Through maybePop so the PopScope guard above runs.
          leading: CustomAppBarBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
          title: const Text('Review & Log'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Confidence badge
              _ConfidenceBadge(confidence: _result!.confidence),
              const SizedBox(height: AppSpacing.md),

              // Meal name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Meal name',
                  border: const OutlineInputBorder(),
                  errorText: nameError,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _nameEdited = true),
              ),
              const SizedBox(height: AppSpacing.md),

              // Slot selector (optional — build-a-meal redesign)
              Text('Meal type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              OptionalSlotChipSelector(
                selectedSlot: _slot,
                onSlotSelected: (s) => setState(() => _slot = s),
              ),
              const SizedBox(height: AppSpacing.md),

              // Items editor — shared with the build-a-meal draft editor and
              // Edit Meal (item 13): independently editable quantity per item,
              // swipe-to-swap via the shared food-swap picker.
              MealComponentEditor(
                initialComponents: _components,
                onComponentsChanged: (updated) =>
                    setState(() => _components = updated),
                onRequestSwap: _swapComponentFood,
                removeUndoLabels: (
                  removed: content.getValue(
                    ContentKeys.mealLogReviewItemRemoved,
                  ),
                  undo: content.getValue(ContentKeys.mealLogActionsUndo),
                ),
              ),

              // AI notes
              if (_result!.notes != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _result!.notes!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              KylePrimaryButton(
                text: 'Log this meal',
                isLoading: isLoading,
                // An empty name cannot be logged; the field says why (31-002).
                onPressed: isLoading || _nameIsEmpty ? null : _logMeal,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final MealAnalysisConfidence confidence;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (confidence) {
      case MealAnalysisConfidence.high:
        color = AppColors.electrolyteDark;
        label = 'High confidence';
        break;
      case MealAnalysisConfidence.medium:
        color = AppColors.orange;
        label = 'Medium confidence';
        break;
      case MealAnalysisConfidence.low:
        color = AppColors.dragonfruit;
        label = 'Low confidence — please review';
        break;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
