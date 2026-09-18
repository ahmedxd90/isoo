from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
old="""  return preg_match('/^Bearer\\s+(.+)$/i', $h, $m) ? trim($m[1]) : null;
}"""
new="""  if (preg_match('/^Bearer\\s+(.+)$/i', $h, $m)) return trim($m[1]);
  $q=$_GET['access_token'] ?? '';
  return is_string($q) && $q !== '' ? trim($q) : null;
}"""
if old not in s: raise SystemExit('bearer marker missing')
p.write_text(s.replace(old,new,1))
print('patched token compatibility')
