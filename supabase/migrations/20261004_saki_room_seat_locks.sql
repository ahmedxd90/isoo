-- Native room seat locking for owners and moderators.
create table if not exists public.room_seat_locks (
  room_id uuid not null references public.rooms(id) on delete cascade,
  seat_no integer not null check (seat_no >= 1 and seat_no <= 20),
  locked_by uuid not null references public.profiles(id) on delete cascade,
  locked_at timestamptz not null default now(),
  primary key (room_id, seat_no)
);

create index if not exists room_seat_locks_room_idx
  on public.room_seat_locks(room_id);

alter table public.room_seat_locks enable row level security;

drop policy if exists room_seat_locks_select on public.room_seat_locks;
create policy room_seat_locks_select on public.room_seat_locks
  for select to authenticated
  using (
    exists (
      select 1 from public.rooms r
      where r.id = room_id and r.owner_id = auth.uid()
    )
    or exists (
      select 1 from public.room_members m
      where m.room_id = room_seat_locks.room_id and m.user_id = auth.uid()
    )
  );

create or replace function public.set_room_seat_locked(
  p_room_id uuid,
  p_seat_no integer,
  p_locked boolean
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_allowed boolean;
  v_seat_count integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select seat_count into v_seat_count
  from public.rooms
  where id = p_room_id;

  if v_seat_count is null then
    raise exception 'room_not_found';
  end if;
  if p_seat_no < 1 or p_seat_no > v_seat_count then
    raise exception 'invalid_seat';
  end if;

  select exists (
    select 1 from public.rooms where id = p_room_id and owner_id = v_user_id
  ) or exists (
    select 1 from public.room_moderators
    where room_id = p_room_id and user_id = v_user_id
  ) into v_allowed;

  if not v_allowed then
    raise exception 'seat_lock_permission_denied';
  end if;

  if p_locked then
    insert into public.room_seat_locks(room_id, seat_no, locked_by)
    values (p_room_id, p_seat_no, v_user_id)
    on conflict (room_id, seat_no) do update
      set locked_by = excluded.locked_by, locked_at = now();
  else
    delete from public.room_seat_locks
    where room_id = p_room_id and seat_no = p_seat_no;
  end if;

  return p_locked;
end;
$$;

grant execute on function public.set_room_seat_locked(uuid, integer, boolean)
to authenticated;

create or replace function public.claim_room_seat(p_room_id uuid, p_seat_no integer)
returns jsonb
language plpgsql
security definer
set search_path to public
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
  select * into v_room from public.rooms where id = p_room_id for update;
  if v_room.id is null then raise exception 'room_not_found'; end if;
  if p_seat_no < 1 or p_seat_no > v_room.seat_count then raise exception 'invalid_seat'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=v_user_id)
     and v_room.owner_id<>v_user_id then raise exception 'room_membership_required'; end if;

  v_is_owner := v_room.owner_id = v_user_id;
  v_is_moderator := exists(select 1 from public.room_moderators where room_id=p_room_id and user_id=v_user_id);
  v_is_follower := v_is_owner or exists(select 1 from public.room_follows where room_id=p_room_id and user_id=v_user_id);

  if v_room.mic_permission='owner' and not v_is_owner then raise exception 'mic_permission_denied'; end if;
  if v_room.mic_permission='moderators' and not(v_is_owner or v_is_moderator) then raise exception 'mic_permission_denied'; end if;
  if v_room.mic_permission='followers' and not(v_is_owner or v_is_moderator or v_is_follower) then raise exception 'mic_permission_denied'; end if;
  if exists(select 1 from public.room_seat_locks where room_id=p_room_id and seat_no=p_seat_no)
     and not(v_is_owner or v_is_moderator) then raise exception 'seat_locked'; end if;

  select user_id into v_occupied_by from public.room_seats
  where room_id=p_room_id and seat_no=p_seat_no for update;
  if v_occupied_by is not null and v_occupied_by<>v_user_id then raise exception 'seat_occupied'; end if;

  delete from public.room_seats where room_id=p_room_id and user_id=v_user_id;
  insert into public.room_seats(room_id,seat_no,user_id,is_speaking)
  values(p_room_id,p_seat_no,v_user_id,false);
  return jsonb_build_object('room_id',p_room_id,'seat_no',p_seat_no,'user_id',v_user_id);
end;
$$;

grant execute on function public.claim_room_seat(uuid, integer) to authenticated;
