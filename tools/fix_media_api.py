from pathlib import Path
p=Path('/tmp/api.php'); s=p.read_text()
s=s.replace("if($content==='' || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'invalid_content'],422);", "if(($content==='' && (!isset($d['media']) || !is_array($d['media']) || count($d['media'])===0)) || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'content_or_media_required'],422);")
p.write_text(s); print('media validation fixed')
