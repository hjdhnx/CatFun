import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum KPaginationActionButtonDirection {
  /// 左边
  l,

  /// 右边
  r
}

typedef KPaginationActionCallback = void Function(
  KPaginationActionButtonDirection type,
);

typedef KPaginationInputChangeCallback = void Function(
  int value,
);

class KPaginationActionButton extends StatelessWidget {
  KPaginationActionButton({
    super.key,
    this.direction = KPaginationActionButtonDirection.l,
    this.disable = false,
    required this.onTap,
  });

  final KPaginationActionButtonDirection direction;
  final bool disable;
  final VoidCallback onTap;

  bool get isLeft => direction == KPaginationActionButtonDirection.l;

  String get directionStr {
    if (isLeft) return "上一页";
    return "下一页";
  }

  double get boxOpacity {
    return disable ? .3 : 1;
  }

  final List<IconData> _icons = [
    CupertinoIcons.left_chevron,
    CupertinoIcons.right_chevron
  ];

  @override
  Widget build(BuildContext context) {
    Color borderColor = context.isDarkMode ? Colors.white : Colors.black;
    Color textColor = context.isDarkMode ? Colors.white : Colors.black;

    List<Widget> children = [
      Text(
        directionStr,
        style: TextStyle(
          fontSize: 9,
          color: textColor,
        ),
      ),
    ];
    int index = 0;
    if (!isLeft) index = 1;
    IconData icon = _icons[index];
    children.insert(
      index,
      Icon(
        icon,
        size: 15,
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: boxOpacity,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class KPagination extends StatefulWidget {
  final KPaginationActionCallback onActionTap;

  final bool turnL;

  final bool turnR;

  final VoidCallback onJumpTap;

  final TextEditingController textEditingController;

  const KPagination({
    super.key,
    required this.onActionTap,
    required this.onJumpTap,
    required this.textEditingController,
    this.turnL = true,
    this.turnR = true,
  });

  @override
  createState() => _KPaginationState();
}

class _KPaginationState extends State<KPagination> {
  TextEditingController get textEditingController =>
      widget.textEditingController;

  int get outputTextValue {
    var text = textEditingController.text;
    return int.parse(text);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              KPaginationActionButton(
                disable: !widget.turnL,
                onTap: () {
                  if (widget.turnL) {
                    widget.onActionTap(KPaginationActionButtonDirection.l);
                  }
                },
              ),
              const SizedBox(
                width: 6,
              ),
              KPaginationActionButton(
                disable: !widget.turnR,
                direction: KPaginationActionButtonDirection.r,
                onTap: () {
                  if (widget.turnR) {
                    widget.onActionTap(KPaginationActionButtonDirection.r);
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 66,
                child: CupertinoTextField(
                  controller: textEditingController,
                  textAlign: TextAlign.center,

                  /// 怕不是要上天, 一个分页给爷整个几千页?
                  maxLength: 4,

                  /// The content entered must be a number!!
                  /// link: https://stackoverflow.com/a/49578197
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  keyboardType: TextInputType.number,

                  padding: EdgeInsets.zero,
                  strutStyle: const StrutStyle(
                    forceStrutHeight: true,
                  ),
                  style: TextStyle(
                    color: context.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    widget.onJumpTap();
                  },
                  child: const Text(
                    "点击跳转",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
