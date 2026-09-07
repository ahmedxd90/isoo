-- SAKI room music library and synchronized playback state.
create table if not exists public.room_music (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  storage_path text not null,
  audio_url text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.room_music_state (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  music_id uuid references public.room_music(id) on delete set null,
  is_playing boolean not null default false,
  position_seconds double precision not null default 0,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.room_music enable row level security;
alter table public.room_music_state enable row level security;

drop policy if exists room_music_read on public.room_music;
create policy room_music_read on public.room_music for select to authenticated using (true);
drop policy if exists room_music_insert on public.room_music;
create policy room_music_insert on public.room_music for insert to authenticated with check (
  owner_id = auth.uid() and (
    exists (select 1 from public.rooms r where r.id = room_music.room_id and r.owner_id = auth.uid())
    or exists (select 1 from public.room_moderators m where m.room_id = room_music.room_id and m.user_id = auth.uid())
  )
);
drop policy if exists room_music_delete on public.room_music;
create policy room_music_delete on public.room_music for delete to authenticated using (
  owner_id = auth.uid() or exists (select 1 from public.rooms r where r.id = room_music.room_id and r.owner_id = auth.uid())
);

drop policy if exists room_music_state_read on public.room_music_state;
create policy room_music_state_read on public.room_music_state for select to authenticated using (true);
drop policy if exists room_music_state_write on public.room_music_state;
create policy room_music_state_write on public.room_music_state for all to authenticated using (
  exists (select 1 from public.rooms r where r.id = room_music_state.room_id and r.owner_id = auth.uid())
  or exists (select 1 from public.room_moderators m where m.room_id = room_music_state.room_id and m.user_id = auth.uid())
) with check (
  exists (select 1 from public.rooms r where r.id = room_music_state.room_id and r.owner_id = auth.uid())
  or exists (select 1 from public.room_moderators m where m.room_id = room_music_state.room_id and m.user_id = auth.uid())
);

insert into storage.buckets (id, name, public)
values ('room_music', 'room_music', true)
on conflict (id) do nothing;

drop policy if exists room_music_storage_read on storage.objects;
create policy room_music_storage_read on storage.objects for select to authenticated using (bucket_id = 'room_music');
drop policy if exists room_music_storage_insert on storage.objects;
create policy room_music_storage_insert on storage.objects for insert to authenticated with check (bucket_id = 'room_music' and owner_id = auth.uid()::text);
drop policy if exists room_music_storage_update on storage.objects;
create policy room_music_storage_update on storage.objects for update to authenticated using (bucket_id = 'room_music' and owner_id = auth.uid()::text);
drop policy if exists room_music_storage_delete on storage.objects;
create policy room_music_storage_delete on storage.objects for delete to authenticated using (bucket_id = 'room_music' and owner_id = auth.uid()::text);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.room_music;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.room_music_state;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
