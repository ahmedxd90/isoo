do $$
declare
  fn record;
  definition text;
  rewritten text;
begin
  for fn in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proname in (
        'purchase_trace_store_item',
        'gift_vip',
        'saki_wheel_place_bet',
        'saki_vip_slot_spin',
        'saki_store_buy'
      )
  loop
    select pg_get_functiondef(fn.oid) into definition;
    rewritten := definition;

    rewritten := replace(
      rewritten,
      'select gold_coins into balance from public.saki_account_modules where user_id = auth.uid() for update',
      'select m.gold_coins into balance from public.saki_account_modules as m where m.user_id = auth.uid() for update'
    );
    rewritten := replace(
      rewritten,
      'update public.saki_account_modules set gold_coins = gold_coins - item.price_gold_coins, updated_at = now() where user_id = auth.uid()',
      'update public.saki_account_modules as m set gold_coins = m.gold_coins - item.price_gold_coins, updated_at = now() where m.user_id = auth.uid()'
    );
    rewritten := replace(
      rewritten,
      '(select gold_coins from public.saki_account_modules where user_id = auth.uid())',
      '(select m.gold_coins from public.saki_account_modules as m where m.user_id = auth.uid())'
    );
    rewritten := replace(
      rewritten,
      'update saki_account_modules set gold_coins = gold_coins - cost,',
      'update saki_account_modules as m set gold_coins = m.gold_coins - cost,'
    );
    rewritten := replace(
      rewritten,
      'where user_id = auth.uid() and gold_coins >= cost',
      'where m.user_id = auth.uid() and m.gold_coins >= cost'
    );
    rewritten := replace(
      rewritten,
      'update saki_account_modules set gold_coins=gold_coins-p_amount,updated_at=now() where user_id=auth.uid() and gold_coins>=p_amount',
      'update saki_account_modules as m set gold_coins=m.gold_coins-p_amount,updated_at=now() where m.user_id=auth.uid() and m.gold_coins>=p_amount'
    );
    rewritten := replace(
      rewritten,
      'update public.saki_account_modules set gold_coins=gold_coins-p_wager,updated_at=now() where user_id=auth.uid() and gold_coins>=p_wager',
      'update public.saki_account_modules as m set gold_coins=m.gold_coins-p_wager,updated_at=now() where m.user_id=auth.uid() and m.gold_coins>=p_wager'
    );
    rewritten := replace(
      rewritten,
      'select gold_coins into v_balance from public.saki_account_modules where user_id=auth.uid()',
      'select m.gold_coins into v_balance from public.saki_account_modules as m where m.user_id=auth.uid()'
    );
    rewritten := replace(
      rewritten,
      'update saki_account_modules set gold_coins=gold_coins-p.price,updated_at=now() where user_id=auth.uid() and gold_coins>=p.price',
      'update saki_account_modules as m set gold_coins=m.gold_coins-p.price,updated_at=now() where m.user_id=auth.uid() and m.gold_coins>=p.price'
    );

    if rewritten <> definition then
      execute rewritten;
    end if;
  end loop;
end;
$$;
