-- Real room music player v2: metadata, shared playlist and clock-based sync.
alter table public.room_music add column if not exists artist text not null default 'SAKI Creator';
alter table public.room_music add column if not exists cover_url text;
alter table public.room_music add column if not exists duration_seconds double precision not null default 0;
alter table public.room_music_state add column if not exists started_at timestamptz;
alter table public.room_music_state add column if not exists repeat_mode text not null default 'off' check (repeat_mode in ('off','one','all'));
alter table public.room_music_state add column if not exists shuffle_mode boolean not null default false;

create table if not exists public.room_playlist (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  track_id uuid not null references public.room_music(id) on delete cascade,
  added_by uuid not null references public.profiles(id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  unique(room_id, track_id)
);
alter table public.room_playlist enable row level security;
drop policy if exists room_playlist_read on public.room_playlist;
create policy room_playlist_read on public.room_playlist for select to authenticated using (
  exists (select 1 from public.room_members m where m.room_id=room_playlist.room_id and m.user_id=auth.uid())
  or exists (select 1 from public.rooms r where r.id=room_playlist.room_id and r.owner_id=auth.uid())
);
drop policy if exists room_playlist_write on public.room_playlist;
create policy room_playlist_write on public.room_playlist for all to authenticated using (
  exists (select 1 from public.rooms r where r.id=room_playlist.room_id and r.owner_id=auth.uid())
  or exists (select 1 from public.room_moderators m where m.room_id=room_playlist.room_id and m.user_id=auth.uid())
) with check (
  exists (select 1 from public.rooms r where r.id=room_playlist.room_id and r.owner_id=auth.uid())
  or exists (select 1 from public.room_moderators m where m.room_id=room_playlist.room_id and m.user_id=auth.uid())
);

-- Replace the state RPC with clock and playback-mode fields.
drop function if exists public.set_room_music_state(uuid,uuid,uuid,boolean,double precision,double precision);
create function public.set_room_music_state(
  p_room_id uuid, p_music_id uuid, p_owner_id uuid, p_is_playing boolean,
  p_position_seconds double precision default 0, p_volume double precision default 1,
  p_started_at timestamptz default null, p_repeat_mode text default 'off', p_shuffle_mode boolean default false
) returns void language plpgsql security definer set search_path=public as $$
declare room_owner uuid; current_owner uuid; selected_owner uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select r.owner_id into room_owner from public.rooms r where r.id=p_room_id and r.is_active=true;
  if room_owner is null then raise exception 'room_not_found'; end if;
  if not (room_owner=auth.uid() or exists(select 1 from public.room_members rm where rm.room_id=p_room_id and rm.user_id=auth.uid())) then raise exception 'room_member_required'; end if;
  if p_music_id is not null then
    select m.owner_id into selected_owner from public.room_music m where m.id=p_music_id;
    if selected_owner is null or selected_owner<>p_owner_id then raise exception 'music_owner_mismatch'; end if;
  end if;
  select s.owner_id into current_owner from public.room_music_state s where s.room_id=p_room_id;
  if not (room_owner=auth.uid() or current_owner=auth.uid() or p_owner_id=auth.uid() or exists(select 1 from public.room_moderators m where m.room_id=p_room_id and m.user_id=auth.uid())) then raise exception 'music_control_forbidden'; end if;
  if p_position_seconds<0 or p_volume<0 or p_volume>1 then raise exception 'invalid_music_state'; end if;
  if p_repeat_mode not in ('off','one','all') then raise exception 'invalid_repeat_mode'; end if;
  insert into public.room_music_state(room_id,music_id,owner_id,is_playing,position_seconds,volume,started_at,repeat_mode,shuffle_mode,updated_by,updated_at)
  values(p_room_id,p_music_id,p_owner_id,coalesce(p_is_playing,false),p_position_seconds,p_volume,case when p_is_playing then coalesce(p_started_at,now()) else null end,p_repeat_mode,p_shuffle_mode,auth.uid(),now())
  on conflict(room_id) do update set music_id=excluded.music_id,owner_id=excluded.owner_id,is_playing=excluded.is_playing,position_seconds=excluded.position_seconds,volume=excluded.volume,started_at=excluded.started_at,repeat_mode=excluded.repeat_mode,shuffle_mode=excluded.shuffle_mode,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
end; $$;
revoke all on function public.set_room_music_state(uuid,uuid,uuid,boolean,double precision,double precision,timestamptz,text,boolean) from public;
grant execute on function public.set_room_music_state(uuid,uuid,uuid,boolean,double precision,double precision,timestamptz,text,boolean) to authenticated;

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_playlist; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
