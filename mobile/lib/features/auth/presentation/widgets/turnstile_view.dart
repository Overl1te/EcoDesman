import "dart:io";

import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";

class TurnstileView extends StatelessWidget {
  const TurnstileView({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String> onToken;

  @override
  Widget build(BuildContext context) {
    if (Platform.environment.containsKey("FLUTTER_TEST") || siteKey.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 72,
      child: _TurnstileWebView(siteKey: siteKey, onToken: onToken),
    );
  }
}

class _TurnstileWebView extends StatefulWidget {
  const _TurnstileWebView({required this.siteKey, required this.onToken});

  final String siteKey;
  final ValueChanged<String> onToken;

  @override
  State<_TurnstileWebView> createState() => _TurnstileWebViewState();
}

class _TurnstileWebViewState extends State<_TurnstileWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final html = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
    <style>
      html, body { margin: 0; padding: 0; background: transparent; }
      .wrap { display: flex; justify-content: center; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="cf-turnstile" data-sitekey="${widget.siteKey}" data-callback="onOk" data-expired-callback="onExpired" data-error-callback="onExpired"></div>
    </div>
    <script>
      function onOk(token) { TurnstileHost.postMessage(token); }
      function onExpired() { TurnstileHost.postMessage(""); }
    </script>
  </body>
</html>
""";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        "TurnstileHost",
        onMessageReceived: (message) => widget.onToken(message.message),
      )
      ..loadHtmlString(
        html,
        baseUrl: "https://xn--b1apekb3anb5cpb.xn--p1ai/",
      );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
