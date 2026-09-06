create or replace function public.clear_room_messages(p_room_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.rooms where id = p_room_id and owner_id = auth.uid())
     and not exists (select 1 from public.room_moderators where room_id = p_room_id and user_id = auth.uid()) then
    raise exception 'room_admin_required';
  end if;
  delete from public.room_messages where room_id = p_room_id;
end;
$$;
revoke all on function public.clear_room_messages(uuid) from public;
grant execute on function public.clear_room_messages(uuid) to authenticated;

alter table public.room_seats drop constraint if exists room_seats_seat_no_allowed;
alter table public.room_seats add constraint room_seats_seat_no_allowed check (seat_no between 1 and 20);
