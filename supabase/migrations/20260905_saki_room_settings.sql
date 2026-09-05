alter table public.rooms add column if not exists seat_count integer not null default 10;
alter table public.rooms add column if not exists background_url text;

alter table public.rooms drop constraint if exists rooms_seat_count_allowed;
alter table public.rooms add constraint rooms_seat_count_allowed check (seat_count in (5, 10, 15, 20));

-- Owners can update only their own room settings; the public room policies keep reads available.
drop policy if exists saki_rooms_owner_update on public.rooms;
create policy saki_rooms_owner_update on public.rooms
  for update using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Room owners need to see and revoke bans from their own room.
drop policy if exists room_bans_owner_manage on public.room_bans;
create policy room_bans_owner_manage on public.room_bans
  for all using (exists (select 1 from public.rooms r where r.id = room_bans.room_id and r.owner_id = auth.uid()))
  with check (exists (select 1 from public.rooms r where r.id = room_bans.room_id and r.owner_id = auth.uid()));

-- Make room backgrounds publicly readable after upload.
drop policy if exists saki_room_background_insert on storage.objects;
create policy saki_room_background_insert on storage.objects
  for insert with check (bucket_id = 'rooms' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists saki_room_background_update on storage.objects;
create policy saki_room_background_update on storage.objects
  for update using (bucket_id = 'rooms' and (storage.foldername(name))[1] = auth.uid()::text);
