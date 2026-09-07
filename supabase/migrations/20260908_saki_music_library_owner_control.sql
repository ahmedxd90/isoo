-- SAKI shared music: each user's library is global, and the song owner controls playback.
alter table public.room_music alter column room_id drop not null;
alter table public.room_music_state add column if not exists owner_id uuid references public.profiles(id) on delete set null;
alter table public.room_music_state add column if not exists volume double precision not null default 1;

update public.room_music_state s
set owner_id = m.owner_id
from public.room_music m
where s.music_id = m.id and s.owner_id is null;

alter table public.room_music drop constraint if exists room_music_room_id_fkey;
alter table public.room_music add constraint room_music_room_id_fkey foreign key (room_id) references public.rooms(id) on delete set null;

create index if not exists room_music_owner_created_idx on public.room_music(owner_id, created_at desc);

drop policy if exists room_music_read on public.room_music;
create policy room_music_read on public.room_music for select to authenticated using (true);

drop policy if exists room_music_insert on public.room_music;
create policy room_music_insert on public.room_music for insert to authenticated with check (owner_id = auth.uid());

drop policy if exists room_music_state_write on public.room_music_state;
create policy room_music_state_write on public.room_music_state for all to authenticated using (
  owner_id = auth.uid()
  or updated_by = auth.uid()
) with check (
  owner_id = auth.uid()
  or updated_by = auth.uid()
);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.room_music_state;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
