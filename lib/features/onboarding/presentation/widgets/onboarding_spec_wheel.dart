import 'package:flutter/material.dart';
import '../theme/onboarding_design_tokens.dart';

/// Inline value wheel from the HTML spec (personal-info birth year, body
/// composition ft/in/weight): selected row in Sansita 700 cream between two
/// 1px orange-40% hairlines, neighbors in Apercu cream-40%.
///
/// Spec sizes: birth year 27/21 px, body-composition wheels 25/20 px.
class OnboardingSpecWheel extends StatelessWidget {
  const OnboardingSpecWheel({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.labelFor,
    required this.selectedIndex,
    required this.onChanged,
    this.centerFontSize = 27,
    this.adjacentFontSize = 21,
    this.height = 132,
    this.itemExtent = 44,
    this.hairlineInset = 22,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelFor;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double centerFontSize;
  final double adjacentFontSize;
  final double height;
  final double itemExtent;
  final double hairlineInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: itemExtent,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 8,
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final selected = index == selectedIndex;
                return Center(
                  child: Text(
                    labelFor(index),
                    style: selected
                        ? TextStyle(
                            fontFamily: OnbTokens.fontDisplay,
                            fontSize: centerFontSize,
                            fontWeight: FontWeight.w700,
                            color: OnbTokens.cream,
                          )
                        : TextStyle(
                            fontFamily: OnbTokens.fontBody,
                            fontSize: adjacentFontSize,
                            color: OnbTokens.creamA(0.4),
                          ),
                  ),
                );
              },
            ),
          ),
          // Hairlines framing the selected row (1px orange-40%).
          IgnorePointer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: hairlineInset),
                  color: OnbTokens.orange40,
                ),
                SizedBox(height: itemExtent - 1),
                Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: hairlineInset),
                  color: OnbTokens.orange40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
