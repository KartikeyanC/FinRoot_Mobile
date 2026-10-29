import 'package:flutter/widgets.dart';

/// Corner radii — restyle spec "Shape": 12 for inputs and menu items, 16 for
/// inner/icon tiles, 20 for every card and dialog, 24 for the top of bottom
/// sheets, and fully round for buttons, pills, tabs and segmented controls.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12; // radius-md: inputs, selects, menu items
  static const double md = 16; // radius-lg: inner tiles, icon tiles
  static const double lg = 20; // radius-card: cards, dialogs, menus
  static const double xl = 24; // radius-sheet: bottom-sheet top corners
  static const double pill = 999; // radius-full

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius tile = BorderRadius.all(Radius.circular(md));
  static const BorderRadius field = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}
