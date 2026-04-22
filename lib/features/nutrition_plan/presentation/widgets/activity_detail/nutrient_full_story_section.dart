import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../auth/domain/user_preferences.dart';
import '../../../../settings/presentation/providers/settings_controller.dart';
import '../../../../settings/presentation/providers/sweat_profile_controller.dart';
import '../../../domain/nutrient_transparency_data.dart';
import '../../../domain/nutrition_target_overrides.dart';
import 'transparency_accordion.dart';

/// Renders the "Full Story" accordion for nutrient transparency.
///
/// Handles all four nutrient types (Carbs, Fluids, Sodium, Protein).
/// Accent colors, labels, and badges are driven by [NutrientTransparencyData].
///
/// New optional callbacks added for Phase 5 wiring:
/// - [onEditKnownSweatRate]: called when user taps to edit their known sweat rate.
/// - [onEditKnownSodiumConcentration]: called when user taps to edit their known
///   sodium concentration.
///
/// Both callbacks are null in Phase 4; Phase 5 will provide them.
class NutrientFullStorySection extends ConsumerStatefulWidget {
  const NutrientFullStorySection({
    super.key,
    required this.data,
    this.onSettingsChanged,
    this.onEditKnownSweatRate,
    this.onEditKnownSodiumConcentration,
  });

  final NutrientTransparencyData data;
  final VoidCallback? onSettingsChanged;

  /// TODO(phase5): wire up to sweat-rate edit flow.
  final VoidCallback? onEditKnownSweatRate;

  /// TODO(phase5): wire up to sodium-concentration edit flow.
  final VoidCallback? onEditKnownSodiumConcentration;

  @override
  ConsumerState<NutrientFullStorySection> createState() =>
      _NutrientFullStorySectionState();
}

class _NutrientFullStorySectionState
    extends ConsumerState<NutrientFullStorySection> {
  GutTraining? _pendingGutTraining;
  final _personalTargetController = TextEditingController();
  final _knownSweatRateController = TextEditingController();
  final _knownSodiumConcController = TextEditingController();
  bool _showGutSaved = false;
  bool _showTargetSaved = false;
  bool _showSweatRateSaved = false;
  bool _showSodiumConcSaved = false;
  bool _useImperialSweatRate = false; // mL/hr vs oz/hr toggle

  @override
  void initState() {
    super.initState();
    final currentTarget = widget.data.currentPersonalTargetGPerH;
    if (currentTarget != null) {
      _personalTargetController.text = currentTarget.round().toString();
    }
  }

  @override
  void didUpdateWidget(NutrientFullStorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.currentPersonalTargetGPerH !=
        widget.data.currentPersonalTargetGPerH) {
      final val = widget.data.currentPersonalTargetGPerH;
      _personalTargetController.text =
          val != null ? val.round().toString() : '';
    }
  }

  @override
  void dispose() {
    _personalTargetController.dispose();
    _knownSweatRateController.dispose();
    _knownSodiumConcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.data.nutrientColor;

    return TransparencyAccordion(
      title: 'The Full Story',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "TESTED ✓" badge for nutrients where the athlete has lab data.
          if (widget.data.isTested) ...[
            _buildTestedBadge(context, accentColor),
            const SizedBox(height: 10),
          ],
          for (int i = 0; i < widget.data.storySections.length; i++) ...[
            if (i > 0) _buildDivider(context),
            _buildStorySection(context, widget.data.storySections[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTestedBadge(BuildContext context, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.science_outlined,
            size: 12,
            color: accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            'TESTED \u2713',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildStorySection(BuildContext context, StorySection section) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryText =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final dimText = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    final accentColor = widget.data.nutrientColor;

    // Transparency note (no question/answer)
    if (section.transparencyNote != null && section.question.isEmpty) {
      return _buildTransparencyNote(context, section.transparencyNote!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question
        Text(
          section.question,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),

        // Answer (supports **bold** for key phrases)
        _buildRichText(
          section.answer,
          normalColor: secondaryText,
          boldColor: primaryText,
        ),

        // Data chips (label · value — label in accent, value in secondary)
        if (section.dataChips.isNotEmpty) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: section.dataChips.map((chip) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: _buildChipRichText(chip, secondaryText, accentColor),
              );
            }).toList(),
          ),
        ],

        // Citation
        if (section.citation != null) ...[
          const SizedBox(height: 4),
          Text(
            section.citation!,
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: dimText,
            ),
          ),
        ],

        // Transparency note (inline with a Q&A)
        if (section.transparencyNote != null) ...[
          const SizedBox(height: 8),
          _buildTransparencyNote(context, section.transparencyNote!),
        ],

        // Inline edits
        if (section.inlineEditType == InlineEditType.gutTraining)
          _buildGutTrainingEdit(context),
        if (section.inlineEditType == InlineEditType.personalTarget)
          _buildPersonalTargetEdit(context),
        if (section.inlineEditType == InlineEditType.knownSweatRate &&
            widget.onEditKnownSweatRate != null)
          _buildKnownSweatRateEdit(context),
        if (section.inlineEditType == InlineEditType.knownSodiumConcentration &&
            widget.onEditKnownSodiumConcentration != null)
          _buildKnownSodiumConcentrationEdit(context),
      ],
    );
  }

  Widget _buildTransparencyNote(BuildContext context, String note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warningColor =
        isDark ? const Color(0xFFF0C87E) : const Color(0xFFD4A84E);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: warningColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSPARENCY NOTE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: warningColor.withValues(alpha: 0.8),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          _buildRichText(
            note,
            normalColor: isDark
                ? AppColors.textDarkSecondary
                : AppColors.textLightSecondary,
            boldColor: warningColor,
            fontSize: 12,
            height: 1.55,
          ),
        ],
      ),
    );
  }

  /// Parses `**bold**` markers in text and renders as RichText.
  Widget _buildRichText(
    String text, {
    required Color normalColor,
    required Color boldColor,
    double fontSize = 12.5,
    double height = 1.65,
  }) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: isBold ? boldColor : normalColor,
          height: height,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// Renders a data chip with the label (before ·) in nutrient accent color.
  Widget _buildChipRichText(
      String chip, Color secondaryText, Color accentColor) {
    final dotIndex = chip.indexOf(' \u00b7 ');
    if (dotIndex == -1) {
      // No separator — render plain
      return Text(
        chip,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          color: secondaryText,
        ),
      );
    }
    final label = chip.substring(0, dotIndex);
    final value = chip.substring(dotIndex);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: accentColor,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGutTrainingEdit(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.data.nutrientColor;
    final settingsAsync = ref.watch(settingsControllerProvider);
    final currentGut = settingsAsync.value?.gutTrainingLevel ??
        GutTraining.moderate;
    final selectedGut = _pendingGutTraining ?? currentGut;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR GUT TRAINING',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 9),
          _buildGutChips(context, selectedGut, accentColor),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSaveButton(
                context: context,
                accentColor: accentColor,
                onTap: () => _saveGutTraining(selectedGut),
              ),
            ],
          ),
          if (_showGutSaved)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Saved \u2713',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGutChips(
      BuildContext context, GutTraining selected, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: GutTraining.values.map((level) {
        final isActive = level == selected;
        final label = level.name[0].toUpperCase() + level.name.substring(1);
        final mult = switch (level) {
          GutTraining.low => '0.7\u00d7',
          GutTraining.moderate => '1.0\u00d7',
          GutTraining.high => '1.2\u00d7',
        };

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                left: level == GutTraining.low ? 0 : 3,
                right: level == GutTraining.high ? 0 : 3),
            child: GestureDetector(
              onTap: () => setState(() => _pendingGutTraining = level),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.09)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.22)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? accentColor
                            : isDark
                                ? AppColors.textDarkSecondary
                                : AppColors.textLightSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mult,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: isActive
                            ? accentColor.withValues(alpha: 0.7)
                            : isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonalTargetEdit(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.data.nutrientColor;
    final sport = widget.data.personalTargetSport ?? 'run';
    final sportCap = sport[0].toUpperCase() + sport.substring(1);
    final unit = widget.data.primaryUnit;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PERSONAL ${widget.data.nutrientLabel.toUpperCase()} TARGET DURING $sportCap',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: TextFormField(
                  controller: _personalTargetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Auto',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              _buildResetButton(context),
              const SizedBox(width: 6),
              _buildSaveButton(
                context: context,
                accentColor: accentColor,
                onTap: _savePersonalTarget,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Click Reset to use the algorithm recommendation',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (_showTargetSaved)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Saved \u2713',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Known Sweat Rate inline edit
  // ---------------------------------------------------------------------------

  Widget _buildKnownSweatRateEdit(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.data.nutrientColor;
    final unit = _useImperialSweatRate ? 'oz/hr' : 'mL/hr';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OR ENTER A KNOWN SWEAT RATE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _knownSweatRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unit toggle: mL/hr ↔ oz/hr
              GestureDetector(
                onTap: () => setState(() =>
                    _useImperialSweatRate = !_useImperialSweatRate),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildSaveButton(
                context: context,
                accentColor: accentColor,
                onTap: _saveKnownSweatRate,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tap unit to switch mL/hr \u2194 oz/hr',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          if (_showSweatRateSaved)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Saved \u2713',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Known Sodium Concentration inline edit
  // ---------------------------------------------------------------------------

  Widget _buildKnownSodiumConcentrationEdit(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.data.nutrientColor;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OR ENTER A TESTED SODIUM CONCENTRATION',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _knownSodiumConcController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'mg/L',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              _buildSaveButton(
                context: context,
                accentColor: accentColor,
                onTap: _saveKnownSodiumConcentration,
              ),
            ],
          ),
          if (_showSodiumConcSaved)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Saved \u2713',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveKnownSweatRate() async {
    final text = _knownSweatRateController.text.trim();
    if (text.isEmpty) return;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return;

    // Convert oz/hr → mL/hr if needed (1 fl oz ≈ 29.5735 mL)
    final mlPerHour = _useImperialSweatRate
        ? (value * 29.5735).round()
        : value.round();

    final sweatController =
        ref.read(sweatProfileControllerProvider.notifier);
    sweatController.setKnownSweatRate(mlPerHour);
    final error = await sweatController.save();

    if (error != null) {
      // Silently swallow — sheet doesn't have a BuildContext scaffold
      return;
    }

    setState(() => _showSweatRateSaved = true);
    widget.onEditKnownSweatRate?.call();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSweatRateSaved = false);
    });
  }

  Future<void> _saveKnownSodiumConcentration() async {
    final text = _knownSodiumConcController.text.trim();
    if (text.isEmpty) return;
    final value = int.tryParse(text);
    if (value == null || value <= 0) return;

    final sweatController =
        ref.read(sweatProfileControllerProvider.notifier);
    sweatController.setKnownSodiumConcentration(value);
    final error = await sweatController.save();

    if (error != null) return;

    setState(() => _showSodiumConcSaved = true);
    widget.onEditKnownSodiumConcentration?.call();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSodiumConcSaved = false);
    });
  }

  Widget _buildSaveButton({
    required BuildContext context,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          'Save',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        _personalTargetController.clear();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          'Reset',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Future<void> _saveGutTraining(GutTraining level) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .saveAllPreferences(gutTrainingLevel: level);
    setState(() {
      _pendingGutTraining = null;
      _showGutSaved = true;
    });
    widget.onSettingsChanged?.call();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showGutSaved = false);
    });
  }

  Future<void> _savePersonalTarget() async {
    final text = _personalTargetController.text.trim();
    final sport = widget.data.personalTargetSport ?? 'running';

    final settingsState = ref.read(settingsControllerProvider).value;
    final existingOverrides = settingsState?.nutritionTargetOverrides;

    NutritionTargetOverrides updatedOverrides;
    if (text.isEmpty) {
      // Reset to auto (null out the override for this sport)
      updatedOverrides = _clearCarbOverride(existingOverrides, sport);
    } else {
      final value = double.tryParse(text);
      if (value == null || value <= 0) return;
      updatedOverrides = _setCarbOverride(existingOverrides, sport, value);
    }

    final clamped = NutritionTargetGuardrails.clampAll(updatedOverrides);
    await ref
        .read(settingsControllerProvider.notifier)
        .saveNutritionTargetOverrides(clamped);
    setState(() => _showTargetSaved = true);
    widget.onSettingsChanged?.call();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showTargetSaved = false);
    });
  }

  NutritionTargetOverrides _setCarbOverride(
    NutritionTargetOverrides? existing,
    String sport,
    double value,
  ) {
    final base = existing ?? const NutritionTargetOverrides();
    final s = sport.toLowerCase();
    if (s.contains('run')) {
      final current = base.duringRun ?? const DuringActivityOverrides();
      return base.copyWith(
          duringRun: () => current.copyWith(carbRateGPerH: () => value));
    } else if (s.contains('cycl') || s.contains('bike')) {
      final current = base.duringCycling ?? const DuringActivityOverrides();
      return base.copyWith(
          duringCycling: () => current.copyWith(carbRateGPerH: () => value));
    } else if (s.contains('swim')) {
      final current = base.duringSwimming ?? const DuringActivityOverrides();
      return base.copyWith(
          duringSwimming: () => current.copyWith(carbRateGPerH: () => value));
    }
    return base;
  }

  NutritionTargetOverrides _clearCarbOverride(
    NutritionTargetOverrides? existing,
    String sport,
  ) {
    final base = existing ?? const NutritionTargetOverrides();
    final s = sport.toLowerCase();
    if (s.contains('run')) {
      final current = base.duringRun;
      if (current == null) return base;
      return base.copyWith(
          duringRun: () => DuringActivityOverrides(
                sodiumRateMgPerH: current.sodiumRateMgPerH,
                fluidRateMlPerH: current.fluidRateMlPerH,
              ));
    } else if (s.contains('cycl') || s.contains('bike')) {
      final current = base.duringCycling;
      if (current == null) return base;
      return base.copyWith(
          duringCycling: () => DuringActivityOverrides(
                sodiumRateMgPerH: current.sodiumRateMgPerH,
                fluidRateMlPerH: current.fluidRateMlPerH,
              ));
    } else if (s.contains('swim')) {
      final current = base.duringSwimming;
      if (current == null) return base;
      return base.copyWith(
          duringSwimming: () => DuringActivityOverrides(
                sodiumRateMgPerH: current.sodiumRateMgPerH,
                fluidRateMlPerH: current.fluidRateMlPerH,
              ));
    }
    return base;
  }
}
