from pathlib import Path
p=Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s=p.read_text()
s=s.replace('''                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: image == null
''','''                      GestureDetector(
                        onTap: _showRoomInfo,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: image == null
''',1)
s=s.replace('''                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
''','''                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showRoomInfo,
                          child: Column(
''',1)
s=s.replace('''                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showOnline,
''','''                          ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showOnline,
''',1)
old='''                      IconButton(
                        onPressed: _send,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
'''
new='''                      IconButton(
                        onPressed: _showEmojiPanel,
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.amberAccent),
                      ),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _showRoomTools,
                        icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                      ),
                      IconButton(
'''
s=s.replace(old,new,1)
p.write_text(s)
print('patched room header and toolbar')
