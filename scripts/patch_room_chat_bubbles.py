from pathlib import Path
p=Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s=p.read_text()
start=s.index('                          final msg = messages[i - 1];')
end=s.index('                        },\n                      );', start)
new='''                          final msg = messages[i - 1];
                          final senderId = msg['sender_id'] as String? ?? '';
                          final messageType = msg['message_type'] as String? ?? 'chat';
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _service.userProfile(senderId),
                            builder: (_, profileSnap) {
                              final profile = profileSnap.data ?? const <String, dynamic>{};
                              final username = profile['username'] as String? ?? 'عضو';
                              final body = msg['body'] as String? ?? '';
                              final isSpecial = messageType == 'join' || messageType == 'seat';
                              final isEmoji = messageType == 'emoji';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14), border: isSpecial ? Border.all(color: Colors.amber.withValues(alpha: .35)) : null),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  SakiAvatar(url: profile['avatar_url'] as String?, label: username, radius: 17),
                                  const SizedBox(width: 8),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(username, style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text(body, style: TextStyle(color: Colors.white, fontSize: isEmoji ? 28 : 13)),
                                  ])),
                                ]),
                              );
                            },
                          );
'''
s=s[:start]+new+s[end:]
p.write_text(s)
print('patched chat bubbles')
