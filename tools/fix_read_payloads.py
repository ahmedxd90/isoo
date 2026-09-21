from pathlib import Path
p = Path('/tmp/api.php')
s = p.read_text()
s = s.replace('$row=null;', '')
s = s.replace(',shipping_agent,created_at FROM profiles', ',created_at FROM profiles')
p.write_text(s)
