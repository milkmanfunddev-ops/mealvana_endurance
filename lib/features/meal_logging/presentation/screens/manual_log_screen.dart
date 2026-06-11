import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/slot_chip_selector.dart';

/// Manual meal entry screen.
///
/// Route: `/meal-log/manual`
/// Extras: `{ 'logDate': String }`
class ManualLogScreen extends ConsumerStatefulWidget {
  const ManualLogScreen({super.key});

  @override
  ConsumerState<ManualLogScreen> createState() => _ManualLogScreenState();
}

class _ManualLogScreenState extends ConsumerState<ManualLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MealSlot _slot = MealSlot.breakfast;
  bool _showExtra = false;

  String? _logDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logDate == null) {
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      _logDate = extra?['logDate'] as String? ??
          _todayDateString();
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(mealLogControllerProvider.notifier).logManualMeal(
          name: _nameCtrl.text.trim(),
          slot: _slot,
          logDate: _logDate!,
          calories: int.tryParse(_calCtrl.text),
          carbsG: double.tryParse(_carbCtrl.text),
          proteinG: double.tryParse(_protCtrl.text),
          fatG: double.tryParse(_fatCtrl.text),
          sodiumMg: double.tryParse(_sodiumCtrl.text),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
      context.pop();
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(
          context, 'Failed to log meal. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Log a Meal'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Name
              TextFormField(
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

              // Slot selector
              Text(
                'Meal type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              SlotChipSelector(
                selectedSlot: _slot,
                onSlotSelected: (s) => setState(() => _slot = s),
              ),
              const SizedBox(height: AppSpacing.md),

              // Calories
              _numField('Calories (kcal)', _calCtrl),
              const SizedBox(height: AppSpacing.sm),

              // Carbs
              _numField('Carbs (g)', _carbCtrl),
              const SizedBox(height: AppSpacing.sm),

              // Protein
              _numField('Protein (g)', _protCtrl),
              const SizedBox(height: AppSpacing.sm),

              // Fat
              _numField('Fat (g)', _fatCtrl),
              const SizedBox(height: AppSpacing.md),

              // "Add more detail" toggle
              InkWell(
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
                _numField('Sodium (mg)', _sodiumCtrl),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
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
                text: 'Save',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return TextFormField(
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
