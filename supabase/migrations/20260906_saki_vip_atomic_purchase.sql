-- Robust atomic VIP purchase using the real gold wallet balance.
-- The account row is locked before charging to prevent races or double spending.
drop function if exists public.purchase_vip(integer);
create function public.purchase_vip(p_level integer)
returns table(vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare
  cost bigint;
  expires timestamptz;
  current_level integer;
  balance bigint;
  new_balance bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_level < 1 or p_level > 7 then raise exception 'invalid_vip_level'; end if;
  cost := case p_level when 1 then 60000 when 2 then 200000 when 3 then 500000 when 4 then 1000000 when 5 then 2000000 when 6 then 4000000 when 7 then 8000000 end;

  select coalesce(p.vip_level, 0), p.vip_expires_at into current_level, expires
    from public.profiles p where p.id = auth.uid() for update;
  if not found then raise exception 'profile_not_found'; end if;
  if expires is null or expires <= now() then current_level := 0; expires := now(); end if;
  if current_level > p_level then raise exception 'vip_level_lower_than_current'; end if;

  select m.gold_coins into balance from public.saki_account_modules m
    where m.user_id = auth.uid() for update;
  if not found then raise exception 'wallet_not_found'; end if;
  if coalesce(balance, 0) < cost then raise exception 'insufficient_gold'; end if;
  new_balance := balance - cost;

  update public.saki_account_modules
     set gold_coins = new_balance, vip_level = p_level,
         vip_label = 'VIP ' || p_level, updated_at = now()
   where user_id = auth.uid();
  expires := expires + interval '30 days';
  update public.profiles
     set vip_level = p_level, vip_expires_at = expires, updated_at = now()
   where id = auth.uid();

  -- Do not roll back the successful purchase if an optional audit insert is blocked.
  begin
    insert into public.vip_transactions(sender_id, recipient_id, vip_level, price, transaction_type)
      values(auth.uid(), auth.uid(), p_level, cost, 'purchase');
  exception when others then
    null;
  end;

  return query select p_level, expires, new_balance;
end; $$;
revoke all on function public.purchase_vip(integer) from public;
grant execute on function public.purchase_vip(integer) to authenticated;
