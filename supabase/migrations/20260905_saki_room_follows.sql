create table if not exists public.room_follows (room_id uuid not null references public.rooms(id) on delete cascade, user_id uuid not null references public.profiles(id) on delete cascade, created_at timestamptz not null default now(), primary key (room_id,user_id));
alter table public.room_follows enable row level security;
drop policy if exists "saki_room_follows_select" on public.room_follows;
create policy "saki_room_follows_select" on public.room_follows for select using (true);
drop policy if exists "saki_room_follows_insert" on public.room_follows;
create policy "saki_room_follows_insert" on public.room_follows for insert with check (auth.uid() = user_id);
drop policy if exists "saki_room_follows_delete" on public.room_follows;
create policy "saki_room_follows_delete" on public.room_follows for delete using (auth.uid() = user_id);
