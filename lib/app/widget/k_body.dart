import 'package:flutter/cupertino.dart';

/// [BottomAppBar] 中定义的常量, 没有暴露出来
/// ```dart
/// final BottomAppBarThemeData defaults = isMaterial3
/// ? _BottomAppBarDefaultsM3(context) // 这里默认是80(_BottomAppBarDefaultsM3)
/// : _BottomAppBarDefaultsM2(context);
/// ```
double kDefaultAppBottomBarHeight = 80;

class KBody extends StatelessWidget {
  final Widget child;

  final EdgeInsets? padding;
  const KBody({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsetsGeometry.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child),
          SizedBox(height: kDefaultAppBottomBarHeight),
        ],
      ),
    );
  }
}
