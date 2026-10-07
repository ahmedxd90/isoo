-- Royal special seats: host and legend. Only room owners and moderators can claim them.
create table if not exists public.room_special_seats (
  room_id uuid not null references public.rooms(id) on delete cascade,
  seat_kind text not null check (seat_kind in ('host', 'legend')),
  user_id uuid references public.profiles(id) on delete set null,
  joined_at timestamptz not null default now(),
  is_speaking boolean not null default false,
  primary key (room_id, seat_kind)
);

create index if not exists room_special_seats_user_id_idx
  on public.room_special_seats(user_id);

alter table public.room_special_seats enable row level security;
drop policy if exists room_special_seats_read on public.room_special_seats;
create policy room_special_seats_read on public.room_special_seats
  for select to authenticated using (
    exists (
      select 1 from public.room_members m
      where m.room_id = room_special_seats.room_id and m.user_id = auth.uid()
    )
    or exists (
      select 1 from public.rooms r
      where r.id = room_special_seats.room_id and r.owner_id = auth.uid()
    )
  );

create or replace function public.claim_room_special_seat(
  p_room_id uuid,
  p_seat_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_is_owner boolean;
  v_is_moderator boolean;
begin
  if v_user_id is null then raise exception 'not_authenticated'; end if;
  if p_seat_kind not in ('host', 'legend') then raise exception 'invalid_special_seat'; end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if v_room.id is null then raise exception 'room_not_found'; end if;
  v_is_owner := v_room.owner_id = v_user_id;
  v_is_moderator := exists (
    select 1 from public.room_moderators
    where room_id = p_room_id and user_id = v_user_id
  );
  if not (v_is_owner or v_is_moderator) then
    raise exception 'room_admin_required';
  end if;
  delete from public.room_special_seats where room_id = p_room_id and user_id = v_user_id;
  insert into public.room_special_seats(room_id, seat_kind, user_id, is_speaking)
  values (p_room_id, p_seat_kind, v_user_id, false)
  on conflict (room_id, seat_kind) do update
    set user_id = excluded.user_id, joined_at = now(), is_speaking = false;
  return jsonb_build_object(
    'room_id', p_room_id, 'seat_kind', p_seat_kind, 'user_id', v_user_id
  );
end;
$$;

revoke all on function public.claim_room_special_seat(uuid, text) from public;
grant execute on function public.claim_room_special_seat(uuid, text) to authenticated;

create or replace function public.leave_room_special_seat(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.room_special_seats
  where room_id = p_room_id and user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.leave_room_special_seat(uuid) from public;
grant execute on function public.leave_room_special_seat(uuid) to authenticated;

create or replace function public.set_room_special_seat_speaking(
  p_room_id uuid,
  p_speaking boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.room_special_seats
  set is_speaking = p_speaking
  where room_id = p_room_id and user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.set_room_special_seat_speaking(uuid, boolean) from public;
grant execute on function public.set_room_special_seat_speaking(uuid, boolean) to authenticated;

alter publication supabase_realtime add table public.room_special_seats;
