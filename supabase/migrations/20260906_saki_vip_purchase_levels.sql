-- VIP is purchased with gold from the authenticated user's wallet.
-- The selected level is the purchased level (not an upgrade-only operation).
drop function if exists public.purchase_vip(integer);

create or replace function public.purchase_vip(p_level integer)
returns table(vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  cost bigint;
  expires timestamptz;
begin
  if p_level < 1 or p_level > 7 then
    raise exception 'invalid_vip_level';
  end if;

  cost := case p_level
    when 1 then 60000
    when 2 then 200000
    when 3 then 500000
    when 4 then 1000000
    when 5 then 2000000
    when 6 then 4000000
    when 7 then 8000000
  end;

  select coalesce(vip_expires_at, now())
    into expires
    from public.profiles
   where id = auth.uid();

  if expires < now() then
    expires := now();
  end if;

  update public.saki_account_modules
     set gold_coins = gold_coins - cost,
         vip_level = p_level,
         vip_label = 'VIP ' || p_level,
         updated_at = now()
   where user_id = auth.uid()
     and gold_coins >= cost;

  if not found then
    raise exception 'insufficient_gold';
  end if;

  expires := expires + interval '30 days';

  update public.profiles
     set vip_level = p_level,
         vip_expires_at = expires,
         updated_at = now()
   where id = auth.uid();

  insert into public.vip_transactions(
    sender_id, recipient_id, vip_level, price, transaction_type
  ) values (
    auth.uid(), auth.uid(), p_level, cost, 'purchase'
  );

  return query
  select p_level, expires, m.gold_coins
    from public.saki_account_modules m
   where m.user_id = auth.uid();
end;
$$;

revoke all on function public.purchase_vip(integer) from public;
grant execute on function public.purchase_vip(integer) to authenticated;
