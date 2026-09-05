-- SAKI rooms: numeric nine-digit IDs and one active room per owner.
create sequence if not exists public.saki_room_id_seq minvalue 473692816 start 473692816;

select setval(
  'public.saki_room_id_seq',
  greatest(
    coalesce((select max(room_id::bigint) from public.rooms where room_id ~ '^[0-9]{9}$'), 473692815),
    473692815
  ),
  true
);

update public.rooms
set room_id = lpad(nextval('public.saki_room_id_seq')::text, 9, '0')
where room_id is null or room_id !~ '^[0-9]{9}$';

alter table public.rooms drop constraint if exists rooms_room_id_format;
alter table public.rooms add constraint rooms_room_id_format check (room_id ~ '^[0-9]{9}$');
alter table public.rooms alter column room_id set default lpad(nextval('public.saki_room_id_seq')::text, 9, '0');
create unique index if not exists rooms_room_id_key on public.rooms(room_id);
create unique index if not exists rooms_one_active_owner_key on public.rooms(owner_id) where is_active = true;

-- Keep the public room list readable and permit only the owner to create/update their room.
drop policy if exists "rooms readable" on public.rooms;
create policy "rooms readable" on public.rooms for select using (is_active = true or auth.uid() = owner_id);

drop policy if exists "room owner" on public.rooms;
create policy "room owner" on public.rooms for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
