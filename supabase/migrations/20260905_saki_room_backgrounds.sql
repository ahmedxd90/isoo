create table if not exists public.room_backgrounds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists room_backgrounds_room_created_idx
  on public.room_backgrounds(room_id, created_at desc);

alter table public.room_backgrounds enable row level security;
drop policy if exists room_backgrounds_owner_read on public.room_backgrounds;
create policy room_backgrounds_owner_read on public.room_backgrounds
  for select using (owner_id = auth.uid());
drop policy if exists room_backgrounds_owner_insert on public.room_backgrounds;
create policy room_backgrounds_owner_insert on public.room_backgrounds
  for insert with check (owner_id = auth.uid());
drop policy if exists room_backgrounds_owner_delete on public.room_backgrounds;
create policy room_backgrounds_owner_delete on public.room_backgrounds
  for delete using (owner_id = auth.uid());
