import 'package:flutter/widgets.dart';

/// Corner radii — the web's (`--radius: 0.75rem`): cards `rounded-xl` 12,
/// buttons and fields `rounded-lg` 10.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius field = BorderRadius.all(Radius.circular(10));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}
