-- Host agency wallet finance: diamonds -> USD, USD -> gold, and withdrawal reservations.
-- The rates match the existing host dashboard contract: 250k=13, 500k=26,
-- 1M=52, 2M=102. Gold conversion follows the existing wallet package rate: $1=7,500 gold.

create table if not exists public.host_agency_wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  usd_balance numeric(12,2) not null default 0,
  usd_reserved numeric(12,2) not null default 0,
  total_usd_earned numeric(12,2) not null default 0,
  total_usd_withdrawn numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint host_agency_wallets_nonnegative check (usd_balance >= 0 and usd_reserved >= 0 and usd_reserved <= usd_balance)
);

create table if not exists public.host_agency_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('diamonds_to_usd','usd_to_gold','withdrawal_reserve','withdrawal_release','withdrawal_paid')),
  diamonds bigint not null default 0,
  usd_amount numeric(12,2) not null default 0,
  gold_coins bigint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.host_agency_withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.trace_agencies(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  usd_amount numeric(12,2) not null check (usd_amount > 0),
  channel text not null default 'shipping_agent',
  status text not null default 'pending' check (status in ('pending','approved','rejected','paid','cancelled')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.host_agency_wallets enable row level security;
alter table public.host_agency_wallet_transactions enable row level security;
alter table public.host_agency_withdrawal_requests enable row level security;

drop policy if exists host_agency_wallet_self on public.host_agency_wallets;
create policy host_agency_wallet_self on public.host_agency_wallets for select to authenticated using (user_id = auth.uid());
drop policy if exists host_agency_wallet_transactions_self on public.host_agency_wallet_transactions;
create policy host_agency_wallet_transactions_self on public.host_agency_wallet_transactions for select to authenticated using (user_id = auth.uid());
drop policy if exists host_agency_withdrawals_self on public.host_agency_withdrawal_requests;
create policy host_agency_withdrawals_self on public.host_agency_withdrawal_requests for select to authenticated using (user_id = auth.uid());

create or replace function public.host_agency_diamond_usd_value(p_diamonds bigint)
returns numeric(12,2)
language plpgsql immutable as $$
declare v_usd numeric(12,2) := 0;
begin
  if p_diamonds is null or p_diamonds < 0 then return 0; end if;
  if p_diamonds >= 2000000 then
    v_usd := floor(p_diamonds / 2000000)::numeric * 102
      + case when mod(p_diamonds,2000000) >= 1000000 then 52
             when mod(p_diamonds,2000000) >= 500000 then 26
             when mod(p_diamonds,2000000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 1000000 then
    v_usd := floor(p_diamonds / 1000000)::numeric * 52
      + case when mod(p_diamonds,1000000) >= 500000 then 26
             when mod(p_diamonds,1000000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 500000 then
    v_usd := floor(p_diamonds / 500000)::numeric * 26
      + case when mod(p_diamonds,500000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 250000 then
    v_usd := floor(p_diamonds / 250000)::numeric * 13;
  end if;
  return v_usd;
end; $$;

create or replace function public.host_agency_convert_diamonds_to_usd(p_diamonds bigint)
returns table(usd_balance numeric, usd_reserved numeric, diamonds bigint)
language plpgsql security definer set search_path=public as $$
declare v_usd numeric(12,2); v_wallet public.host_agency_wallets%rowtype;
begin
  if not public.is_host_agency_member(auth.uid()) then raise exception 'host_agency_required'; end if;
  if p_diamonds is null or p_diamonds < 250000 then raise exception 'minimum_250k_diamonds'; end if;
  v_usd := public.host_agency_diamond_usd_value(p_diamonds);
  if v_usd <= 0 then raise exception 'invalid_diamonds'; end if;
  update public.saki_account_modules
    set diamonds = diamonds - p_diamonds, updated_at = now()
    where user_id = auth.uid() and diamonds >= p_diamonds;
  if not found then raise exception 'insufficient_diamonds'; end if;
  insert into public.host_agency_wallets(user_id,usd_balance,total_usd_earned,updated_at)
    values(auth.uid(),v_usd,v_usd,now())
    on conflict(user_id) do update set usd_balance=host_agency_wallets.usd_balance+excluded.usd_balance,total_usd_earned=host_agency_wallets.total_usd_earned+excluded.total_usd_earned,updated_at=now();
  insert into public.host_agency_wallet_transactions(user_id,transaction_type,diamonds,usd_amount,metadata)
    values(auth.uid(),'diamonds_to_usd',p_diamonds,v_usd,jsonb_build_object('rates','250k=13;500k=26;1m=52;2m=102'));
  select * into v_wallet from public.host_agency_wallets where user_id=auth.uid();
  return query select v_wallet.usd_balance,v_wallet.usd_reserved,(select diamonds from public.saki_account_modules where user_id=auth.uid());
end; $$;

create or replace function public.host_agency_convert_usd_to_gold(p_usd numeric)
returns table(usd_balance numeric, usd_reserved numeric, gold_coins bigint)
language plpgsql security definer set search_path=public as $$
declare v_gold bigint; v_wallet public.host_agency_wallets%rowtype;
begin
  if not public.is_host_agency_member(auth.uid()) then raise exception 'host_agency_required'; end if;
  if p_usd is null or p_usd <= 0 then raise exception 'invalid_usd'; end if;
  v_gold := floor(p_usd * 7500)::bigint;
  update public.host_agency_wallets
    set usd_balance=usd_balance-p_usd, updated_at=now()
    where user_id=auth.uid() and usd_balance-usd_reserved >= p_usd;
  if not found then raise exception 'insufficient_usd'; end if;
  update public.saki_account_modules set gold_coins=gold_coins+v_gold,updated_at=now() where user_id=auth.uid();
  insert into public.host_agency_wallet_transactions(user_id,transaction_type,usd_amount,gold_coins,metadata)
    values(auth.uid(),'usd_to_gold',p_usd,v_gold,jsonb_build_object('gold_per_usd',7500));
  select * into v_wallet from public.host_agency_wallets where user_id=auth.uid();
  return query select v_wallet.usd_balance,v_wallet.usd_reserved,(select gold_coins from public.saki_account_modules where user_id=auth.uid());
end; $$;

create or replace function public.host_agency_request_usd_withdrawal(p_usd numeric)
returns uuid
language plpgsql security definer set search_path=public as $$
declare v_agency_id uuid; v_id uuid;
begin
  if not public.is_host_agency_member(auth.uid()) then raise exception 'host_agency_required'; end if;
  if p_usd is null or p_usd <= 0 then raise exception 'invalid_usd'; end if;
  select agency_id into v_agency_id from public.trace_agency_members where user_id=auth.uid() and role='agent' and status='active' limit 1;
  if v_agency_id is null then raise exception 'host_agency_required'; end if;
  update public.host_agency_wallets set usd_reserved=usd_reserved+p_usd,updated_at=now()
    where user_id=auth.uid() and usd_balance-usd_reserved >= p_usd;
  if not found then raise exception 'insufficient_usd'; end if;
  insert into public.host_agency_withdrawal_requests(agency_id,user_id,usd_amount) values(v_agency_id,auth.uid(),p_usd) returning id into v_id;
  insert into public.host_agency_wallet_transactions(user_id,transaction_type,usd_amount,metadata) values(auth.uid(),'withdrawal_reserve',p_usd,jsonb_build_object('request_id',v_id,'channel','shipping_agent'));
  return v_id;
end; $$;

create or replace function public.host_agency_my_withdrawals()
returns table(id uuid,usd_amount numeric,status text,channel text,created_at timestamptz)
language sql security definer set search_path=public as $$
  select id,usd_amount,status,channel,created_at from public.host_agency_withdrawal_requests where user_id=auth.uid() order by created_at desc limit 50;
$$;

create or replace function public.host_agency_wallet_dashboard()
returns jsonb
language sql security definer set search_path=public as $$
  select jsonb_build_object(
    'diamonds', coalesce((select diamonds from public.saki_account_modules where user_id=auth.uid()),0),
    'gold_coins', coalesce((select gold_coins from public.saki_account_modules where user_id=auth.uid()),0),
    'usd_balance', coalesce((select usd_balance from public.host_agency_wallets where user_id=auth.uid()),0),
    'usd_reserved', coalesce((select usd_reserved from public.host_agency_wallets where user_id=auth.uid()),0),
    'total_usd_earned', coalesce((select total_usd_earned from public.host_agency_wallets where user_id=auth.uid()),0),
    'agency', (select jsonb_build_object('id',a.id,'name',a.name,'country',a.country,'agent_code',a.agent_code)
               from public.trace_agency_members m join public.trace_agencies a on a.id=m.agency_id
               where m.user_id=auth.uid() and m.role='agent' and m.status='active' limit 1)
  );
$$;

revoke all on function public.host_agency_diamond_usd_value(bigint),public.host_agency_convert_diamonds_to_usd(bigint),public.host_agency_convert_usd_to_gold(numeric),public.host_agency_request_usd_withdrawal(numeric),public.host_agency_my_withdrawals(),public.host_agency_wallet_dashboard() from anon,public;
grant execute on function public.host_agency_diamond_usd_value(bigint),public.host_agency_convert_diamonds_to_usd(bigint),public.host_agency_convert_usd_to_gold(numeric),public.host_agency_request_usd_withdrawal(numeric),public.host_agency_my_withdrawals(),public.host_agency_wallet_dashboard() to authenticated;
