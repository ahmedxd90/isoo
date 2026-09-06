import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

class LiveBroadcastSetupPage extends StatefulWidget {
  const LiveBroadcastSetupPage({super.key, required this.room});
  final Map<String, dynamic> room;
  @override
  State<LiveBroadcastSetupPage> createState() => _LiveBroadcastSetupPageState();
}

class _LiveBroadcastSetupPageState extends State<LiveBroadcastSetupPage> {
  final _title = TextEditingController();
  Map<String, dynamic>? _profile;
  @override
  void initState() {
    super.initState();
    _title.text = widget.room['name'] as String? ?? 'بث SAKI مباشر';
    SakiService.instance.myProfile().then((value) {
      if (mounted) setState(() => _profile = value);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF140D29),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: const Text('إعداد البث المباشر'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 26),
          SakiAvatar(
            url: _profile?['avatar_url'] as String?,
            label: _profile?['username'] as String?,
            radius: 48,
          ),
          const SizedBox(height: 14),
          Text(
            _profile?['username'] as String? ?? 'حسابي',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _title,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'عنوان البث',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ستظهر صورة حسابك كصورة البث، وسيتمكن المستخدمون من دخول البث وإرسال الهدايا والتفاعل معك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isNotEmpty) Navigator.pop(context, title);
              },
              icon: const Icon(Icons.live_tv_rounded),
              label: const Text('بدء بث مباشر حقيقي'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
