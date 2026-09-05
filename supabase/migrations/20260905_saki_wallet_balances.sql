alter table public.saki_account_modules add column if not exists gold_coins bigint not null default 0;
alter table public.saki_account_modules add column if not exists diamonds bigint not null default 0;
update public.saki_account_modules set diamonds = 0 where diamonds is null or diamonds = 50;

create or replace function public.convert_diamonds_to_gold(amount bigint)
returns table(gold_coins bigint, diamonds bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if amount is null or amount <= 0 then
    raise exception 'invalid_amount';
  end if;
  update public.saki_account_modules
  set diamonds = diamonds - amount,
      gold_coins = gold_coins + amount,
      updated_at = now()
  where user_id = auth.uid() and diamonds >= amount;
  if not found then
    raise exception 'insufficient_diamonds';
  end if;
  return query select m.gold_coins, m.diamonds from public.saki_account_modules m where m.user_id = auth.uid();
end;
$$;
revoke all on function public.convert_diamonds_to_gold(bigint) from public;
grant execute on function public.convert_diamonds_to_gold(bigint) to authenticated;
