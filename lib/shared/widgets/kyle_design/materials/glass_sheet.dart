/// The summoned `glass-sheet` (`docs/ssot/spec/design/tokens.md` §Materials),
/// as a call ([showGlassSheet]) and as a router page ([GlassSheetPage]).
///
/// Spec for the page form: `docs/ssot/spec/design/components/glass-sheet.md`
/// **v1** (PROPOSED Lee 2026-09-22, authored app-side, awaiting Xuan). Both
/// forms rise on the same route (Material's modal bottom sheet), so a screen
/// the router opens as a sheet enters exactly like a sheet a widget summons.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_theme.dart';
import '../navigation/slide_over_pager.dart';
import 'glass.dart';

/// Summons a sheet on the ratified `glass-sheet` recipe
/// (`docs/ssot/spec/design/tokens.md` §Materials): the standard scrim between
/// the page and the sheet, a transparent route background so nothing but the
/// glass is painted, and [GlassSheetSurface] under a bottom-only [SafeArea].
///
/// The recipe used to be re-assembled by hand at every call site, and a
/// caller that forgot the scrim or the transparent background got a sheet
/// that looked nearly right. [builder] draws only the content; its padding is
/// the caller's.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  barrierColor: AppMaterials.sheetScrim,
  backgroundColor: Colors.transparent,
  builder: (context) => _body(builder(context)),
);

Widget _body(Widget child) =>
    GlassSheetSurface(child: SafeArea(top: false, child: child));

/// A router page presented as a full-height glass sheet over the page under
/// it (GS-1..GS-5 in the spec).
///
/// * **GS-1** — the same entrance as [showGlassSheet]: it rises from the
///   bottom edge over the `glass-sheet` scrim, on Material's modal bottom
///   sheet route.
/// * **GS-2** — full height below the status bar; the page under it stays
///   in place, dimmed and blurred, and is what a close returns to.
/// * **GS-3** — closable three ways, all one pop: a tap on the scrim, a drag
///   down, or the content's own close (which pops the route).
/// * **GS-4** — dark-first: the content renders in the dark theme whatever
///   the app's theme, as the tokens define the glass for the `blackberry`
///   ground only.
/// * **GS-5** — Reduce Motion: the sheet is there on the next frame, no rise.
class GlassSheetPage<T> extends Page<T> {
  const GlassSheetPage({
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    required this.child,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    final reduceMotion = SlideOverPager.reduceMotionOf(context);
    return ModalBottomSheetRoute<T>(
      settings: this,
      isScrollControlled: true,
      useSafeArea: true,
      modalBarrierColor: AppMaterials.sheetScrim,
      backgroundColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(context).scrimLabel,
      barrierOnTapHint: MaterialLocalizations.of(
        context,
      ).scrimOnTapHint(MaterialLocalizations.of(context).bottomSheetLabel),
      sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
      builder: (context) => Theme(
        data: AppTheme.darkTheme,
        child: _body(SizedBox.expand(child: child)),
      ),
    );
  }
}
