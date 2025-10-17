import 'dart:async';
import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:catmovie/app/extension.dart';
import 'package:catmovie/app/widget/zoom.dart';
import 'package:catmovie/utils/boop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:get/get.dart';
import 'package:catmovie/app/modules/home/controllers/home_controller.dart';
import 'package:catmovie/app/modules/home/views/mirror_check.dart';
import 'package:catmovie/app/shared/mirror_status_stack.dart';
import 'package:catmovie/shared/manage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xi/xi.dart';

enum MenuActionType {
  /// 检测源
  check,

  /// 删除不可用源
  deleteUnavailable,

  /// 导出
  export,
}

class ItemModel {
  String title;
  IconData icon;
  MenuActionType action;

  ItemModel(
    this.title,
    this.icon,
    this.action,
  );
}

class MirrorTableView extends StatefulWidget {
  const MirrorTableView({super.key});

  @override
  createState() => _MirrorTableViewState();
}

class _MirrorTableViewState extends State<MirrorTableView>
    with AfterLayoutMixin {
  final HomeController home = Get.find<HomeController>();

  List<ISpiderAdapter> get _mirrorList {
    return home.mirrorList;
  }

  List<ISpiderAdapter> mirrorList = [];

  ScrollController scrollController = ScrollController(
    initialScrollOffset: 0,
    keepScrollOffset: true,
  );

  double get cacheMirrorTableScrollControllerOffset {
    return home.cacheMirrorTableScrollControllerOffset;
  }

  void updateCacheMirrorTableScrollControllerOffset() {
    if (cacheMirrorTableScrollControllerOffset <= 0) return;

    if (mounted &&
        scrollController.hasClients &&
        scrollController.position.hasContentDimensions &&
        scrollController.position.maxScrollExtent > 0) {
      double targetOffset = cacheMirrorTableScrollControllerOffset;
      double maxOffset = scrollController.position.maxScrollExtent;

      if (targetOffset > maxOffset) {
        targetOffset = maxOffset;
      }

      scrollController.jumpTo(targetOffset);
    }
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    updateCacheMirrorTableScrollControllerOffset();
  }

  @override
  void initState() {
    super.initState();

    mirrorList = _mirrorList;
    updateMirrorStatusMap();

    scrollController.addListener(() {
      double offset = scrollController.offset;
      home.updateCacheMirrorTableScrollControllerOffset(offset);
    });
  }

  @override
  void didUpdateWidget(MirrorTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mirrorList != _mirrorList) {
      setState(() {
        mirrorList = _mirrorList;
      });
    }
  }

  void updateMirrorStatusMap() {
    __statusMap = MirrorStatusStack().getStacks;
    setState(() {});
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Map<String, bool> __statusMap = {};

  int get mirrorGridCount {
    double screenWidth = MediaQuery.of(context).size.width;
    double minCardWidth = 160;
    double spacing = 12;
    int count = ((screenWidth + spacing) / (minCardWidth + spacing)).floor();
    count = count.clamp(2, 6);
    return count;
  }

  Future<void> handleClickSubMenu(MenuActionType action) async {
    switch (action) {
      case MenuActionType.check:
        XHttp.setTimeout(24, 24);
        bool? checkCanDone = await showCupertinoDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            var refData = home.mirrorList;
            return MirrorCheckView(
              list: refData,
            );
          },
        );
        XHttp.setDefaultTImeout();
        if (checkCanDone ?? false) {
          updateMirrorStatusMap();
        }
        break;
      case MenuActionType.deleteUnavailable:
        bool status = await showDelUnavailableMirrorDialog();
        if (!status) return;
        List<String> result = SpiderManage.removeUnavailable(
          __statusMap,
        );
        setState(() {
          mirrorList.removeWhere((element) => result.contains(element.meta.id));
        });
        if (result.isNotEmpty) {
          home.updateMirrorIndex(0);
        }
        break;
      case MenuActionType.export:
        String append = SpiderManage.export(
          full: home.isNsfw,
        );

        DateTime today = DateTime.now();
        String dateSlug =
            "${today.year.toString()}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}";

        String filename = "YY$dateSlug.json";
        if (GetPlatform.isIOS) {
          Directory directory = await getTemporaryDirectory();
          String path = '${directory.path}/$filename';
          File file = File(path);
          await file.writeAsString(append);
          SharePlus.instance.share(ShareParams(files: [XFile(path)]));
        } else if (GetPlatform.isDesktop) {
          Directory? directory = await getDownloadsDirectory();
          if (directory == null) return;
          String? path = await FilePicker.platform.saveFile(
            initialDirectory: directory.path,
            fileName: filename,
          );
          if (path == null) return;
          File file = File(path);
          file.existsSync();
          file.writeAsStringSync(append);
        }
        break;
    }
  }

  Future<bool> showDelUnavailableMirrorDialog() async {
    var completer = Completer<bool>();
    showCupertinoDialog(
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('确定要删除所有失效源吗？'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text(
              '取消',
              style: TextStyle(
                color: Colors.blue,
              ),
            ),
            onPressed: () {
              Get.back();
              completer.complete(false);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Get.back();
              completer.complete(true);
            },
            child: const Text(
              '确定',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          )
        ],
      ),
      context: Get.context as BuildContext,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.mediaQuery.size.height * .72,
      child: Column(
        spacing: 0,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? Colors.blue.shade700.withValues(alpha: .3)
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.cube_box,
                        size: 24,
                        color: context.isDarkMode
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "源管理",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.isDarkMode
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          "${_mirrorList.length} 个数据源",
                          style: TextStyle(
                            fontSize: 12,
                            color: context.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  spacing: 12,
                  children: [
                    PullDownButton(
                      itemBuilder: (BuildContext context) {
                        return [
                          PullDownMenuItem(
                            onTap: () {
                              handleClickSubMenu(MenuActionType.check);
                              boop.selection();
                            },
                            title: '批量检测源',
                            icon: Icons.assignment,
                          ),
                          PullDownMenuItem(
                            title: '导出源',
                            onTap: () {
                              // handleClickSubMenu(MenuActionType.export);
                              // boop.selection();
                            },
                            icon: CupertinoIcons.arrowshape_turn_up_right,
                          ),
                          PullDownMenuItem(
                            onTap: () {
                              // handleClickSubMenu(
                              //     MenuActionType.deleteUnavailable);
                              // boop.selection();
                            },
                            title: '一键删除失效源',
                            isDestructive: true,
                            icon: CupertinoIcons.delete,
                          ),
                        ];
                      },
                      buttonBuilder: (BuildContext context, showMenu) {
                        return Zoom(
                          onTap: showMenu,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.isDarkMode
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.ellipsis,
                              size: 18,
                              color: context.isDarkMode
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        );
                      },
                    ),
                    Zoom(
                      onTap: () {
                        EasyLoading.dismiss();
                        Navigator.pop(context);
                      },
                      child: Container(
                              padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.isDarkMode
                              ? Colors.red.shade700.withValues(alpha: .2)
                              : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                            Icons.close,
                            size: 18,
                            color: context.isDarkMode
                                ? Colors.red.shade300
                                : Colors.red.shade600,
                          ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
              child: SizedBox(
                width: double.infinity,
                child: Scrollbar(
                  controller: scrollController,
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: mirrorGridCount,
                      mainAxisExtent: 88,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: mirrorList.length,
                    itemBuilder: (_, index) {
                      var e = mirrorList[index];
                      return MirrorCard(
                        item: e,
                        current: home.currentMirrorItem == e,
                        onTap: () {
                          var index = mirrorList.indexOf(e);
                          home.updateMirrorIndex(index);
                          Get.back();
                          boop.selection();
                        },
                        hashTable: __statusMap,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MirrorCard extends StatelessWidget {
  const MirrorCard({
    super.key,
    required this.item,
    this.current = false,
    required this.onTap,
    required this.hashTable,
  });

  final ISpiderAdapter item;

  final bool current;

  final VoidCallback onTap;

  final Map<String, bool> hashTable;

  String get _title => item.meta.name;

  String get _desc => item.meta.desc;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = current
        ? (context.isDarkMode ? "#f1f1f1" : "#1a237e").$color
        : (context.isDarkMode ? '#272727' : "#e2e8f0").$color;

    Color textColor = current
        ? (context.isDarkMode ? Colors.black : Colors.white)
        : (context.isDarkMode ? Colors.white : Colors.black);

    return Zoom(
      scaleRatio: .99,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: current
              ? LinearGradient(
                  colors: context.isDarkMode
                      ? [Colors.grey.shade100, Colors.grey.shade200]
                      : [Colors.indigo.shade700, Colors.purple.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: current ? null : backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: current
              ? [
                  BoxShadow(
                    color: (context.isDarkMode ? Colors.grey : Colors.indigo)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  current ? Icons.done : CupertinoIcons.right_chevron,
                  color: textColor,
                  size: 16,
                ),
              ],
            ),
            if (_desc.isNotEmpty)
              Text(
                _desc,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  decoration: TextDecoration.none,
                  fontWeight: current ? FontWeight.bold : FontWeight.w300,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Builder(builder: (context) {
              var status = item.meta.status
                  ? MovieStatusType.available
                  : MovieStatusType.unavailable;
              var cacheStatus = hashTable[item.meta.id] ?? true;
              return MovieStatusWidget(
                status: status,
                cacheStatus: cacheStatus,
              );
            }),
            Builder(builder: (context) {
              var gfw = item.meta.extra['gfw'];
              var _type = item.meta.type;
              var status = item.meta.status
                  ? MovieStatusType.available
                  : MovieStatusType.unavailable;
              var cacheStatus = hashTable[item.meta.id] ?? true;

              bool isAvailable =
                  status == MovieStatusType.available && cacheStatus;

              var list = [
                _type == SourceType.maccms ? "VOD" : "JS",
                if (gfw is bool) gfw ? "直连" : "翻墙",
              ];
              return Row(
                spacing: 6,
                children: list.asMap().entries.map((entry) {
                  int index = entry.key;
                  String item = entry.value;

                  Color backgroundColor;
                  Color textColor;
                  BoxDecoration decoration;

                  if (isAvailable) {
                    textColor = Colors.white;
                    if (index == 0) {
                      backgroundColor = item == "VOD"
                          ? Colors.blue.shade600
                          : Colors.purple.shade600;
                    } else {
                      backgroundColor = item == "直连"
                          ? Colors.green.shade600
                          : Colors.orange.shade600;
                    }
                    decoration = BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: backgroundColor.withValues(alpha: .3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    );
                  } else {
                    textColor = Colors.grey.shade600;
                    decoration = BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    );
                  }

                  return Opacity(
                    opacity: isAvailable ? 1.0 : 0.6,
                    child: Container(
                      decoration: decoration,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                          fontWeight:
                              isAvailable ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

enum MovieStatusType {
  /// 可用
  available,

  /// 不可用
  unavailable,
}

extension MovieStatusTypeExtension on MovieStatusType {
  String get text {
    switch (this) {
      case MovieStatusType.available:
        return '可用';
      case MovieStatusType.unavailable:
        return '上次不可用';
    }
  }
}

class MovieStatusWidget extends StatelessWidget {
  const MovieStatusWidget({
    super.key,
    this.status = MovieStatusType.available,
    required this.cacheStatus,
  });

  final MovieStatusType status;
  final bool cacheStatus;
  String get _text {
    return _type.text;
  }

  Color get _color {
    switch (_type) {
      case MovieStatusType.available:
        return Colors.green;
      case MovieStatusType.unavailable:
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  MovieStatusType get _type {
    return cacheStatus
        ? MovieStatusType.available
        : MovieStatusType.unavailable;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _color,
          ),
        ),
        Text(
          _text,
          style: TextStyle(
            color: _color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class PopMenuBox extends StatefulWidget {
  const PopMenuBox({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<ItemModel> items;

  final ValueChanged<MenuActionType> onTap;

  @override
  State<PopMenuBox> createState() => _PopMenuBoxState();
}

class _PopMenuBoxState extends State<PopMenuBox> {
  ItemModel? _hoverPopMenuItem;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: const Color(0xFF4C4C4C),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.items
                .map(
                  (item) => InkWell(
                    onTap: () {
                      widget.onTap(item.action);
                    },
                    onHover: (isHover) {
                      _hoverPopMenuItem = isHover ? item : null;
                      setState(() {});
                    },
                    onTapDown: (_) {
                      _hoverPopMenuItem = item;
                      setState(() {});
                    },
                    onTapCancel: () {
                      _hoverPopMenuItem = null;
                      setState(() {});
                    },
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _hoverPopMenuItem?.title == item.title
                            ? Colors.blue
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            item.icon,
                            size: 15,
                            color: Colors.white,
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(
                                left: 10,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
