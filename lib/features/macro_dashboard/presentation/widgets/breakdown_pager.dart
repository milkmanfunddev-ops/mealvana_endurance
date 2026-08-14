import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';
import '../providers/macro_dashboard_providers.dart';

/// The Breakdown Pager — full-screen overlay with the three breakdown pages
/// (Today's Energy · Active Energy · Today's Fuel), swipeable with pager
/// dots, ported from the reference rendering (prototypes/macro-dashboard
/// @ aa81d21, "Breakdown Pager" + its three sheet components). Opened at the
/// active face's page: All → 0, Workout → 1, Meals → 2.
Future<void> showBreakdownPager(
  BuildContext context, {
  required int initialIndex,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Breakdown',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (_, __, ___) => BreakdownPager(initialIndex: initialIndex),
    transitionBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

const _sheetBg = Color.fromRGBO(48, 18, 44, 1);
const _popoverBg = Color.fromRGBO(64, 26, 58, 1);

class _InfoContent {
  const _InfoContent({
    required this.title,
    this.body,
    this.kcal,
    this.lines = const [],
    this.note,
  });

  final String title;
  final String? body;
  final String? kcal;
  final List<(String, String)> lines;
  final String? note;
}

class BreakdownPager extends ConsumerStatefulWidget {
  const BreakdownPager({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  ConsumerState<BreakdownPager> createState() => _BreakdownPagerState();
}

class _BreakdownPagerState extends ConsumerState<BreakdownPager> {
  late final PageController _controller;
  late int _index;
  _InfoContent? _info;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 2);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showInfo(_InfoContent info) => setState(() => _info = info);

  @override
  Widget build(BuildContext context) {
    final dayAsync = ref.watch(macroDashboardDayProvider);
    final data = dayAsync.value;
    final energy = data?.energy;
    final breakdown = data?.breakdown;

    return Material(
      color: _sheetBg,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: energy == null || breakdown == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MeTokens.electrolyte,
                          ),
                        )
                      : PageView(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _index = i),
                          children: [
                            _TodaysEnergyPage(
                              energy: energy,
                              breakdown: breakdown,
                              onInfo: _showInfo,
                            ),
                            _ActiveEnergyPage(
                              energy: energy,
                              breakdown: breakdown,
                              onInfo: _showInfo,
                            ),
                            _TodaysFuelPage(
                              energy: energy,
                              breakdown: breakdown,
                              onInfo: _showInfo,
                            ),
                          ],
                        ),
                ),
                _dotsBar(),
              ],
            ),
            // Fixed close — stays put while pages swipe under it.
            Positioned(
              top: 16,
              left: 18,
              child: _CloseButton(onTap: () => Navigator.of(context).pop()),
            ),
            if (_info != null)
              _InfoPopover(
                info: _info!,
                onClose: () => setState(() => _info = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dotsBar() {
    const labels = ["Today's Energy", 'Active Energy', "Today's Fueling"];
    return Container(
      padding: const EdgeInsets.only(top: 13, bottom: 16),
      decoration: BoxDecoration(
        color: _sheetBg,
        border: Border(top: BorderSide(color: MeTokens.creamAlpha(0.07))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Semantics(
              button: true,
              label: 'Go to ${labels[i]}',
              child: GestureDetector(
                onTap: () {
                  setState(() => _index = i);
                  _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4.5),
                  width: i == _index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? MeTokens.electrolyte
                        : MeTokens.creamAlpha(0.28),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MeTokens.cream,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close, size: 14, color: MeTokens.blackberry),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(62, 16, 62, 8),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: MeTokens.cream,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: children,
          ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.mark, {this.size = 10});

  final BurnMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (mark) {
      case BurnMark.verified:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: MeTokens.electrolyte,
          ),
        );
      case BurnMark.selfReported:
        // Half-filled ring (reference: left half electrolyte).
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _HalfDotPainter()),
        );
      case BurnMark.estimated:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: MeTokens.electrolyteAlpha(0.55),
              width: 1.5,
            ),
          ),
        );
    }
  }
}

class _HalfDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = MeTokens.electrolyte;
    canvas.drawOval(rect.deflate(0.75), ring);
    final fill = Paint()..color = MeTokens.electrolyte;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
    canvas.drawOval(rect.deflate(0.75), fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoDot extends StatelessWidget {
  const _InfoDot({required this.onTap, this.accent = false, this.size = 16});

  final VoidCallback onTap;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? MeTokens.electrolyteAlpha(0.8)
        : MeTokens.creamAlpha(0.5);
    final border =
        accent ? MeTokens.electrolyteAlpha(0.4) : MeTokens.creamAlpha(0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Text(
          'i',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: size * 0.66,
            height: 1,
            color: color,
          ),
        ),
      ),
    );
  }
}

String _clockLabel(int minutesSinceMidnight) {
  final h24 = minutesSinceMidnight ~/ 60;
  final minute = (minutesSinceMidnight % 60).toString().padLeft(2, '0');
  final hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final suffix = h24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $suffix';
}

TextStyle _contextStyle() => TextStyle(
      fontFamily: 'Apercu',
      fontSize: 11.5,
      letterSpacing: 0.4,
      color: MeTokens.creamAlpha(0.42),
    );

TextStyle _sectionLabelStyle({Color? color}) => TextStyle(
      fontFamily: 'Apercu',
      fontWeight: FontWeight.w500,
      fontSize: 10.5,
      letterSpacing: 1.4,
      color: color ?? MeTokens.creamAlpha(0.45),
    );

// ---------------------------------------------------------------------------
// Page 1 — Today's Energy
// ---------------------------------------------------------------------------

class _TodaysEnergyPage extends StatelessWidget {
  const _TodaysEnergyPage({
    required this.energy,
    required this.breakdown,
    required this.onInfo,
  });

  final EnergyCardData energy;
  final BreakdownData breakdown;
  final ValueChanged<_InfoContent> onInfo;

  static const _info = {
    'resting': _InfoContent(
      title: 'Resting',
      body:
          "We estimate this from your height, weight, age and sex, then count only the share for the hours that have passed today — so it grows as the day goes on. A device can't measure this, so it's always our estimate.",
    ),
    'workout': _InfoContent(
      title: 'Workout',
      body:
          "When you have a device connected, this comes straight from it. If you log a workout by hand, it's self-reported and we estimate the calories from the type and duration.",
    ),
    'dailymove': _InfoContent(
      title: 'Daily movement',
      body:
          "Measured by your device's all-day tracking. Without a connected device, we fall back to an estimate.",
    ),
    'digestion': _InfoContent(
      title: 'Digestion',
      body:
          'Your body uses roughly 10% of the calories you eat to digest them, so this rises as you log food.',
    ),
    'source': _InfoContent(
      title: 'What the marks mean',
      body:
          "Verified means the number came from your device — not that it's exact. Device calorie figures are estimates too; the label tells you where the number came from, not that it's perfect.",
    ),
    'total': _InfoContent(
      title: 'Total burned',
      body:
          'Add the four together and you get your total energy burned for the day — sometimes called your total daily energy expenditure.',
    ),
    'net': _InfoContent(
      title: 'Net',
      body:
          "Calories in minus calories out. This isn't a target to drive negative — for training, staying fueled matters more than a deficit.",
    ),
  };

  @override
  Widget build(BuildContext context) {
    final pct = (breakdown.minutesSinceMidnight / 1440 * 100).round();
    final rows = [
      (
        'Resting',
        'estimated',
        BurnMark.estimated,
        breakdown.restingSoFar.floorToDouble(),
        breakdown.restingByEnd.roundToDouble(),
        false,
        'resting',
      ),
      (
        'Workout',
        switch (breakdown.workoutMark) {
          BurnMark.verified => 'verified · Garmin',
          BurnMark.selfReported => 'self-reported',
          BurnMark.estimated => 'estimated',
        },
        breakdown.workoutMark,
        breakdown.workoutSoFar,
        breakdown.workoutByEnd.roundToDouble(),
        true,
        'workout',
      ),
      (
        'Daily movement',
        breakdown.movementMark == BurnMark.verified
            ? 'verified · Garmin'
            : 'estimated',
        breakdown.movementMark,
        breakdown.movementSoFar.floorToDouble(),
        breakdown.movementByEnd.roundToDouble(),
        true,
        'dailymove',
      ),
      (
        'Digestion',
        'estimated',
        BurnMark.estimated,
        breakdown.digestionSoFar.floorToDouble(),
        breakdown.digestionByEnd.roundToDouble(),
        true,
        'digestion',
      ),
    ];
    final burnedByEnd = rows.fold<double>(0, (a, r) => a + r.$5);

    return _PageScaffold(
      title: "Today's Energy",
      children: [
        Center(
          child: Text(
            '${_clockLabel(breakdown.minutesSinceMidnight)}  ·  $pct% of the day done',
            style: _contextStyle(),
          ),
        ),
        const SizedBox(height: 14),
        // HERO: net energy balance
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: MeTokens.creamAlpha(0.045),
            border: Border.all(color: MeTokens.creamAlpha(0.11)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'NET ENERGY BALANCE',
                    style: _sectionLabelStyle(color: MeTokens.creamAlpha(0.5)),
                  ),
                  const SizedBox(width: 6),
                  _InfoDot(onTap: () => onInfo(_info['net']!)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _monoBig(kcalStr(energy.eatenKcal), MeTokens.orange),
                  _dim('eaten'),
                  Text(
                    '−',
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 16,
                      color: MeTokens.creamAlpha(0.4),
                    ),
                  ),
                  _monoBig(kcalStr(energy.burnedKcal), MeTokens.electrolyte),
                  _dim('burned'),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '=',
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      height: 0.8,
                      color: MeTokens.creamAlpha(0.35),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    netStr(energy.netKcal),
                    style: const TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: 48,
                      height: 0.8,
                      color: MeTokens.orange,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: MeTokens.orangeAlpha(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 14,
            runSpacing: 4,
            children: [
              Text.rich(
                TextSpan(
                  style: _supportStyle(),
                  children: [
                    const TextSpan(text: 'Eaten '),
                    TextSpan(
                      text: kcalStr(energy.eatenKcal),
                      style: TextStyle(color: MeTokens.creamAlpha(0.72)),
                    ),
                    TextSpan(
                      text:
                          ' / ${kcalStr(energy.targetKcal)} · ${kcalStr(energy.remainingKcal.clamp(0, double.infinity))} to go',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: _supportStyle(),
                  children: [
                    const TextSpan(text: 'Burned '),
                    TextSpan(
                      text: kcalStr(energy.burnedKcal),
                      style: TextStyle(color: MeTokens.creamAlpha(0.72)),
                    ),
                    TextSpan(text: ' / ${kcalStr(burnedByEnd)} projected'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            'WHERE THE BURN COMES FROM',
            style: _sectionLabelStyle(),
          ),
        ),
        const SizedBox(height: 8),
        // RECEIPT
        Container(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          decoration: BoxDecoration(
            color: MeTokens.creamAlpha(0.035),
            border: Border.all(color: MeTokens.creamAlpha(0.09)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 13, bottom: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MeTokens.creamAlpha(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ENERGY BURNED',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          letterSpacing: 1,
                          color: MeTokens.creamAlpha(0.45),
                        ),
                      ),
                    ),
                    _colHeader('so far'),
                    _colHeader("by day's end"),
                  ],
                ),
              ),
              for (final r in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: MeTokens.creamAlpha(0.055)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _Mark(r.$3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.$1,
                                  style: TextStyle(
                                    fontFamily: 'Apercu',
                                    fontSize: 14.5,
                                    color: MeTokens.creamAlpha(0.92),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _InfoDot(onTap: () => onInfo(_info[r.$7]!)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.$2,
                              style: TextStyle(
                                fontFamily: 'Apercu',
                                fontSize: 10.5,
                                color: MeTokens.creamAlpha(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _receiptValue(r.$4, r.$6, MeTokens.creamAlpha(0.92)),
                      _receiptValue(r.$5, r.$6, MeTokens.creamAlpha(0.7)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Total burned',
                            style: TextStyle(
                              fontFamily: 'Apercu',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: MeTokens.cream,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _InfoDot(
                            onTap: () => onInfo(_info['total']!),
                            accent: true,
                          ),
                        ],
                      ),
                    ),
                    _totalValue(energy.burnedKcal, MeTokens.electrolyte),
                    _totalValue(
                      burnedByEnd,
                      MeTokens.electrolyteAlpha(0.75),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 13,
          runSpacing: 6,
          children: [
            _legend(const _Mark(BurnMark.verified, size: 8),
                'verified by Garmin'),
            _legend(
                const _Mark(BurnMark.selfReported, size: 8), 'self-reported'),
            _legend(const _Mark(BurnMark.estimated, size: 8), 'estimated'),
            _InfoDot(onTap: () => onInfo(_info['source']!), size: 15),
          ],
        ),
      ],
    );
  }

  Widget _colHeader(String text) => SizedBox(
        width: 64,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 9.5,
            letterSpacing: 0.4,
            color: MeTokens.creamAlpha(0.4),
          ),
        ),
      );

  Widget _receiptValue(double v, bool plus, Color color) => SizedBox(
        width: 64,
        child: Text.rich(
          TextSpan(
            children: [
              if (plus)
                TextSpan(
                  text: '+',
                  style: TextStyle(
                    fontFamily: 'Apercu Mono',
                    fontSize: 12,
                    color: MeTokens.creamAlpha(0.32),
                  ),
                ),
              TextSpan(
                text: kcalStr(v),
                style: TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontSize: 14,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          textAlign: TextAlign.right,
        ),
      );

  Widget _totalValue(double v, Color color) => SizedBox(
        width: 64,
        child: Text(
          kcalStr(v),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'Apercu Mono',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );

  Widget _legend(Widget mark, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10.5,
              color: MeTokens.creamAlpha(0.55),
            ),
          ),
        ],
      );

  Widget _monoBig(String text, Color color) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Apercu Mono',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  Widget _dim(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Apercu',
          fontSize: 12,
          color: MeTokens.creamAlpha(0.5),
        ),
      );

  TextStyle _supportStyle() => TextStyle(
        fontFamily: 'Apercu',
        fontSize: 11,
        color: MeTokens.creamAlpha(0.42),
      );
}

// ---------------------------------------------------------------------------
// Page 2 — Active Energy
// ---------------------------------------------------------------------------

class _ActiveEnergyPage extends StatelessWidget {
  const _ActiveEnergyPage({
    required this.energy,
    required this.breakdown,
    required this.onInfo,
  });

  final EnergyCardData energy;
  final BreakdownData breakdown;
  final ValueChanged<_InfoContent> onInfo;

  static const _totalInfo = _InfoContent(
    title: 'Active energy',
    body:
        "The calories from your workouts — just the Workout slice of your full daily burn, opened up. Everyday movement, resting and digestion sit outside this number; you'll find them in Today's Energy. Done sessions count toward today's burn now; planned ones are a forecast and don't count until they're recorded.",
  );
  static const _sourceInfo = _InfoContent(
    title: 'What the marks mean',
    body:
        "Verified means the number came from your device — not that it's exact; device calorie figures are estimates too. Planned numbers are a forecast and are never counted as energy already spent.",
  );

  @override
  Widget build(BuildContext context) {
    final rows = energy.workoutRows;
    final hasPlanned = energy.workoutPlannedKcal > 0;
    final pct = (breakdown.minutesSinceMidnight / 1440 * 100).round();

    return _PageScaffold(
      title: 'Active Energy',
      children: [
        Center(
          child: Text(
            '${_clockLabel(breakdown.minutesSinceMidnight)}  ·  '
            '${hasPlanned ? '$pct% of the day done' : 'all workouts done'}',
            style: _contextStyle(),
          ),
        ),
        const SizedBox(height: 14),
        // HERO: done leads
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DONE SO FAR',
                style: _sectionLabelStyle(
                  color: MeTokens.electrolyteAlpha(0.85),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    kcalStr(energy.workoutDoneKcal),
                    style: const TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: 56,
                      height: 0.86,
                      color: MeTokens.cream,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: MeTokens.creamAlpha(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              hasPlanned
                  ? Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 12.5,
                          color: MeTokens.creamAlpha(0.55),
                        ),
                        children: [
                          TextSpan(
                            text: '+${kcalStr(energy.workoutPlannedKcal)}',
                            style: TextStyle(
                              fontFamily: 'Apercu Mono',
                              color: MeTokens.creamAlpha(0.8),
                            ),
                          ),
                          const TextSpan(text: ' planned → '),
                          TextSpan(
                            text: kcalStr(energy.workoutProjectedKcal),
                            style: TextStyle(
                              fontFamily: 'Apercu Mono',
                              color: MeTokens.electrolyteAlpha(0.9),
                            ),
                          ),
                          const TextSpan(text: ' projected'),
                        ],
                      ),
                    )
                  : Text(
                      "all of today's workouts are in",
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 12.5,
                        color: MeTokens.creamAlpha(0.55),
                      ),
                    ),
            ],
          ),
        ),
        // Stacked share bar
        if (rows.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final r in rows) ...[
                  Expanded(
                    flex: energy.workoutProjectedKcal > 0
                        ? ((r.kcal / energy.workoutProjectedKcal) * 1000)
                            .round()
                            .clamp(1, 1000)
                        : 1,
                    child: Container(
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color:
                            r.planned ? Colors.transparent : MeTokens.electrolyte,
                        border: r.planned
                            ? Border.all(
                                color: MeTokens.electrolyteAlpha(0.5),
                                width: 1.5,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${kcalStr(energy.workoutDoneKcal)} done',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 10.5,
                  color: MeTokens.electrolyteAlpha(0.8),
                ),
              ),
              if (hasPlanned)
                Text(
                  '${kcalStr(energy.workoutPlannedKcal)} planned',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 10.5,
                    color: MeTokens.creamAlpha(0.4),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // RECEIPT of workouts
        for (final r in rows) ...[
          _workoutCard(r),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 5),
        // TOTAL
        Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: MeTokens.electrolyteAlpha(0.06),
            border: Border.all(color: MeTokens.electrolyteAlpha(0.18)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Active energy',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: MeTokens.cream,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _InfoDot(onTap: () => onInfo(_totalInfo), accent: true),
                    ],
                  ),
                  Text(
                    kcalStr(energy.workoutProjectedKcal),
                    style: const TextStyle(
                      fontFamily: 'Apercu Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: MeTokens.electrolyte,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${kcalStr(energy.workoutDoneKcal)} done',
                    style: TextStyle(
                      fontFamily: 'Apercu Mono',
                      fontSize: 11,
                      color: MeTokens.electrolyteAlpha(0.85),
                    ),
                  ),
                  if (hasPlanned)
                    Text(
                      ' + ${kcalStr(energy.workoutPlannedKcal)} planned',
                      style: TextStyle(
                        fontFamily: 'Apercu Mono',
                        fontSize: 11,
                        color: MeTokens.creamAlpha(0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 13,
          runSpacing: 6,
          children: [
            _legendItem(
                const _Mark(BurnMark.verified, size: 8), 'verified · Garmin'),
            _legendItem(
                const _Mark(BurnMark.selfReported, size: 8), 'self-reported'),
            _legendItem(const _Mark(BurnMark.estimated, size: 8),
                'planned (estimate)'),
            _InfoDot(onTap: () => onInfo(_sourceInfo), size: 15),
          ],
        ),
      ],
    );
  }

  Widget _workoutCard(EnergyWorkoutRow r) {
    final planned = r.planned;
    final mark = planned
        ? BurnMark.estimated
        : r.verified
            ? BurnMark.verified
            : BurnMark.selfReported;
    final status = planned
        ? 'planned (estimate)'
        : r.verified
            ? 'verified · Garmin · as planned'
            : 'self-reported · awaiting sync';
    return Opacity(
      opacity: planned ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: planned
              ? MeTokens.creamAlpha(0.02)
              : MeTokens.creamAlpha(0.04),
          border: Border.all(
            color:
                planned ? MeTokens.creamAlpha(0.08) : MeTokens.creamAlpha(0.1),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: planned ? Colors.transparent : MeTokens.electrolyte,
                    border: planned
                        ? Border.all(
                            color: MeTokens.electrolyteAlpha(0.45),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Icon(
                    _sportIcon(r.sport),
                    size: 16,
                    color: planned
                        ? MeTokens.electrolyteAlpha(0.7)
                        : MeTokens.blackberry,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Compadre',
                                fontSize: 16,
                                color: MeTokens.cream,
                              ),
                            ),
                          ),
                          if (planned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: MeTokens.creamAlpha(0.25),
                                ),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'PLANNED',
                                style: TextStyle(
                                  fontFamily: 'Apercu',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: MeTokens.creamAlpha(0.55),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.timeLabel} · ${r.metaLabel}',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 11,
                          color: MeTokens.creamAlpha(0.5),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onInfo(
                    _InfoContent(
                      title: r.name,
                      kcal: '${kcalStr(r.kcal)} kcal',
                      lines: [
                        ('Duration', r.metaLabel),
                        (
                          planned ? 'Est. calories' : 'Calories',
                          '${kcalStr(r.kcal)} kcal',
                        ),
                      ],
                      note: planned
                          ? 'An estimate from the planned session. The actual number replaces this once the workout is recorded.'
                          : null,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        kcalStr(r.kcal),
                        style: TextStyle(
                          fontFamily: 'Apercu Mono',
                          fontSize: 16,
                          color: planned
                              ? MeTokens.creamAlpha(0.6)
                              : MeTokens.cream,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 10,
                          color: MeTokens.creamAlpha(0.4),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 13,
                        color: MeTokens.creamAlpha(0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: MeTokens.creamAlpha(0.07)),
                ),
              ),
              child: Row(
                children: [
                  _Mark(mark, size: 9),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 11,
                        color: MeTokens.creamAlpha(0.62),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sportIcon(String sport) => switch (sport) {
        'swimming' => Icons.pool,
        'cycling' => Icons.directions_bike,
        'strength' => Icons.fitness_center,
        _ => Icons.directions_run,
      };

  Widget _legendItem(Widget mark, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10.5,
              color: MeTokens.creamAlpha(0.55),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Page 3 — Today's Fuel
// ---------------------------------------------------------------------------

class _TodaysFuelPage extends StatefulWidget {
  const _TodaysFuelPage({
    required this.energy,
    required this.breakdown,
    required this.onInfo,
  });

  final EnergyCardData energy;
  final BreakdownData breakdown;
  final ValueChanged<_InfoContent> onInfo;

  @override
  State<_TodaysFuelPage> createState() => _TodaysFuelPageState();
}

class _TodaysFuelPageState extends State<_TodaysFuelPage> {
  bool _weekly = false;
  bool _mealsOpen = false;

  static const _sourceInfo = _InfoContent(
    title: 'Self-reported',
    body:
        "Every meal here is logged by you — typed, searched, or barcode-scanned. Unlike workouts, food can't be device-measured, so the fuel side is always an estimate. Both sides of the ledger are estimates; neither is ground truth.",
  );

  @override
  Widget build(BuildContext context) {
    final energy = widget.energy;
    return _PageScaffold(
      title: "Today's Fuel",
      children: [
        // Daily / Weekly toggle
        Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: MeTokens.creamAlpha(0.08),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              _tab('Daily', !_weekly, () => setState(() => _weekly = false)),
              _tab('Weekly', _weekly, () => setState(() => _weekly = true)),
            ],
          ),
        ),
        if (!_weekly) ..._daily(energy) else ..._weeklyView(),
      ],
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? MeTokens.cream : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color:
                    active ? MeTokens.blackberry : MeTokens.creamAlpha(0.65),
              ),
            ),
          ),
        ),
      );

  List<Widget> _daily(EnergyCardData energy) {
    final bd = widget.breakdown;
    final pctOfTarget = energy.targetKcal > 0
        ? (energy.eatenKcal / energy.targetKcal * 100).round()
        : 0;
    final loggedMeals = bd.mealRows.where((m) => !m.planned).length;
    final plannedMeals = bd.mealRows.where((m) => m.planned).length;
    return [
      const SizedBox(height: 14),
      Center(
        child: Text(
          _clockLabel(bd.minutesSinceMidnight),
          style: _contextStyle(),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            kcalStr(energy.eatenKcal),
            style: const TextStyle(
              fontFamily: 'Sansita',
              fontWeight: FontWeight.w700,
              fontSize: 34,
              height: 1,
              color: MeTokens.cream,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ ${kcalStr(energy.targetKcal)} kcal',
            style: TextStyle(
              fontFamily: 'Sansita',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: MeTokens.creamAlpha(0.5),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Center(
        child: Text(
          '$pctOfTarget% of target · ${kcalStr(energy.remainingKcal.clamp(0, double.infinity))} to go',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 11.5,
            color: MeTokens.creamAlpha(0.45),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          _ring('Carbs', energy.carbEatenG, bd.plannedCarbsG,
              energy.carbTargetG, MeTokens.electrolyte),
          _ring('Protein', energy.proteinEatenG, bd.plannedProteinG,
              energy.proteinTargetG, MeTokens.proteinAccent),
          _ring('Fat', energy.fatEatenG, bd.plannedFatG, energy.fatTargetG,
              MeTokens.fatAccent),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 5,
        children: [
          _arcLegend(MeTokens.electrolyte, 'logged'),
          _arcLegend(MeTokens.electrolyteAlpha(0.32), '+ planned'),
        ],
      ),
      const SizedBox(height: 11),
      Center(
        child: GestureDetector(
          onTap: () => widget.onInfo(_sourceInfo),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined,
                  size: 12, color: MeTokens.creamAlpha(0.45)),
              const SizedBox(width: 5),
              Text(
                'All intake is self-reported — an estimate',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 11,
                  color: MeTokens.creamAlpha(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: MeTokens.creamAlpha(0.1))),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _mealsOpen = !_mealsOpen),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WHERE IT CAME FROM · '
                '$loggedMeals logged${plannedMeals > 0 ? ' + $plannedMeals planned' : ''}',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0.9,
                  color: MeTokens.creamAlpha(0.5),
                ),
              ),
              AnimatedRotation(
                turns: _mealsOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: MeTokens.creamAlpha(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_mealsOpen) ...[
        const SizedBox(height: 8),
        for (final m in widget.breakdown.mealRows) _mealRow(m),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Logged so far',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: MeTokens.cream,
                ),
              ),
              Text(
                '${kcalStr(energy.eatenKcal)} kcal',
                style: const TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: MeTokens.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _ring(
    String label,
    double consumed,
    double planned,
    double target,
    Color color,
  ) {
    final over = consumed > target;
    final left = over
        ? '+${(consumed - target).round()} g over'
        : '${(target - consumed).round()} g left';
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 98,
            height: 98,
            child: CustomPaint(
              painter: _RingPainter(
                loggedFraction:
                    target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0,
                plannedFraction: target > 0
                    ? ((consumed + planned) / target).clamp(0.0, 1.0)
                    : 0,
                color: color,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${consumed.round()}',
                            style: const TextStyle(
                              fontFamily: 'Sansita',
                              fontWeight: FontWeight.w700,
                              fontSize: 21,
                              height: 1,
                              color: MeTokens.cream,
                            ),
                          ),
                          TextSpan(
                            text: 'g',
                            style: TextStyle(
                              fontFamily: 'Apercu',
                              fontSize: 11,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${target.round()}',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 9.5,
                        color: MeTokens.creamAlpha(0.42),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 12,
                  color: MeTokens.creamAlpha(0.78),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            left,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10,
              color: over ? color : MeTokens.creamAlpha(0.45),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arcLegend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10.5,
              color: MeTokens.creamAlpha(0.55),
            ),
          ),
        ],
      );

  Widget _mealRow(BreakdownMealRow m) {
    return Opacity(
      opacity: m.planned ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: MeTokens.creamAlpha(0.06))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 14.5,
                            color: MeTokens.cream,
                          ),
                        ),
                      ),
                      if (m.planned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: MeTokens.creamAlpha(0.22)),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'PLANNED',
                            style: TextStyle(
                              fontFamily: 'Apercu',
                              fontWeight: FontWeight.w600,
                              fontSize: 8,
                              letterSpacing: 0.5,
                              color: MeTokens.creamAlpha(0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    m.timeLabel,
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 10.5,
                      color: MeTokens.creamAlpha(0.45),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: kcalStr(m.kcal),
                        style: TextStyle(
                          fontFamily: 'Apercu Mono',
                          fontSize: 13,
                          color: MeTokens.creamAlpha(0.9),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' kcal',
                        style: TextStyle(
                          fontFamily: 'Apercu Mono',
                          fontSize: 9,
                          color: MeTokens.creamAlpha(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Apercu Mono',
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(
                        text: '${m.carbsG.round()}',
                        style: const TextStyle(color: MeTokens.electrolyte),
                      ),
                      TextSpan(
                        text: ' · ',
                        style: TextStyle(color: MeTokens.creamAlpha(0.3)),
                      ),
                      TextSpan(
                        text: '${m.proteinG.round()}',
                        style: const TextStyle(color: MeTokens.proteinAccent),
                      ),
                      TextSpan(
                        text: ' · ',
                        style: TextStyle(color: MeTokens.creamAlpha(0.3)),
                      ),
                      TextSpan(
                        text: '${m.fatG.round()}',
                        style: const TextStyle(color: MeTokens.fatAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _weeklyView() {
    final bd = widget.breakdown;
    return [
      const SizedBox(height: 18),
      Text(
        'CARB PERIODIZATION',
        style: _sectionLabelStyle(),
      ),
      const SizedBox(height: 4),
      Text(
        'Carbs track training load — up on hard days, down on easy ones.',
        style: TextStyle(
          fontFamily: 'Apercu',
          fontSize: 12,
          height: 1.5,
          color: MeTokens.creamAlpha(0.6),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: MeTokens.creamAlpha(0.08)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyChartPainter(
                  carbs: bd.weeklyCarbTargets,
                  load: bd.weeklyLoad,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Text(
                    d,
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 10,
                      color: MeTokens.creamAlpha(0.4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: MeTokens.electrolyte,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Carbs (g)',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 12,
                        color: MeTokens.creamAlpha(0.7),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MeTokens.orangeAlpha(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Training load',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 12,
                        color: MeTokens.creamAlpha(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Carbs ramp into the week\'s hardest efforts, then ease on recovery '
        'days. Protein and fat hold steadier across the week.',
        style: TextStyle(
          fontFamily: 'Apercu',
          fontSize: 12,
          height: 1.5,
          color: MeTokens.creamAlpha(0.55),
        ),
      ),
    ];
  }
}

/// Two concentric progress arcs: logged (solid) over planned (light),
/// 9px stroke, round caps, starting at 12 o'clock.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.loggedFraction,
    required this.plannedFraction,
    required this.color,
  });

  final double loggedFraction;
  final double plannedFraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - 9) / 2 - 4,
    );
    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = c;

    canvas.drawArc(
      rect,
      0,
      6.28318,
      false,
      stroke(MeTokens.creamAlpha(0.1))..strokeCap = StrokeCap.butt,
    );
    const start = -1.5708; // 12 o'clock
    if (plannedFraction > 0) {
      canvas.drawArc(
        rect,
        start,
        6.28318 * plannedFraction,
        false,
        stroke(color.withValues(alpha: 0.32)),
      );
    }
    if (loggedFraction > 0) {
      canvas.drawArc(
        rect,
        start,
        6.28318 * loggedFraction,
        false,
        stroke(color),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.loggedFraction != loggedFraction ||
      oldDelegate.plannedFraction != plannedFraction ||
      oldDelegate.color != color;
}

/// The weekly carb-periodization chart: orange training-load bars behind a
/// smoothed electrolyte carb line with dots.
class _WeeklyChartPainter extends CustomPainter {
  const _WeeklyChartPainter({required this.carbs, required this.load});

  final List<double?> carbs;
  final List<double> load;

  @override
  void paint(Canvas canvas, Size size) {
    final n = carbs.length;
    if (n < 2) return;
    final slot = size.width / (n - 1);
    const barWidth = 20.0;

    // Load bars
    final barPaint = Paint()..color = MeTokens.orangeAlpha(0.16);
    for (var i = 0; i < load.length && i < n; i++) {
      final h = load[i].clamp(0.0, 1.0) * size.height;
      if (h <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * slot - barWidth / 2,
            size.height - h,
            barWidth,
            h,
          ),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }

    // Grid lines
    final grid = Paint()
      ..color = MeTokens.creamAlpha(0.07)
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        grid,
      );
    }

    // Carb line (smoothed) + dots
    final values = [for (final v in carbs) v ?? 0.0];
    final maxV =
        values.fold<double>(0, (m, v) => v > m ? v : m) * 1.1 + 0.001;
    Offset pt(int i) =>
        Offset(i * slot, size.height - (values[i] / maxV) * size.height);

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = MeTokens.electrolyte,
    );
    final dot = Paint()..color = MeTokens.electrolyte;
    for (var i = 0; i < n; i++) {
      if (carbs[i] == null) continue;
      canvas.drawCircle(pt(i), 2.8, dot);
    }
  }

  @override
  bool shouldRepaint(_WeeklyChartPainter oldDelegate) =>
      oldDelegate.carbs != carbs || oldDelegate.load != load;
}

// ---------------------------------------------------------------------------
// Info popover
// ---------------------------------------------------------------------------

class _InfoPopover extends StatelessWidget {
  const _InfoPopover({required this.info, required this.onClose});

  final _InfoContent info;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: const Color.fromRGBO(20, 8, 18, 0.5),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(28),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 312),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: _popoverBg,
                border: Border.all(color: MeTokens.creamAlpha(0.12)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.6),
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          info.title,
                          style: const TextStyle(
                            fontFamily: 'Sansita',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: MeTokens.cream,
                          ),
                        ),
                      ),
                      if (info.kcal != null)
                        Text(
                          info.kcal!,
                          style: const TextStyle(
                            fontFamily: 'Apercu Mono',
                            fontSize: 14,
                            color: MeTokens.electrolyte,
                          ),
                        ),
                    ],
                  ),
                  if (info.body != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      info.body!,
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 13.5,
                        height: 1.55,
                        color: MeTokens.creamAlpha(0.78),
                      ),
                    ),
                  ],
                  if (info.lines.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    for (final (k, v) in info.lines)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: MeTokens.creamAlpha(0.08)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              k,
                              style: TextStyle(
                                fontFamily: 'Apercu',
                                fontSize: 12.5,
                                color: MeTokens.creamAlpha(0.6),
                              ),
                            ),
                            Text(
                              v,
                              style: TextStyle(
                                fontFamily: 'Apercu Mono',
                                fontSize: 12.5,
                                color: MeTokens.creamAlpha(0.92),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (info.note != null) ...[
                    const SizedBox(height: 11),
                    Text(
                      info.note!,
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 11.5,
                        height: 1.5,
                        color: MeTokens.creamAlpha(0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MeTokens.orange,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: MeTokens.blackberry,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
