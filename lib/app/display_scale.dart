import 'package:flutter/widgets.dart';

/// Draws the whole app at [scale] times its normal size while still filling
/// the screen: Settings → Appearance → Display size.
///
/// It works like Android's own Display size. The app lays out on a screen
/// that is `1 / scale` times as large, so at 0.8 it gets 25 % more room and
/// every page fits more, and the result is then drawn up to fill the real
/// screen. Text, icons, padding, sheets and dialogs all change together,
/// because they all sit inside this (it wraps the router, and so the
/// navigator's overlay). Taps go through the same transform.
///
/// Text scaling alone ([MediaQueryData.textScaler]) would grow the words but
/// not the rows and icons around them, which breaks layouts and is not what
/// the setting promises.
class DisplayScale extends StatelessWidget {
  const DisplayScale({super.key, required this.scale, required this.child});

  /// 1.0 is normal size. Below 1 is smaller, above 1 is larger.
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The same widgets at every size, 100 % included. Returning [child] bare
    // at 1.0 would change the tree's shape on the way to or from 100 %, and
    // Flutter would rebuild the navigator from scratch: the person adjusting
    // the setting would be thrown off the Settings page.
    final s = scale > 0 ? scale : 1.0;
    final mq = MediaQuery.of(context);
    final logical = mq.size / s;
    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        // Keeps images and text sharp: each logical pixel now covers more
        // (or fewer) physical pixels.
        devicePixelRatio: mq.devicePixelRatio * s,
        // Status bar, gesture bar and keyboard, in the scaled coordinates.
        padding: mq.padding / s,
        viewPadding: mq.viewPadding / s,
        viewInsets: mq.viewInsets / s,
        systemGestureInsets: mq.systemGestureInsets / s,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: logical, child: child),
      ),
    );
  }
}
