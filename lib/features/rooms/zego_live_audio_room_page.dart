import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../core/data/saki_service.dart';

Widget zegoRoomPageFor(Map<String, dynamic> room) {
  final roomId = room['room_id']?.toString().trim() ?? '';
  if (roomId.isEmpty) {
    return const Scaffold(body: Center(child: Text('معرف الغرفة غير متوفر')));
  }
  final profile = Map<String, dynamic>.from(
    room['profiles'] as Map? ?? const {},
  );
  final name =
      profile['username']?.toString() ??
      SakiService.instance.currentUser?.email?.split('@').first ??
      'مستخدم SAKI';
  return ZegoLiveAudioRoomPage(room: room, roomId: roomId, userName: name);
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
  final messageController = TextEditingController();
  late final Future<Map<String, dynamic>> token;
  late final Stream<List<Map<String, dynamic>>> chat;
  late final Future<bool> moderator;
  bool sending = false;
  bool showChat = true;
  bool canManageRoom = false;

  String get dbRoomId => widget.room['id']?.toString() ?? '';
  bool get isOwner => widget.room['owner_id']?.toString() == service.uid;

  @override
  void initState() {
    super.initState();
    token = loadRoom();
    chat = service.roomMessagesStream(dbRoomId);
    moderator = service.isRoomModerator(dbRoomId);
    moderator.then((value) {
      if (mounted) setState(() => canManageRoom = isOwner || value);
    });
  }

  Future<Map<String, dynamic>> loadRoom() async {
    if (service.client.auth.currentSession == null) {
      throw const AuthException('يرجى تسجيل الدخول أولًا');
    }
    await service.joinRoom(dbRoomId);
    return service.zegoRoomToken(widget.roomId, userName: widget.userName);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await service.sendRoomMessage(dbRoomId, text);
      messageController.clear();
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> openSettings() async {
    final allowed = isOwner || await moderator;
    if (!allowed || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomSettingsPage(
          room: widget.room,
          roomId: dbRoomId,
          isOwner: isOwner,
        ),
      ),
    );
  }

  Future<void> openGifts() async {
    final members = await service.roomMembers(dbRoomId);
    final gifts = await service.roomGiftCatalog();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151827),
      builder: (_) => GiftSheet(
        roomId: dbRoomId,
        members: members,
        gifts: gifts,
        service: service,
      ),
    );
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
          final host = data['isOwner'] == true || isOwner;
          final config = host
              ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
              : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();
          // الجمهور يدخل صامتًا؛ الصوت يبدأ فقط عند أخذ مقعد حقيقي.
          config.turnOnMicrophoneWhenJoining = false;
          if (host) config.seat.takeIndexWhenJoining = -1;
          config.userAvatarUrl = service
              .currentUser
              ?.userMetadata?['avatar_url']
              ?.toString();
          // إبقاء شريط ZEGOCLOUD الأصلي والدردشة الأصلية كما في التصميم السابق.
          config.inRoomMessage.visible = true;
          config.inRoomMessage.showName = true;
          config.inRoomMessage.showAvatar = true;
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
          config.foreground = _overlay();
          return Scaffold(
            backgroundColor: const Color(0xFF0D1020),
            body: SafeArea(
              top: false,
              child: ZegoUIKitPrebuiltLiveAudioRoom(
                appID: (data['appId'] as num).toInt(),
                token: data['token'].toString(),
                userID: _safe(data['userId']?.toString() ?? 'user'),
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

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  Widget _overlay() {
    final profile = Map<String, dynamic>.from(
      widget.room['profiles'] as Map? ?? const {},
    );
    return Stack(
      children: [
        Positioned(
          top: 38,
          left: 10,
          right: 10,
          child: RoomHeader(
            room: widget.room,
            owner: profile,
            isOwner: canManageRoom,
            onSettings: openSettings,
            onGifts: openGifts,
            onExit: () => Navigator.pop(context),
          ),
        ),
        if (showChat)
          Positioned(
            left: 10,
            right: 10,
            bottom: 78,
            height: 190,
            child: ChatPanel(
              stream: chat,
              controller: messageController,
              sending: sending,
              onSend: sendMessage,
              onClose: () => setState(() => showChat = false),
            ),
          ),
        if (!showChat)
          Positioned(
            left: 14,
            bottom: 82,
            child: TextButton.icon(
              onPressed: () => setState(() => showChat = true),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: const Text(
                'فتح الدردشة',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class RoomHeader extends StatelessWidget {
  const RoomHeader({
    super.key,
    required this.room,
    required this.owner,
    required this.isOwner,
    required this.onSettings,
    required this.onGifts,
    required this.onExit,
  });
  final Map<String, dynamic> room;
  final Map<String, dynamic> owner;
  final bool isOwner;
  final VoidCallback onSettings;
  final VoidCallback onGifts;
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
        TextButton(
          onPressed: onGifts,
          child: const Text(
            'هدايا',
            style: TextStyle(color: Color(0xFFFFD166)),
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

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.stream,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onClose,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'الدردشة النصية',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                return ListView.builder(
                  reverse: true,
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[rows.length - index - 1];
                    final profile = Map<String, dynamic>.from(
                      row['profiles'] as Map? ?? const {},
                    );
                    final avatar = profile['avatar_url']?.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xB820263D),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundImage: avatar?.isNotEmpty == true
                                ? NetworkImage(avatar!)
                                : null,
                            child: avatar?.isNotEmpty == true
                                ? null
                                : const Icon(Icons.person, size: 14),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${profile['username'] ?? 'مستخدم'}\n${row['body'] ?? ''}',
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
                      vertical: 6,
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
      ),
    );
  }
}

class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({
    super.key,
    required this.room,
    required this.roomId,
    required this.isOwner,
  });
  final Map<String, dynamic> room;
  final String roomId;
  final bool isOwner;
  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  final service = SakiService.instance;
  late final TextEditingController name;
  late final TextEditingController announcement;
  late final AudioPlayer player;
  late Future<List<Map<String, dynamic>>> moderators;
  late Future<List<Map<String, dynamic>>> music;
  String? backgroundUrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.room['name']?.toString() ?? '');
    announcement = TextEditingController(
      text: widget.room['announcement']?.toString() ?? '',
    );
    backgroundUrl = widget.room['background_url']?.toString();
    player = AudioPlayer();
    moderators = service.roomModeratorsForOwner(widget.roomId);
    music = service.roomMusic(widget.roomId);
  }

  @override
  void dispose() {
    name.dispose();
    announcement.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await service.updateRoomSettings(
        widget.roomId,
        name: name.text,
        announcement: announcement.text,
        backgroundUrl: backgroundUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الغرفة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickBackground() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      final url = await service.uploadRoomBackground(widget.roomId, file);
      await service.saveRoomBackground(widget.roomId, url);
      setState(() => backgroundUrl = url);
      await save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر رفع الخلفية: $e')));
      }
    }
  }

  Future<void> addModerator() async {
    final members = await service.roomMembers(widget.roomId);
    if (!mounted) {
      return;
    }
    final user = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF151827),
      builder: (_) => MemberPicker(members: members),
    );
    if (user == null) {
      return;
    }
    await service.addRoomModerator(widget.roomId, user['id'].toString());
    setState(() => moderators = service.roomModeratorsForOwner(widget.roomId));
  }

  Future<void> uploadMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) {
      return;
    }
    final file = result.files.single;
    try {
      final track = await service.uploadRoomMusic(
        widget.roomId,
        file.name,
        file.bytes!,
        file.extension ?? 'mp3',
        'audio/${file.extension ?? 'mpeg'}',
      );
      await service.addRoomPlaylistTrack(widget.roomId, track['id'].toString());
      setState(() => music = service.roomMusic(widget.roomId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إضافة الموسيقى: $e')));
      }
    }
  }

  Future<void> playTrack(Map<String, dynamic> track) async {
    final url = track['audio_url']?.toString();
    if (url == null || url.isEmpty) {
      return;
    }
    await player.setUrl(url);
    await player.play();
    await service.setActiveRoomMusic(
      widget.roomId,
      musicId: track['id']?.toString(),
      ownerId: service.uid,
      isPlaying: true,
      startedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1020),
      appBar: AppBar(
        title: const Text('إعدادات الغرفة'),
        backgroundColor: const Color(0xFF151827),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (backgroundUrl?.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                backgroundUrl!,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          _Field(controller: name, label: 'اسم الغرفة'),
          _Field(controller: announcement, label: 'إعلان الغرفة'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: pickBackground,
            icon: const Icon(Icons.wallpaper),
            label: const Text('تغيير خلفية الغرفة'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'جاري الحفظ...' : 'حفظ بيانات الغرفة'),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'مشرفو الغرفة',
            action: widget.isOwner ? addModerator : null,
            actionText: 'إضافة مشرف',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: moderators,
            builder: (_, snapshot) {
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                children: rows.map((row) {
                  final profile = Map<String, dynamic>.from(
                    row['profiles'] as Map? ?? const {},
                  );
                  return ListTile(
                    leading: _Avatar(url: profile['avatar_url']?.toString()),
                    title: Text(
                      profile['username']?.toString() ?? 'مستخدم',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: widget.isOwner
                        ? IconButton(
                            onPressed: () async {
                              await service.removeRoomModerator(
                                widget.roomId,
                                row['user_id'].toString(),
                              );
                              setState(() {
                                moderators = service.roomModeratorsForOwner(
                                  widget.roomId,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.redAccent,
                            ),
                          )
                        : null,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'موسيقى الغرفة',
            action: widget.isOwner ? uploadMusic : null,
            actionText: 'إضافة موسيقى',
          ),
          const Text(
            'التشغيل والتحكم متاحان للمالك والمشرف فقط، والحالة تحفظ لحظيًا في Supabase.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: music,
            builder: (_, snapshot) {
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                children: rows.map((track) {
                  return ListTile(
                    leading: const Icon(
                      Icons.music_note,
                      color: Color(0xFFFFD166),
                    ),
                    title: Text(
                      track['title']?.toString() ?? 'موسيقى',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      track['artist']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: IconButton(
                      onPressed: () => playTrack(track),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF151827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.actionText,
  });
  final String title;
  final VoidCallback? action;
  final String actionText;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      if (action != null)
        TextButton(onPressed: action, child: Text(actionText)),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
    child: url?.isNotEmpty == true ? null : const Icon(Icons.person),
  );
}

class MemberPicker extends StatelessWidget {
  const MemberPicker({super.key, required this.members});
  final List<Map<String, dynamic>> members;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'اختر مستخدمًا ليصبح مشرفًا',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      ...members.map((row) {
        final p = Map<String, dynamic>.from(row['profiles'] as Map? ?? row);
        return ListTile(
          onTap: () => Navigator.pop(context, p),
          leading: _Avatar(url: p['avatar_url']?.toString()),
          title: Text(
            p['username']?.toString() ?? 'مستخدم',
            style: const TextStyle(color: Colors.white),
          ),
        );
      }),
    ],
  );
}

class GiftSheet extends StatefulWidget {
  const GiftSheet({
    super.key,
    required this.roomId,
    required this.members,
    required this.gifts,
    required this.service,
  });
  final String roomId;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> gifts;
  final SakiService service;
  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> {
  String? recipient;
  bool sending = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صندوق الهدايا',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text(
          'اختر المستخدم ثم الهدية لإرسالها بشكل حقيقي.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: recipient,
          hint: const Text(
            'اختر مستلمًا',
            style: TextStyle(color: Colors.white70),
          ),
          dropdownColor: const Color(0xFF20263D),
          items: widget.members.map((row) {
            final p = Map<String, dynamic>.from(row['profiles'] as Map? ?? row);
            return DropdownMenuItem(
              value: p['id']?.toString() ?? row['user_id']?.toString(),
              child: Text(
                p['username']?.toString() ?? 'مستخدم',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => recipient = value),
        ),
        SizedBox(
          height: 120,
          child: GridView.count(
            crossAxisCount: 4,
            children: widget.gifts
                .map(
                  (gift) => InkWell(
                    onTap: recipient == null || sending
                        ? null
                        : () => send(gift),
                    child: Column(
                      children: [
                        Text(
                          gift['icon']?.toString() ?? '🎁',
                          style: const TextStyle(fontSize: 32),
                        ),
                        Text(
                          gift['name']?.toString() ?? 'هدية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  Future<void> send(Map<String, dynamic> gift) async {
    setState(() => sending = true);
    try {
      await widget.service.sendRoomGift(
        roomId: widget.roomId,
        recipientId: recipient!,
        giftId: gift['id'].toString(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم إرسال الهدية')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}
