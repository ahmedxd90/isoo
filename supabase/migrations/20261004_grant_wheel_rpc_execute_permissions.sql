-- Ensure PostgREST authenticated clients can call every wheel RPC.
-- The functions remain SECURITY DEFINER and perform their own auth and membership checks.
grant execute on function public.saki_wheel_current_round(uuid) to authenticated;
grant execute on function public.saki_wheel_place_bet(uuid, text, bigint) to authenticated;
grant execute on function public.saki_wheel_resolve(bigint) to authenticated;
grant execute on function public.ensure_room_membership(uuid) to authenticated;
