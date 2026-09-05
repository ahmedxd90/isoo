from pathlib import Path
p=Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s=p.read_text()
s=s.replace("subtitle: const Text('إعدادات المالك متاحة هنا', style: TextStyle(color: Colors.white60))));", "subtitle: const Text('إعدادات المالك متاحة هنا', style: TextStyle(color: Colors.white60)))));")
s=s.replace("child: Text(emoji, style: const TextStyle(fontSize: 30))).toList()))));", "child: Text(emoji, style: const TextStyle(fontSize: 30))).toList())))));")
p.write_text(s)
print('fixed sheet parentheses')
