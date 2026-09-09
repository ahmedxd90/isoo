create or replace function public.leave_room(p_room_id uuid)
returns boolean
language plpgsql security definer set search_path=public as $$
begin
  delete from public.room_seats where room_id=p_room_id and user_id=auth.uid();
  delete from public.room_members where room_id=p_room_id and user_id=auth.uid();
  return true;
end; $$;
revoke all on function public.leave_room(uuid) from public;
grant execute on function public.leave_room(uuid) to authenticated;
