import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/meal_component_editor.dart';
import '../widgets/slot_chip_selector.dart';

/// Edit an existing [MealLog] entry.
///
/// Route: `/meal-log/edit`
/// Extras: `{ 'log': MealLog }`
///
/// When the log has components the editor shows a per-component list
/// ([MealComponentEditor]). When it has no components (quick-manual entry) it
/// shows the simple macro fields, matching [ManualLogScreen].
///
/// On save the controller calls [MealLogController.updateLog], which goes
/// through [MealLoggingService.updateLog] (recomputes totals from components
/// when present) and then [MealLogRepository.updateLog] (offline-first).
class EditMealLogScreen extends ConsumerStatefulWidget {
  const EditMealLogScreen({super.key});

  @override
  ConsumerState<EditMealLogScreen> createState() => _EditMealLogScreenState();
}

class _EditMealLogScreenState extends ConsumerState<EditMealLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MealLog? _originalLog;
  MealSlot _slot = MealSlot.breakfast;
  List<MealComponent> _components = const [];
  bool _showExtra = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final log = extra?['log'] as MealLog?;
    if (log == null) return;

    _originalLog = log;
    _slot = log.slot;
    _components = List<MealComponent>.from(log.components);

    _nameCtrl.text = log.name;
    _notesCtrl.text = log.notes ?? '';

    if (log.components.isEmpty) {
      // Simple macro fields
      _calCtrl.text = log.calories?.toString() ?? '';
      _carbCtrl.text = log.carbsG?.toStringAsFixed(1) ?? '';
      _protCtrl.text = log.proteinG?.toStringAsFixed(1) ?? '';
      _fatCtrl.text = log.fatG?.toStringAsFixed(1) ?? '';
      _sodiumCtrl.text = log.sodiumMg?.toStringAsFixed(0) ?? '';
      // Show extra panel if sodium or notes are set
      if ((log.sodiumMg ?? 0) > 0 || (log.notes?.isNotEmpty ?? false)) {
        _showExtra = true;
      }
    }
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
    final original = _originalLog;
    if (original == null) return;

    MealLog updated;
    if (_components.isNotEmpty) {
      // Component-based log: service recomputes totals
      updated = original.copyWith(
        name: _nameCtrl.text.trim(),
        slot: _slot,
        components: _components,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      // Simple manual log: pass macro fields directly
      updated = original.copyWith(
        name: _nameCtrl.text.trim(),
        slot: _slot,
        calories: int.tryParse(_calCtrl.text),
        carbsG: double.tryParse(_carbCtrl.text),
        proteinG: double.tryParse(_protCtrl.text),
        fatG: double.tryParse(_fatCtrl.text),
        sodiumMg: double.tryParse(_sodiumCtrl.text),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    }

    await ref.read(mealLogControllerProvider.notifier).updateLog(updated);

    if (!mounted) return;
    final controllerState = ref.read(mealLogControllerProvider);
    if (controllerState is AsyncData) {
      MealvanaSnackbar.showSuccess(context, 'Meal updated');
      context.pop();
    } else if (controllerState is AsyncError) {
      MealvanaSnackbar.showError(context, 'Failed to update meal. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;
    final original = _originalLog;
    final hasComponents = _components.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Edit Meal'),
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

              // Photo thumbnail (read-only) when available
              if (original?.photoPath != null && original!.photoPath!.isNotEmpty)
                _PhotoThumbnail(photoPath: original.photoPath!),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meal name',
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

              if (hasComponents) ...[
                // Per-component editor
                MealComponentEditor(
                  initialComponents: _components,
                  onComponentsChanged: (updated) =>
                      setState(() => _components = updated),
                ),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                // Simple macro fields
                _numField('Calories (kcal)', _calCtrl),
                const SizedBox(height: AppSpacing.sm),
                _numField('Carbs (g)', _carbCtrl),
                const SizedBox(height: AppSpacing.sm),
                _numField('Protein (g)', _protCtrl),
                const SizedBox(height: AppSpacing.sm),
                _numField('Fat (g)', _fatCtrl),
                const SizedBox(height: AppSpacing.md),
              ],

              // "Add more detail" toggle — always available for notes / sodium
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
                // Sodium only shown for simple-entry logs (components carry own sodium)
                if (!hasComponents) ...[
                  _numField('Sodium (mg)', _sodiumCtrl),
                  const SizedBox(height: AppSpacing.sm),
                ],
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
                text: 'Save changes',
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

// ---------------------------------------------------------------------------
// Read-only photo thumbnail (signed URL resolved inline)
// ---------------------------------------------------------------------------

class _PhotoThumbnail extends ConsumerWidget {
  const _PhotoThumbnail({required this.photoPath});

  final String photoPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(mealPhotoSignedUrlProvider(photoPath));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: urlAsync.when(
        data: (url) {
          if (url == null) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
