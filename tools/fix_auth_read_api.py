from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
s=s.replace(', p.shipping_agent FROM auth_sessions', ' FROM auth_sessions')
s=s.replace("respond(['ok'=>true,'data'=>$row?[$r\now]:[]]);", "respond(['ok'=>true,'data'=>$row?[$row]:[]]);")
s=s.replace("respond(['ok'=>true,'data'=>$row?[$r\now]:[]]);", "respond(['ok'=>true,'data'=>$row?[$row]:[]]);")
p.write_text(s)
