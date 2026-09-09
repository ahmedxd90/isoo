drop function if exists public.claim_room_seat(uuid, integer);
drop function if exists public.leave_room_seat(uuid);

create function public.claim_room_seat(
  p_room_id uuid,
  p_seat_no integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_occupied_by uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_seat_no < 1 or p_seat_no > 20 then
    raise exception 'invalid_seat';
  end if;

  if not exists (
    select 1
    from public.room_members
    where room_id = p_room_id and user_id = v_user_id
  ) then
    raise exception 'room_membership_required';
  end if;

  -- Serialize seat changes for this room so moving seats cannot briefly
  -- expose two seats or overwrite another user during concurrent taps.
  perform 1 from public.rooms where id = p_room_id for update;
  if not found then
    raise exception 'room_not_found';
  end if;

  select user_id into v_occupied_by
  from public.room_seats
  where room_id = p_room_id and seat_no = p_seat_no
  for update;

  if v_occupied_by is not null and v_occupied_by <> v_user_id then
    raise exception 'seat_occupied';
  end if;

  delete from public.room_seats
  where room_id = p_room_id and user_id = v_user_id;

  insert into public.room_seats (room_id, seat_no, user_id, is_speaking)
  values (p_room_id, p_seat_no, v_user_id, false);

  return jsonb_build_object(
    'room_id', p_room_id,
    'seat_no', p_seat_no,
    'user_id', v_user_id
  );
end;
$$;

revoke all on function public.claim_room_seat(uuid, integer) from public;
grant execute on function public.claim_room_seat(uuid, integer) to authenticated;

create function public.leave_room_seat(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.room_seats
  where room_id = p_room_id and user_id = v_user_id;

  return found;
end;
$$;

revoke all on function public.leave_room_seat(uuid) from public;
grant execute on function public.leave_room_seat(uuid) to authenticated;
