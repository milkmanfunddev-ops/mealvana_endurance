import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../nutrition_plan/domain/nutrition_plan.dart';
import '../../nutrition_plan/domain/food_item_data.dart';
import '../../../shared/providers/unit_system_provider.dart';
import '../../../shared/utils/unit_formatter.dart';
import '../../nutrition_plan/domain/run_parameters.dart' show UnitSystem;

part 'pdf_generator_service.g.dart';

@riverpod
PdfGeneratorService pdfGeneratorService(Ref ref) {
  return PdfGeneratorService(ref);
}

class PdfGeneratorService {
  PdfGeneratorService(this._ref);

  final Ref _ref;

  static const _primaryColor = PdfColor.fromInt(0xFF381633);
  static const _darkColor = PdfColor.fromInt(0xFF1C0E1B);
  static const _creamColor = PdfColor.fromInt(0xFFF8F6EB);
  static const _blackColor = PdfColor.fromInt(0xFF0A0A0A);

  Future<Uint8List> generateNutritionPlanPdf({
    required NutritionPlan nutritionPlan,
    required DateTime sentDate,
    String? senderName,
  }) async {
    final useMetric =
        (_ref.read(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;
    final pdf = pw.Document();

    final logoBytes = await rootBundle.load(
      'assets/images/endurance_welcome_logo.png',
    );
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Center(
            child: pw.Image(
              logo,
              width: 200,
              height: 100,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              'Nutrition Plan',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: _darkColor,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildInfoSection(nutritionPlan, sentDate, senderName),
          pw.SizedBox(height: 30),
          if (nutritionPlan.macroTargets != null)
            _buildMacroTargets(nutritionPlan.macroTargets!, useMetric),
          pw.SizedBox(height: 20),
          ..._buildPlanSections(nutritionPlan.sections, useMetric),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildInfoSection(
    NutritionPlan plan,
    DateTime sentDate,
    String? senderName,
  ) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final activityDate = plan.runDateTime != null
        ? dateFormat.format(plan.runDateTime!)
        : 'Not scheduled';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _primaryColor, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Activity Date:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              pw.Text(
                activityDate,
                style: const pw.TextStyle(fontSize: 12, color: _blackColor),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sent:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              pw.Text(
                dateFormat.format(sentDate),
                style: const pw.TextStyle(fontSize: 12, color: _blackColor),
              ),
            ],
          ),
          if (senderName != null && senderName.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'From:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                pw.Text(
                  senderName,
                  style: const pw.TextStyle(fontSize: 12, color: _blackColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildMacroTargets(PlanMacroSummary targets, bool useMetric) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _creamColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Macro Targets',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _darkColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem('Carbs', '${targets.carbs}g'),
              _buildMacroItem('Protein', '${targets.protein}g'),
              _buildMacroItem('Fat', '${targets.fat}g'),
              _buildMacroItem('Calories', '${targets.calories}'),
            ],
          ),
          if (targets.sodium != null || targets.fluids != null) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (targets.sodium != null)
                  _buildMacroItem('Sodium', '${targets.sodium}mg'),
                if (targets.fluids != null)
                  _buildMacroItem(
                    'Fluids',
                    _formatFluidsFromOz(targets.fluids!, useMetric),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildMacroItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: _blackColor),
        ),
      ],
    );
  }

  /// Calculate section totals from food items
  Map<String, int> _calculateSectionTotals(PlanSection section) {
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalSodium = 0;
    int totalFluids = 0;

    for (final foodItem in section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        totalCarbs += nutrition.carbs ?? 0;
        totalProtein += nutrition.protein ?? 0;
        totalSodium += nutrition.sodium ?? 0;
        totalFluids += (nutrition.fluids ?? 0).toInt();
      }
    }

    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'sodium': totalSodium,
      'fluids': totalFluids,
    };
  }

  /// Build section subtitle with actual vs target values
  String _buildSectionSubtitle(PlanSection section, bool useMetric) {
    final totals = _calculateSectionTotals(section);
    final parts = <String>[];

    // Carbs (unit-invariant)
    if (section.carbsTarget != null && section.carbsTarget! > 0) {
      parts.add('${totals['carbs']}/${section.carbsTarget!.toInt()}g carbs');
    }

    // Fluids (canonical mL - convert to fl oz for imperial display)
    if (section.fluidsTarget != null && section.fluidsTarget! > 0) {
      final actualMl = (totals['fluids'] ?? 0).toDouble();
      final targetMl = section.fluidsTarget!;
      final unitLabel = UnitFormatter.fluidUnitLabel(useMetric: useMetric);
      final actualDisplay = useMetric
          ? actualMl.round()
          : (actualMl * UnitFormatter.kFlOzPerMl).round();
      final targetDisplay = useMetric
          ? targetMl.round()
          : (targetMl * UnitFormatter.kFlOzPerMl).round();
      parts.add('$actualDisplay/$targetDisplay$unitLabel fluids');
    }

    // Sodium (unit-invariant)
    if (section.sodiumTarget != null && section.sodiumTarget! > 0) {
      parts.add(
        '${totals['sodium']}/${section.sodiumTarget!.toInt()}mg sodium',
      );
    }

    return parts.join(', ');
  }

  /// Format a fluids value stored in fl oz (PlanMacroSummary.fluids' native
  /// unit) for display, converting to mL when the metric pref is active.
  String _formatFluidsFromOz(int fluidOz, bool useMetric) {
    final unitLabel = UnitFormatter.fluidUnitLabel(useMetric: useMetric);
    if (useMetric) {
      final ml = (fluidOz * UnitFormatter.kMlPerFlOz).round();
      return '$ml$unitLabel';
    }
    return '$fluidOz$unitLabel';
  }

  /// Format food item display text with quantity
  /// The quantity field already contains the full display text (e.g., "1 protein bar", "2 bananas")
  String _formatFoodItem(FoodItemData food) {
    return food.quantity;
  }

  List<pw.Widget> _buildPlanSections(
    List<PlanSection> sections,
    bool useMetric,
  ) {
    return sections.map((section) {
      final subtitle = _buildSectionSubtitle(section, useMetric);

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  section.title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          ...section.foodItems.map((food) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    margin: const pw.EdgeInsets.only(top: 6, right: 8),
                    decoration: const pw.BoxDecoration(
                      color: _primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      _formatFoodItem(food),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: _blackColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 20),
        ],
      );
    }).toList();
  }
}
