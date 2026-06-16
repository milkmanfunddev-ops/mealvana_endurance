import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/meal_analysis_result.dart';

/// An editable list of [MealAnalysisItem]s.
///
/// Exposes an [onItemsChanged] callback so parent widgets can track the current
/// item list for use when submitting a log entry.
class MealItemsEditor extends StatefulWidget {
  const MealItemsEditor({
    super.key,
    required this.initialItems,
    required this.onItemsChanged,
  });

  final List<MealAnalysisItem> initialItems;
  final ValueChanged<List<MealAnalysisItem>> onItemsChanged;

  @override
  State<MealItemsEditor> createState() => _MealItemsEditorState();
}

class _MealItemsEditorState extends State<MealItemsEditor> {
  late List<MealAnalysisItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item.name);
    final portionCtrl = TextEditingController(text: item.portion);
    final calCtrl =
        TextEditingController(text: item.calories.toString());
    final carbCtrl =
        TextEditingController(text: item.carbG.toStringAsFixed(1));
    final protCtrl =
        TextEditingController(text: item.proteinG.toStringAsFixed(1));
    final fatCtrl =
        TextEditingController(text: item.fatG.toStringAsFixed(1));
    final sodiumCtrl =
        TextEditingController(text: item.sodiumMg.toStringAsFixed(0));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Name', nameCtrl),
              const SizedBox(height: 8),
              _field('Portion', portionCtrl),
              const SizedBox(height: 8),
              _numField('Calories', calCtrl),
              const SizedBox(height: 8),
              _numField('Carbs (g)', carbCtrl),
              const SizedBox(height: 8),
              _numField('Protein (g)', protCtrl),
              const SizedBox(height: 8),
              _numField('Fat (g)', fatCtrl),
              const SizedBox(height: 8),
              _numField('Sodium (mg)', sodiumCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updated = MealAnalysisItem(
                name: nameCtrl.text.trim().isEmpty
                    ? item.name
                    : nameCtrl.text.trim(),
                portion: portionCtrl.text.trim().isEmpty
                    ? item.portion
                    : portionCtrl.text.trim(),
                calories: int.tryParse(calCtrl.text) ?? item.calories,
                carbG: double.tryParse(carbCtrl.text) ?? item.carbG,
                proteinG: double.tryParse(protCtrl.text) ?? item.proteinG,
                fatG: double.tryParse(fatCtrl.text) ?? item.fatG,
                sodiumMg: double.tryParse(sodiumCtrl.text) ?? item.sodiumMg,
              );
              setState(() {
                _items[index] = updated;
              });
              widget.onItemsChanged(List.unmodifiable(_items));
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Controllers outlive the dialog route; dispose once it closes.
      nameCtrl.dispose();
      portionCtrl.dispose();
      calCtrl.dispose();
      carbCtrl.dispose();
      protCtrl.dispose();
      fatCtrl.dispose();
      sodiumCtrl.dispose();
    });
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  int get _totalCalories =>
      _items.fold(0, (sum, item) => sum + item.calories);
  double get _totalCarbG =>
      _items.fold(0.0, (sum, item) => sum + item.carbG);
  double get _totalProteinG =>
      _items.fold(0.0, (sum, item) => sum + item.proteinG);
  double get _totalFatG =>
      _items.fold(0.0, (sum, item) => sum + item.fatG);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${item.portion} · ${item.calories} kcal  '
                'C ${item.carbG.toStringAsFixed(0)}g  '
                'P ${item.proteinG.toStringAsFixed(0)}g  '
                'F ${item.fatG.toStringAsFixed(0)}g',
                style: theme.textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editItem(i),
                tooltip: 'Edit',
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$_totalCalories kcal  '
                  'C ${_totalCarbG.toStringAsFixed(0)}g  '
                  'P ${_totalProteinG.toStringAsFixed(0)}g  '
                  'F ${_totalFatG.toStringAsFixed(0)}g',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
