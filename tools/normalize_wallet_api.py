from pathlib import Path
import re
p=Path('/tmp/api.php')
s=p.read_text()
block=r'''if ($action === 'wallet' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  try {
    $q=$pdo->prepare('SELECT * FROM saki_account_modules WHERE user_id=:u LIMIT 1');
    $q->execute([':u'=>$u['id']]); $row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) $row=['user_id'=>$u['id'],'wallet_balance'=>0,'gold_coins'=>0,'diamonds'=>0,'vip_level'=>(int)($u['vip_level']??0),'wealth_level'=>(int)($u['wealth_level']??0),'charm_level'=>0,'wallet_currency'=>'gold'];
    respond(['ok'=>true,'data'=>$row]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'wallet_sql:'.$e->getMessage()],500); }
}
'''
s,n=re.subn(r"if \(\$action === 'wallet'.*?(?=\nif \(\$action ===)", '', s, flags=re.S)
if n<1: raise SystemExit('no wallet blocks removed')
marker="if ($action === 'store_products'"
if marker not in s: raise SystemExit('store marker missing')
s=s.replace(marker,block+marker,1)
p.write_text(s)
print('removed',n)
