import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlUserProfileView extends StatefulWidget {
  const HtmlUserProfileView({
    super.key,
    required this.data,
    required this.onClose,
    required this.onFollow,
    required this.onMessage,
    required this.onOpenProfile,
    required this.onMore,
  });

  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onOpenProfile;
  final VoidCallback onMore;

  @override
  State<HtmlUserProfileView> createState() => _HtmlUserProfileViewState();
}

class _HtmlUserProfileViewState extends State<HtmlUserProfileView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'UserProfileBridge',
        onMessageReceived: (message) {
          final payload = jsonDecode(message.message);
          if (payload is! Map) return;
          switch (payload['type']?.toString()) {
            case 'ready':
              _sync();
            case 'closeMiniProfile':
              widget.onClose();
            case 'toggleFollow':
              widget.onFollow();
            case 'openPrivateChat':
              widget.onMessage();
            case 'openMainProfile':
              widget.onOpenProfile();
            case 'openMoreMenu':
              widget.onMore();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url.startsWith('file://')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset('assets/rooms/user_profile_html.html');
  }

  void _sync() {
    _controller.runJavaScript('renderProfileData(${jsonEncode(widget.data)});');
  }

  @override
  void didUpdateWidget(covariant HtmlUserProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _sync();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
