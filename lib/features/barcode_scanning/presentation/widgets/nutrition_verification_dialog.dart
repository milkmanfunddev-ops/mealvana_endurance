import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/shared/widgets/secondary_button.dart';
import '../../domain/api_food_product.dart';
import '../../../nutrition_plan/domain/food.dart';

/// Dialog for verifying and editing nutritional values before importing scanned food
class NutritionVerificationDialog extends StatefulWidget {
  final ApiFoodProduct apiProduct;
  final Food mappedFood;
  final VoidCallback onCancel;
  final Function(Food) onConfirm;

  const NutritionVerificationDialog({
    super.key,
    required this.apiProduct,
    required this.mappedFood,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<NutritionVerificationDialog> createState() => _NutritionVerificationDialogState();
}

class _NutritionVerificationDialogState extends State<NutritionVerificationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _carbsController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _sodiumController;
  late TextEditingController _servingSizeController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values
    _nameController = TextEditingController(text: widget.mappedFood.name);
    _caloriesController = TextEditingController(
      text: widget.mappedFood.caloriesPerServing?.toString() ?? '',
    );
    _carbsController = TextEditingController(
      text: widget.mappedFood.carbsPerServing?.toStringAsFixed(1) ?? '',
    );
    _proteinController = TextEditingController(
      text: widget.mappedFood.proteinPerServing?.toStringAsFixed(1) ?? '',
    );
    _fatController = TextEditingController(
      text: widget.mappedFood.fatPerServing?.toStringAsFixed(1) ?? '',
    );
    _sodiumController = TextEditingController(
      text: widget.mappedFood.sodiumMg?.toString() ?? '',
    );
    _servingSizeController = TextEditingController(
      text: widget.mappedFood.servingSize ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    _servingSizeController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    // Create updated Food object with edited values
    final updatedFood = Food(
      id: widget.mappedFood.id,
      name: _nameController.text.trim(),
      imageAddress: widget.mappedFood.imageAddress,
      description: widget.mappedFood.description,
      instructions: widget.mappedFood.instructions,
      servingAmount: widget.mappedFood.servingAmount,
      displayName: widget.mappedFood.displayName,
      displayNamePlural: widget.mappedFood.displayNamePlural,
      servingUnit: widget.mappedFood.servingUnit,
      servingUnitPlural: widget.mappedFood.servingUnitPlural,
      servingQualifier: widget.mappedFood.servingQualifier,
      servingSize: _servingSizeController.text.trim(),
      carbsPerServing: double.tryParse(_carbsController.text),
      sodiumMg: int.tryParse(_sodiumController.text),
      fluidMlPerServing: widget.mappedFood.fluidMlPerServing,
      caloriesPerServing: int.tryParse(_caloriesController.text),
      proteinPerServing: double.tryParse(_proteinController.text),
      fatPerServing: double.tryParse(_fatController.text),
      caffeineMg: widget.mappedFood.caffeineMg,
      potassiumMg: widget.mappedFood.potassiumMg,
      beforeRunSuitable: widget.mappedFood.beforeRunSuitable,
      duringRunSuitable: widget.mappedFood.duringRunSuitable,
      runPortable: widget.mappedFood.runPortable,
      requiresPreparation: widget.mappedFood.requiresPreparation,
      aidStationAvailable: widget.mappedFood.aidStationAvailable,
      maxServingsBefore: widget.mappedFood.maxServingsBefore,
      maxServingsDuring: widget.mappedFood.maxServingsDuring,
    );

    widget.onConfirm(updatedFood);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Verify Nutrition Info',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product image (if available)
            if (widget.mappedFood.imageUrl != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.mappedFood.imageUrl!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.food_bank,
                          size: 40,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Info message
            _buildTextField(
              controller: _nameController,
              label: 'Product Name',
              icon: Icons.fastfood,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _servingSizeController,
              label: 'Serving Size',
              icon: Icons.straighten,
            ),
            const SizedBox(height: 12),

            _buildNumberField(
              controller: _caloriesController,
              label: 'Calories',
              icon: Icons.local_fire_department,
              suffix: 'cal',
            ),
            const SizedBox(height: 12),

            _buildNumberField(
              controller: _carbsController,
              label: 'Carbohydrates',
              icon: Icons.grain,
              suffix: 'g',
              allowDecimals: true,
            ),
            const SizedBox(height: 12),

            _buildNumberField(
              controller: _proteinController,
              label: 'Protein',
              icon: Icons.fitness_center,
              suffix: 'g',
              allowDecimals: true,
            ),
            const SizedBox(height: 12),

            _buildNumberField(
              controller: _fatController,
              label: 'Fat',
              icon: Icons.water_drop,
              suffix: 'g',
              allowDecimals: true,
            ),
            const SizedBox(height: 12),

            _buildNumberField(
              controller: _sodiumController,
              label: 'Sodium',
              icon: Icons.scatter_plot,
              suffix: 'mg',
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: widget.onCancel,
                    text: 'Cancel',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    onPressed: _onConfirm,
                    text: 'Add to Plan',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    bool allowDecimals = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
      inputFormatters: [
        if (allowDecimals)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixText: suffix,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}