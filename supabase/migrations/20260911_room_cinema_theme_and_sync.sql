-- Shared cinema mode for rooms. State is persistent so returning viewers resume at the live position.
alter table public.rooms add column if not exists theme_key text not null default 'default';

create table if not exists public.room_cinema_state (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  video_id text,
  video_title text,
  is_playing boolean not null default false,
  position_seconds double precision not null default 0,
  volume double precision not null default 1,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);

alter table public.room_cinema_state enable row level security;
drop policy if exists room_cinema_state_read on public.room_cinema_state;
create policy room_cinema_state_read on public.room_cinema_state for select to authenticated
using (exists(select 1 from public.room_members rm where rm.room_id=room_cinema_state.room_id and rm.user_id=auth.uid()) or exists(select 1 from public.rooms r where r.id=room_cinema_state.room_id and r.owner_id=auth.uid()));
drop policy if exists room_cinema_state_write on public.room_cinema_state;
create policy room_cinema_state_write on public.room_cinema_state for all to authenticated
using (exists(select 1 from public.rooms r where r.id=room_cinema_state.room_id and (r.owner_id=auth.uid() or exists(select 1 from public.room_moderators m where m.room_id=r.id and m.user_id=auth.uid()))))
with check (exists(select 1 from public.rooms r where r.id=room_cinema_state.room_id and (r.owner_id=auth.uid() or exists(select 1 from public.room_moderators m where m.room_id=r.id and m.user_id=auth.uid()))));

create or replace function public.set_room_cinema_state(
  p_room_id uuid,
  p_video_id text,
  p_video_title text,
  p_is_playing boolean,
  p_position_seconds double precision,
  p_volume double precision
) returns public.room_cinema_state
language plpgsql security definer set search_path=public
as $$
declare v public.room_cinema_state;
begin
  if not exists(select 1 from public.rooms r where r.id=p_room_id and (r.owner_id=auth.uid() or exists(select 1 from public.room_moderators m where m.room_id=r.id and m.user_id=auth.uid()))) then raise exception 'cinema_control_denied'; end if;
  insert into public.room_cinema_state(room_id,video_id,video_title,is_playing,position_seconds,volume,changed_by,changed_at)
  values(p_room_id,nullif(trim(p_video_id),''),nullif(trim(p_video_title),''),coalesce(p_is_playing,false),greatest(coalesce(p_position_seconds,0),0),least(greatest(coalesce(p_volume,1),0),1),auth.uid(),now())
  on conflict(room_id) do update set video_id=excluded.video_id,video_title=excluded.video_title,is_playing=excluded.is_playing,position_seconds=excluded.position_seconds,volume=excluded.volume,changed_by=excluded.changed_by,changed_at=excluded.changed_at
  returning * into v;
  return v;
end;
$$;
revoke all on function public.set_room_cinema_state(uuid,text,text,boolean,double precision,double precision) from public;
grant execute on function public.set_room_cinema_state(uuid,text,text,boolean,double precision,double precision) to authenticated;

do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_cinema_state') then alter publication supabase_realtime add table public.room_cinema_state; end if;
end $$;

-- Cinema mode always uses ten seats and the dedicated cinema visual theme.
create or replace function public.saki_cinema_theme_guard()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.theme_key='cinema' then new.seat_count:=10; end if;
  return new;
end;
$$;
drop trigger if exists saki_cinema_theme_guard on public.rooms;
create trigger saki_cinema_theme_guard before insert or update of theme_key,seat_count on public.rooms for each row execute function public.saki_cinema_theme_guard();
