-- Fix: the earlier room settings guard was forcing every theme back to default.
-- Cinema is a valid persistent theme and must reach every open room immediately.
create or replace function public.saki_room_settings_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.seat_count := case when new.seat_count in (5,10,15,20) then new.seat_count else 10 end;
  new.mic_permission := case when new.mic_permission in ('everyone','followers','moderators','owner') then new.mic_permission else 'everyone' end;
  new.theme_key := case when new.theme_key in ('default','cinema') then new.theme_key else 'default' end;
  new.membership_fee := 0;
  new.reward_rate := 0;
  if new.theme_key = 'cinema' then new.seat_count := 10; end if;
  return new;
end;
$$;

-- Ensure all room changes are broadcast to open clients.
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms') then
    alter publication supabase_realtime add table public.rooms;
  end if;
end $$;

-- Reinstall the guard after any older migration and normalize only invalid values.
drop trigger if exists saki_room_settings_guard on public.rooms;
create trigger saki_room_settings_guard
before insert or update of seat_count,mic_permission,theme_key,membership_fee,reward_rate
on public.rooms for each row execute function public.saki_room_settings_guard();

update public.rooms
set theme_key = case when theme_key in ('default','cinema') then theme_key else 'default' end,
    seat_count = case when theme_key = 'cinema' then 10 when seat_count in (5,10,15,20) then seat_count else 10 end;
