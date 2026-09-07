-- Keep gift history rows removable by super admins without foreign-key failures.
alter table public.gift_announcements
  drop constraint if exists gift_announcements_gift_id_fkey;
alter table public.gift_announcements
  add constraint gift_announcements_gift_id_fkey
  foreign key (gift_id) references public.room_gift_catalog(id) on delete cascade;

alter table public.room_gifts
  drop constraint if exists room_gifts_gift_id_fkey;
alter table public.room_gifts
  add constraint room_gifts_gift_id_fkey
  foreign key (gift_id) references public.room_gift_catalog(id) on delete cascade;

create or replace function public.admin_delete_room_gift(p_gift_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_saki_super_admin() then
    raise exception 'super_admin_required';
  end if;
  delete from public.gift_announcements where gift_id = p_gift_id;
  delete from public.room_gift_inventory where gift_id = p_gift_id;
  delete from public.room_gifts where gift_id = p_gift_id;
  delete from public.room_gift_catalog where id = p_gift_id;
  if not found then raise exception 'gift_not_found'; end if;
  return true;
end;
$$;
revoke all on function public.admin_delete_room_gift(uuid) from public;
grant execute on function public.admin_delete_room_gift(uuid) to authenticated;

-- Required for Supabase Flutter stream() to deliver new seat emoji events.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'room_emoji_events'
  ) then
    alter publication supabase_realtime add table public.room_emoji_events;
  end if;
end $$;
