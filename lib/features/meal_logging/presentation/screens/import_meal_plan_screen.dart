import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../application/meal_ai_service.dart';
import '../../application/meal_plan_text_extractor.dart';
import '../../domain/meal_analysis_result.dart' show MealAnalysisConfidence;
import '../../domain/meal_plan_result.dart';
import '../providers/meal_log_providers.dart';

/// AI meal-plan import: pick a PDF (or image of a printed plan), parse it with
/// Claude, review/trim the extracted meals, then save them as reusable
/// favorites ("My Meals").
///
/// Route: `/meal-log/import-plan`
class ImportMealPlanScreen extends ConsumerStatefulWidget {
  const ImportMealPlanScreen({super.key});

  @override
  ConsumerState<ImportMealPlanScreen> createState() =>
      _ImportMealPlanScreenState();
}

enum _Phase { idle, parsing, review, importing }

/// A parsed meal the user can rename or exclude before importing.
class _EditableMeal {
  _EditableMeal(this.source)
      : nameController = TextEditingController(text: source.name),
        include = true;

  final ParsedPlanMeal source;
  final TextEditingController nameController;
  bool include;

  ParsedPlanMeal toParsed() {
    final name = nameController.text.trim();
    return ParsedPlanMeal(
      name: name.isEmpty ? source.name : name,
      dayLabel: source.dayLabel,
      suggestedSlot: source.suggestedSlot,
      confidence: source.confidence,
      items: source.items,
      totals: source.totals,
      notes: source.notes,
    );
  }
}

class _ImportMealPlanScreenState extends ConsumerState<ImportMealPlanScreen> {
  _Phase _phase = _Phase.idle;
  String? _planTitle;
  List<_EditableMeal> _meals = [];
  String? _error;

  static const _allowedExtensions = MealPlanTextExtractor.supportedExtensions;

  /// Below this many characters of extracted text, we assume there was nothing
  /// readable (e.g. a scanned/image-only PDF) rather than send noise to the AI.
  static const _minTextChars = 20;

  @override
  void dispose() {
    for (final m in _meals) {
      m.nameController.dispose();
    }
    super.dispose();
  }

  int get _selectedCount => _meals.where((m) => m.include).length;

  Future<void> _pickAndParse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return; // cancelled

    final file = picked.files.first;
    final bytes = file.bytes;
    final ext = (file.extension ?? '').toLowerCase();
    if (bytes == null || ext.isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Could not read that file. Please try another.';
      });
      return;
    }

    setState(() {
      _phase = _Phase.parsing;
      _error = null;
    });

    try {
      // Extract text on-device — let the busy frame paint first, since this is
      // CPU-bound for large PDFs.
      await Future<void>.delayed(Duration.zero);
      final text = MealPlanTextExtractor.extract(bytes: bytes, extension: ext);
      if (text.trim().length < _minTextChars) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.idle;
          _error = "We couldn't find readable text in that file. If it's a "
              'scanned PDF, try a text-based PDF, a Word doc, or a .txt file.';
        });
        return;
      }

      final result =
          await ref.read(mealAiServiceProvider).parseMealPlanText(text);
      if (!mounted) return;
      setState(() {
        _planTitle = result.planTitle;
        _meals = result.meals.map(_EditableMeal.new).toList();
        _phase = _Phase.review;
      });
    } on UnsupportedDocumentException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = 'That file type isn\'t supported. Use a PDF, Word doc, or .txt.';
      });
    } on DocumentExtractionException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = "We couldn't read that file. It may be corrupt or password-protected.";
      });
    } on InsufficientCreditsException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = "You're out of AI credits. Top up to import meal plans.";
      });
    } on MealAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = 'Something went wrong reading your plan. Please try again.';
      });
    }
  }

  Future<void> _import() async {
    final selected =
        _meals.where((m) => m.include).map((m) => m.toParsed()).toList();
    if (selected.isEmpty) return;

    setState(() => _phase = _Phase.importing);
    try {
      final count = await ref
          .read(mealLogControllerProvider.notifier)
          .importPlanAsSavedMeals(selected);
      if (!mounted) return;
      MealvanaSnackbar.showSuccess(
        context,
        count == 1 ? 'Saved 1 meal to My Meals' : 'Saved $count meals to My Meals',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.review);
      MealvanaSnackbar.showError(context, 'Could not save meals. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        elevation: 0,
        title: const Text('Import Meal Plan'),
      ),
      body: switch (_phase) {
        _Phase.parsing => const _Busy(label: 'Reading your plan…'),
        _Phase.importing => const _Busy(label: 'Saving meals…'),
        _Phase.idle => _IdleBody(error: _error, onPick: _pickAndParse),
        _Phase.review => _reviewBody(isDark),
      },
      bottomNavigationBar: _phase == _Phase.review && _selectedCount > 0
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.electrolyte,
                  foregroundColor: AppColors.blackberry,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.bookmark_add),
                label: Text(
                  _selectedCount == 1
                      ? 'Save 1 meal to My Meals'
                      : 'Save $_selectedCount meals to My Meals',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: _import,
              ),
            )
          : null,
    );
  }

  Widget _reviewBody(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        if (_planTitle != null && _planTitle!.trim().isNotEmpty) ...[
          Text(
            _planTitle!,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Review the meals below. Uncheck any you don\'t want, tweak names, '
          'then save them to My Meals to log anytime.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: (isDark ? AppColors.cream : AppColors.blackberry)
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final meal in _meals) _mealCard(meal, isDark),
      ],
    );
  }

  Widget _mealCard(_EditableMeal meal, bool isDark) {
    final t = meal.source.totals;
    final macro = '${t.calories} kcal  ·  C ${t.carbG.toStringAsFixed(0)}g  ·  '
        'P ${t.proteinG.toStringAsFixed(0)}g  ·  F ${t.fatG.toStringAsFixed(0)}g';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: meal.include,
                  activeColor: AppColors.electrolyteDark,
                  onChanged: (v) =>
                      setState(() => meal.include = v ?? false),
                ),
                Expanded(
                  child: TextField(
                    controller: meal.nameController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Meal name',
                    ),
                  ),
                ),
                _ConfidenceBadge(meal.source.confidence),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meal.source.dayLabel != null &&
                      meal.source.dayLabel!.trim().isNotEmpty)
                    Text(
                      '${meal.source.dayLabel}  ·  ${meal.source.suggestedSlot.wireValue}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                (isDark ? AppColors.cream : AppColors.blackberry)
                                    .withValues(alpha: 0.55),
                          ),
                    ),
                  const SizedBox(height: 2),
                  Text(macro,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    meal.source.items.map((i) => i.name).join(', '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              (isDark ? AppColors.cream : AppColors.blackberry)
                                  .withValues(alpha: 0.65),
                        ),
                  ),
                  if (meal.source.notes != null &&
                      meal.source.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meal.source.notes!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.orange,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.electrolyte),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.error, required this.onPick});
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined,
                size: 64, color: AppColors.electrolyteDark),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Import a meal plan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a PDF, Word doc, or text file. We\'ll read the meals on your '
              'device and add them to My Meals so you can log them anytime.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.dragonfruit),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.electrolyte,
                foregroundColor: AppColors.blackberry,
                minimumSize: const Size(220, 52),
              ),
              icon: const Icon(Icons.upload_file),
              label: Text(error == null ? 'Choose file' : 'Try again',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge(this.confidence);
  final MealAnalysisConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      MealAnalysisConfidence.high => ('High', AppColors.electrolyteDark),
      MealAnalysisConfidence.medium => ('Medium', AppColors.orange),
      MealAnalysisConfidence.low => ('Low', AppColors.dragonfruit),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
