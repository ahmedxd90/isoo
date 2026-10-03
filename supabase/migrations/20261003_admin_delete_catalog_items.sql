-- Safe, super-admin-only hard deletion for catalog items.
-- Historical rows that point to a deleted catalog item are removed in the same transaction.

alter table public.gift_announcements
  drop constraint if exists gift_announcements_gift_id_fkey;
alter table public.gift_announcements
  add constraint gift_announcements_gift_id_fkey
  foreign key (gift_id) references public.room_gift_catalog(id) on delete cascade;

alter table public.room_gifts
  drop constraint if exists room_gifts_gift_id_fkey;
alter table public.room_gifts
  add constraint room_gifts_gift_id_fkey
  foreign key (gift_id) references public.room_gift_catalog(id) on delete cascade;

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
  delete from public.gift_announcements where gift_id = p_gift_id;
  delete from public.room_gift_inventory where gift_id = p_gift_id;
  delete from public.room_gifts where gift_id = p_gift_id;
  delete from public.room_gift_catalog where id = p_gift_id;
  if not found then raise exception 'gift_not_found'; end if;
  return true;
end;
$$;
revoke all on function public.admin_delete_room_gift(uuid) from public;
grant execute on function public.admin_delete_room_gift(uuid) to authenticated;

create or replace function public.admin_delete_store_product(p_product_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_saki_super_admin() then
    raise exception 'super_admin_required';
  end if;
  -- A redeem code can remain, but its deleted product reward cannot.
  delete from public.saki_redeem_code_rewards where store_product_id = p_product_id;
  delete from public.saki_store_entrance_plays where product_id = p_product_id;
  delete from public.saki_store_inventory where product_id = p_product_id;
  delete from public.saki_store_products where id = p_product_id;
  if not found then raise exception 'store_product_not_found'; end if;
  return true;
end;
$$;
revoke all on function public.admin_delete_store_product(uuid) from public;
grant execute on function public.admin_delete_store_product(uuid) to authenticated;
