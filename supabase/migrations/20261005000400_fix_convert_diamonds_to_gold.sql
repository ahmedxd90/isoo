-- Qualify wallet columns to avoid PL/pgSQL ambiguity with the amount/output names.
create or replace function public.convert_diamonds_to_gold(amount bigint)
returns table(gold_coins bigint, diamonds bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if amount is null or amount <= 0 then
    raise exception 'invalid_amount';
  end if;

  update public.saki_account_modules as wallet
  set diamonds = wallet.diamonds - amount,
      gold_coins = wallet.gold_coins + amount,
      updated_at = now()
  where wallet.user_id = auth.uid()
    and wallet.diamonds >= amount;

  if not found then
    raise exception 'insufficient_diamonds';
  end if;

  return query
    select wallet.gold_coins, wallet.diamonds
    from public.saki_account_modules as wallet
    where wallet.user_id = auth.uid();
end;
$$;

revoke all on function public.convert_diamonds_to_gold(bigint) from public, anon;
grant execute on function public.convert_diamonds_to_gold(bigint) to authenticated;
