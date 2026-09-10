-- Real SAKI recharge agents and atomic gold top-ups.
create table if not exists public.shipping_agents (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  saki_coins bigint not null default 0 check (saki_coins >= 0),
  assigned_by uuid references public.profiles(id),
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.shipping_agents enable row level security;
drop policy if exists shipping_agents_self_read on public.shipping_agents;
create policy shipping_agents_self_read on public.shipping_agents for select using (user_id=auth.uid() or public.is_saki_super_admin());

create table if not exists public.shipping_transactions (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  saki_coins bigint not null check (saki_coins > 0),
  gold_coins bigint not null check (gold_coins > 0),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
alter table public.shipping_transactions enable row level security;
drop policy if exists shipping_transactions_own on public.shipping_transactions;
create policy shipping_transactions_own on public.shipping_transactions for select using (agent_id=auth.uid() or recipient_id=auth.uid() or public.is_saki_super_admin());

create or replace function public.is_shipping_agent(p_user_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.shipping_agents where user_id=p_user_id and is_active=true);
$$;

create or replace function public.shipping_agent_dashboard() returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_agent public.shipping_agents%rowtype; v_profile public.profiles%rowtype;
begin
  select * into v_agent from public.shipping_agents where user_id=auth.uid() and is_active=true;
  if v_agent.user_id is null then raise exception 'shipping_agent_not_found'; end if;
  select * into v_profile from public.profiles where id=auth.uid();
  return jsonb_build_object('user_id',v_profile.id,'username',coalesce(v_profile.display_name,v_profile.username),'saki_id',v_profile.saki_id,'avatar_url',v_profile.avatar_url,'saki_coins',v_agent.saki_coins,'gold_per_saki',8000);
end; $$;

create or replace function public.shipping_find_user(p_saki_id bigint) returns table(user_id uuid,username text,saki_id bigint,avatar_url text)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_shipping_agent() then raise exception 'shipping_agent_required'; end if;
  return query select p.id,coalesce(p.display_name,p.username),p.saki_id,p.avatar_url from public.profiles p where p.saki_id=p_saki_id limit 1;
end; $$;

create or replace function public.shipping_topup_user(p_recipient_saki_id bigint,p_saki_coins bigint) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_agent public.shipping_agents%rowtype; v_recipient public.profiles%rowtype; v_gold bigint; v_tx uuid; v_agent_name text;
begin
  if p_saki_coins is null or p_saki_coins <= 0 then raise exception 'invalid_saki_coins'; end if;
  select * into v_agent from public.shipping_agents where user_id=auth.uid() and is_active=true for update;
  if v_agent.user_id is null then raise exception 'shipping_agent_required'; end if;
  select * into v_recipient from public.profiles where saki_id=p_recipient_saki_id;
  if v_recipient.id is null then raise exception 'recipient_not_found'; end if;
  if v_recipient.id=auth.uid() then raise exception 'cannot_topup_self'; end if;
  if v_agent.saki_coins < p_saki_coins then raise exception 'insufficient_saki_coins'; end if;
  v_gold := p_saki_coins * 8000;
  update public.shipping_agents set saki_coins=saki_coins-p_saki_coins,updated_at=now() where user_id=auth.uid() and saki_coins>=p_saki_coins;
  if not found then raise exception 'insufficient_saki_coins'; end if;
  insert into public.saki_account_modules(user_id,gold_coins) values(v_recipient.id,v_gold) on conflict(user_id) do update set gold_coins=public.saki_account_modules.gold_coins+v_gold,updated_at=now();
  insert into public.shipping_transactions(agent_id,recipient_id,saki_coins,gold_coins) values(auth.uid(),v_recipient.id,p_saki_coins,v_gold) returning id into v_tx;
  select coalesce(display_name,username,'وكيل الشحن') into v_agent_name from public.profiles where id=auth.uid();
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data) values(v_recipient.id,auth.uid(),'shipping_topup',v_tx,false,jsonb_build_object('agent_name',v_agent_name,'saki_coins',p_saki_coins,'gold_coins',v_gold,'message','تم شحن رصيدك بعملات ذهبية من وكيل الشحن'));
  return jsonb_build_object('transaction_id',v_tx,'saki_coins',p_saki_coins,'gold_coins',v_gold);
end; $$;

create or replace function public.admin_shipping_agents() returns table(user_id uuid,username text,saki_id bigint,avatar_url text,is_active boolean,saki_coins bigint,assigned_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  return query select a.user_id,coalesce(p.display_name,p.username),p.saki_id,p.avatar_url,a.is_active,a.saki_coins,a.assigned_at from public.shipping_agents a join public.profiles p on p.id=a.user_id order by a.assigned_at desc;
end; $$;

create or replace function public.admin_assign_shipping_agent(p_saki_id bigint) returns void
language plpgsql security definer set search_path=public as $$ declare v_user uuid;
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  select id into v_user from public.profiles where saki_id=p_saki_id;
  if v_user is null then raise exception 'user_not_found'; end if;
  insert into public.shipping_agents(user_id,assigned_by,is_active) values(v_user,auth.uid(),true) on conflict(user_id) do update set is_active=true,updated_at=now();
end; $$;

create or replace function public.admin_remove_shipping_agent(p_user_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  update public.shipping_agents set is_active=false,updated_at=now() where user_id=p_user_id;
end; $$;

create or replace function public.admin_add_saki_coins(p_user_id uuid,p_amount bigint) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  if p_amount <= 0 then raise exception 'invalid_amount'; end if;
  update public.shipping_agents set saki_coins=saki_coins+p_amount,updated_at=now() where user_id=p_user_id;
  if not found then raise exception 'shipping_agent_not_found'; end if;
end; $$;

revoke all on function public.is_shipping_agent(uuid),public.shipping_agent_dashboard(),public.shipping_find_user(bigint),public.shipping_topup_user(bigint,bigint),public.admin_shipping_agents(),public.admin_assign_shipping_agent(bigint),public.admin_remove_shipping_agent(uuid),public.admin_add_saki_coins(uuid,bigint) from public,anon;
grant execute on function public.is_shipping_agent(uuid),public.shipping_agent_dashboard(),public.shipping_find_user(bigint),public.shipping_topup_user(bigint,bigint),public.admin_shipping_agents(),public.admin_assign_shipping_agent(bigint),public.admin_remove_shipping_agent(uuid),public.admin_add_saki_coins(uuid,bigint) to authenticated;
