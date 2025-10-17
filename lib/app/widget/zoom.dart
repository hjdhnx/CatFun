import 'package:bounce_tapper/bounce_tapper.dart';
import 'package:flutter/material.dart';

class HoverCursor extends StatelessWidget {
  const HoverCursor({
    super.key,
    required this.child,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
  });

  final Widget child;
  final HitTestBehavior hitTestBehavior;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      hitTestBehavior: hitTestBehavior,
      child: child,
    );
  }
}

class Zoom extends StatelessWidget {
  const Zoom({
    super.key,
    required this.child,
    this.onTap,
    this.scaleRatio = 0.965,
    this.highlightColor = Colors.transparent,
    this.hitTestBehavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleRatio;
  final Color highlightColor;
  final HitTestBehavior hitTestBehavior;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      hitTestBehavior: hitTestBehavior,
      child: BounceTapper(
        shrinkScaleFactor: scaleRatio,
        onTap: onTap,
        highlightColor: highlightColor,
        child: child,
      ),
    );
  }
}
