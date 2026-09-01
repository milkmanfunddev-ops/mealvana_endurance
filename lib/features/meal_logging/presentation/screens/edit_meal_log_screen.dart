import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../../ai_credits/presentation/widgets/token_pill.dart';
import '../../../ai_coach/presentation/widgets/ai_thinking_status.dart';
import '../../application/meal_ai_service.dart';
import '../../domain/meal_analysis_result.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../../../nutrition_plan/presentation/providers/swap_food_controller.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/meal_analysis_skeleton.dart';
import '../widgets/meal_component_editor.dart';
import '../widgets/slot_chip_selector.dart' show OptionalSlotChipSelector;

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
/// User's choice when leaving the edit screen with unsaved changes.
enum _LeaveAction { discard, save, keepEditing }

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

  static final _timeFmt = DateFormat('h:mm a');

  MealLog? _originalLog;
  MealSlot? _slot;
  List<MealComponent> _components = const [];
  bool _showExtra = false;
  bool _initialized = false;

  /// Object path of the meal photo inside the `meal-photos` bucket. Held in
  /// state (not read straight off [_originalLog]) so a re-scan can swap in the
  /// newly-captured photo and have it persist on save.
  String? _photoPath;

  /// True while a re-scan photo is uploading + being analysed by Mealvana AI AI.
  bool _isRescanning = false;

  /// Bumped each time a re-scan replaces the item list. Used to key
  /// [MealComponentEditor] so it re-seeds from the new components (it only
  /// reads `initialComponents` in its `initState`).
  int _rescanEpoch = 0;

  /// The time the meal was eaten. Anchored to the log's calendar day
  /// ([MealLog.logDate]); only the time-of-day is user-editable here so an
  /// entry can be moved to the moment it was actually eaten without changing
  /// which day it counts toward. Seeded from the real log in
  /// [didChangeDependencies]; the default only covers the no-extra fallback.
  DateTime _eatenAt = DateTime.now();

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
    _photoPath = log.photoPath;

    // Seed the eaten-time from the existing value (falling back to the recorded
    // time), but anchor the date to the log's calendar day so editing the time
    // never silently moves the entry to a different day's totals.
    final base = log.eatenAt ?? log.createdAt;
    final day =
        DateTime.tryParse(log.logDate) ??
        DateTime(base.year, base.month, base.day);
    _eatenAt = DateTime(day.year, day.month, day.day, base.hour, base.minute);

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

  // ── Photo re-scan ─────────────────────────────────────────────────────────

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

  /// Re-capture the meal photo and replace the current items with a fresh Mealvana AI
  /// AI analysis. Mirrors the photo capture flow in the Log a Meal screen but
  /// updates this log in place instead of creating a new one. The replacement only
  /// happens after the user confirms, and the edit is held in memory until
  /// "Save changes" — so the unsaved-changes guard still protects it.
  Future<void> _rescanPhoto() async {
    // Metered AI must fail closed: the button is hidden when the release flag
    // is off, and this guard covers any path that reaches here anyway.
    if (!ref.read(appConfigProvider).describeMealEnabled) return;
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    XFile? file;
    try {
      // 1000px keeps enough detail for food recognition while trimming ~30%
      // off the image's share of model input tokens vs 1200px.
      file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1000,
      );
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Could not access the camera or gallery.',
        );
      }
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _isRescanning = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      MealPhotoAnalysis analysis;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        // A dotless filename would make split().last return the whole name,
        // so only trust the extension when a dot is actually present.
        final parts = file.name.split('.');
        final ext = (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
        analysis = await service.analyzePhotoBytes(bytes, extension: ext);
      } else {
        analysis = await service.analyzePhoto(File(file.path));
      }

      if (!mounted) return;
      final newComponents = analysis.result.items
          .map(_itemToComponent)
          .toList();
      final confirmed = await _confirmReplace(newComponents);
      if (!mounted || !confirmed) return;

      setState(() {
        _components = newComponents;
        _photoPath = analysis.storagePath;
        _rescanEpoch++;
        if (_nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = analysis.result.name;
        }
      });
      if (mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          'Items updated — tap "Save changes" to keep them.',
        );
      }
    } on InsufficientCreditsException catch (e) {
      maybeShowInsufficientCreditsPaywall(e);
    } on MealAiException catch (e) {
      if (!mounted) return;
      if (e.kind == MealAiFailureKind.notFood) {
        MealvanaSnackbar.showWarning(context, e.userMessage);
      } else {
        MealvanaSnackbar.showError(context, e.userMessage);
      }
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isRescanning = false);
    }
  }

  /// Prompts for a photo source. Returns null if dismissed. On web there is no
  /// camera option, so the gallery is used directly.
  Future<ImageSource?> _pickImageSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A re-scan is a metered AI call, so both source options carry
            // the token price like the other photo entry points.
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              trailing: const TokenCostTag(),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              trailing: const TokenCostTag(),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms replacing the current items with the [newComponents] detected by
  /// a re-scan. Returns false if the user cancels or dismisses.
  Future<bool> _confirmReplace(List<MealComponent> newComponents) async {
    final preview = newComponents.isEmpty
        ? 'No food items were detected.'
        : newComponents.map((c) => '• ${c.name} (${c.portion})').join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace items?'),
        content: SingleChildScrollView(
          child: Text(
            'Mealvana AI detected:\n\n$preview\n\n'
            'This replaces the current items on this meal.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: newComponents.isEmpty
                ? null
                : () => Navigator.of(ctx).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Builds the [MealLog] that a save would persist from the current form
  /// state. Kept separate from [_submit] so [_hasUnsavedChanges] can compare
  /// against it without duplicating the field-mapping logic.
  MealLog? _buildUpdatedLog() {
    final original = _originalLog;
    if (original == null) return null;

    if (_components.isNotEmpty) {
      // Component-based log: service recomputes totals
      return original.copyWith(
        name: _nameCtrl.text.trim(),
        slot: _slot,
        clearSlot: _slot == null,
        components: _components,
        photoPath: _photoPath,
        eatenAt: _eatenAt,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    }
    // Simple manual log: pass macro fields directly
    return original.copyWith(
      name: _nameCtrl.text.trim(),
      slot: _slot,
      clearSlot: _slot == null,
      calories: int.tryParse(_calCtrl.text),
      carbsG: double.tryParse(_carbCtrl.text),
      proteinG: double.tryParse(_protCtrl.text),
      fatG: double.tryParse(_fatCtrl.text),
      sodiumMg: double.tryParse(_sodiumCtrl.text),
      photoPath: _photoPath,
      eatenAt: _eatenAt,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = _buildUpdatedLog();
    if (updated == null) return;

    await ref.read(mealLogControllerProvider.notifier).updateLog(updated);

    if (!mounted) return;
    final controllerState = ref.read(mealLogControllerProvider);
    if (controllerState is AsyncData) {
      // Re-baseline so the screen is no longer considered "dirty" (the edits
      // are now the persisted truth) before we pop.
      _originalLog = updated;
      MealvanaSnackbar.showSuccess(context, 'Meal updated');
      context.pop();
    } else if (controllerState is AsyncError) {
      MealvanaSnackbar.showError(
        context,
        'Failed to update meal. Please try again.',
      );
    }
  }

  /// Whether the form holds edits that a save would persist. Drives the
  /// unsaved-changes guard so navigating away (back button / system back)
  /// after editing a component's quantity doesn't silently discard the change
  /// — the bug where an edited quantity "reverts" on returning to the page.
  bool _hasUnsavedChanges() {
    final original = _originalLog;
    final updated = _buildUpdatedLog();
    if (original == null || updated == null) return false;

    if (updated.name != original.name) return true;
    if (updated.slot != original.slot) return true;
    if ((updated.notes ?? '') != (original.notes ?? '')) return true;
    if ((updated.photoPath ?? '') != (original.photoPath ?? '')) return true;

    // Eaten time: only compare when the original carried an explicit value, so
    // seeding a default (from createdAt) doesn't register as an edit.
    final origEaten = original.eatenAt;
    if (origEaten != null && !updated.eatenAt!.isAtSameMomentAs(origEaten)) {
      return true;
    }

    if (original.components.isNotEmpty || _components.isNotEmpty) {
      if (_encodeComponents(updated.components) !=
          _encodeComponents(original.components)) {
        return true;
      }
    } else {
      // Simple manual log: compare the macro fields.
      if (updated.calories != original.calories) return true;
      if (updated.carbsG != original.carbsG) return true;
      if (updated.proteinG != original.proteinG) return true;
      if (updated.fatG != original.fatG) return true;
      if (updated.sodiumMg != original.sodiumMg) return true;
    }
    return false;
  }

  static String _encodeComponents(List<MealComponent> components) =>
      jsonEncode(components.map((c) => c.toJson()).toList());

  /// Opens the shared food-swap picker (returnSelection mode) and maps the
  /// chosen food + quantity into a replacement [MealComponent]. Returns null if
  /// the user cancels. Wired to [MealComponentEditor.onRequestSwap] so swiping
  /// an item swaps it (mirrors the Activity Detail food rows).
  Future<MealComponent?> _swapComponentFood(MealComponent current) async {
    final selection = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {
        'returnSelection': true,
        // Neutral category — the picker still searches the full catalog.
        'category': 'before_run',
        'foodToSwapName': current.name,
      },
    );
    if (selection == null) return null;

    final food = selection.food;
    final qty = selection.quantity;
    final qtyLabel = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    final unit = qty == 1
        ? (food.servingUnit ?? 'serving')
        : (food.servingUnitPlural ?? food.servingUnit ?? 'servings');
    double? scale(num? v) => v == null ? null : v.toDouble() * qty;

    return MealComponent(
      name: food.displayName ?? food.name,
      portion: '$qtyLabel $unit',
      calories: food.caloriesPerServing != null
          ? (food.caloriesPerServing! * qty).round()
          : null,
      carbG: scale(food.carbsPerServing),
      proteinG: scale(food.proteinPerServing),
      fatG: scale(food.fatPerServing),
      sodiumMg: scale(food.sodiumMg),
    );
  }

  /// Prompts the user before discarding unsaved edits. Returns the chosen
  /// action; `keepEditing` (or a dismissed dialog) leaves the screen in place.
  Future<_LeaveAction> _promptUnsavedChanges() async {
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes to this meal. Save them before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.keepEditing),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.discard),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return action ?? _LeaveAction.keepEditing;
  }

  /// Handles a blocked back-navigation attempt (see [PopScope]).
  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;
    if (!_hasUnsavedChanges()) {
      // Nothing to lose — leave immediately.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final action = await _promptUnsavedChanges();
    if (!mounted) return;
    switch (action) {
      case _LeaveAction.discard:
        Navigator.of(context).pop();
      case _LeaveAction.save:
        await _submit();
      case _LeaveAction.keepEditing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;
    final hasComponents = _components.isNotEmpty;
    final describeMealEnabled = ref.watch(
      appConfigProvider.select((config) => config.describeMealEnabled),
    );

    return PopScope(
      // Intercept all back-navigation so unsaved edits aren't silently
      // discarded. Programmatic `context.pop()` (used after a successful save)
      // bypasses this guard, so the save flow is unaffected.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        appBar: AppBar(
          // Route through maybePop so the PopScope unsaved-changes guard above
          // still fires (a bare CustomAppBarBackButton pops directly and would
          // bypass the discard/save prompt).
          leading: CustomAppBarBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
          title: const Text('Edit Meal'),
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: AppSpacing.screenPaddingHorizontal,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // Photo thumbnail — tappable to re-scan with a new photo
                    // (view-only while the meal-AI release flag is off).
                    if (_photoPath != null && _photoPath!.isNotEmpty)
                      _PhotoThumbnail(
                        // Keyed by path so the image reloads after a re-scan.
                        key: ValueKey(_photoPath),
                        photoPath: _photoPath!,
                        onTap: !describeMealEnabled || _isRescanning
                            ? null
                            : _rescanPhoto,
                      ),

                    // Re-scan action — lets the user recapture the meal photo and
                    // have Mealvana AI AI re-estimate the items. Available even when no
                    // photo exists yet (e.g. a manual log gaining a photo).
                    // Hidden while the meal-AI release flag is off so this
                    // metered entry point fails closed like the others.
                    if (describeMealEnabled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _isRescanning ? null : _rescanPhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 20),
                          label: Text(
                            (_photoPath != null && _photoPath!.isNotEmpty)
                                ? 'Re-scan photo'
                                : 'Scan a photo',
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Meal name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Slot selector
                    Text(
                      'Meal type',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    OptionalSlotChipSelector(
                      selectedSlot: _slot,
                      onSlotSelected: (s) => setState(() => _slot = s),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Time eaten — editable so a meal logged after the fact sits at
                    // the time it was actually eaten (not when it was recorded).
                    Text(
                      'Time eaten',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // A re-scan replaces exactly this list, so the skeleton
                    // stands in for it rather than covering the page — the
                    // items dissolve and re-form in place.
                    if (_isRescanning) ...[
                      const MealAnalysisSkeleton(
                        phases: AiThinkingStatus.photoPhases,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (hasComponents) ...[
                      // Per-component editor
                      MealComponentEditor(
                        key: ValueKey(_rescanEpoch),
                        initialComponents: _components,
                        onComponentsChanged: (updated) =>
                            setState(() => _components = updated),
                        onRequestSwap: _swapComponentFood,
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
          ],
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
// Meal photo thumbnail (signed URL resolved inline). Tappable to re-scan.
// ---------------------------------------------------------------------------

class _PhotoThumbnail extends ConsumerWidget {
  const _PhotoThumbnail({super.key, required this.photoPath, this.onTap});

  final String photoPath;

  /// When non-null, the thumbnail is tappable (used to trigger a photo
  /// re-scan) and shows a "Tap to re-scan" affordance.
  final VoidCallback? onTap;

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
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Image.network(
                    url,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  if (onTap != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to re-scan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
