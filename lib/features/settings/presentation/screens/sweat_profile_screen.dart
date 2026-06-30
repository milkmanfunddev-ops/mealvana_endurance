import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../providers/sweat_profile_controller.dart';

/// Dedicated settings screen for the user's sweat profile.
///
/// Covers:
///  - Sweat Rate (Light / Medium / Heavy)
///  - Sweat Sodium category (Low / Average / High)
///  - Optional "Personalize with a sweat test" section for entering
///    lab-measured values (sweat rate, sodium concentration, test date/source)
class SweatProfileScreen extends ConsumerStatefulWidget {
  const SweatProfileScreen({super.key});

  @override
  ConsumerState<SweatProfileScreen> createState() => _SweatProfileScreenState();
}

class _SweatProfileScreenState extends ConsumerState<SweatProfileScreen> {
  // Local text controllers for the sweat test fields.
  // We initialize them once the controller state loads.
  final _sweatRateController = TextEditingController();
  final _sodiumController = TextEditingController();

  // Unit toggle: mL/hr vs oz/hr for known sweat rate display.
  bool _showOzHr = false;
  bool _initialized = false;

  static const double _mlPerOz = 29.5735;

  @override
  void dispose() {
    _sweatRateController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  void _initFromState(SweatProfileState s) {
    if (_initialized) return;
    _initialized = true;

    if (s.knownSweatRateMlPerHour != null) {
      _sweatRateController.text = _showOzHr
          ? (s.knownSweatRateMlPerHour! / _mlPerOz).round().toString()
          : s.knownSweatRateMlPerHour.toString();
    }
    if (s.knownSodiumConcentrationMgPerLiter != null) {
      _sodiumController.text = s.knownSodiumConcentrationMgPerLiter.toString();
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final controller = ref.read(sweatProfileControllerProvider.notifier);

    // Push text-field values into the controller before saving.
    final rateText = _sweatRateController.text.trim();
    if (rateText.isEmpty) {
      controller.setKnownSweatRate(null);
    } else {
      final raw = int.tryParse(rateText);
      if (raw == null) {
        MealvanaSnackbar.showError(context, 'Enter a whole number for sweat rate.');
        return;
      }
      // Convert oz/hr back to mL/hr if the user is in imperial mode.
      final mlPerHour = _showOzHr ? (raw * _mlPerOz).round() : raw;
      controller.setKnownSweatRate(mlPerHour);
    }

    final sodiumText = _sodiumController.text.trim();
    if (sodiumText.isEmpty) {
      controller.setKnownSodiumConcentration(null);
    } else {
      final raw = int.tryParse(sodiumText);
      if (raw == null) {
        MealvanaSnackbar.showError(context, 'Enter a whole number for sodium concentration.');
        return;
      }
      controller.setKnownSodiumConcentration(raw);
    }

    final error = await controller.save();
    if (!mounted) return;

    if (error != null) {
      MealvanaSnackbar.showError(context, error);
    } else {
      MealvanaSnackbar.showSuccess(context, 'Sweat profile saved.');
    }
  }

  // ── Unit toggle ───────────────────────────────────────────────────────────

  void _toggleUnit() {
    final text = _sweatRateController.text.trim();
    setState(() {
      if (text.isNotEmpty) {
        final value = int.tryParse(text);
        if (value != null) {
          if (_showOzHr) {
            // switching back to mL/hr
            _sweatRateController.text = (value * _mlPerOz).round().toString();
          } else {
            // switching to oz/hr
            _sweatRateController.text = (value / _mlPerOz).round().toString();
          }
        }
      }
      _showOzHr = !_showOzHr;
    });
  }

  // ── How-to-test bottom sheet ──────────────────────────────────────────────

  void _showHowToTestSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _HowToTestSheet(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(sweatProfileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          'Sweat Profile',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ContentArea(
        child: asyncState.when(
          data: (s) {
            _initFromState(s);
            return _buildContent(context, s);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Unable to load sweat profile.\n$error',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.dragonfruit,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SweatProfileState s) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _buildSweatRateSection(context, s),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSweatSodiumSection(context, s),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSweatTestSection(context, s),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: s.isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blackberry,
                    disabledBackgroundColor:
                        AppColors.blackberry.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: s.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cream,
                          ),
                        )
                      : Text(
                          'Save',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sweat Rate section ────────────────────────────────────────────────────

  Widget _buildSweatRateSection(BuildContext context, SweatProfileState s) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sweat Rate',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How much you typically sweat during exercise.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KyleSweatRateSegmentedControl(
            selected: s.sweatRate,
            onChanged: (rate) =>
                ref.read(sweatProfileControllerProvider.notifier).setSweatRate(rate),
          ),
        ],
      ),
    );
  }

  // ── Sweat Sodium section ──────────────────────────────────────────────────

  Widget _buildSweatSodiumSection(BuildContext context, SweatProfileState s) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sweat Sodium',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How salty your sweat tastes. If you\'re not sure, "Average" is a safe default.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KyleSweatSodiumSegmentedControl(
            selected: s.sweatSodium,
            onChanged: (sodium) =>
                ref.read(sweatProfileControllerProvider.notifier).setSweatSodium(sodium),
          ),
        ],
      ),
    );
  }

  // ── Sweat test section ────────────────────────────────────────────────────

  Widget _buildSweatTestSection(BuildContext context, SweatProfileState s) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Personalize with a sweat test',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showHowToTestSheet,
                icon: const FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size: 14,
                  color: AppColors.orange,
                ),
                label: Text(
                  'How to test',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter values from a lab test or personal measurement to override the algorithm.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Known Sweat Rate
          _buildKnownSweatRateField(context),

          const SizedBox(height: AppSpacing.md),

          // Known Sodium Concentration
          _buildLabel(context, 'Sodium Concentration (mg/L)'),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _sodiumController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(
              context,
              hint: 'e.g. 800',
              suffix: 'mg/L',
              icon: FontAwesomeIcons.droplet.data,
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Test Date
          _buildLabel(context, 'Test Date'),
          const SizedBox(height: AppSpacing.xs),
          _buildTestDatePicker(context, s),

          const SizedBox(height: AppSpacing.md),

          // Test Source
          _buildLabel(context, 'Test Source'),
          const SizedBox(height: AppSpacing.xs),
          _buildTestSourceDropdown(context, s),
        ],
      ),
    );
  }

  Widget _buildKnownSweatRateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLabel(
                context,
                'Known Sweat Rate',
              ),
            ),
            // Unit toggle
            GestureDetector(
              onTap: _toggleUnit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showOzHr ? 'oz/hr' : 'mL/hr',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: !_showOzHr
                            ? AppColors.orange
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                        fontWeight:
                            !_showOzHr ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      ' / ',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'oz/hr',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: _showOzHr
                            ? AppColors.orange
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                        fontWeight:
                            _showOzHr ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _sweatRateController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(
            context,
            hint: _showOzHr ? 'e.g. 44' : 'e.g. 1300',
            suffix: _showOzHr ? 'oz/hr' : 'mL/hr',
            icon: FontAwesomeIcons.personRunning.data,
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTestDatePicker(BuildContext context, SweatProfileState s) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final selected = await showAppDatePicker(
          context: context,
          initialDate: s.sweatTestDate ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
        );
        if (selected != null) {
          ref
              .read(sweatProfileControllerProvider.notifier)
              .setSweatTestDate(selected);
        }
      },
      borderRadius: AppRadius.inputRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          borderRadius: AppRadius.inputRadius,
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.calendar,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                s.sweatTestDate != null
                    ? '${s.sweatTestDate!.month}/${s.sweatTestDate!.day}/${s.sweatTestDate!.year}'
                    : 'Select test date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: s.sweatTestDate != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (s.sweatTestDate != null)
              GestureDetector(
                onTap: () => ref
                    .read(sweatProfileControllerProvider.notifier)
                    .setSweatTestDate(null),
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSourceDropdown(BuildContext context, SweatProfileState s) {
    const sources = [
      _SweatTestSource('self_calculated', 'Self-calculated'),
      _SweatTestSource('commercial_test', 'Commercial lab test'),
      _SweatTestSource('gatorade_gx', 'Gatorade Gx patch'),
      _SweatTestSource('estimated', 'Estimated'),
      _SweatTestSource('other', 'Other'),
    ];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: s.sweatTestSource,
      hint: Text(
        'Select source',
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      decoration: _inputDecoration(
        context,
        hint: '',
        icon: FontAwesomeIcons.vial.data,
      ),
      items: sources
          .map(
            (src) => DropdownMenuItem(
              value: src.value,
              child: Text(
                src.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) =>
          ref.read(sweatProfileControllerProvider.notifier).setSweatTestSource(value),
      dropdownColor: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: Icon(
        icon,
        size: AppIconSizes.controlIcon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      suffix: suffix != null && suffix.isNotEmpty
          ? Text(
              suffix,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    );
  }
}

// ── Internal data class ────────────────────────────────────────────────────

class _SweatTestSource {
  const _SweatTestSource(this.value, this.label);
  final String value;
  final String label;
}

// ── How-to-test information sheet ─────────────────────────────────────────

class _HowToTestSheet extends StatelessWidget {
  const _HowToTestSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to measure your sweat profile',
                      style: AppTextStyles.subtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Option 1 — Self-calculated (free)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Weigh yourself (kg) before and after a 60-minute run at steady effort '
                      'without drinking. Each 1 kg lost equals ~1000 mL of sweat. '
                      'Also note how your kit tastes — chalky-white residue on skin or kit '
                      'suggests high sodium. Six-indicator checks (urine colour, skin taste, '
                      'muscle cramps, headache, swelling, pace drop) can confirm your profile.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Option 2 — LEVELEN Sweat Test (\$)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'A lab-grade patch worn during exercise captures sweat and provides '
                      'precise sodium concentration (mg/L) and sweat-rate data. '
                      'Results are delivered digitally within minutes of finishing.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Option 3 — Gatorade Gx Sweat Patch (\$)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Stick the patch on your forearm before a workout. A colorimetric strip '
                      'shows a Low / Moderate / High sodium reading after 20+ minutes of '
                      'activity. Scan the QR code in the Gatorade app for a full analysis '
                      'and recommended electrolyte plan.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Tip: Run tests under similar conditions (temperature, intensity) '
                      'for the most repeatable results.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
