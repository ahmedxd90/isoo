import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../profile/vip_widgets.dart';

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
  Widget build(BuildContext context) {
    final vip = (widget.data['vipLevel'] as num?)?.toInt() ?? 0;
    final showUserCenter = vip >= 4 && vip <= 10;
    return SafeArea(
      bottom: true,
      maintainBottomViewPadding: true,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          WebViewWidget(controller: _controller),
          if (showUserCenter)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: .72,
                    widthFactor: 1,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(35),
                      ),
                      child: Opacity(
                        opacity: .34,
                        child: VipSvgaAsset(
                          assetPath: 'assets/vip/user_center_svip$vip.svga',
                          fallbackAsset: 'assets/vip/title_vip$vip.png',
                          size: double.infinity,
                          loop: true,
                        ),
                      ),
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
