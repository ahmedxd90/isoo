from pathlib import Path
import re
s=Path('lib/core/data/saki_service.dart').read_text()
api=Path('/tmp/api.php').read_text()
actions=sorted(set(re.findall(r"\$action\s*===\s*'([^']+)'",api)))
print('API_ACTIONS', len(actions))
print('\n'.join(actions))
print('\nSUPABASE_METHODS')
pat=re.compile(r'^  (?:Future|Stream|void|String|bool|int|double)<?[^\n]*?\s+(\w+)\([^\n]*',re.M)
starts=list(pat.finditer(s))
for i,m in enumerate(starts):
    end=starts[i+1].start() if i+1<len(starts) else len(s)
    body=s[m.start():end]
    if 'client.' in body or 'Supabase' in body or '.storage' in body:
        calls=sorted(set(re.findall(r'client\.(?:from|rpc|storage|auth)',body)))
        print(f'{m.group(1)}\t{calls}\t{body.count("client.")}')
print('\nDIRECT_FILES')
for p in sorted(Path('lib').rglob('*.dart')):
    t=p.read_text(errors='ignore')
    if re.search(r'supabase_flutter|Supabase\.instance|client\.(?:from|rpc|storage|auth)',t): print(p)
