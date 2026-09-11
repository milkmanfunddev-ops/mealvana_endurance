import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_materials.dart';
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
  builder: (context) =>
      GlassSheetSurface(child: SafeArea(top: false, child: builder(context))),
);
