import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:catmovie/utils/screen_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebviewView extends StatefulWidget {
  const WebviewView({super.key});

  @override
  createState() => _WebviewViewState();
}

class _WebviewViewState extends State<WebviewView> {
  final url = Get.arguments;
  final GlobalKey webViewKey = GlobalKey();
  
  bool _isLoading = true;

  @override
  void initState() {
    WakelockPlus.enable();
    execScreenDirction(ScreenDirction.x);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    WakelockPlus.disable();
    execScreenDirction(ScreenDirction.y);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black38,
        ),
        margin: const EdgeInsets.symmetric(vertical: 9),
        child: IconButton(
          icon: const BackButtonIcon(),
          color: Colors.white,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      body: Stack(
        children: [
          InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(
              url: WebUri(url),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              transparentBackground: true,
            ),
            onWebViewCreated: (controller) {
              // WebView controller created
            },
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
            onReceivedError: (controller, request, error) {
              setState(() => _isLoading = false);
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
