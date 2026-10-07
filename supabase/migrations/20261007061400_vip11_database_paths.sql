-- Enable VIP 11 across transaction, gift, and redemption-code paths.
-- This migration changes constraints/functions only; it does not assign VIP to any account.

alter table public.vip_transactions
  drop constraint if exists vip_transactions_vip_level_check;
alter table public.vip_transactions
  add constraint vip_transactions_vip_level_check check (vip_level between 1 and 11);

alter table public.saki_redeem_codes
  drop constraint if exists saki_redeem_codes_vip_level_check;
alter table public.saki_redeem_codes
  add constraint saki_redeem_codes_vip_level_check
  check (vip_level is null or vip_level between 1 and 11);

alter table public.saki_redeem_code_rewards
  drop constraint if exists saki_redeem_code_rewards_vip_level_check;
alter table public.saki_redeem_code_rewards
  add constraint saki_redeem_code_rewards_vip_level_check
  check (vip_level is null or vip_level between 1 and 11);

create or replace function public.gift_vip(p_saki_id bigint, p_level integer)
returns table(recipient_username text, vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  cost bigint;
  target uuid;
  expires timestamptz;
  balance bigint;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_level < 1 or p_level > 11 then
    raise exception 'invalid_vip_level';
  end if;

  cost := case p_level
    when 1 then 60000 when 2 then 200000 when 3 then 500000
    when 4 then 1000000 when 5 then 2000000 when 6 then 4000000
    when 7 then 8000000 when 8 then 10000000 when 9 then 12000000
    when 10 then 20000000 when 11 then 500000000
  end;

  select p.id into target
    from public.profiles as p
   where p.saki_id = p_saki_id
   for update;
  if target is null then
    raise exception 'recipient_not_found';
  end if;
  if target = auth.uid() then
    raise exception 'cannot_gift_self';
  end if;

  update public.saki_account_modules
     set gold_coins = gold_coins - cost,
         updated_at = now()
   where user_id = auth.uid()
     and gold_coins >= cost;
  if not found then
    raise exception 'insufficient_gold';
  end if;

  select coalesce(p.vip_expires_at, now())
    into expires
    from public.profiles as p
   where p.id = target;
  if expires < now() then
    expires := now();
  end if;
  expires := expires + interval '30 days';

  update public.profiles as p
     set vip_level = greatest(p.vip_level, p_level),
         vip_expires_at = expires,
         updated_at = now()
   where p.id = target;

  update public.saki_account_modules as m
     set vip_level = greatest(m.vip_level, p_level),
         vip_label = 'VIP ' || p_level,
         updated_at = now()
   where m.user_id = target;

  insert into public.vip_transactions
    (sender_id, recipient_id, vip_level, price, transaction_type)
  values (auth.uid(), target, p_level, cost, 'gift');

  select m.gold_coins into balance
    from public.saki_account_modules as m
   where m.user_id = auth.uid();
  return query
    select p.username, p.vip_level, p.vip_expires_at, balance
      from public.profiles as p
     where p.id = target;
end;
$$;
revoke all on function public.gift_vip(bigint, integer) from public;
grant execute on function public.gift_vip(bigint, integer) to authenticated;
