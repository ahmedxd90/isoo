-- Real room settings: cover image, seat count, mic permissions, default theme,
-- zero membership/reward fees, and automatic owner follow.

create or replace function public.saki_room_settings_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.seat_count := case when new.seat_count in (5,10,15,20) then new.seat_count else 10 end;
  new.mic_permission := case when new.mic_permission in ('everyone','followers','moderators','owner') then new.mic_permission else 'everyone' end;
  new.theme_key := 'default';
  new.membership_fee := 0;
  new.reward_rate := 0;
  return new;
end;
$$;

drop trigger if exists saki_room_settings_guard on public.rooms;
create trigger saki_room_settings_guard
before insert or update of seat_count,mic_permission,theme_key,membership_fee,reward_rate
on public.rooms
for each row execute function public.saki_room_settings_guard();

-- Existing rooms are normalized without changing names, images, or owners.
update public.rooms
set seat_count = case when seat_count in (5,10,15,20) then seat_count else 10 end,
    mic_permission = case when mic_permission in ('everyone','followers','moderators','owner') then mic_permission else 'everyone' end,
    theme_key = 'default', membership_fee = 0, reward_rate = 0;

-- Owners automatically follow their own room, including existing rooms.
insert into public.room_follows(room_id,user_id)
select r.id,r.owner_id from public.rooms r
where r.owner_id is not null
on conflict (room_id,user_id) do nothing;

create or replace function public.saki_auto_follow_room_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is not null then
    insert into public.room_follows(room_id,user_id)
    values(new.id,new.owner_id)
    on conflict (room_id,user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists saki_auto_follow_room_owner on public.rooms;
create trigger saki_auto_follow_room_owner
after insert on public.rooms
for each row execute function public.saki_auto_follow_room_owner();

create or replace function public.claim_room_seat(p_room_id uuid,p_seat_no integer)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare
  v_user_id uuid := auth.uid();
  v_occupied_by uuid;
  v_room public.rooms%rowtype;
  v_is_owner boolean;
  v_is_moderator boolean;
  v_is_follower boolean;
begin
  if v_user_id is null then raise exception 'not_authenticated'; end if;
  select * into v_room from public.rooms where id=p_room_id for update;
  if v_room.id is null then raise exception 'room_not_found'; end if;
  if p_seat_no < 1 or p_seat_no > v_room.seat_count then raise exception 'invalid_seat'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=v_user_id)
     and v_room.owner_id <> v_user_id then raise exception 'room_membership_required'; end if;

  v_is_owner := v_room.owner_id = v_user_id;
  v_is_moderator := exists(select 1 from public.room_moderators where room_id=p_room_id and user_id=v_user_id);
  v_is_follower := v_is_owner or exists(select 1 from public.room_follows where room_id=p_room_id and user_id=v_user_id);
  if v_room.mic_permission='owner' and not v_is_owner then raise exception 'mic_permission_denied'; end if;
  if v_room.mic_permission='moderators' and not (v_is_owner or v_is_moderator) then raise exception 'mic_permission_denied'; end if;
  if v_room.mic_permission='followers' and not (v_is_owner or v_is_moderator or v_is_follower) then raise exception 'mic_permission_denied'; end if;

  select user_id into v_occupied_by from public.room_seats where room_id=p_room_id and seat_no=p_seat_no for update;
  if v_occupied_by is not null and v_occupied_by <> v_user_id then raise exception 'seat_occupied'; end if;
  delete from public.room_seats where room_id=p_room_id and user_id=v_user_id;
  insert into public.room_seats(room_id,seat_no,user_id,is_speaking) values(p_room_id,p_seat_no,v_user_id,false);
  return jsonb_build_object('room_id',p_room_id,'seat_no',p_seat_no,'user_id',v_user_id);
end;
$$;

revoke all on function public.claim_room_seat(uuid,integer) from public;
grant execute on function public.claim_room_seat(uuid,integer) to authenticated;
