import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/log_date_time.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import 'slot_chip_selector.dart';

/// Reusable manual meal-entry form.
///
/// Hosts the name / optional slot / time eaten / macro fields and the Save
/// button, and writes the entry via [MealLogController.logManualMeal]. It is
/// intentionally chrome-less (no Scaffold / AppBar) so it can be embedded
/// either in a full screen ([ManualLogScreen]) or inline as the quick-log
/// "Manual" tab of `LogMealScreen`.
///
/// On a successful write it calls [onLogged] and clears the form (so the
/// inline tab can log another item in a row); on failure it calls
/// [onLogError]. The host decides what "logged" means beyond that (pop a
/// route, show a snackbar, dismiss the keyboard, …) so messaging stays
/// consistent with the surrounding surface.
class ManualLogForm extends ConsumerStatefulWidget {
  const ManualLogForm({
    super.key,
    required this.logDate,
    required this.onLogged,
    required this.onLogError,
    this.scrollController,
  });

  /// `yyyy-MM-dd` date the entry is logged against.
  final String logDate;

  /// Called once the meal has been written successfully.
  final VoidCallback onLogged;

  /// Called when the write fails.
  final VoidCallback onLogError;

  /// Optional controller so the form scrolls with a parent sheet. When null the
  /// form uses its own [SingleChildScrollView].
  final ScrollController? scrollController;

  @override
  ConsumerState<ManualLogForm> createState() => _ManualLogFormState();
}

class _ManualLogFormState extends ConsumerState<ManualLogForm> {
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MealSlot? _slot;
  late DateTime _eatenAt;
  bool _showExtra = false;

  @override
  void initState() {
    super.initState();
    _eatenAt = eatenAtForLogDate(widget.logDate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    _sodiumCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eatenAt),
      helpText: 'Time eaten',
    );
    if (picked == null) return;
    setState(() {
      _eatenAt = DateTime(
        _eatenAt.year,
        _eatenAt.month,
        _eatenAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref
        .read(mealLogControllerProvider.notifier)
        .logManualMeal(
          name: _nameCtrl.text.trim(),
          slot: _slot,
          logDate: widget.logDate,
          calories: int.tryParse(_calCtrl.text),
          carbsG: double.tryParse(_carbCtrl.text),
          proteinG: double.tryParse(_protCtrl.text),
          fatG: double.tryParse(_fatCtrl.text),
          sodiumMg: double.tryParse(_sodiumCtrl.text),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          eatenAt: _eatenAt,
        );

    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      widget.onLogged();
      // Reset for the next entry — the inline "Manual" tab stays open so the
      // user can log several items in a row without re-navigating.
      setState(() {
        _nameCtrl.clear();
        _calCtrl.clear();
        _carbCtrl.clear();
        _protCtrl.clear();
        _fatCtrl.clear();
        _sodiumCtrl.clear();
        _notesCtrl.clear();
        _slot = null;
        _eatenAt = eatenAtForLogDate(widget.logDate);
      });
    } else {
      widget.onLogError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Name
          TextFormField(
            key: const ValueKey('manual_log.name_field'),
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Meal name',
              hintText: 'e.g. Oatmeal with banana',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Slot selector — optional (build-a-meal redesign): the user may
          // leave a logged meal untagged.
          Text('Meal type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          OptionalSlotChipSelector(
            selectedSlot: _slot,
            onSlotSelected: (s) => setState(() => _slot = s),
          ),
          const SizedBox(height: AppSpacing.md),

          // Time eaten
          Text('Time eaten', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickTime,
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
                    _timeFmt.format(_eatenAt),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  Text(
                    'Change',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _numField('Calories (kcal)', _calCtrl, 'calories'),
          const SizedBox(height: AppSpacing.sm),
          _numField('Carbs (g)', _carbCtrl, 'carbs'),
          const SizedBox(height: AppSpacing.sm),
          _numField('Protein (g)', _protCtrl, 'protein'),
          const SizedBox(height: AppSpacing.sm),
          _numField('Fat (g)', _fatCtrl, 'fat'),
          const SizedBox(height: AppSpacing.md),

          // "Add more detail" toggle
          InkWell(
            key: const ValueKey('manual_log.more_detail_toggle'),
            onTap: () => setState(() => _showExtra = !_showExtra),
            child: Row(
              children: [
                Icon(
                  _showExtra
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _showExtra ? 'Hide details' : 'Add more detail',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (_showExtra) ...[
            const SizedBox(height: AppSpacing.sm),
            _numField('Sodium (mg)', _sodiumCtrl, 'sodium'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey('manual_log.notes_field'),
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          KylePrimaryButton(
            key: const ValueKey('manual_log.save_button'),
            text: 'Save',
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: AppSpacing.screenPaddingHorizontal,
      child: form,
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String keySlug) {
    return TextFormField(
      key: ValueKey('manual_log.${keySlug}_field'),
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
