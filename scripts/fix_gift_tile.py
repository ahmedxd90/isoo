from pathlib import Path
p = Path('/home/ubuntu/isoo/lib/features/rooms/room_gift_ranking_sheet.dart')
s = p.read_text()
needle = "        ],\n      ),\n    );\n  }\n}\n\nclass GiftGoldBadge"
replacement = "        ],\n      ),\n      ),\n    );\n  }\n}\n\nclass GiftGoldBadge"
if needle not in s:
    raise SystemExit('tile ending not found')
p.write_text(s.replace(needle, replacement, 1))
