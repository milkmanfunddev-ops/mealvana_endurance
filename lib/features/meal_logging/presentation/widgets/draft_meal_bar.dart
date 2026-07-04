import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../providers/draft_meal_controller.dart';
import 'meal_component_editor.dart';
import 'slot_chip_selector.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');

/// Persistent bottom bar shown above the tabbed log sheet's tab body whenever
/// the build-a-meal draft has at least one component.
///
/// Tapping the bar (or "Edit") opens the full build/edit canvas — name, time
/// eaten, optional meal category, notes, and the [MealComponentEditor] — so
/// users can add/swap/edit foods before *and* after the initial "Save meal"
/// (item 1). Tapping "Save meal" here commits immediately with whatever name/
/// slot/time is already set.
class DraftMealBar extends ConsumerWidget {
  const DraftMealBar({super.key, required this.logDate, this.onSaved});

  final String logDate;

  /// Called after a successful save (e.g. so the host can close the sheet).
  final VoidCallback? onSaved;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(draftMealControllerProvider(logDate).notifier)
        .save();
    if (!context.mounted) return;
    if (ok) {
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
      onSaved?.call();
    } else {
      MealvanaSnackbar.showError(context, 'Failed to log meal. Please try again.');
    }
  }

  void _openEditor(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DraftMealEditorSheet(logDate: logDate, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftMealControllerProvider(logDate));
    if (draft.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final totals = draft.totals;
    final itemCount = draft.components.length;

    return Material(
      color: bg,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              // Only the text/totals area opens the editor — scoped so it
              // doesn't compete with the "Save meal" button's own tap target.
              child: InkWell(
                onTap: () => _openEditor(context, ref),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      draft.displayName(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$itemCount item${itemCount == 1 ? '' : 's'}  ·  '
                      '${totals.calories} kcal  ·  '
                      'C ${totals.carbsG.toStringAsFixed(0)}g  '
                      'P ${totals.proteinG.toStringAsFixed(0)}g  '
                      'F ${totals.fatG.toStringAsFixed(0)}g',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            KylePrimaryButton(
              text: 'Save meal',
              isFullWidth: false,
              onPressed: () => _save(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full build/edit canvas
// ---------------------------------------------------------------------------

class _DraftMealEditorSheet extends ConsumerStatefulWidget {
  const _DraftMealEditorSheet({required this.logDate, this.onSaved});

  final String logDate;
  final VoidCallback? onSaved;

  @override
  ConsumerState<_DraftMealEditorSheet> createState() =>
      _DraftMealEditorSheetState();
}

class _DraftMealEditorSheetState extends ConsumerState<_DraftMealEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  bool _alsoSaveAsFavorite = false;
  bool _showNotes = false;

  DraftMealController get _controller =>
      ref.read(draftMealControllerProvider(widget.logDate).notifier);

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftMealControllerProvider(widget.logDate));
    _nameCtrl = TextEditingController(text: draft.name ?? '');
    _notesCtrl = TextEditingController(text: draft.notes ?? '');
    _showNotes = (draft.notes ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(DateTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Time eaten',
    );
    if (picked == null) return;
    _controller.setEatenAt(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    _controller.setName(_nameCtrl.text);
    _controller.setNotes(_notesCtrl.text);
    final ok = await _controller.save(alsoSaveAsFavorite: _alsoSaveAsFavorite);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(); // close editor sheet
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
      widget.onSaved?.call();
    } else {
      MealvanaSnackbar.showError(context, 'Failed to log meal. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final draft = ref.watch(draftMealControllerProvider(widget.logDate));

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Build Your Meal',
                  style: AppTextStyles.subtitle.copyWith(color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                // Name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Meal name',
                    hintText: draft.displayName().isEmpty
                        ? 'e.g. Lunch'
                        : draft.displayName(),
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),

                // Time eaten
                Text('Time eaten', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _pickTime(draft.eatenAt),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _timeFmt.format(draft.eatenAt),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Spacer(),
                        Text(
                          'Change',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Optional meal category
                Text('Meal type', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                OptionalSlotChipSelector(
                  selectedSlot: draft.slot,
                  onSlotSelected: _controller.setSlot,
                ),
                const SizedBox(height: AppSpacing.md),

                // Component editor — add/swap/edit/delete foods.
                MealComponentEditor(
                  key: ValueKey(draft.components.length),
                  initialComponents: draft.components,
                  onComponentsChanged: _controller.updateComponents,
                ),
                const SizedBox(height: AppSpacing.md),

                InkWell(
                  onTap: () => setState(() => _showNotes = !_showNotes),
                  child: Row(
                    children: [
                      Icon(
                        _showNotes
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showNotes ? 'Hide notes' : 'Add a note',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (_showNotes) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),

                CheckboxListTile(
                  value: _alsoSaveAsFavorite,
                  onChanged: (v) =>
                      setState(() => _alsoSaveAsFavorite = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Also save as a favorite'),
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: draft.isEmpty
                            ? null
                            : () {
                                _controller.clear();
                                Navigator.of(context).pop();
                              },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: KylePrimaryButton(
                        text: 'Save meal',
                        onPressed: draft.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}
