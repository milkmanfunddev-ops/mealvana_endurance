import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/meal_analysis_result.dart';
import '../../domain/portion_quantity.dart';

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

  Future<void> _editItem(int index) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditItemDialog(
        item: _items[index],
        onSave: (updated) {
          setState(() {
            _items[index] = updated;
          });
          widget.onItemsChanged(List.unmodifiable(_items));
        },
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

/// Per-item "Edit Item" dialog for a [MealAnalysisItem].
///
/// Owns its own [TextEditingController]s so their lifetime is tied to the dialog
/// element (disposed in [dispose]) rather than a fragile post-close callback.
///
/// The recognized macros are absolute for [MealAnalysisItem.portion]. The
/// dialog captures that portion's leading number as the baseline quantity and
/// lets the user change the **Quantity** field to scale every macro
/// proportionally, mirroring the ratio approach in `TemplateScalingService`.
///
/// While editing, the Portion label is never rewritten (bug 39fe3fdb): it
/// keeps showing the unit portion (e.g. "1 cup") and the Quantity field alone
/// communicates how many were eaten. Because the persisted portion string is
/// the only place quantity is stored, [_persistedPortion] folds the chosen
/// quantity back into the portion at save time (e.g. "2 cup"), so saved rows
/// render the eaten amount exactly as before.
class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item, required this.onSave});

  final MealAnalysisItem item;
  final ValueChanged<MealAnalysisItem> onSave;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _protCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _sodiumCtrl;

  late final double _baseQty;
  late final double _baseCal;
  late final double _baseCarb;
  late final double _baseProt;
  late final double _baseFat;
  late final double _baseSodium;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item.name);
    _portionCtrl = TextEditingController(text: item.portion);
    _calCtrl = TextEditingController(text: item.calories.toString());
    _carbCtrl = TextEditingController(text: item.carbG.toStringAsFixed(1));
    _protCtrl = TextEditingController(text: item.proteinG.toStringAsFixed(1));
    _fatCtrl = TextEditingController(text: item.fatG.toStringAsFixed(1));
    _sodiumCtrl = TextEditingController(text: item.sodiumMg.toStringAsFixed(0));

    _baseQty = parseLeadingQuantity(item.portion) ?? 1.0;
    _baseCal = item.calories.toDouble();
    _baseCarb = item.carbG;
    _baseProt = item.proteinG;
    _baseFat = item.fatG;
    _baseSodium = item.sodiumMg;
    _qtyCtrl = TextEditingController(text: fmtQty(_baseQty));
    _qtyCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _qtyCtrl.dispose();
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    _sodiumCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) return;
    final ratio = qty / _baseQty;
    _calCtrl.text = (_baseCal * ratio).round().toString();
    _carbCtrl.text = (_baseCarb * ratio).toStringAsFixed(1);
    _protCtrl.text = (_baseProt * ratio).toStringAsFixed(1);
    _fatCtrl.text = (_baseFat * ratio).toStringAsFixed(1);
    _sodiumCtrl.text = (_baseSodium * ratio).toStringAsFixed(0);
    // The Portion label is deliberately NOT rewritten here — it stays at the
    // unit portion while Quantity communicates the amount (bug 39fe3fdb). The
    // quantity is folded into the persisted portion in [_persistedPortion].
  }

  /// The portion string to persist: the Portion text with the chosen Quantity
  /// folded into its leading number, so the saved row still renders the eaten
  /// amount ("2 cup · 400 kcal"). When Quantity is untouched (or invalid) the
  /// Portion text is saved verbatim, preserving manual portion edits.
  String _persistedPortion() {
    final text = _portionCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0 || qty == _baseQty) return text;
    return replaceLeadingQuantity(text, qty) ?? text;
  }

  void _save() {
    final item = widget.item;
    final persistedPortion = _persistedPortion();
    final updated = MealAnalysisItem(
      name: _nameCtrl.text.trim().isEmpty ? item.name : _nameCtrl.text.trim(),
      portion: persistedPortion.isEmpty ? item.portion : persistedPortion,
      calories: int.tryParse(_calCtrl.text) ?? item.calories,
      carbG: double.tryParse(_carbCtrl.text) ?? item.carbG,
      proteinG: double.tryParse(_protCtrl.text) ?? item.proteinG,
      fatG: double.tryParse(_fatCtrl.text) ?? item.fatG,
      sodiumMg: double.tryParse(_sodiumCtrl.text) ?? item.sodiumMg,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Name', _nameCtrl),
            const SizedBox(height: 8),
            _field('Portion', _portionCtrl),
            const SizedBox(height: 8),
            _numField('Quantity', _qtyCtrl,
                helperText: 'Scales the nutrients below'),
            const SizedBox(height: 8),
            _numField('Calories', _calCtrl),
            const SizedBox(height: 8),
            _numField('Carbs (g)', _carbCtrl),
            const SizedBox(height: 8),
            _numField('Protein (g)', _protCtrl),
            const SizedBox(height: 8),
            _numField('Fat (g)', _fatCtrl),
            const SizedBox(height: 8),
            _numField('Sodium (mg)', _sodiumCtrl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
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

  Widget _numField(String label, TextEditingController ctrl,
      {String? helperText}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

}
