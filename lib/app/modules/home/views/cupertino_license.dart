import 'package:aurora/aurora.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:catmovie/app/modules/home/controllers/home_controller.dart';
import 'package:catmovie/app/modules/home/views/settings_view.dart';
import 'package:catmovie/app/widget/zoom.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:catmovie/app/extension.dart';
import 'package:catmovie/app/widget/window_appbar.dart';
import 'package:catmovie/widget/flutter_custom_license_page.dart';
import 'package:smooth_list_view/smooth_list_view.dart';
import 'package:tuple/tuple.dart';

const kGithubRepo = "https://github.com/waifu-project/movie";

// 开发者们
var kDevelopers = <Tuple2<String, String>>[
  Tuple2("d1y", "https://avatars.githubusercontent.com/u/45585937?v=4"),
  Tuple2("左福龙", "https://s2.loli.net/2025/09/13/WgfESD8aziGscRI.jpg"),
];

void _showInfo(
  String currentPackage,
  List<LicenseEntry> packageLicenses,
  BuildContext context,
) {
  Navigator.of(context).push(
    CupertinoPageRoute(builder: (context) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoEasyAppBar(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CupertinoNavigationBarBackButton(),
                  Expanded(
                    child: Text(
                      currentPackage,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Text(''),
                ],
              ),
              const Divider(),
            ],
          ),
        ),
        child: Material(
          child: SmoothListView.builder(
            duration: kSmoothListViewDuration,
            itemCount: packageLicenses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  packageLicenses[index]
                      .paragraphs
                      .map((paragraph) => paragraph.text)
                      .join("\n"),
                ),
              );
            },
          ),
        ),
      );
    }),
  );
}

Widget _buildRealBody(LicenseData? licenseData, BuildContext context) {
  Widget _title(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 18, color: CupertinoColors.systemBlue),
    );
  }

  return Stack(
    children: [
      Positioned.fill(
        child: ClipRRect(
          child: Aurora(
            size: 88,
            colors: [
              Color(0xffc2e59c).withValues(alpha: .24),
              Color(0xff64b3f4).withValues(alpha: .24),
            ],
            blur: 66,
          ),
        ),
      ),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(18).copyWith(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              // Text("该项目仅可用于学习交流, 请勿用于商业用途, 如有侵权请联系开发者进行删除"),
              _title("开发者"),
              Row(
                spacing: 18,
                children: kDevelopers.map((item) {
                  return Zoom(
                    onTap: () {
                      if (item.item1 == "d1y") {
                        "https://github.com/d1y".openURL();
                      }
                    },
                    child: Column(
                      spacing: 6,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(42),
                          child: CachedNetworkImage(
                            imageUrl: item.item2,
                            width: 42,
                            height: 42,
                          ),
                        ),
                        Text(item.item1),
                      ],
                    ),
                  );
                }).toList(),
              ),
              _title("开源地址"),
              Zoom(
                onTap: kGithubRepo.openURL,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: .12),
                    ),
                  ),
                  width: double.infinity,
                  height: 88,
                  child: ClipRRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Aurora(
                            size: 88,
                            colors: [
                              Color(0xffc2e59c).withValues(alpha: .88),
                              Color(0xff64b3f4).withValues(alpha: .88),
                            ],
                            blur: 120,
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            spacing: 12,
                            children: [
                              SvgPicture.string(
                                kGithubIconSvg,
                                width: 80,
                              ),
                              Column(
                                spacing: 6,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("waifu-project/movie",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                      )),
                                  Text(
                                    "仅供学习参考, 请勿用于商业用途",
                                    maxLines: 2,
                                    style: TextStyle(
                                        color:
                                            Colors.blue.withValues(alpha: .72),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _title("以下是使用到的开源项目"),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    children: licenseData!.packages
                        .where((item) {
                          return !item.startsWith("_");
                        })
                        .toList()
                        .map(
                          (currentPackage) => CupertinoButton(
                            sizeStyle: CupertinoButtonSize.small,
                            child: Text(currentPackage),
                            onPressed: () {
                              List<LicenseEntry> packageLicenses = licenseData
                                  .packageLicenseBindings[currentPackage]!
                                  .map((binding) =>
                                      licenseData.licenses[binding])
                                  .toList();
                              _showInfo(
                                  currentPackage, packageLicenses, context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

CustomLicensePage cupertinoLicensePage = CustomLicensePage((
  context,
  licenseData,
) {
  return CupertinoPageScaffold(child: body(licenseData, context));
});

Widget body(
  AsyncSnapshot<LicenseData> licenseDataFuture,
  BuildContext context,
) {
  switch (licenseDataFuture.connectionState) {
    case ConnectionState.done:
      LicenseData? licenseData = licenseDataFuture.data;
      return _buildRealBody(licenseData, context);
    default:
      return const Center(
        child: CupertinoActivityIndicator(),
      );
  }
}
