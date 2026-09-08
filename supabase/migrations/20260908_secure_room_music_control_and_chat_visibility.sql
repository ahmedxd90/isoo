create or replace function public.set_room_music_state(p_room_id uuid,p_music_id uuid,p_owner_id uuid,p_is_playing boolean,p_position_seconds double precision default 0,p_volume double precision default 1)
returns void language plpgsql security definer set search_path=public as $$
declare current_owner uuid; selected_owner uuid; room_owner uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select r.owner_id into room_owner from public.rooms r where r.id=p_room_id and r.is_active=true;
  if room_owner is null then raise exception 'room_not_found'; end if;
  if not (room_owner=auth.uid() or exists(select 1 from public.room_members rm where rm.room_id=p_room_id and rm.user_id=auth.uid())) then raise exception 'room_member_required'; end if;
  select s.owner_id into current_owner from public.room_music_state s where s.room_id=p_room_id;
  if p_music_id is not null then
    select m.owner_id into selected_owner from public.room_music m where m.id=p_music_id;
    if selected_owner is null or selected_owner<>p_owner_id then raise exception 'music_owner_mismatch'; end if;
  end if;
  if not (room_owner=auth.uid() or current_owner=auth.uid() or p_owner_id=auth.uid()) then raise exception 'music_control_forbidden'; end if;
  if p_position_seconds<0 or p_volume<0 or p_volume>1 then raise exception 'invalid_music_state'; end if;
  insert into public.room_music_state(room_id,music_id,owner_id,is_playing,position_seconds,volume,updated_by,updated_at)
  values(p_room_id,p_music_id,p_owner_id,coalesce(p_is_playing,false),p_position_seconds,p_volume,auth.uid(),now())
  on conflict(room_id) do update set music_id=excluded.music_id,owner_id=excluded.owner_id,is_playing=excluded.is_playing,position_seconds=excluded.position_seconds,volume=excluded.volume,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
end; $$;
revoke all on function public.set_room_music_state(uuid,uuid,uuid,boolean,double precision,double precision) from public;
grant execute on function public.set_room_music_state(uuid,uuid,uuid,boolean,double precision,double precision) to authenticated;
drop policy if exists room_music_state_write on public.room_music_state;
create policy room_music_state_write on public.room_music_state for all to authenticated
using (exists(select 1 from public.room_members rm where rm.room_id=room_music_state.room_id and rm.user_id=auth.uid()) or exists(select 1 from public.rooms r where r.id=room_music_state.room_id and r.owner_id=auth.uid()))
with check (exists(select 1 from public.room_members rm where rm.room_id=room_music_state.room_id and rm.user_id=auth.uid()) or exists(select 1 from public.rooms r where r.id=room_music_state.room_id and r.owner_id=auth.uid()));
drop policy if exists room_music_read on public.room_music;
create policy room_music_read on public.room_music for select to authenticated
using (owner_id=auth.uid() or exists(select 1 from public.room_music_state s join public.room_members rm on rm.room_id=s.room_id and rm.user_id=auth.uid() where s.music_id=room_music.id));
drop policy if exists room_music_state_read on public.room_music_state;
create policy room_music_state_read on public.room_music_state for select to authenticated
using (exists(select 1 from public.room_members rm where rm.room_id=room_music_state.room_id and rm.user_id=auth.uid()) or exists(select 1 from public.rooms r where r.id=room_music_state.room_id and r.owner_id=auth.uid()));
