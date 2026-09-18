from pathlib import Path
old='164807497226-s2shfippqh2gsnaplrmqhf292mp9iobm.apps.googleusercontent.com'
new='164807497226-k7h6m36u5rphd0th08em1u233nu1hfhq.apps.googleusercontent.com'
files=[Path('/tmp/api.php'),Path('tools/extend_google_api.py'),Path('lib/features/auth/login_page.dart')]
for p in files:
    text=p.read_text()
    if old not in text:
        raise SystemExit(f'old client id not found in {p}')
    p.write_text(text.replace(old,new))
    print(p)
