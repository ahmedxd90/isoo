create table if not exists public.saki_redeem_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses > 0),
  used_count integer not null default 0 check (used_count >= 0),
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.saki_redeem_code_rewards (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.saki_redeem_codes(id) on delete cascade,
  reward_type text not null check (reward_type in ('store_item','gold','vip','wealth')),
  item_id uuid references public.trace_store_catalog(id) on delete restrict,
  quantity bigint not null default 1 check (quantity > 0),
  duration_days integer check (duration_days is null or duration_days > 0),
  vip_level integer check (vip_level is null or vip_level between 1 and 7),
  wealth_level integer check (wealth_level is null or wealth_level >= 0),
  created_at timestamptz not null default now(),
  constraint saki_redeem_reward_shape check (
    (reward_type = 'store_item' and item_id is not null)
    or (reward_type = 'gold' and item_id is null)
    or (reward_type = 'vip' and item_id is null and vip_level is not null)
    or (reward_type = 'wealth' and item_id is null and wealth_level is not null)
  )
);

create table if not exists public.saki_redeem_code_uses (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.saki_redeem_codes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  unique (code_id, user_id)
);

create index if not exists saki_redeem_codes_active_idx on public.saki_redeem_codes(is_active, expires_at);
create index if not exists saki_redeem_code_uses_user_idx on public.saki_redeem_code_uses(user_id, redeemed_at desc);

alter table public.saki_redeem_codes enable row level security;
alter table public.saki_redeem_code_rewards enable row level security;
alter table public.saki_redeem_code_uses enable row level security;

drop policy if exists saki_redeem_codes_admin_read on public.saki_redeem_codes;
create policy saki_redeem_codes_admin_read on public.saki_redeem_codes for select to authenticated using (public.is_saki_super_admin());
drop policy if exists saki_redeem_code_rewards_admin_read on public.saki_redeem_code_rewards;
create policy saki_redeem_code_rewards_admin_read on public.saki_redeem_code_rewards for select to authenticated using (public.is_saki_super_admin());
drop policy if exists saki_redeem_code_uses_admin_read on public.saki_redeem_code_uses;
create policy saki_redeem_code_uses_admin_read on public.saki_redeem_code_uses for select to authenticated using (public.is_saki_super_admin() or user_id = auth.uid());

create or replace function public.admin_create_redeem_code(
  p_code text,
  p_expires_at timestamptz,
  p_max_uses integer,
  p_rewards jsonb
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
  v_reward jsonb;
  v_code text := upper(trim(p_code));
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  if v_code !~ '^[A-Z0-9]{6,12}$' then raise exception 'invalid_code_format'; end if;
  if p_expires_at <= now() then raise exception 'invalid_expiry'; end if;
  if p_max_uses is null or p_max_uses < 1 then raise exception 'invalid_max_uses'; end if;
  if jsonb_typeof(coalesce(p_rewards, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_rewards, '[]'::jsonb)) = 0 then raise exception 'rewards_required'; end if;
  insert into public.saki_redeem_codes(code, expires_at, max_uses, created_by)
    values (v_code, p_expires_at, p_max_uses, auth.uid()) returning id into v_id;
  for v_reward in select * from jsonb_array_elements(p_rewards) loop
    insert into public.saki_redeem_code_rewards(code_id, reward_type, item_id, quantity, duration_days, vip_level, wealth_level)
    values (
      v_id,
      v_reward->>'reward_type',
      nullif(v_reward->>'item_id', '')::uuid,
      coalesce(nullif(v_reward->>'quantity','')::bigint, 1),
      nullif(v_reward->>'duration_days','')::integer,
      nullif(v_reward->>'vip_level','')::integer,
      nullif(v_reward->>'wealth_level','')::integer
    );
  end loop;
  return v_id;
exception when unique_violation then
  raise exception 'code_already_exists';
end; $$;

create or replace function public.admin_redeem_codes()
returns table(id uuid, code text, expires_at timestamptz, max_uses integer, used_count integer, is_active boolean, created_at timestamptz, rewards jsonb)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  return query
  select c.id, c.code, c.expires_at, c.max_uses, c.used_count, c.is_active, c.created_at,
    coalesce((select jsonb_agg(jsonb_build_object('reward_type', r.reward_type, 'item_id', r.item_id, 'quantity', r.quantity, 'duration_days', r.duration_days, 'vip_level', r.vip_level, 'wealth_level', r.wealth_level, 'item', case when r.item_id is null then null else jsonb_build_object('id', i.id, 'name', i.name, 'asset_key', i.asset_key, 'category', i.category) end) order by r.created_at) from public.saki_redeem_code_rewards r left join public.trace_store_catalog i on i.id = r.item_id where r.code_id = c.id), '[]'::jsonb)
  from public.saki_redeem_codes c order by c.created_at desc limit 200;
end; $$;

create or replace function public.redeem_saki_code(p_code text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_code public.saki_redeem_codes%rowtype;
  v_use public.saki_redeem_code_uses%rowtype;
  v_reward record;
  v_item public.trace_store_catalog%rowtype;
  v_item_expiry timestamptz;
  v_vip_expiry timestamptz;
  v_vip_level integer;
  v_wealth_level integer;
  v_gold bigint := 0;
  v_rewards jsonb := '[]'::jsonb;
  v_now timestamptz := now();
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_code from public.saki_redeem_codes where code = upper(trim(p_code)) for update;
  if v_code.id is null then raise exception 'code_not_found'; end if;
  if not v_code.is_active then raise exception 'code_inactive'; end if;
  if v_code.expires_at <= v_now then raise exception 'code_expired'; end if;
  if v_code.used_count >= v_code.max_uses then raise exception 'code_max_uses_reached'; end if;
  if exists(select 1 from public.saki_redeem_code_uses where code_id = v_code.id and user_id = auth.uid()) then raise exception 'code_already_used'; end if;

  insert into public.saki_redeem_code_uses(code_id, user_id) values(v_code.id, auth.uid()) returning * into v_use;
  update public.saki_redeem_codes set used_count = used_count + 1 where id = v_code.id;

  for v_reward in select * from public.saki_redeem_code_rewards where code_id = v_code.id order by created_at loop
    if v_reward.reward_type = 'gold' then
      update public.saki_account_modules set gold_coins = gold_coins + v_reward.quantity, updated_at = v_now where user_id = auth.uid();
      if not found then insert into public.saki_account_modules(user_id, gold_coins) values(auth.uid(), v_reward.quantity); end if;
      v_gold := v_gold + v_reward.quantity;
      v_rewards := v_rewards || jsonb_build_array(jsonb_build_object('type','gold','quantity',v_reward.quantity));
    elsif v_reward.reward_type = 'store_item' then
      select * into v_item from public.trace_store_catalog where id = v_reward.item_id and is_active = true;
      if v_item.id is null then raise exception 'store_item_not_found'; end if;
      v_item_expiry := case when v_reward.duration_days is null then null else v_now + make_interval(days => v_reward.duration_days) end;
      insert into public.trace_store_inventory(user_id, item_id, purchased_at, expires_at, is_active) values(auth.uid(), v_item.id, v_now, v_item_expiry, true)
        on conflict(user_id, item_id) do update set purchased_at=v_now, expires_at=case when excluded.expires_at is null then null else greatest(coalesce(public.trace_store_inventory.expires_at, v_now), excluded.expires_at) end, is_active=true;
      v_rewards := v_rewards || jsonb_build_array(jsonb_build_object('type','store_item','item_id',v_item.id,'name',v_item.name,'asset_key',v_item.asset_key,'category',v_item.category,'duration_days',v_reward.duration_days,'expires_at',v_item_expiry));
    elsif v_reward.reward_type = 'vip' then
      select greatest(coalesce(p.vip_level,0), v_reward.vip_level), case when p.vip_expires_at is null or p.vip_expires_at <= v_now then v_now else p.vip_expires_at end into v_vip_level, v_vip_expiry from public.profiles p where p.id = auth.uid() for update;
      v_vip_expiry := v_vip_expiry + make_interval(days => coalesce(v_reward.duration_days, 30));
      update public.profiles set vip_level=v_vip_level, vip_expires_at=v_vip_expiry, updated_at=v_now where id=auth.uid();
      update public.saki_account_modules set vip_level=v_vip_level, vip_label='VIP ' || v_vip_level, updated_at=v_now where user_id=auth.uid();
      v_rewards := v_rewards || jsonb_build_array(jsonb_build_object('type','vip','level',v_vip_level,'duration_days',v_reward.duration_days,'expires_at',v_vip_expiry));
    elsif v_reward.reward_type = 'wealth' then
      select greatest(coalesce(p.wealth_level,0), v_reward.wealth_level) into v_wealth_level from public.profiles p where p.id=auth.uid() for update;
      update public.profiles set wealth_level=v_wealth_level, updated_at=v_now where id=auth.uid();
      update public.saki_account_modules set wealth_level=v_wealth_level, updated_at=v_now where user_id=auth.uid();
      v_rewards := v_rewards || jsonb_build_array(jsonb_build_object('type','wealth','level',v_wealth_level));
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
