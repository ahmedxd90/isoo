create table if not exists public.room_emojis (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  gif_url text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.room_emoji_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji_id uuid not null references public.room_emojis(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists room_emoji_events_room_created_idx on public.room_emoji_events(room_id, created_at desc);
alter table public.room_emojis enable row level security;
alter table public.room_emoji_events enable row level security;
drop policy if exists room_emojis_read on public.room_emojis;
create policy room_emojis_read on public.room_emojis for select to authenticated using (is_active=true or public.is_saki_super_admin());
drop policy if exists room_emoji_events_read on public.room_emoji_events;
create policy room_emoji_events_read on public.room_emoji_events for select to authenticated using (exists(select 1 from public.room_members m where m.room_id=room_emoji_events.room_id and m.user_id=auth.uid()));
drop policy if exists room_emoji_events_insert on public.room_emoji_events;
create policy room_emoji_events_insert on public.room_emoji_events for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.room_members m where m.room_id=room_emoji_events.room_id and m.user_id=auth.uid()));
drop policy if exists room_emoji_admin_write on public.room_emojis;
create policy room_emoji_admin_write on public.room_emojis for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin());
