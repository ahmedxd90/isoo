alter table public.profiles add column if not exists vip_level integer not null default 0;
alter table public.profiles add column if not exists vip_expires_at timestamptz;

create table if not exists public.vip_transactions (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  vip_level integer not null check (vip_level between 1 and 7),
  price bigint not null,
  transaction_type text not null check (transaction_type in ('purchase','gift')),
  created_at timestamptz not null default now()
);
alter table public.vip_transactions enable row level security;
drop policy if exists "vip_transactions_own" on public.vip_transactions;
create policy "vip_transactions_own" on public.vip_transactions for select using (auth.uid() = sender_id or auth.uid() = recipient_id);

create or replace function public.purchase_vip(p_level integer)
returns table(vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare cost bigint; expires timestamptz;
begin
  if p_level < 1 or p_level > 7 then raise exception 'invalid_vip_level'; end if;
  cost := case p_level when 1 then 60000 when 2 then 200000 when 3 then 500000 when 4 then 1000000 when 5 then 2000000 when 6 then 4000000 when 7 then 8000000 end;
  select coalesce(vip_expires_at, now()) into expires from profiles where id = auth.uid();
  if expires < now() then expires := now(); end if;
  update saki_account_modules set gold_coins = gold_coins - cost, vip_level = greatest(vip_level, p_level), vip_label = 'VIP ' || p_level, updated_at = now() where user_id = auth.uid() and gold_coins >= cost;
  if not found then raise exception 'insufficient_gold'; end if;
  expires := expires + interval '30 days';
  update profiles set vip_level = greatest(vip_level, p_level), vip_expires_at = expires, updated_at = now() where id = auth.uid();
  insert into vip_transactions(sender_id, recipient_id, vip_level, price, transaction_type) values(auth.uid(), auth.uid(), p_level, cost, 'purchase');
  return query select p_level, expires, m.gold_coins from saki_account_modules m where m.user_id = auth.uid();
end; $$;

create or replace function public.gift_vip(p_saki_id bigint, p_level integer)
returns table(recipient_username text, vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare cost bigint; target uuid; expires timestamptz;
begin
  if p_level < 1 or p_level > 7 then raise exception 'invalid_vip_level'; end if;
  cost := case p_level when 1 then 60000 when 2 then 200000 when 3 then 500000 when 4 then 1000000 when 5 then 2000000 when 6 then 4000000 when 7 then 8000000 end;
  select id into target from profiles where saki_id = p_saki_id;
  if target is null then raise exception 'recipient_not_found'; end if;
  update saki_account_modules set gold_coins = gold_coins - cost, updated_at = now() where user_id = auth.uid() and gold_coins >= cost;
  if not found then raise exception 'insufficient_gold'; end if;
  select coalesce(vip_expires_at, now()) into expires from profiles where id = target;
  if expires < now() then expires := now(); end if;
  expires := expires + interval '30 days';
  update profiles set vip_level = greatest(vip_level, p_level), vip_expires_at = expires, updated_at = now() where id = target;
  update saki_account_modules set vip_level = greatest(vip_level, p_level), vip_label = 'VIP ' || p_level, updated_at = now() where user_id = target;
  insert into vip_transactions(sender_id, recipient_id, vip_level, price, transaction_type) values(auth.uid(), target, p_level, cost, 'gift');
  return query select p.username, p.vip_level, p.vip_expires_at, m.gold_coins from profiles p join saki_account_modules m on m.user_id = p.id where p.id = target;
end; $$;
revoke all on function public.purchase_vip(integer) from public;
revoke all on function public.gift_vip(bigint, integer) from public;
grant execute on function public.purchase_vip(integer) to authenticated;
grant execute on function public.gift_vip(bigint, integer) to authenticated;
