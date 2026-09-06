create or replace function public.admin_delete_room_gift(p_gift_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_saki_super_admin() then
    raise exception 'super_admin_required';
  end if;
  delete from public.room_gift_inventory where gift_id = p_gift_id;
  delete from public.room_gifts where gift_id = p_gift_id;
  delete from public.room_gift_catalog where id = p_gift_id;
  if not found then
    raise exception 'gift_not_found';
  end if;
  return true;
end;
$$;
revoke all on function public.admin_delete_room_gift(uuid) from public;
grant execute on function public.admin_delete_room_gift(uuid) to authenticated;
