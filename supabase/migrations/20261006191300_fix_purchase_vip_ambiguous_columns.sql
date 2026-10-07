-- Resolve PL/pgSQL OUT-parameter/column ambiguity in purchase_vip.
-- Preserve the live 1..11 price schedule, wallet charging, 30-day renewal,
-- transaction logging, and return shape; only qualify table-column references.
create or replace function public.purchase_vip(p_level integer)
returns table(vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare
  cost bigint;
  expires timestamptz;
begin
  if p_level < 1 or p_level > 11 then
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
    when 8 then 10000000
    when 9 then 12000000
    when 10 then 20000000
    when 11 then 500000000
  end;

  -- vip_expires_at is also an OUT parameter, so always qualify the column.
  select coalesce(p.vip_expires_at, now())
    into expires
    from public.profiles as p
   where p.id = auth.uid();

  if expires < now() then
    expires := now();
  end if;

  update public.saki_account_modules as m
     set gold_coins = m.gold_coins - cost,
         vip_level = greatest(m.vip_level, p_level),
         vip_label = 'VIP ' || p_level,
         updated_at = now()
   where m.user_id = auth.uid()
     and m.gold_coins >= cost;
  if not found then
    raise exception 'insufficient_gold';
  end if;

  expires := expires + interval '30 days';
  update public.profiles as p
     set vip_level = greatest(p.vip_level, p_level),
         vip_expires_at = expires,
         updated_at = now()
   where p.id = auth.uid();

  insert into public.vip_transactions
    (sender_id, recipient_id, vip_level, price, transaction_type)
  values
    (auth.uid(), auth.uid(), p_level, cost, 'purchase');

  return query
  select p_level, expires, m.gold_coins
    from public.saki_account_modules as m
   where m.user_id = auth.uid();
end;
$$;
