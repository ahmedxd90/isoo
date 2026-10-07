-- PostgREST cannot resolve two overloaded RPCs when the request omits p_request_id.
-- The application uses the four-argument function; remove the obsolete five-argument version.
drop function if exists public.send_room_luck_gift(uuid, uuid, uuid, integer, uuid);

revoke all on function public.send_room_luck_gift(uuid, uuid, uuid, integer) from public;
grant execute on function public.send_room_luck_gift(uuid, uuid, uuid, integer) to authenticated;
