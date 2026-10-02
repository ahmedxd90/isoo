-- Completing a profile updates gender in addition to the already-approved
-- profile fields. RLS still permits changes only to the caller's own row.
grant update (gender) on table public.profiles to authenticated;

-- gift_type is a legacy primary key retained for compatibility. New catalog
-- rows created by the admin form omit it, so let PostgreSQL generate a unique
-- value instead of weakening the key or rewriting preserved catalog entries.
alter table public.room_gift_catalog
  alter column gift_type set default ('custom_' || gen_random_uuid()::text);
