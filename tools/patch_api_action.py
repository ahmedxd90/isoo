from pathlib import Path

path = Path('/tmp/api.php')
text = path.read_text()
old = "$action = $_GET['action'] ?? 'health';"
new = "$requestBody = body();\n$action = $_GET['action'] ?? ($requestBody['action'] ?? 'health');"
if old not in text:
    raise SystemExit('target line not found')
path.write_text(text.replace(old, new, 1))
print('patched', path, 'bytes', path.stat().st_size)
