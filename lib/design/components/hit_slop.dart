import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../tokens/app_spacing.dart';

/// Grows the tappable area of [child] to at least [minSize] (48dp) on each
/// axis without changing its layout or how it looks.
///
/// A touch that lands in the extra band is handed to [child] at the nearest
/// point on its edge, so a 40dp round button answers a 48dp tap. With
/// [expandSemantics] the accessibility node is reported at the larger size
/// too (use it on a single control, not on a row of them).
///
/// The band only works where the ancestors' own bounds reach it; wrap a tight
/// row in a [HitSlop] as well (as [AppPage]'s title row does) so the band
/// above and below its buttons is not cut off by the row.
class HitSlop extends SingleChildRenderObjectWidget {
  const HitSlop({
    super.key,
    this.minSize = AppSpacing.minTouchTarget,
    this.expandSemantics = false,
    this.margin,
    required Widget super.child,
  });

  final double minSize;
  final bool expandSemantics;

  /// A fixed band around [child] instead of "grow to [minSize]": for a row of
  /// controls whose own bounds would cut their bands off.
  final EdgeInsets? margin;

  @override
  RenderHitSlop createRenderObject(BuildContext context) =>
      RenderHitSlop(minSize, expandSemantics, margin);

  @override
  void updateRenderObject(BuildContext context, RenderHitSlop renderObject) {
    renderObject
      ..minSize = minSize
      ..expandSemantics = expandSemantics
      ..margin = margin;
  }
}

class RenderHitSlop extends RenderProxyBox {
  RenderHitSlop(this._minSize, this._expandSemantics, [this._margin]);

  EdgeInsets? _margin;
  set margin(EdgeInsets? v) {
    if (v == _margin) return;
    _margin = v;
    markNeedsSemanticsUpdate();
  }

  double _minSize;
  set minSize(double v) {
    if (v == _minSize) return;
    _minSize = v;
    markNeedsSemanticsUpdate();
  }

  bool _expandSemantics;
  set expandSemantics(bool v) {
    if (v == _expandSemantics) return;
    _expandSemantics = v;
    markNeedsSemanticsUpdate();
  }

  Rect get _slopRect {
    final m = _margin;
    if (m != null) return m.inflateRect(Offset.zero & size);
    final dx = math.max(0.0, (_minSize - size.width) / 2);
    final dy = math.max(0.0, (_minSize - size.height) / 2);
    return Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null || size.isEmpty) return false;
    if (size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    if (!_slopRect.contains(position)) return false;
    const eps = 0.01;
    final inside = Offset(
      position.dx.clamp(0.0, size.width - eps),
      position.dy.clamp(0.0, size.height - eps),
    );
    if (c.hitTest(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  Rect get semanticBounds =>
      _expandSemantics ? _slopRect : super.semanticBounds;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_expandSemantics) config.isSemanticBoundary = true;
  }
}
