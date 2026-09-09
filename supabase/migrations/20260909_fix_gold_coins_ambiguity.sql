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

  update public.saki_account_modules as m
  set diamonds = m.diamonds - amount,
      gold_coins = m.gold_coins + amount,
      updated_at = now()
  where m.user_id = auth.uid()
    and m.diamonds >= amount;

  if not found then
    raise exception 'insufficient_diamonds';
  end if;

  return query
    select m.gold_coins as gold_coins,
           m.diamonds as diamonds
    from public.saki_account_modules as m
    where m.user_id = auth.uid();
end;
$$;

create or replace function public.send_room_gift(
  p_room_id uuid,
  p_recipient_id uuid,
  p_gift_id uuid,
  p_quantity integer default 1
)
returns table(
  gold_coins bigint,
  gift_name text,
  total_price bigint,
  recipient_diamonds bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  g room_gift_catalog%rowtype;
  v_total bigint;
  v_reward bigint;
  sender_ok boolean;
  recipient_ok boolean;
begin
  if p_quantity is null or p_quantity < 1 or p_quantity > 99 then
    raise exception 'invalid_quantity';
  end if;

  select * into g
  from public.room_gift_catalog
  where id = p_gift_id and is_active = true;

  if g.id is null then
    raise exception 'gift_not_found';
  end if;

  select exists(
    select 1 from public.room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) into sender_ok;

  select exists(
    select 1 from public.room_members
    where room_id = p_room_id and user_id = p_recipient_id
  ) into recipient_ok;

  if not sender_ok then raise exception 'sender_room_member_required'; end if;
  if not recipient_ok and p_recipient_id <> auth.uid() then
    raise exception 'room_member_required';
  end if;

  v_total := g.price * p_quantity;
  v_reward := floor(v_total * 0.60);

  update public.saki_account_modules as m
  set gold_coins = m.gold_coins - v_total,
      updated_at = now()
  where m.user_id = auth.uid()
    and m.gold_coins >= v_total;

  if not found then raise exception 'insufficient_gold'; end if;

  insert into public.saki_account_modules(user_id, diamonds)
  values (p_recipient_id, v_reward)
  on conflict(user_id) do update
    set diamonds = public.saki_account_modules.diamonds + excluded.diamonds,
        updated_at = now();

  insert into public.room_gifts(
    room_id, sender_id, recipient_id, gift_id, quantity,
    total_price, recipient_diamonds
  ) values (
    p_room_id, auth.uid(), p_recipient_id, p_gift_id, p_quantity,
    v_total, v_reward
  );

  insert into public.room_gift_inventory(user_id, gift_id, quantity)
  values (p_recipient_id, p_gift_id, p_quantity)
  on conflict(user_id, gift_id) do update
    set quantity = public.room_gift_inventory.quantity + excluded.quantity;

  insert into public.gift_announcements(
    room_id, sender_id, recipient_id, gift_id, total_price, recipient_diamonds
  ) values (
    p_room_id, auth.uid(), p_recipient_id, p_gift_id, v_total, v_reward
  );

  return query
    select m.gold_coins as gold_coins,
           g.name as gift_name,
           v_total as total_price,
           v_reward as recipient_diamonds
    from public.saki_account_modules as m
    where m.user_id = auth.uid();
end;
$$;

revoke all on function public.convert_diamonds_to_gold(bigint) from public;
grant execute on function public.convert_diamonds_to_gold(bigint) to authenticated;
revoke all on function public.send_room_gift(uuid, uuid, uuid, integer) from public;
grant execute on function public.send_room_gift(uuid, uuid, uuid, integer) to authenticated;
