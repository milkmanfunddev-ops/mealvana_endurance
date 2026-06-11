import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_analysis_result.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/meal_items_editor.dart';
import '../widgets/slot_chip_selector.dart';

/// Review & confirm screen shown after AI analysis (photo or describe flows).
///
/// Route: `/meal-log/review`
/// Extras: `{ 'result': MealAnalysisResult, 'source': String, 'logDate': String, 'photoPath': String? }`
class MealReviewScreen extends ConsumerStatefulWidget {
  const MealReviewScreen({super.key});

  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen> {
  final _nameCtrl = TextEditingController();

  MealAnalysisResult? _result;
  String? _source;
  String? _logDate;
  String? _photoPath;
  MealSlot _slot = MealSlot.breakfast;
  List<MealAnalysisItem> _items = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      _result = extra?['result'] as MealAnalysisResult?;
      _source = extra?['source'] as String?;
      _logDate = extra?['logDate'] as String?;
      _photoPath = extra?['photoPath'] as String?;

      if (_result != null) {
        _nameCtrl.text = _result!.name;
        _slot = _result!.suggestedSlot;
        _items = List.from(_result!.items);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
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

  Future<void> _logMeal() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _logDate == null) return;

    final source = MealLogSource.fromWireValue(_source) ?? MealLogSource.photo;
    final components = _items.map(_itemToComponent).toList();

    await ref.read(mealLogControllerProvider.notifier).logFromComponents(
          name: name,
          slot: _slot,
          logDate: _logDate!,
          source: source,
          components: components,
          photoPath: _photoPath,
        );

    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      context.go('/main');
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(context, 'Failed to log meal. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(mealLogControllerProvider);
    final isLoading = controllerState is AsyncLoading;

    if (_result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Meal')),
        body: const Center(child: Text('Missing analysis result.')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
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
              decoration: const InputDecoration(
                labelText: 'Meal name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
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

            // Items editor
            MealItemsEditor(
              initialItems: _items,
              onItemsChanged: (items) => setState(() => _items = items),
            ),

            // AI notes
            if (_result!.notes != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
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
              onPressed: isLoading ? null : _logMeal,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
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
        color = const Color(0xFF00C896);
        label = 'High confidence';
        break;
      case MealAnalysisConfidence.medium:
        color = const Color(0xFFFF9500);
        label = 'Medium confidence';
        break;
      case MealAnalysisConfidence.low:
        color = const Color(0xFFFF2D55);
        label = 'Low confidence — please review';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
