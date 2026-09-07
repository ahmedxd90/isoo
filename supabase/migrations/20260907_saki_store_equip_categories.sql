create or replace function public.saki_store_equip(p_product_id uuid,p_equipped boolean)
returns boolean language plpgsql security definer set search_path=public as $$
declare c text;
begin
  select p.category into c
  from saki_store_products p
  join saki_store_inventory i on i.product_id=p.id
  where p.id=p_product_id and i.user_id=auth.uid();
  if c is null then raise exception 'store_item_not_owned'; end if;
  update saki_store_inventory i
  set equipped=false
  from saki_store_products p
  where i.product_id=p.id and i.user_id=auth.uid() and p.category=c;
  update saki_store_inventory set equipped=p_equipped
  where user_id=auth.uid() and product_id=p_product_id;
  return true;
end; $$;
revoke all on function public.saki_store_equip(uuid,boolean) from public;
grant execute on function public.saki_store_equip(uuid,boolean) to authenticated;
