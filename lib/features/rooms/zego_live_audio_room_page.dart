import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../core/data/saki_service.dart';

Widget zegoRoomPageFor(Map<String, dynamic> room) {
  final id = room['room_id']?.toString().trim() ?? '';
  if (id.isEmpty) {
    return const Scaffold(body: Center(child: Text('معرف الغرفة غير متوفر')));
  }
  final profile = Map<String, dynamic>.from(
    room['profiles'] as Map? ?? const {},
  );
  final username =
      profile['username']?.toString() ??
      SakiService.instance.currentUser?.email?.split('@').first ??
      'مستخدم SAKI';
  return ZegoLiveAudioRoomPage(room: room, roomId: id, userName: username);
}

class ZegoLiveAudioRoomPage extends StatefulWidget {
  const ZegoLiveAudioRoomPage({
    super.key,
    required this.room,
    required this.roomId,
    required this.userName,
  });
  final Map<String, dynamic> room;
  final String roomId;
  final String userName;
  @override
  State<ZegoLiveAudioRoomPage> createState() => _ZegoLiveAudioRoomPageState();
}

class _ZegoLiveAudioRoomPageState extends State<ZegoLiveAudioRoomPage> {
  final service = SakiService.instance;
  final message = TextEditingController();
  late final Future<Map<String, dynamic>> token;
  late final Stream<List<Map<String, dynamic>>> chat;
  late final Stream<List<Map<String, dynamic>>> seats;
  bool sending = false;
  bool showChat = true;
  String get dbId => widget.room['id']?.toString() ?? '';
  bool get owner => widget.room['owner_id']?.toString() == service.uid;

  @override
  void initState() {
    super.initState();
    token = loadRoom();
    chat = service.roomMessagesStream(dbId);
    seats = service.roomSeatsStream(dbId);
  }

  Future<Map<String, dynamic>> loadRoom() async {
    if (service.client.auth.currentSession == null) {
      throw const AuthException('يرجى تسجيل الدخول أولًا');
    }
    await service.joinRoom(dbId);
    return service.zegoRoomToken(widget.roomId, userName: widget.userName);
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  void toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> sendMessage() async {
    final text = message.text.trim();
    if (text.isEmpty || sending) {
      return;
    }
    setState(() => sending = true);
    try {
      await service.sendRoomMessage(dbId, text);
      message.clear();
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> chooseSeat() async {
    final no = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF151827),
      builder: (_) => SeatSheet(stream: seats),
    );
    if (no == null) {
      return;
    }
    try {
      final ok = await ZegoUIKitPrebuiltLiveAudioRoomController().seat.audience
          .take(no - 1);
      if (!ok) throw Exception('المقعد غير متاح أو يحتاج موافقة المالك');
      await service.claimRoomSeat(dbId, no);
      toast('تم أخذ المقعد ويمكنك التحدث الآن');
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> leaveSeat() async {
    try {
      await ZegoUIKitPrebuiltLiveAudioRoomController().seat.speaker.leave();
      await service.leaveRoomSeat(dbId);
      toast('تم ترك المقعد');
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> showMembers() async {
    final members = await service.roomMembers(dbId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151827),
      builder: (_) => MembersSheet(members: members),
    );
  }

  Future<void> editRoom() async {
    if (!owner) return;
    final name = TextEditingController(text: widget.room['name']?.toString());
    final announcement = TextEditingController(
      text: widget.room['announcement']?.toString() ?? '',
    );
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151827),
      builder: (_) => SettingsSheet(name: name, announcement: announcement),
    );
    name.dispose();
    announcement.dispose();
    if (result == null) {
      return;
    }
    try {
      await service.updateRoomSettings(
        dbId,
        name: result['name'],
        announcement: result['announcement'],
      );
      toast('تم حفظ إعدادات الغرفة');
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<Map<String, dynamic>>(
        future: token,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('الغرفة الصوتية')),
              body: Center(child: Text('تعذر الدخول: ${snapshot.error}')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          final isHost = data['isOwner'] == true || owner;
          final config = isHost
              ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
              : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();
          config.turnOnMicrophoneWhenJoining = isHost;
          config.inRoomMessage.visible = false;
          config.innerText = ZegoUIKitPrebuiltLiveAudioRoomInnerText(
            takeSeatMenuButton: 'خذ مقعدًا',
            switchSeatMenuButton: 'بدّل المقعد',
            removeSpeakerMenuDialogButton: 'إنزال %0 من المقعد',
            muteSpeakerMenuDialogButton: 'كتم %0',
            cancelMenuDialogButton: 'إلغاء',
            removeUserMenuDialogButton: 'إخراج %0 من الغرفة',
            memberListTitle: 'المتصلون',
            memberListRoleYou: 'أنت',
            memberListRoleHost: 'مالك الغرفة',
            memberListRoleSpeaker: 'متحدث',
            applyToTakeSeatButton: 'اطلب مقعدًا',
            cancelTheTakeSeatApplicationButton: 'إلغاء الطلب',
            memberListAgreeButton: 'قبول',
            memberListDisagreeButton: 'رفض',
            messageEmptyToast: 'اكتب رسالة',
          );
          config.foreground = overlay();
          return Scaffold(
            backgroundColor: const Color(0xFF0D1020),
            body: SafeArea(
              top: false,
              child: ZegoUIKitPrebuiltLiveAudioRoom(
                appID: (data['appId'] as num).toInt(),
                token: data['token'].toString(),
                userID: safe(data['userId']?.toString() ?? 'user'),
                userName: data['userName']?.toString() ?? widget.userName,
                roomID: data['roomId'].toString(),
                config: config,
                events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
                  onError: (e) =>
                      debugPrint('ZEGOCLOUD ${e.code}: ${e.message}'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  Widget overlay() {
    final profile = Map<String, dynamic>.from(
      widget.room['profiles'] as Map? ?? const {},
    );
    return Stack(
      children: [
        Positioned(
          top: 38,
          left: 10,
          right: 10,
          child: Header(
            room: widget.room,
            owner: profile,
            isOwner: owner,
            onSettings: editRoom,
            onExit: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 14,
          child: Actions(
            onMembers: showMembers,
            onSeats: chooseSeat,
            onLeave: leaveSeat,
            onChat: () => setState(() => showChat = !showChat),
          ),
        ),
        if (showChat)
          Positioned(
            left: 10,
            right: 10,
            bottom: 68,
            height: 230,
            child: Chat(
              stream: chat,
              controller: message,
              sending: sending,
              onSend: sendMessage,
            ),
          ),
      ],
    );
  }
}

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.room,
    required this.owner,
    required this.isOwner,
    required this.onSettings,
    required this.onExit,
  });
  final Map<String, dynamic> room;
  final Map<String, dynamic> owner;
  final bool isOwner;
  final VoidCallback onSettings;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final image = room['image_url']?.toString();
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: image?.isNotEmpty == true
                    ? Image.network(
                        image!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(
                        width: 42,
                        height: 42,
                        child: ColoredBox(
                          color: Color(0xFF303864),
                          child: Icon(Icons.mic, color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room['name']?.toString() ?? 'غرفة صوتية',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'room_id: ${room['room_id']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    'المالك: ${owner['username'] ?? 'منشئ الغرفة'}',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isOwner)
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }
}

class Actions extends StatelessWidget {
  const Actions({
    super.key,
    required this.onMembers,
    required this.onSeats,
    required this.onLeave,
    required this.onChat,
  });
  final VoidCallback onMembers;
  final VoidCallback onSeats;
  final VoidCallback onLeave;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ActionButton(icon: Icons.people, text: 'المتصلون', onTap: onMembers),
      const SizedBox(height: 7),
      ActionButton(icon: Icons.event_seat, text: 'خذ مقعدًا', onTap: onSeats),
      const SizedBox(height: 7),
      ActionButton(icon: Icons.mic_off, text: 'اترك المقعد', onTap: onLeave),
      const SizedBox(height: 7),
      ActionButton(icon: Icons.chat, text: 'الدردشة', onTap: onChat),
    ],
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xDD20263D),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Chat extends StatelessWidget {
  const Chat({
    super.key,
    required this.stream,
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            return ListView.builder(
              reverse: true,
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final row = rows[rows.length - i - 1];
                final p = Map<String, dynamic>.from(
                  row['profiles'] as Map? ?? const {},
                );
                final image = p['avatar_url']?.toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xB820263D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundImage: image?.isNotEmpty == true
                            ? NetworkImage(image!)
                            : null,
                        child: image?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person, size: 15),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${p['username'] ?? 'مستخدم'}\n${row['body'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xDD20263D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send, color: Color(0xFFFFD166)),
          ),
        ],
      ),
    ],
  );
}

class SeatSheet extends StatelessWidget {
  const SeatSheet({super.key, required this.stream});
  final Stream<List<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر مقعدًا للتحدث',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ستدخل الغرفة مستمعًا ولن يعمل الميكروفون قبل أخذ مقعد.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final taken = {
                for (final r in snapshot.data ?? const <Map<String, dynamic>>[])
                  (r['seat_no'] as num).toInt(),
              };
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(10, (i) {
                  final no = i + 1;
                  final busy = taken.contains(no);
                  return InkWell(
                    onTap: busy ? null : () => Navigator.pop(context, no),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: busy
                            ? const Color(0xFF713F46)
                            : const Color(0xFF273052),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            busy ? Icons.person : Icons.event_seat,
                            color: busy
                                ? Colors.white54
                                : const Color(0xFFFFD166),
                          ),
                          Text(
                            '$no',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MembersSheet extends StatelessWidget {
  const MembersSheet({super.key, required this.members});
  final List<Map<String, dynamic>> members;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'المتصلون الآن',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        ...members.map((p) {
          final image = p['avatar_url']?.toString();
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: image?.isNotEmpty == true
                  ? NetworkImage(image!)
                  : null,
              child: image?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person),
            ),
            title: Text(
              p['username']?.toString() ?? 'مستخدم',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }),
      ],
    ),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.name,
    required this.announcement,
  });
  final TextEditingController name;
  final TextEditingController announcement;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18,
      right: 18,
      top: 18,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'إعدادات الغرفة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextField(
          controller: name,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'اسم الغرفة',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        TextField(
          controller: announcement,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'الإعلان',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': name.text.trim(),
              'announcement': announcement.text.trim(),
            }),
            child: const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    ),
  );
}
