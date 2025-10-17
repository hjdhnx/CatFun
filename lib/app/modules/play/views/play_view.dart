import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:after_layout/after_layout.dart';
import 'package:aurora/aurora.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:catmovie/app/extension.dart';
import 'package:catmovie/app/modules/home/views/tv.dart';
import 'package:catmovie/app/modules/play/controllers/play_controller.dart';
import 'package:catmovie/app/modules/play/views/cast_screen.dart';
import 'package:catmovie/app/widget/zoom.dart';
import 'package:catmovie/isar/schema/video_history_schema.dart';
import 'package:catmovie/shared/enum.dart';
import 'package:catmovie/shared/env.dart';
import 'package:catmovie/utils/boop.dart';
import 'package:clipboard/clipboard.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:catmovie/app/modules/home/controllers/home_controller.dart';
import 'package:catmovie/app/modules/home/views/parse_vip_manage.dart';
import 'package:catmovie/app/widget/window_appbar.dart';
import 'package:catmovie/widget/simple_html/flutter_html.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:isar_community/isar.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:simple/x.dart';
import 'package:tuple/tuple.dart';
import 'package:xi/xi.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;

enum PlaylistSort { down, up }

List<String> kDescEmptyList = [
  "暂无简介",
  "无简介",
];

extension PlaylistSortExt on PlaylistSort {
  String get name {
    if (this == PlaylistSort.down) return "正序";
    return "倒序";
  }

  IconData get icon {
    if (this == PlaylistSort.down) return CupertinoIcons.sort_down;
    return CupertinoIcons.sort_up;
  }
}

class PlayState extends Equatable {
  const PlayState(this.tabIndex, this.index);
  final int tabIndex;
  final int index;

  @override
  List<Object?> get props => [tabIndex, index];
}

PlayState kEmptyPlayState = const PlayState(-1, -1);

class PlayView extends StatefulWidget {
  const PlayView({super.key});

  @override
  State<PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<PlayView> with AfterLayoutMixin {
  final PlayController play = Get.find<PlayController>();
  final HomeController home = Get.find<HomeController>();
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  Player? player;
  late VideoController controller;

  VideoKernel videoKernel = VideoKernel.webview;

  bool get canBeShowParseVipButton {
    return home.parseVipList.isNotEmpty;
  }

  double get screenHeight {
    var ret = MediaQuery.of(context).size.height;
    return ret;
  }

  List<Videos> playlist = [];

  final double offsetSize = 12;
  final coverHeightScale = .48;

  PlaylistSort playlistSort = PlaylistSort.down;

  BoxFit mediaKitFit = kVideoFits.keys.first;

  bool get playlistIsEmpty {
    bool allEmpty = playlist.length == 1 && playlist[0].datas.isEmpty;
    return playlist.isEmpty || allEmpty;
  }

  int get playListGridCount {
    double screenWidth = context.mediaQuery.size.width;
    double minCardWidth = 188;
    double spacing = 5;
    int count = ((screenWidth + spacing) / (minCardWidth + spacing)).floor();
    count = count.clamp(1, 6);
    return count;
  }

  int get _bufferSize {
    var mb = 125; // 125MB
    if (GetPlatform.isDesktop) {
      mb = 1024; // 1GB
    }
    return mb * 1024 * 1024;
  }

  Future<String> _tempPath() async {
    var dir = await getTemporaryDirectory();
    return path.join(dir.path, "video_cache");
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    focusNode.requestFocus();
    videoKernel = getSettingAsKeyIdent<VideoKernel>(SettingsAllKey.videoKernel);
    if (videoKernel.isMediaKit) {
      MPVLogLevel logLevel = MPVLogLevel.info;
      if (CMEnv.isDebug) {
        debugPrint("video log level is debug");
        logLevel = MPVLogLevel.debug;
      }
      player = Player(
        configuration: PlayerConfiguration(
          bufferSize: _bufferSize,
          osc: false,
          logLevel: logLevel,
        ),
      );
      controller = VideoController(player!, onSpeedUpChanged: (flag) {
        if (flag) {
          boop.call(HapticsType.medium);
        }
      });
      if (player!.platform is NativePlayer) {
        var pp = player!.platform as NativePlayer;
        var temp = await _tempPath();
        debugPrint("video cache dir is $temp");
        pp.setProperty("demuxer-cache-dir", temp);
      }
    }
    playlist = play.movieItem.videos;
    loadHistory();
    if (mounted) setState(() {});
  }

  void loadHistory() {
    var item = play.movieItem;
    var cx = item.getContext()!;
    play.historyContext = videoHistoryAs
        .filter()
        .isNsfwEqualTo(home.isNsfw)
        .sidEqualTo(cx.id)
        .ctx((cx) {
      return cx.detailIDEqualTo(item.id);
    }).findFirstSync();
    if (play.historyContext == null) return;
    var tabIndex = play.historyContext!.ctx.pTabIndex;
    var index = play.historyContext!.ctx.pIndex;
    debugPrint("load history t: $tabIndex, i: $index");
    if (tabIndex <= -1 || index <= -1) return;
    if (videoKernel.isMediaKit) {
      handlePlay(tabIndex, index);
    }
  }

  @override
  void dispose() {
    player?.dispose().catchError((error) {
      debugPrint("player dispose error: $error");
    });
    super.dispose();
  }

  // NOTE(d1y): 是否显示封面(只在未播放过时展示)
  var showVideoCover = true;

  Future<void> handlePlay(int tabIndex, int index) async {
    var realPlaylist = playlist[tabIndex].datas;
    var curr = playlist[tabIndex].datas[index];
    var isUpSort = playlistSort == PlaylistSort.up;
    var isOk = await play.handleTapPlayerButtom(
      curr,
      realPlaylist,
      tabIndex,
      videoKernel,
      player,
      isUpSort,
      play.movieItem,
    );
    if (!isOk) {
      boop.error();
      return;
    }
    boop.success();
    var realIndex = index;
    if (isUpSort) {
      realIndex = getReversalIndex(realPlaylist, index);
    }
    showVideoCover = false;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 124), () {
      play.updatePlayState(tabIndex, index, realIndex, curr.name);
    });
  }

  void handleSortPlaylist() {
    if (playlistSort == PlaylistSort.down) {
      playlistSort = PlaylistSort.up;
    } else {
      playlistSort = PlaylistSort.down;
    }
    playlist.asMap().forEach((idx, item) {
      playlist[idx].datas = item.datas.reversed.toList();
    });
    var idx = getReversalIndex(playlist[0].datas, play.playState.index);
    // play.playState = kEmptyPlayState;
    play.playState = PlayState(play.playState.tabIndex, idx);
    play.update();
    EasyLoading.showToast(
      "切换到${playlistSort.name}",
      toastPosition: EasyLoadingToastPosition.bottom,
    );
    setState(() {});
  }

  Widget _buildCoverImage() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: play.movieItem.smallCoverImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child:
                          Container(color: Colors.white.withValues(alpha: .12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: play.movieItem.smallCoverImage,
              fit: BoxFit.contain,
            ),
          )
        ],
      ),
    );
  }

  double lastScrollOffset = 0;

  void showMediaKitPlaylist() {
    var fw = context.mediaQuery.size.width;
    var w = fw * .32;
    if (w >= 320) w = 320;
    var list = playlist[play.tabIndex].datas;
    Get.dialog(
      useSafeArea: false,
      MediaKitPlaylist(
        width: w,
        list: list,
        sort: playlistSort,
        index: play.playState.index,
        restoreOffset: lastScrollOffset,
        onScroll: (offset) {
          lastScrollOffset = offset;
        },
        onTap: (index) {
          handlePlay(play.tabIndex, index);
          Get.back();
        },
        onSortTap: () {
          handleSortPlaylist();
        },
      ),
    );
  }

  Widget _buildMediaKit() {
    Widget boxFitView = MaterialDesktopCustomButton(
      onPressed: () {
        List<BoxFit> fits = kVideoFits.keys.toList();
        int idx = fits.indexOf(mediaKitFit);
        idx = (idx + 1) % fits.length;
        mediaKitFit = fits[idx];
        setState(() {});
        var msg = "切换到${kVideoFits[mediaKitFit] ?? '未知模式'}";
        EasyLoading.showToast(
          msg,
          toastPosition: EasyLoadingToastPosition.bottom,
        );
      },
      icon: Opacity(
        opacity: .88,
        child: const Icon(Icons.aspect_ratio, size: 23),
      ),
    );
    Widget videoView = Video(
      fit: mediaKitFit,
      fill: Colors.black,
      placeholder: showVideoCover ? _buildCoverImage() : null,
      controller: controller,
      onEnterFullscreen: () async {
        await defaultEnterNativeFullscreen();
        // workaround: 在 iOS 上全屏之后播放会暂停
        if (GetPlatform.isIOS) {
          Future.delayed(const Duration(milliseconds: 88), () {
            controller.player.pause();
            controller.player.play();
          });
        }
      },
      onExitFullscreen: () async {
        await defaultExitNativeFullscreen();
        if (GetPlatform.isIOS) {
          SystemChrome.setPreferredOrientations(
            [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
          );
        }
      },
    );
    var topButtonBar = [
      CupertinoNavigationBarBackButton(
        color: Colors.white,
        previousPageTitle: "返回",
      ),
      const Spacer(),
      MaterialDesktopCustomButton(
        onPressed: showMediaKitPlaylist,
        icon: Row(
          spacing: 6,
          children: [
            Icon(CupertinoIcons.ellipsis_circle_fill),
            Text("播放列表", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ];
    if (GetPlatform.isDesktop) {
      var bottomButtonBar = [
        MaterialDesktopSkipPreviousButton(),
        MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopSkipNextButton(),
        MaterialDesktopVolumeButton(),
        MaterialDesktopPositionIndicator(),
        Spacer(),
        boxFitView,
        MaterialDesktopFullscreenButton(),
      ];
      videoView = MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          bottomButtonBar: bottomButtonBar,
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          topButtonBar: topButtonBar,
          bottomButtonBar: bottomButtonBar,
          // TODO(d1y): add playlist shortcut
          keyboardShortcuts: {
            // // cmd-s
            // const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            //     showMediaKitPlaylist,
            // // cmd-t
            // const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            //     showMediaKitPlaylist,
          },
        ),
        child: videoView,
      );
    } else {
      var bottomButtonBar = [
        MaterialPositionIndicator(),
        Spacer(),
        boxFitView,
        MaterialFullscreenButton(),
      ];
      videoView = MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          seekBarMargin: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          bottomButtonBarMargin: EdgeInsets.symmetric(
            vertical: 24,
            horizontal: 12,
          ),
          seekGesture: true,
          seekOnDoubleTap: true,
          speedUpOnLongPress: true,
          bottomButtonBar: bottomButtonBar,
        ),
        fullscreen: MaterialVideoControlsThemeData(
          seekBarMargin: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          bottomButtonBarMargin: EdgeInsets.symmetric(
            vertical: 24,
            horizontal: 12,
          ),
          brightnessGesture: true,
          volumeGesture: true,
          seekGesture: true,
          seekOnDoubleTap: true,
          speedUpOnLongPress: true,
          topButtonBar: topButtonBar,
          bottomButtonBar: bottomButtonBar,
        ),
        child: videoView,
      );
    }
    return Positioned.fill(child: videoView);
  }

  Widget _oneView(bool isLargeScreen) {
    return Stack(
      children: [
        if (videoKernel.isMediaKit)
          _buildMediaKit()
        else
          Positioned.fill(child: _buildCoverImage()),
      ],
    );
  }

  Widget _twoView(bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWithDesc,
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ).copyWith(top: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "播放列表",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!playlistIsEmpty &&
                      playlist[play.tabIndex].datas.length >= 2)
                    IconButton(
                      tooltip: playlistSort.name,
                      onPressed: handleSortPlaylist,
                      icon: Transform.rotate(
                        angle: playlistSort == PlaylistSort.up ? math.pi : 0,
                        child: SvgPicture.string(
                          r"""
                      <svg t="1758649652025" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="8688" width="200" height="200"><path d="M301.696 164.544c-27.776 0-51.2 24-54.464 55.808l-0.384 7.424v452.416L175.872 598.528c-20.48-23.488-53.312-24.64-75.008-2.624-21.696 22.016-24.832 59.712-7.104 86.08l4.544 5.888 164.608 189.632c1.536 1.792 3.2 3.456 4.928 5.056l-4.928-5.12a53.312 53.312 0 0 0 29.12 17.536l1.536 0.32a30.592 30.592 0 0 0 3.456 0.448l1.472 0.128 1.344 0.064 1.92 0.064 1.792-0.128h1.408c0.512 0 0.96 0 1.472-0.128L301.696 896a50.88 50.88 0 0 0 38.784-18.56l164.672-189.568 4.48-5.888c17.728-26.368 14.656-64-7.04-86.08-21.76-22.016-54.592-20.864-75.072 2.624l-70.912 81.664v-452.48c0-34.816-24.576-63.168-54.912-63.168z m365.76 601.92l-5.76 0.32a49.792 49.792 0 0 0-42.88 52.736 49.408 49.408 0 0 0 48.64 47.232h243.84l5.696-0.384c25.6-3.136 44.416-26.24 42.88-52.736a49.408 49.408 0 0 0-48.64-47.168h-243.84zM588.544 465.856a49.792 49.792 0 0 0-42.88 52.736 49.408 49.408 0 0 0 48.64 47.232h316.992l5.696-0.384c25.6-3.136 44.416-26.24 42.88-52.736a49.408 49.408 0 0 0-48.64-47.232H594.368l-5.76 0.384zM521.152 164.544l-5.76 0.384a49.792 49.792 0 0 0-42.88 52.736 49.408 49.408 0 0 0 48.64 47.232h390.144l5.696-0.384c25.6-3.136 44.416-26.24 42.88-52.736a49.408 49.408 0 0 0-48.64-47.232H521.216z" fill="#333333" p-id="8689"></path></svg>
                      """,
                          width: 21,
                          height: 21,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            context.isDarkMode ? Colors.white : Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  if (playlist.length > 1)
                    IconButton(
                      tooltip: "播放源",
                      onPressed: () {
                        showCupertinoModalBottomSheet(
                            context: context,
                            builder: (_) {
                              return SizedBox(
                                width: double.infinity,
                                height: context.mediaQuery.size.height * .72,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    spacing: 12,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            spacing: 6,
                                            children: [
                                              SvgPicture.string(
                                                r"""
<svg t="1758651075092" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="19790" width="200" height="200"><path d="M384.31 162.15c8.82 0 16 7.18 16 16v224c0 8.82-7.18 16-16 16h-224c-8.82 0-16-7.18-16-16v-224c0-8.82 7.18-16 16-16h224m0-64h-224c-44.18 0-80 35.82-80 80v224c0 44.18 35.82 80 80 80h224c44.18 0 80-35.82 80-80v-224c0-44.18-35.82-80-80-80zM383.79 607.69c8.82 0 16 7.18 16 16v224c0 8.82-7.18 16-16 16h-224c-8.82 0-16-7.18-16-16v-224c0-8.82 7.18-16 16-16h224m0-64h-224c-44.18 0-80 35.82-80 80v224c0 44.18 35.82 80 80 80h224c44.18 0 80-35.82 80-80v-224c0-44.18-35.82-80-80-80zM860.1 608c8.82 0 16 7.18 16 16v224c0 8.82-7.18 16-16 16h-224c-8.82 0-16-7.18-16-16V624c0-8.82 7.18-16 16-16h224m0-64h-224c-44.18 0-80 35.82-80 80v224c0 44.18 35.82 80 80 80h224c44.18 0 80-35.82 80-80V624c0-44.18-35.82-80-80-80zM912.21 113H585.22c-17.67 0-32 14.33-32 32s14.33 32 32 32h326.99c17.67 0 32-14.33 32-32s-14.32-32-32-32zM912.21 404H585.22c-17.67 0-32 14.33-32 32s14.33 32 32 32h326.99c17.67 0 32-14.33 32-32s-14.32-32-32-32zM910.18 258.5H583.19c-17.67 0-32 14.33-32 32s14.33 32 32 32h326.99c17.67 0 32-14.33 32-32s-14.32-32-32-32z" p-id="19791"></path><path d="M717 822.41c-12.14 0-24.3-4.19-34.02-12.6l-0.85-0.73-41.6-41.39c-12.53-12.46-12.58-32.73-0.12-45.25 12.46-12.53 32.73-12.58 45.25-0.12l31.88 31.72 90.49-79.12c13.3-11.63 33.52-10.28 45.15 3.03 11.63 13.3 10.28 33.52-3.03 45.15l-98.91 86.48c-9.7 8.54-21.96 12.83-34.24 12.83z m-7.89-61c-0.02 0.02-0.04 0.03-0.05 0.05l0.05-0.05z" p-id="19792"></path></svg>
""",
                                                width: 24,
                                                height: 24,
                                                colorFilter: ColorFilter.mode(
                                                  context.isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                              Text(
                                                "选择播放源",
                                                style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            icon: Icon(Icons.close),
                                          )
                                        ],
                                      ),
                                      Expanded(
                                          child: SizedBox(
                                        width: double.infinity,
                                        child: SingleChildScrollView(
                                          child: Wrap(
                                            alignment: WrapAlignment.start,
                                            spacing: 9,
                                            runSpacing: 12,
                                            children: playlist
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              int index = entry.key;
                                              var item = entry.value;
                                              var isCurr =
                                                  index == play.tabIndex;
                                              return HoverCursor(
                                                child: CupertinoButton.filled(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 12,
                                                  ),
                                                  color: isCurr
                                                      ? (context.isDarkMode
                                                              ? "#f1f1f1"
                                                              : "#0f0f0f")
                                                          .$color
                                                      : (context.isDarkMode
                                                              ? '#272727'
                                                              : "#e2e8f0")
                                                          .$color,
                                                  child: Text(item.title,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isCurr
                                                            ? (context
                                                                    .isDarkMode
                                                                ? Colors.black
                                                                : Colors.white)
                                                            : Theme.of(context)
                                                                .textTheme
                                                                .labelLarge!
                                                                .color,
                                                      )),
                                                  onPressed: () {
                                                    if (index !=
                                                        play.tabIndex) {
                                                      play.changeTabIndex(
                                                          index);
                                                      boop.selection();
                                                    }
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              );
                            });
                      },
                      icon: SvgPicture.string(
                        r"""
<svg t="1758648418740" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="5908" width="200" height="200"><path d="M487 347.43C487 424.512 424.512 487 347.43 487H237.57C160.488 487 98 424.512 98 347.43V237.57C98 160.488 160.488 98 237.57 98h109.86C424.512 98 487 160.488 487 237.57v109.86zM487 786.43C487 863.512 424.512 926 347.43 926H237.57C160.488 926 98 863.512 98 786.43V676.57C98 599.488 160.488 537 237.57 537h109.86C424.512 537 487 599.488 487 676.57v109.86zM926 347.43C926 424.512 863.512 487 786.43 487H676.57C599.488 487 537 424.512 537 347.43V237.57C537 160.488 599.488 98 676.57 98h109.86C863.512 98 926 160.488 926 237.57v109.86zM730.7 533.6c-107.861 0-195.3 87.439-195.3 195.3s87.439 195.3 195.3 195.3S926 836.761 926 728.9s-87.439-195.3-195.3-195.3z m0 309.734c-63.2 0-114.435-51.234-114.435-114.434S667.5 614.465 730.7 614.465 845.134 665.7 845.134 728.9 793.9 843.334 730.7 843.334z" fill="#666666" p-id="5909"></path></svg>
""",
                        width: 21,
                        height: 21,
                        colorFilter: ColorFilter.mode(
                          (context.isDarkMode ? Colors.white : Colors.black),
                          BlendMode.srcIn,
                        ),
                        fit: BoxFit.cover,
                      ),
                    )
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: offsetSize),
            child: Builder(builder: (context) {
              if (playlistIsEmpty) {
                return emptyPlaylistWidget;
              }
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 2 : playListGridCount,
                  mainAxisExtent: 48,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: playlist[play.tabIndex].datas.length,
                itemBuilder: (context, index) {
                  var curr = playlist[play.tabIndex].datas[index];
                  String playUrl = curr.url;
                  var isCast =
                      curr.type == VideoType.m3u8 || curr.type == VideoType.mp4;
                  return Builder(builder: (menuContext) {
                    return PullDownButton(
                      itemBuilder: (context) {
                        return [
                          PullDownMenuItem(
                            onTap: () async {
                              await FlutterClipboard.copy(
                                playUrl,
                              );
                              EasyLoading.showToast(
                                "复制链接成功",
                                maskType: EasyLoadingMaskType.none,
                              );
                            },
                            title: '复制链接',
                            icon: CupertinoIcons.doc_on_clipboard,
                          ),
                          if (isCast)
                            PullDownMenuItem(
                              title: '投屏播放',
                              subtitle: '仅支持局域网里的设备',
                              onTap: () {
                                showCupertinoModalBottomSheet(
                                    context: context,
                                    backgroundColor: (context.isDarkMode
                                            ? Colors.black
                                            : Colors.white)
                                        .withValues(alpha: .88),
                                    builder: (
                                      BuildContext context,
                                    ) {
                                      return CastScreen(
                                        onTapDevice: (cx) async {
                                          try {
                                            await cx.setUrl(playUrl);
                                            await cx.play();
                                            // TODO: 支持控制远程DLNA设备
                                            if (!context.mounted) {
                                              return;
                                            }
                                            Navigator.of(context).pop();
                                            EasyLoading.showToast(
                                              "即将开始投屏播放",
                                              toastPosition:
                                                  EasyLoadingToastPosition
                                                      .bottom,
                                              duration:
                                                  Duration(milliseconds: 240),
                                            );
                                          } catch (e) {
                                            EasyLoading.showToast(
                                              "播放失败",
                                              toastPosition:
                                                  EasyLoadingToastPosition
                                                      .bottom,
                                              duration:
                                                  Duration(milliseconds: 240),
                                            );
                                          }
                                        },
                                      );
                                    });
                              },
                              icon: CupertinoIcons.tv,
                            ),
                        ];
                      },
                      buttonBuilder: (context, showMenu) {
                        return HoverCursor(
                          child: CupertinoButton.filled(
                            color: (context.isDarkMode ? '#222222' : '#f4e8f8')
                                .$color,
                            padding: EdgeInsets.zero,
                            child: Builder(builder: (cx) {
                              var text = curr.name;
                              var ps = play.playState;
                              var lastedPlay = ps.tabIndex == play.tabIndex &&
                                  index == ps.index;
                              var textColor = context.isDarkMode
                                  ? Colors.white
                                  : Colors.black;
                              if (lastedPlay) {
                                text += "\n(上次播放)";
                                textColor = Color(0xFF6750A4);
                              }
                              return Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }),
                            onPressed: () {
                              boop.selection();
                              handlePlay(
                                play.tabIndex,
                                index,
                              );
                            },
                            onLongPress: () {
                              showMenu();
                              boop.success();
                            },
                          ),
                        );
                      },
                    );
                  });
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _realBodyView() {
    var width = context.mediaQuery.size.width;
    var height = context.mediaQuery.size.height;
    var isPad = (width / height) > 1.38; // 宽高比大于 1.38 认为是 Pad(大屏)
    var isLargeScreen = width > 720 && isPad;
    var one = isLargeScreen ? 16 : 9;
    var two = isLargeScreen ? 9 : 16;
    var sep = Container(
      width: 1,
      height: double.infinity,
      color: (context.isDarkMode ? Colors.white : Colors.black)
          .withValues(alpha: .12),
    );
    Widget body = Flex(
      direction: isLargeScreen ? Axis.horizontal : Axis.vertical,
      children: [
        Expanded(flex: one, child: _oneView(isLargeScreen)),
        if (isLargeScreen) sep,
        Expanded(flex: two, child: _twoView(isLargeScreen)),
      ],
    );
    double topbarHeight = GetPlatform.isDesktop ? 56 : 48;
    return Stack(
      children: [
        Positioned.fill(
          top: topbarHeight,
          child: body,
        ),
        Positioned(
          left: 0,
          top: 0,
          width: width,
          height: topbarHeight,
          child: MoveWindow(
            child: Container(
              decoration: BoxDecoration(
                color: (context.isDarkMode ? '#141218' : "#fef7ff").$color,
              ),
              padding: EdgeInsets.only(
                top: GetPlatform.isDesktop ? 12 : 0,
                left: 6,
                right: 6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12)
                                .copyWith(right: 24),
                            child: Row(
                              spacing: 6,
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.back, size: 24),
                                Expanded(
                                  child: Text(
                                    play.movieItem.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: context.isDarkMode
                                                ? Colors.white
                                                : Colors.black),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 120,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              var ps = play.playState;
                              if (ps == kEmptyPlayState) {
                                EasyLoading.dismiss();
                                Get.back();
                                return;
                              }
                              var curr = playlist[ps.tabIndex].datas[ps.index];
                              EasyLoading.dismiss();
                              Get.back(
                                result: Tuple2(play.playState, curr.name),
                              );
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canBeShowParseVipButton)
                    Zoom(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.collections, size: 16),
                            SizedBox(width: 6.0),
                            Text(
                              "解析源",
                              style: TextStyle(fontSize: 14.0),
                            ),
                            SizedBox(width: 2.0),
                          ],
                        ),
                        onPressed: () {
                          Get.to(() => const ParseVipManagePageView());
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlayController>(
      builder: (play) => Scaffold(
        body: Shortcuts(
          shortcuts: {
            // esc
            const SingleActivator(LogicalKeyboardKey.escape):
                const DismissIntent(),
            // backspace
            const SingleActivator(LogicalKeyboardKey.backspace):
                const DismissIntent(),
            // enter
            const SingleActivator(LogicalKeyboardKey.enter):
                const ActivateIntent(),
            // ctrl-p
            const SingleActivator(LogicalKeyboardKey.keyP, control: true):
                ScrollUpIntent(),
            // ctrl-n
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                ScrollDownIntent(),
            // // cmd-shift-[
            // const SingleActivator(LogicalKeyboardKey.braceLeft /* { */,
            //     meta: true, shift: true): TabSwitchLeftIntent(),
            // // cmd-shift-]
            // const SingleActivator(LogicalKeyboardKey.braceRight /* } */,
            //     meta: true, shift: true): TabSwitchRightIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  Get.back();
                  return null;
                },
              ),
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  // 如果只有一集的话, 敲击 `enter` 键自动播放
                  var cx = playlist[play.tabIndex].datas;
                  if (cx.length == 1) {
                    handlePlay(play.tabIndex, 0);
                  }
                  return null;
                },
              ),
              ScrollUpIntent: CallbackAction<ScrollUpIntent>(
                onInvoke: (_) {
                  scrollUp(scrollController);
                  return null;
                },
              ),
              ScrollDownIntent: CallbackAction<ScrollDownIntent>(
                onInvoke: (_) {
                  scrollDown(scrollController);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              focusNode: focusNode,
              child: SafeArea(
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: context.isDarkMode ? Colors.white : Colors.black,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Aurora(
                          size: 88,
                          colors: [
                            Color(0xffc2e59c).withValues(alpha: .24),
                            Color(0xff64b3f4).withValues(alpha: .24)
                          ],
                          blur: 88,
                        ),
                      ),
                      Positioned.fill(child: _realBodyView()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final Style _textOncelineStyle = Style(
    textOverflow: TextOverflow.ellipsis,
    maxLines: 1,
    fontSize: const FontSize(
      12,
    ),
    height: 24,
  );

  final List<String> _textIncludeTags = [
    "p",
    "span",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "pre",
  ];

  Map<String, Style> get _shortDescStyleWithHTML {
    Map<String, Style> map = {};
    for (var ele in _textIncludeTags) {
      map[ele] = _textOncelineStyle;
    }
    return map;
  }

  Widget _buildWithShortDesc(String desc) {
    String humanDesc = desc.trim();
    if (humanDesc.isEmpty) return const SizedBox.shrink();
    // NOTE: 不是标签,实际上不是很严谨!!
    if (humanDesc[0] != '<') {
      return Text(
        humanDesc,
        maxLines: 1,
        style: TextStyle(
          overflow: TextOverflow.ellipsis,
          fontSize: 12,
          color: context.isDarkMode ? Colors.white : Colors.black,
        ),
      );
    }
    return Html(
      data: humanDesc,
      style: _shortDescStyleWithHTML,
    );
  }

  Widget get _buildWithDesc {
    var desc = play.movieItem.desc;
    if (desc.isEmpty ||
        kDescEmptyList.contains(desc) ||
        desc == play.movieItem.title) {
      return SizedBox.shrink();
      // return Container(
      //   margin: const EdgeInsets.symmetric(
      //     horizontal: 12,
      //     vertical: 9,
      //   ),
      //   child: const Text('暂无简介~'),
      // );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: false,
        subtitle: _buildWithShortDesc(desc),
        title: Text(
          '查看简介',
          style: TextStyle(
            fontSize: 18,
            color: context.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * .33,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: SingleChildScrollView(
                controller: ScrollController(),
                child: Html(
                  data: desc,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get emptyPlaylistWidget {
    return Center(
      child: Column(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.tornado,
            size: 42,
            color: CupertinoColors.systemBlue,
          ),
          Text(
            "暂无播放链接",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class MediaKitPlaylist extends StatefulWidget {
  const MediaKitPlaylist({
    super.key,
    required this.width,
    required this.list,
    required this.sort,
    required this.index,
    required this.restoreOffset,
    this.onTap,
    this.onSortTap,
    this.onScroll,
    this.lateShowDuration = const Duration(milliseconds: 240),
  });

  final double width;
  final List<VideoInfo> list;
  final PlaylistSort sort;
  final int index;
  final ValueChanged<int>? onTap;
  final VoidCallback? onSortTap;
  final ValueChanged<double>? onScroll;
  final double restoreOffset;
  final Duration lateShowDuration;

  @override
  State<MediaKitPlaylist> createState() => _MediaKitPlaylistState();
}

class _MediaKitPlaylistState extends State<MediaKitPlaylist>
    with AfterLayoutMixin {
  PlaylistSort sort = PlaylistSort.down;
  List<VideoInfo> list = [];
  int index = -1;

  ScrollController controller = ScrollController();

  bool show = false;

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    show = true;
    sort = widget.sort;
    index = widget.index;
    list = widget.list;
    setState(() {});
    controller.addListener(() {
      var offset = controller.offset;
      widget.onScroll?.call(offset);
    });
    restoreScrollPosition();
  }

  void restoreScrollPosition() {
    var offset = widget.restoreOffset;
    controller.jumpTo(offset);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleSortPlaylist() {
    sort = sort == PlaylistSort.down ? PlaylistSort.up : PlaylistSort.down;
    list = list.reversed.toList();
    index = getReversalIndex(list, index);
    if (mounted) setState(() {});
    widget.onSortTap?.call();
  }

  Widget _buildRealBody() {
    return Container(
      width: widget.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
      ),
      child: ClipRRect(
        child: Stack(
          children: [
            if (GetPlatform.isDesktop)
              Positioned.fill(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.38)
                            : Colors.white.withValues(alpha: 0.24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.21),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          spacing: 3,
                          children: [
                            Text(
                              "选集",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            Opacity(
                              opacity: .68,
                              child: Text(
                                "(共${list.length}集)",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: handleSortPlaylist,
                          icon: Row(
                            spacing: 6,
                            children: [
                              Icon(sort.icon, color: Colors.white),
                              Text(
                                sort.name,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      children: list.map((item) {
                        var currIndex = list.indexOf(item);
                        var isCurr = currIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 9,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 1,
                                  color: Colors.grey.withValues(
                                    alpha: isCurr ? .88 : .24,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              dense: true,
                              mouseCursor: SystemMouseCursors.click,
                              selected: isCurr,
                              selectedTileColor: kActiveColor,
                              hoverColor: Colors.white.withValues(alpha: 0.24),
                              title: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                index = currIndex;
                                if (mounted) setState(() {});
                                widget.onTap?.call(currIndex);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: GestureDetector(
              onTap: () {
                show = false;
                if (mounted) setState(() {});
                Get.back();
              },
            ),
          ),
        ),
        AnimatedPositioned(
          top: 0,
          right: show ? 0 : -widget.width,
          bottom: 0,
          duration: widget.lateShowDuration,
          curve: Curves.easeInOut,
          width: widget.width,
          child: _buildRealBody(),
        ),
      ],
    );
  }
}
