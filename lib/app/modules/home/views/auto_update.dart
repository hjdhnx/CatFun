import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:catmovie/app/extension.dart';
import 'package:catmovie/app/widget/zoom.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:xi/xi.dart';

const kUpdateUpstream =
    "https://api.github.com/repos/waifu-project/movie/releases";

/// 豆包
/// 将HTML中的img标签转换为Markdown图片格式
/// [input] 包含img标签的原始字符串
/// [defaultAlt] 当img标签没有alt属性时使用的默认文本
String convertImgTagsToMarkdown(String input, {String defaultAlt = '图片'}) {
  // 使用原始字符串处理各种引号情况，避免转义问题
  // 处理alt在src后面的情况
  final regexSrcFirst = RegExp(r'''<img[^>]*src=("|')([^"']*)\1[^>]*alt=("|')([^"']*)\3[^>]*>''',
      caseSensitive: false);
  
  // 处理alt在src前面的情况
  final regexAltFirst = RegExp(r'''<img[^>]*alt=("|')([^"']*)\1[^>]*src=("|')([^"']*)\3[^>]*>''',
      caseSensitive: false);

  // 处理没有alt属性的情况
  final regexNoAlt = RegExp(r'''<img[^>]*src=("|')([^"']*)\1[^>]*>''',
      caseSensitive: false);

  // 分步替换，确保所有情况都能被处理
  String result = input
      .replaceAllMapped(regexSrcFirst, (match) {
        String imageUrl = match.group(2) ?? '';
        String altText = match.group(4) ?? defaultAlt;
        return '![$altText]($imageUrl)';
      })
      .replaceAllMapped(regexAltFirst, (match) {
        String altText = match.group(2) ?? defaultAlt;
        String imageUrl = match.group(4) ?? '';
        return '![$altText]($imageUrl)';
      })
      .replaceAllMapped(regexNoAlt, (match) {
        String imageUrl = match.group(2) ?? '';
        return '![$defaultAlt]($imageUrl)';
      });
  
  return result;
}


class AutoUpdate extends StatefulWidget {
  const AutoUpdate({super.key});

  @override
  State<AutoUpdate> createState() => _AutoUpdateState();
}

class _AutoUpdateState extends State<AutoUpdate> with AfterLayoutMixin {
  GithubTag? tag;

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    var resp = await XHttp.dio.get<List<dynamic>>(
      kUpdateUpstream,
      options: $noCacheOption(),
    );
    var tags = (resp.data ?? []).map((item) {
      return GithubTag.fromJson(item as Map<String, dynamic>);
    }).toList();
    tag = tags[0];
    tag!.body = convertImgTagsToMarkdown(tag!.body);
    setState(() {});
  }

  Widget _buildChangelog() {
    if (tag == null) {
      return Expanded(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                child: MarkdownWidget(data: tag!.body),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.mediaQuery.size.height * .72,
      child: Column(
        children: [
          _buildChangelog(),
          Zoom(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ).copyWith(
                bottom: context.mediaQuery.padding.bottom + 24,
              ),
              child: CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.medium,
                onPressed: () {
                  if (tag == null) return;
                  String url =
                      "https://github.com/hjdhnx/CatFun/releases/latest/download/";
                  if (GetPlatform.isAndroid) {
                    url += "catmovie.apk";
                  } else if (GetPlatform.isIOS) {
                    url += "catmovie.ipa";
                  } else if (GetPlatform.isMacOS) {
                    url += "catmovie-mac.zip";
                  } else if (GetPlatform.isWindows) {
                    url += "catmovie-windows.zip";
                  } else if (GetPlatform.isLinux) {
                    url += "catmovie-linux-x86_64.tar.gz";
                  }
                  url.openURL();
                },
                onLongPress: () {
                  if (GetPlatform.isIOS) {
                    var url =
                        "apple-magnifier://install?url=https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie.ipa";
                    url.openURL();
                  }
                },
                child: Text("下载"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GithubTag {
  String tag_name;
  String body;

  GithubTag({
    required this.tag_name,
    required this.body,
  });

  factory GithubTag.fromJson(Map<String, dynamic> json) => GithubTag(
        tag_name: json["tag_name"],
        body: json["body"],
      );
}
