import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlProfileView extends StatefulWidget {
  const HtmlProfileView({
    super.key,
    required this.data,
    required this.posts,
    required this.viewer,
    required this.onBack,
    required this.onFollow,
    required this.onMessage,
    required this.onReport,
    required this.onOpenUser,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> posts;
  final Map<String, dynamic> viewer;
  final VoidCallback onBack;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onReport;
  final ValueChanged<String> onOpenUser;

  @override
  State<HtmlProfileView> createState() => _HtmlProfileViewState();
}

class _HtmlProfileViewState extends State<HtmlProfileView> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050509))
      ..addJavaScriptChannel(
        'ProfileBridge',
        onMessageReceived: (message) {
          final payload = jsonDecode(message.message);
          if (payload is! Map) return;
          final type = payload['type']?.toString() ?? '';
          final param = payload['param']?.toString() ?? '';
          switch (type) {
            case 'ready':
              _ready = true;
              _sync();
            case 'closeActivity':
            case 'handleBackPress':
              widget.onBack();
            case 'toggleFollow':
              widget.onFollow();
            case 'sendMessage':
            case 'openPrivateChat':
              widget.onMessage();
            case 'openReportModal':
            case 'sendReport':
              widget.onReport();
            case 'openUserProfile':
              if (param.isNotEmpty) widget.onOpenUser(param);
            case 'openMainProfile':
              if (param.isNotEmpty) widget.onOpenUser(param);
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
      ..loadFlutterAsset('assets/profile_full_html.html');
  }

  String _js(String functionName, Object value) =>
      '$functionName(${jsonEncode(jsonEncode(value))});';

  void _sync() {
    if (!_ready) return;
    final profile = <String, dynamic>{...widget.data};
    _controller.runJavaScript(
      '${_js('updateProfileData', profile)}'
      '${_js('setViewerData', widget.viewer)}'
      '${widget.posts.map((post) => _js('addPost', post)).join()}',
    );
  }

  @override
  void didUpdateWidget(covariant HtmlProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data || oldWidget.posts != widget.posts)
      _sync();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    maintainBottomViewPadding: true,
    child: WebViewWidget(controller: _controller),
  );
}
