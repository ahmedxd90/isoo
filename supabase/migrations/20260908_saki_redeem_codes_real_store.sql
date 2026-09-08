-- Keep legacy Trace item_id values intact, while new redeem rewards use the real StorePage catalog.
alter table public.saki_redeem_code_rewards
  add column if not exists store_product_id uuid references public.saki_store_products(id) on delete restrict;

alter table public.saki_redeem_code_rewards drop constraint if exists saki_redeem_reward_shape;
alter table public.saki_redeem_code_rewards add constraint saki_redeem_reward_shape check (
  (reward_type = 'store_item' and (item_id is not null or store_product_id is not null))
  or (reward_type = 'gold' and item_id is null and store_product_id is null)
  or (reward_type = 'vip' and item_id is null and store_product_id is null and vip_level is not null)
  or (reward_type = 'wealth' and item_id is null and store_product_id is null and wealth_level is not null)
);

create or replace function public.admin_create_redeem_code(p_code text, p_expires_at timestamptz, p_max_uses integer, p_rewards jsonb)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid; v_reward jsonb; v_code text := upper(trim(p_code));
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  if v_code !~ '^[A-Z0-9]{6,12}$' then raise exception 'invalid_code_format'; end if;
  if p_expires_at <= now() then raise exception 'invalid_expiry'; end if;
  if p_max_uses is null or p_max_uses < 1 then raise exception 'invalid_max_uses'; end if;
  if jsonb_typeof(coalesce(p_rewards, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_rewards, '[]'::jsonb)) = 0 then raise exception 'rewards_required'; end if;
  insert into public.saki_redeem_codes(code, expires_at, max_uses, created_by) values (v_code, p_expires_at, p_max_uses, auth.uid()) returning id into v_id;
  for v_reward in select * from jsonb_array_elements(p_rewards) loop
    insert into public.saki_redeem_code_rewards(code_id, reward_type, store_product_id, item_id, quantity, duration_days, vip_level, wealth_level)
    values (v_id, v_reward->>'reward_type', nullif(v_reward->>'store_product_id','')::uuid, nullif(v_reward->>'item_id','')::uuid, coalesce(nullif(v_reward->>'quantity','')::bigint,1), nullif(v_reward->>'duration_days','')::integer, nullif(v_reward->>'vip_level','')::integer, nullif(v_reward->>'wealth_level','')::integer);
  end loop;
  return v_id;
exception when unique_violation then raise exception 'code_already_exists';
end; $$;

create or replace function public.admin_redeem_codes()
returns table(id uuid, code text, expires_at timestamptz, max_uses integer, used_count integer, is_active boolean, created_at timestamptz, rewards jsonb)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  return query select c.id,c.code,c.expires_at,c.max_uses,c.used_count,c.is_active,c.created_at,
    coalesce((select jsonb_agg(jsonb_build_object('reward_type',r.reward_type,'item_id',r.item_id,'store_product_id',r.store_product_id,'quantity',r.quantity,'duration_days',r.duration_days,'vip_level',r.vip_level,'wealth_level',r.wealth_level,'item',case when r.store_product_id is null then null else jsonb_build_object('id',i.id,'name',i.name,'category',i.category,'price',i.price,'media_type',i.media_type,'media_url',i.media_url,'thumbnail_url',i.thumbnail_url,'duration_days',i.duration_days,'discounted_price',i.discounted_price) end) order by r.created_at) from public.saki_redeem_code_rewards r left join public.saki_store_products i on i.id=r.store_product_id where r.code_id=c.id),'[]'::jsonb)
  from public.saki_redeem_codes c order by c.created_at desc limit 200;
end; $$;

create or replace function public.redeem_saki_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_code public.saki_redeem_codes%rowtype; v_use public.saki_redeem_code_uses%rowtype; v_reward record; v_item public.saki_store_products%rowtype; v_item_expiry timestamptz; v_vip_expiry timestamptz; v_vip_level integer; v_wealth_level integer; v_gold bigint:=0; v_rewards jsonb:='[]'::jsonb; v_now timestamptz:=now();
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_code from public.saki_redeem_codes where code=upper(trim(p_code)) for update;
  if v_code.id is null then raise exception 'code_not_found'; end if;
  if not v_code.is_active then raise exception 'code_inactive'; end if;
  if v_code.expires_at<=v_now then raise exception 'code_expired'; end if;
  if v_code.used_count>=v_code.max_uses then raise exception 'code_max_uses_reached'; end if;
  if exists(select 1 from public.saki_redeem_code_uses where code_id=v_code.id and user_id=auth.uid()) then raise exception 'code_already_used'; end if;
  insert into public.saki_redeem_code_uses(code_id,user_id) values(v_code.id,auth.uid()) returning * into v_use;
  update public.saki_redeem_codes set used_count=used_count+1 where id=v_code.id;
  for v_reward in select * from public.saki_redeem_code_rewards where code_id=v_code.id order by created_at loop
    if v_reward.reward_type='gold' then
      update public.saki_account_modules set gold_coins=gold_coins+v_reward.quantity,updated_at=v_now where user_id=auth.uid();
      if not found then insert into public.saki_account_modules(user_id,gold_coins) values(auth.uid(),v_reward.quantity); end if;
      v_gold:=v_gold+v_reward.quantity; v_rewards:=v_rewards||jsonb_build_array(jsonb_build_object('type','gold','quantity',v_reward.quantity));
    elsif v_reward.reward_type='store_item' and v_reward.store_product_id is not null then
      select * into v_item from public.saki_store_products where id=v_reward.store_product_id and is_active=true;
      if v_item.id is null then raise exception 'store_item_not_found'; end if;
      v_item_expiry:=case when v_reward.duration_days is null then null else v_now+make_interval(days=>v_reward.duration_days) end;
      insert into public.saki_store_inventory(user_id,product_id,quantity,equipped,purchased_at,expires_at) values(auth.uid(),v_item.id,greatest(1,v_reward.quantity::integer),false,v_now,v_item_expiry)
        on conflict(user_id,product_id) do update set quantity=public.saki_store_inventory.quantity+excluded.quantity,purchased_at=v_now,expires_at=case when excluded.expires_at is null then null else greatest(coalesce(public.saki_store_inventory.expires_at,v_now),excluded.expires_at) end;
      v_rewards:=v_rewards||jsonb_build_array(jsonb_build_object('type','store_item','item_id',v_item.id,'name',v_item.name,'category',v_item.category,'media_type',v_item.media_type,'media_url',v_item.media_url,'thumbnail_url',v_item.thumbnail_url,'duration_days',v_reward.duration_days,'expires_at',v_item_expiry));
    elsif v_reward.reward_type='vip' then
      select greatest(coalesce(p.vip_level,0),v_reward.vip_level),case when p.vip_expires_at is null or p.vip_expires_at<=v_now then v_now else p.vip_expires_at end into v_vip_level,v_vip_expiry from public.profiles p where p.id=auth.uid() for update;
      v_vip_expiry:=v_vip_expiry+make_interval(days=>coalesce(v_reward.duration_days,30)); update public.profiles set vip_level=v_vip_level,vip_expires_at=v_vip_expiry,updated_at=v_now where id=auth.uid(); update public.saki_account_modules set vip_level=v_vip_level,vip_label='VIP '||v_vip_level,updated_at=v_now where user_id=auth.uid(); v_rewards:=v_rewards||jsonb_build_array(jsonb_build_object('type','vip','level',v_vip_level,'duration_days',v_reward.duration_days,'expires_at',v_vip_expiry));
    elsif v_reward.reward_type='wealth' then
      select greatest(coalesce(p.wealth_level,0),v_reward.wealth_level) into v_wealth_level from public.profiles p where p.id=auth.uid() for update; update public.profiles set wealth_level=v_wealth_level,updated_at=v_now where id=auth.uid(); update public.saki_account_modules set wealth_level=v_wealth_level,updated_at=v_now where user_id=auth.uid(); v_rewards:=v_rewards||jsonb_build_array(jsonb_build_object('type','wealth','level',v_wealth_level));
    end if;
  end loop;
  return jsonb_build_object('code',v_code.code,'redeemed_at',v_use.redeemed_at,'rewards',v_rewards,'gold_coins',v_gold);
end; $$;
revoke all on function public.admin_create_redeem_code(text,timestamptz,integer,jsonb) from public;
revoke all on function public.admin_redeem_codes() from public;
revoke all on function public.redeem_saki_code(text) from public;
grant execute on function public.admin_create_redeem_code(text,timestamptz,integer,jsonb) to authenticated;
grant execute on function public.admin_redeem_codes() to authenticated;
grant execute on function public.redeem_saki_code(text) to authenticated;
