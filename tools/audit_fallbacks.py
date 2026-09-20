from pathlib import Path
import re
s=Path('lib/core/data/saki_service.dart').read_text()
pat=re.compile(r'^  (?:Future|Stream|void|String|bool|int|double)<?[^\n]*?\s+(\w+)\([^\n]*',re.M)
ms=list(pat.finditer(s))
for i,m in enumerate(ms):
 b=s[m.start():ms[i+1].start() if i+1<len(ms) else len(s)]
 if 'client.' in b or 'Supabase' in b:
  print(f'### {m.group(1)} lines {s[:m.start()].count(chr(10))+1}-{s[:m.start()].count(chr(10))+b.count(chr(10))+1}')
  print('API branch:', 'if (apiToken' in b or 'apiToken != null' in b)
  print('\n'.join(x.strip() for x in b.splitlines() if 'client.' in x or 'apiToken' in x or 'return' in x)[:1200])
