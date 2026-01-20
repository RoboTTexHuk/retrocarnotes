import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'main.dart';

class RetroCarHelpLite extends StatefulWidget {
  const RetroCarHelpLite({super.key});

  @override
  State<RetroCarHelpLite> createState() => _RetroCarHelpLiteState();
}

class _RetroCarHelpLiteState extends State<RetroCarHelpLite> {
  InAppWebViewController? retroCarWebViewController;
  bool retroCarLoading = true;

  Future<bool> retroCarGoBackInWebViewIfPossible() async {
    if (retroCarWebViewController == null) return false;
    try {
      final bool retroCarCanBack =
      await retroCarWebViewController!.canGoBack();
      if (retroCarCanBack) {
        await retroCarWebViewController!.goBack();
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final bool retroCarHandled =
        await retroCarGoBackInWebViewIfPossible();
        return retroCarHandled ? false : false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text("Retro car: notes"),
          centerTitle: true,
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              InAppWebView(
                initialFile: 'assets/retrocars.html',
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                  disableHorizontalScroll: false,
                  disableVerticalScroll: false,
                  transparentBackground: true,
                  mediaPlaybackRequiresUserGesture: false,
                  disableDefaultErrorPage: true,
                  allowsInlineMediaPlayback: true,
                  allowsPictureInPictureMediaPlayback: true,
                  useOnDownloadStart: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                ),
                onWebViewCreated:
                    (InAppWebViewController retroCarController) {
                  retroCarWebViewController = retroCarController;
                },
                onLoadStart: (InAppWebViewController retroCarController,
                    Uri? retroCarUrl) =>
                    setState(() => retroCarLoading = true),
                onLoadStop: (InAppWebViewController retroCarController,
                    Uri? retroCarUrl) async =>
                    setState(() => retroCarLoading = false),
                onLoadError: (InAppWebViewController retroCarController,
                    Uri? retroCarUrl,
                    int retroCarCode,
                    String retroCarMessage) =>
                    setState(() => retroCarLoading = false),
              ),


            ],
          ),
        ),
      ),
    );
  }
}



