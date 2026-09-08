alter table public.profiles
  add column if not exists vip_frame_enabled boolean not null default true;

update public.profiles p
set vip_frame_enabled = exists (
  select 1
  from public.saki_store_inventory i
  join public.saki_store_products sp on sp.id = i.product_id
  where i.user_id = p.id and sp.category = 'frame' and i.equipped = true
);

create or replace function public.saki_store_equip(p_product_id uuid,p_equipped boolean)
returns boolean language plpgsql security definer set search_path=public as $$
declare c text; owner_id uuid;
begin
  select p.category, i.user_id into c, owner_id
  from saki_store_products p join saki_store_inventory i on i.product_id=p.id
  where p.id=p_product_id and i.user_id=auth.uid();
  if c is null then raise exception 'store_item_not_owned'; end if;
  update saki_store_inventory i set equipped=false from saki_store_products p
    where i.product_id=p.id and i.user_id=auth.uid() and p.category=c;
  update saki_store_inventory set equipped=p_equipped
    where user_id=auth.uid() and product_id=p_product_id;
  if c = 'frame' then
    update profiles set vip_frame_enabled=p_equipped, updated_at=now() where id=auth.uid();
  end if;
  return true;
end; $$;
revoke all on function public.saki_store_equip(uuid,boolean) from public;
grant execute on function public.saki_store_equip(uuid,boolean) to authenticated;
