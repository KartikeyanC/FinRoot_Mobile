import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';

/// Centres its child and caps its width at [AppBreakpoints.contentMaxWidth] (or
/// [maxWidth]). A no-op on a phone, where the screen is already narrower than
/// the cap; on a wide tablet it keeps a single column readable instead of
/// letting text and forms stretch edge to edge.
class ContentBounds extends StatelessWidget {
  const ContentBounds({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
