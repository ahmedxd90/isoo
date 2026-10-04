-- SAKI Farm timing: 30 seconds to bet, then 5 seconds to show the result.
create or replace function public.saki_wheel_current_round(p_room_id uuid)
returns public.saki_wheel_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.saki_wheel_rounds;
  n bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.rooms rm where rm.id = p_room_id and coalesce(rm.is_active, true)) then raise exception 'game_room_not_available'; end if;
  if not exists (select 1 from public.room_members m where m.room_id = p_room_id and m.user_id = auth.uid())
     and not exists (select 1 from public.rooms rm where rm.id = p_room_id and rm.owner_id = auth.uid()) then raise exception 'not_room_member'; end if;
  update public.saki_wheel_rounds set status = 'settled'
    where room_id = p_room_id and status = 'result' and result_ends_at <= now();
  select * into r from public.saki_wheel_rounds
    where room_id = p_room_id and status in ('betting', 'result') order by id desc limit 1;
  if r.id is not null then return r; end if;
  select coalesce(max(round_no), 0) + 1 into n from public.saki_wheel_rounds where room_id = p_room_id;
  insert into public.saki_wheel_rounds(room_id, round_no, status, betting_ends_at, result_ends_at)
    values (p_room_id, n, 'betting', now() + interval '30 seconds', now() + interval '35 seconds')
    on conflict (room_id, round_no) do nothing;
  select * into r from public.saki_wheel_rounds where room_id = p_room_id order by id desc limit 1;
  return r;
end;
$$;

grant execute on function public.saki_wheel_current_round(uuid) to authenticated;
