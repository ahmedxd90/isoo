from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
s=s.replace("INSERT INTO room_members(room_id,user_id,joined_at,last_seen) VALUES(:r,:u,UTC_TIMESTAMP(),UTC_TIMESTAMP())", "INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP())")
s=s.replace("INSERT INTO room_members(room_id,user_id,joined_at,last_seen) VALUES(:r,:u,UTC_TIMESTAMP(),UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE last_seen=UTC_TIMESTAMP()", "INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE joined_at=joined_at")
s=s.replace("UPDATE room_members SET last_seen=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u", "UPDATE room_members SET joined_at=joined_at WHERE room_id=:r AND user_id=:u")
s=s.replace(" AND rm.last_seen>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 75 SECOND)", "")
p.write_text(s)
