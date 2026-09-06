-- Indexes used by the in-room daily, weekly, and monthly gift rankings.
create index if not exists room_gifts_room_created_idx
  on public.room_gifts(room_id, created_at desc);
create index if not exists room_members_room_joined_idx
  on public.room_members(room_id, joined_at desc);
