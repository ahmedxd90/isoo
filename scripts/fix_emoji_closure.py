from pathlib import Path
p=Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s=p.read_text()
needle='''                .toList(),
                ),
          ),
        ),
      ),
    );
  }

  void _messageSnack'''
replacement='''                .toList(),
          ),
        ),
      ),
    );
  }

  void _messageSnack'''
if needle not in s:
    raise SystemExit('needle not found')
p.write_text(s.replace(needle,replacement,1))
print('fixed emoji closure')
